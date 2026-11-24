# SWHARTANAH-358 — Construction Management > Report > Print report trắng trang (chỉ user NURAIN)

- Client: SWHARTANAH (server `c:\Ifcasoftware\Hartanah_Live`, local `E:\IFCA Software\SWHARTANAH_LIVE`)
- Trạng thái: FIXED Live (server) 2026-11-24 — Gunner đã áp + test OK, chờ consultant xác nhận
- Report thử: `PM_ProjectCostAnalysisByActivity` (lỗi áp cho MỌI report đi qua `Common/RdlCommControl.ascx`)

## Triệu chứng
- Chỉ login `NURAIN` in report ra trang trắng; user khác OK.
- Console: `Uncaught SyntaxError: missing ) after argument list`.
- View page source: `alert('System.Web.Services.Protocols.SoapException ... SqlException: Incorrect syntax near 'AIN'. Unclosed quotation mark ...')`. Report thật đã render (`TotalPages: 28`) — trắng chỉ vì JS hỏng.

## Root cause (đã xác nhận: stack trace thật + code server)
Call chain:
1. `Common/RdlCommControl.ascx.cs` Page_Load dòng 193: path `System Documents/Report History/<Company>_<CompanyID>/<EmpName>_<UserId>`, `EmpName` = `SysContext.CurrentEmpName` (tên employee, không phải login ID) — tên có dấu `'` (NUR'AIN…).
2. Dòng 196 `DocumentLibrary.UploadFile` (`App_Code/DocumentLibrary.cs:529`) → web service FileServer `Service1.UploadFile` → `FileBLL.CreateNOExistFolder` → `FileBLL.GetFolderIdByPath` (DocumentCenter, DLL riêng, không có source) ghép path vào SQL → lỗi cú pháp.
3. `catch` dòng 211 `alert('{0}')` với `ex.ToString()` không escape → JS vỡ → trắng trang.
- Lỗi thứ 2 nằm chờ: INSERT `CF_ReportHistory` dòng 203–204 cũng ghép `currentEmpName`.

## So TFS
- TFS Live `Rel\IFCA.NET 4.0\Source\PropertyNet\Common\RdlCommControl.ascx.cs` (2026-11-24, mức B): ĐÃ có fix `SysContext.CurrentEmpName = SysContext.CurrentEmpName.ToString().Replace("'", "''");` (không tag Jira) + bỏ qua `AP_CreditorLedgerDetailByTrxDate`; nhưng THIẾU MYMULTI-2202 (null-check EmpName/UserId) mà server Hartanah có → không chép đè.
- TFS Dev `Dev\BRANCHES\NET4.0_REL\PropertyNet\Common\RdlCommControl.ascx.cs`: đã BỎ hẳn khối upload Report History (thay `LogParamters()`, có TRINITY-478) → không dính bug.
- Kết luận: lệch deploy. Không commit TFS.

## Fix (đã áp server Hartanah_Live)
File `Common\RdlCommControl.ascx.cs`, thêm SAU dòng 190 (`try { currentUserId = ... }`):
```csharp
                    // SWHARTANAH-358 start
                    // Port TFS Live fix: escape apostrophe in employee name (e.g. NUR'AIN) used in Report History path SQL
                    currentEmpName = currentEmpName.Replace("'", "''");
                    // SWHARTANAH-358 end
```
Dùng biến cục bộ thay vì gán ngược `SysContext.CurrentEmpName` như TFS (tránh nghi ngờ nhân đôi dấu nháy mỗi lần in nếu giá trị giữ theo session — giả thuyết, chưa kiểm). Fix cả upload folder lẫn INSERT `CF_ReportHistory`.

## Test
- NURAIN in lại report → hiện bình thường (Gunner test OK 2026-11-24).
- User khác vẫn OK.

## Bài học
- Trắng trang + SyntaxError ở report = đọc `alert('...')` trong View page source trước (lần 2 sau PLBPG-62).
- Bug "chỉ 1 user" → nghĩ ngay tới dữ liệu riêng của user (tên có `'`) bị ghép chuỗi SQL/JS.
- Đề xuất gốc: encode message trong `alert` (`HttpUtility.JavaScriptStringEncode`) — ghi ở `de-xuat-sua-tan-goc.md` mục 7.

## Changeset TFS
| Nhánh | Changeset | Ngày | File/object | Ghi chú |
|---|---|---|---|---|
| `$/Property/Rel/IFCA.NET 4.0` | không commit | 2026-11-24 | `Source/PropertyNet/Common/RdlCommControl.ascx.cs` | Fix đã có sẵn trên TFS Live (changeset gốc chưa tra — `tf history`); chỉ port 1 dòng lên server Hartanah_Live `Common\RdlCommControl.ascx.cs` |
| `$/Property/Dev/BRANCHES/NET4.0_REL` | không commit | 2026-11-24 | `PropertyNet/Common/RdlCommControl.ascx.cs` | Dev đã bỏ khối upload Report History, không dính bug |

## Note Jira (EN)
**Tech:** Root Cause: The employee name of user NURAIN contains an apostrophe. When printing, Common/RdlCommControl.ascx.cs saves a copy of the report to Report History using a folder path that includes the employee name; the FileServer service builds its SQL by string concatenation (GetFolderIdByPath), so the apostrophe causes "Incorrect syntax near 'AIN'". The error text is then written into an unescaped JavaScript alert, which breaks the page script and leaves the report page blank. Fix: No new TFS commit - the fix already exists in TFS Live (Rel\IFCA.NET 4.0\Source\PropertyNet\Common\RdlCommControl.ascx.cs) but was not deployed to Hartanah. Ported only that fix to the server file c:\Ifcasoftware\Hartanah_Live\Common\RdlCommControl.ascx.cs (Page_Load, before building the Report History path): currentEmpName = currentEmpName.Replace("'", "''"); marked with SWHARTANAH-358. The whole TFS file was not copied, because the server file has a customization (MYMULTI-2202) that TFS Live does not have. Status: Applied on Hartanah Live and tested OK with user NURAIN and another user; please re-test.

**Non-tech:** Root Cause: User NURAIN's name contains an apostrophe ('), which the system did not handle when saving the report history, so the report page showed blank for this user only. Fix: Applied the existing standard fix (from TFS) to the report print page on Hartanah Live (file Common/RdlCommControl.ascx.cs), so names with an apostrophe are handled correctly. Status: Fixed on Live and tested OK; please ask the user to try printing again.
