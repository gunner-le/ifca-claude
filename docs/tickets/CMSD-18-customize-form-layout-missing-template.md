# CMSD-18 — Customize Form Layout: Missing template (Account Management)

- **Client:** CMSD (DB `CMSD_Train`, site `CMSP_Train`; source CMSD clone từ NAIMCAP)
- **Module:** Property Sales > Opportunity Management > Account Management
- **Ngày:** 2026-10-21
- **Trạng thái:** Đã fix & test OK trên Train (deploy lại view). Cần kiểm tra/deploy view tương tự cho Live.

## Triệu chứng
Account Management → mở account (popup *Purchaser Registration*, `Tenancy/CustomerTab.aspx`) → icon cam cạnh tiêu đề → **Customize Form Layout** → popup *Configure Form View* (`Common/SysTabEdit.aspx`). Dropdown Form Name = "Customer Information" nhưng grid (Form Name / No. of Column To Display) **rỗng** → "Missing template".

## Điều tra
1. Giả thuyết ban đầu: thiếu `Sys_TabClass` cho `PS.OppAccount`/`PS.OppContactInfo` (2 TabNo tên "Customer Information", không có dòng `Sys_TabClass`). **SAI** — không phải form đó; không chạy script insert.
2. Chạy local (cùng DB `CMSD_Train`, source local): mở Edit account báo exception tại `SysTabEdit1.FindControl(...)` trong `CustomerTab.aspx.cs`:
   `System.ArgumentException: Column 'MigratedProfession' does not belong to table Table.`
3. Trace config:
   - `Sys_BaseDt`: `BdtBseNo='PS.Account'`, `BdtFldName='MigratedProfession'`, `BdtTabDisplay='1'`.
   - `Sys_Base` `PS.Account`: `BseReadTable = View_PS_Customer`, `BseWriteTable = CF_Account`.
   - Cột `MigratedProfession` CÓ trong `CF_Account` nhưng `View_PS_Customer` KHÔNG select cột này.
4. Script view NAIMCAP (`$/Property/Dev/BRANCHES/NET4.0_REL/E-Invoice Client Deployment/NAIMCAP/Deployment Package/Database/Views/View_PS_Customer.sql`) đã có cột này.
5. Deploy view NAIMCAP lên local và server Train → Configure Form View hiện template **Customer Information / 2**, Edit (*Column Layout*) hiện đủ field; test Save đổi layout OK.

## Root cause
Gói deploy E-Invoice (clone từ NAIMCAP) lên CMSD chạy thiếu view `View_PS_Customer`: đã có cột `CF_Account.MigratedProfession` + dòng `Sys_BaseDt` (`PS.Account`, `BdtTabDisplay='1'`) nhưng view đọc của Base `PS.Account` chưa select cột → engine dựng form/layout theo Base `PS.Account` lỗi thiếu cột. Màn Configure Form View nuốt lỗi nên grid rỗng (trông như "missing template"); trên local (debug) lộ exception.

## Fix
Deploy lại `View_PS_Customer` theo bản NAIMCAP (có `,b.MigratedProfession`). Không cần sửa code, không patch `Sys_TabClass`.

## Việc còn lại
- Kiểm tra Live CMSD: `sp_helptext 'View_PS_Customer'` — nếu chưa có `MigratedProfession` thì deploy view.
- Đối chiếu danh sách object trong `Deployment Package/Database` của NAIMCAP với những gì đã chạy cho CMSD — có thể còn object khác bị sót.

## Kiến thức rút ra
- Customize Form Layout: icon cam cạnh tiêu đề popup edit → menu "Customize Form Layout / Feedback" → `Common/SysTabEdit.aspx` (grid section: tên + số cột) → Edit/Add mở `Common/SysTabEditSet.aspx` (*Column Layout*: Name, Column No., Available/Selected Columns, Required Field). Dropdown Form Name chỉ liệt kê form có trên trang đang mở.
- Lỗi `Column 'X' does not belong to table Table` khi mở form `SysTabEdit` = `Sys_BaseDt` của Base có field (BdtTabDisplay='1') mà `BseReadTable` (view) không có cột → thường do deploy thiếu view.
- Màn có thể nuốt exception này → triệu chứng chỉ là "rỗng". Khi màn config/layout rỗng bất thường, debug local để lộ exception trước khi nghi thiếu config.
- Tiêu đề "Personal"/"Profile 1" trên popup = tên profile Edge, không phải layout theo user.

## Jira note (English)
**Root Cause:** The E-Invoice deployment package (cloned from NAIMCAP) was only partially applied to CMSD. Column `CF_Account.MigratedProfession` and its field definition (`Sys_BaseDt`, base `PS.Account`, displayed on form) exist, but the read view of that base, `View_PS_Customer`, was not updated and does not return this column. When the Configure Form View screen (Customize Form Layout) builds the form layout from base `PS.Account`, it fails on the missing column and the template list comes up empty.

**Fix:** Redeployed `View_PS_Customer` from the E-Invoice deployment package (includes `MigratedProfession`). No code change required.

**Status:** Fixed and tested on Train — "Customer Information" template now shows and layout changes save correctly. Pending: verify/deploy the same view on Live.
