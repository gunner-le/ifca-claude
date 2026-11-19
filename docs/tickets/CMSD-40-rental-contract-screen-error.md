# CMSD-40 — Rental Management > Contract Management: screen error

- **Client:** CMSD (DB `CMSD_Train`, site `CMSD_Train`; source clone từ NAIM/NAIMCAP, giữ tên page/view customize `_NAIMCAP`)
- **Module:** Rental Management > Contract Management > Contract Management (`Tenancy/...`, form edit `Tenancy/RentalAddedDetail.aspx`)
- **Ngày:** 2026-10-27
- **Trạng thái:** Đã fix & test OK trên Train. Cần kiểm tra/áp dụng tương tự cho Live CMSD.

## Lỗi 1 — Mở màn hình: Compilation Error

### Triệu chứng
Mở Contract Management → yellow page `CS0246: The type or namespace name 'ICallbackEventHandler' could not be found`, Source File `Tenancy\RentalSignUpframe.aspx.cs` line 3.

### Root cause
- `RentalSignUpframe.aspx.cs` chỉ có `using System;` nhưng class implement `ICallbackEventHandler` (namespace `System.Web.UI`).
- Site là Web Site project (CodeFile) → ASP.NET biên dịch batch cả thư mục `Tenancy\` thành 1 assembly → 1 file lỗi làm chết MỌI trang trong thư mục (kể cả trang Contract Management không liên quan file này).

### Fix
```csharp
using System;
// CMSD-40 start
using System.Web;
using System.Web.UI;
// CMSD-40 end

public partial class Tenancy_RentalSignUpframe : IFCA.Web.UI.Page, ICallbackEventHandler
```

## Lỗi 2 — Bấm Edit contract: Column 'TaxExempt' does not belong to table Table

### Triệu chứng
`RentalAddedDetail.aspx` → `SysTabEdit2_CustomControlsCreated` → `SetDefaultCompany` → `SysTabEdit1.FindControl(...)` kích hoạt `SysTabEdit.BuildForm` → `GetValueByColumnName("TaxExempt")` → `ArgumentException`.

### Điều tra
1. Base khai báo `TaxExempt` mà view đọc không có cột: `RT.RentalTenancy_NAIMCAP` → `View_RT_RentalTenancy_NAIMCAP` (`ViewHasCol = N`).
2. So 2 DB:
   - `Naim_TC_Live`: cả `View_RT_RentalTenancy` (92 cột) và `View_RT_RentalTenancy_NAIMCAP` (96 cột) đều KHÔNG có `TaxExempt`; config Sys_ cũng KHÔNG có field `TaxExempt` → NAIM không lỗi.
   - `CMSD_Train`: `View_RT_RentalTenancy` bản chuẩn đã deploy bản mới (15/10/2026, 95 cột, có `TaxExempt`); `View_RT_RentalTenancy_NAIMCAP` vẫn bản NAIM (96 cột, không có).
   - `CMSD_Train` có `Sys_BaseDt` + `Sys_TabDt` field `TaxExempt` cho CẢ `RT.RentalTenancy` lẫn `RT.RentalTenancy_NAIMCAP`.
3. Field config có nhưng view `_NAIMCAP` thiếu: `TaxExempt` (LC, display 1), `TaxExemptDesc` (T, display 1), `TaxExemptStringCode` (LC, display 0, relation `TaxExempt`).
4. View chuẩn lấy 3 cột này từ `CF_Account AS B` (join qua `AR_Debtor.AccountID`); view `_NAIMCAP` cũng có join `CF_Account AS B`.

### Root cause
Gói update tính năng Tax Exempt (Rental) chạy lên CMSD đã thêm config Sys_ cho cả Base chuẩn và Base customize `RT.RentalTenancy_NAIMCAP`, nhưng chỉ cập nhật view chuẩn `View_RT_RentalTenancy`, không cập nhật view customize `View_RT_RentalTenancy_NAIMCAP` → engine `SysTabEdit` dựng form không tìm thấy cột.

### Fix
`ALTER VIEW View_RT_RentalTenancy_NAIMCAP` — chèn trước mệnh đề FROM chính (`FROM dbo.RT_RentalContract INNER JOIN ...`):
```sql
    --CMSD-40 start
    ,B.TaxExempt, B.TaxExemptDesc, 'Common' + B.TaxExempt AS TaxExemptStringCode
    --CMSD-40 end
```
Không sửa code, không xoá config (xoá config thì lần deploy gói sau sẽ lại lỗi).

### Kết quả test
Train: mở màn hình OK, Edit contract OK — Gunner confirm 2026-10-27.

## Việc còn lại
- Live CMSD: kiểm tra `RentalSignUpframe.aspx.cs` và view `View_RT_RentalTenancy_NAIMCAP` trước khi deploy.
- Cùng dạng lỗi còn tiềm ẩn ở các Base khác (kết quả quét `TaxExempt` trên CMSD_Train): `RT.Account` → `View_PS_Customer`, `AR.AdjustmentListView` → `View_PS_ArBill`, `RT.AR_Trx_NAIMCAP` → `View_RT_Ar_Trx_NAIMCAP` đều thiếu cột `TaxExempt` → các màn dùng các Base này sẽ lỗi tương tự khi mở form.

## Kiến thức rút ra
- **CodeFile batch compile:** 1 file `.cs` lỗi compile làm chết mọi trang cùng thư mục — file trong thông báo lỗi có thể không phải trang đang mở.
- **Lệch config Sys_ ↔ view sau khi clone/deploy gói** (đã gặp CMSD-18, CMSD-40): lỗi `Column 'X' does not belong to table Table` từ `SysTabEdit.BuildForm`/`GetValueByColumnName` = `Sys_BaseDt` khai báo field mà `BseReadTable` không có. Gói update bản chuẩn có thể thêm config cho cả Base `_<CLIENT>` nhưng không cập nhật view `_<CLIENT>`. Query quét toàn bộ lệch của 1 Base:
```sql
SELECT bd.BdtBseNo, b.BseReadTable, bd.BdtFldName, bd.BdtTabDisplay
FROM Sys_BaseDt bd
JOIN Sys_Base b ON b.BseNo = bd.BdtBseNo
WHERE bd.BdtBseNo = '<BseNo>'
  AND NOT EXISTS (SELECT 1 FROM sys.columns c
                  WHERE c.object_id = OBJECT_ID(b.BseReadTable)
                    AND c.name = bd.BdtFldName);
```

## Jira note (English)
**Root Cause:**
1. Compilation error: `Tenancy/RentalSignUpframe.aspx.cs` implements `ICallbackEventHandler` but is missing `using System.Web.UI;`. Since the Tenancy folder is compiled as one batch, this broke every page in that folder, including Contract Management.
2. Edit contract error "Column 'TaxExempt' does not belong to table Table": the Tax Exempt update added Sys_ config fields (TaxExempt, TaxExemptDesc, TaxExemptStringCode) to both the standard base `RT.RentalTenancy` and the customized base `RT.RentalTenancy_NAIMCAP`, but only the standard view `View_RT_RentalTenancy` was updated. The customized view `View_RT_RentalTenancy_NAIMCAP` did not return these columns, so the form failed to build.

**Fix:**
1. Added `using System.Web; using System.Web.UI;` to `RentalSignUpframe.aspx.cs`.
2. Altered `View_RT_RentalTenancy_NAIMCAP` to add `B.TaxExempt, B.TaxExemptDesc, 'Common' + B.TaxExempt AS TaxExemptStringCode` (from CF_Account), same as the standard view.

**Status:** Fixed and tested OK on Train. To be applied on Live.
