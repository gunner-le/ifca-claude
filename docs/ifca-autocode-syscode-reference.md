# IFCA — Auto Code / Number Structure (SysCode) — kiến thức dùng chung

Bổ sung cho mục `SysCode` trong `ifca-domain-reference.md`. Áp dụng mọi client (cơ chế framework chuẩn, `IFCA.Web.AutoCode.dll`). Xác nhận qua code decompile thật + data 3 DB khác nhau (2026-10-16, lỗi Save Menu Template).

## Luồng code

`new SysCode(docCodeNo, DocAnchorType, anchorID, ...)` → `new SysCodeTemplate(docCodeNo, anchorID, ...)` → `GenerateCode()` → `SysCodeEntity.Code` (= `SysCode.ToString()`).

- **`DocAnchorType` bị BỎ QUA hoàn toàn** — chỉ `docCodeNo` + `anchorID` (CompanyID) có tác dụng.
- `GetDocCodeId(docCodeNo)` qua `CF_DocCode` — không tìm thấy → throw `"Invalid DocCodeNo"` (exception, KHÔNG ra code rỗng).
- **`GetCompanyID(anchorID)`** resolve company dùng format:
  1. `anchorID = 0` → top company (`Application["SystemOwnerID"]`, hoặc `CF_Company`+`CF_Account.IsSystemOwner='Y'` khi không có HttpContext).
  2. Company có dòng trong `View_CF_DocCode` cho DocCode đó → dùng luôn.
  3. Không có → leo `CF_Company.ParentCompanyID` đệ quy; hết parent → top company.
- `InitList()` nạp format: `select * from View_CF_DocCode where DocCodeID=.. and CompanyID=.. order by FormatOrder`; resource ngoài từ `CF_DocCodeResource`; filter từ `CF_DocCodeFilter`.
- **`GenerateCode()` trả `Code = ""` (KHÔNG exception) khi không có dòng format nào** (`_lstAllResource.Count <= 0`) → triệu chứng điển hình: màn hình check `string.IsNullOrEmpty(code.ToString())` báo lỗi "chưa setup auto code". Nếu format không có Serial → trả luôn chuỗi constant/date.
- Có Serial → gọi SP `Proc_CF_GetAutoCode` (override được bằng `CF_Parameter.Name='Proc_CF_GetAutoCode_SPS'`), tham số: DocCodeID, CompanyID, SDocCodeNo (template `...{0}...`), TableName, CodeField, IsSerialFixed, CodeWidth, Padded, SerialFilter → `@Result` = số serial. Running number/lock ở `CF_DocCodeTemp` (Status Free/Locked/Used, SerialFilter).
- Fixed=Y → serial pad trái theo CodeWidth; N → số trần.

## Bảng

| Bảng | Vai trò / cột chính |
|---|---|
| `CF_DocCode` | Định nghĩa 1 loại số: `DocCodeID, ApplicationID, DocCodeNo` (vd `017`), `DocCodeName`, `DocStringCode` (`AutoCode<No>`), `Resource` (resource cho phép, vd `serial,constant`), `IsApply, SerialFilter, SerialFixed, TableName, PrimaryKey, CodeField, DateField, RecordStatus, DocType` |
| `CF_DocCodeFormat` | Từng phần cấu trúc số, theo company: `DocCodeFormatID, CompanyID, DocCodeID, Name` (`serial`/`constant`/`year`/`month`/`day`/resource), `FormatOrder, Description, Jan..DecSpelling, Format` (giá trị constant), `CodeWidth, Padded, BaseOnNo, RecordStatus, Create/Modify...` — **KHÔNG có cột IsSerialFixed** (view lấy từ nơi khác) |
| `View_CF_DocCode` | View code đọc: có thêm `IsSerialFixed`, chỉ format Active |
| `CF_DocCodeResource` / `CF_DocCodeBaseOn` / `CF_DocCodeFilter` | Resource ngoài (map field trang), base-on, filter reset serial theo năm/tháng... |
| `CF_DocCodeTemp` | Running serial/lock |

## Setup qua UI

**System Setup > Number Structure** (`/System/SysAutoCodeAM.aspx`): Company Navigator (trái trên) chọn company → cây module (trái dưới) chọn loại số → Add: Resource (Serial Number/Constant...), Length of Number, Padding Character, Fixed Length. Cây nhóm theo `CF_DocCode.ApplicationID`; DocCode của module `Common` (ApplicationID 20, `ShowInMenu='N'`) vẫn hiện trong cây (vd "Menu Template No", "Menu No", "Position No", "RPT No"...).

## Query chẩn đoán

```sql
SELECT d.DocCodeID, d.DocCodeNo, d.IsApply, d.RecordStatus AS DocCodeStatus,
       v.CompanyID, c.ParentCompanyID, v.FormatOrder, v.Name AS Resource,
       v.CodeWidth, v.Padded, v.IsSerialFixed, v.Format AS ConstantValue
FROM CF_DocCode d
LEFT JOIN View_CF_DocCode v ON v.DocCodeID = d.DocCodeID
LEFT JOIN CF_Company c      ON c.CompanyID = v.CompanyID
WHERE d.DocCodeNo = '<No>'
ORDER BY v.CompanyID, v.FormatOrder;
-- v.* NULL hết => chưa setup Number Structure
```

## Case đã gặp: DocCode `017` — Menu Template No (2026-10-16)

- Màn hình `System/SysMenuTemplateAM.aspx.cs` `Save()`: `new SysCode("017", DocAnchorType.Company, Application["SystemOwnerID"])` → **luôn anchor SystemOwner**, không theo company user → format ở company con KHÔNG bao giờ được dùng cho màn này.
- Lỗi: DB không có dòng `CF_DocCodeFormat` nào cho 017 → code rỗng → popup "undefined".
- **Bug phụ "undefined"**: nhánh check gọi `sys_error('<msg>')` 1 tham số, nhưng `sys_error(title, message)` cần 2 → message = undefined. Fix: `sys_error('" + Strings.GetString("ErrorMessage") + "','" + Message.FormatMessage(Strings.GetString("NoMenuTempleteNoOfAutoCode")) + "')`. → Gặp popup "undefined" ở chỗ khác: kiểm tra số tham số `sys_error` trước.
- Fix data: Number Structure Menu Template No = Serial, Length 8, Pad `0`, Fixed Yes tại SystemOwner (CompanyID 1) → `0000000x`, khớp template sẵn `00000001`.
- Tham chiếu client khác: (a) Serial width 10 pad 0 tại Company 1; (b) Constant `0` + Serial 7 tại Company 1 (= `0000000x`), company con 181–186 có `MT`+Serial 4/6 (thừa, không dùng).
