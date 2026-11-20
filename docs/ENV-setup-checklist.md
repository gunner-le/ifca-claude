# IFCA — Checklist lỗi setup môi trường mới (local/Train) — dùng chung mọi client

Ghi lại các lỗi gặp khi dựng môi trường mới (restore DB + source của 1 client về máy local/Train). Lỗi dạng này thường KHÔNG phải bug code/data nghiệp vụ. Nhận diện nhanh để không mất thời gian điều tra sai hướng.

Nguồn: đợt setup môi trường CMSD (`CMSP_Train`, company TAIBAH), 2026-10-19 → 2026-10-21; mục 4 bổ sung 2026-10-29 (clone NAIMPS → CMSD_Train); mục 5 bổ sung 2026-11-12 (dựng server mới CMSD tách 2 máy WEB/DB: Train/UAT/Live).

> **Dựng server mới cho 1 client → đọc mục 5 trước** (checklist theo thứ tự + bảng lỗi hay gặp). Mục 1–4 là chi tiết từng lỗi cụ thể.

---

## 1. Report (SSRS Server Report) báo `HTTP status 503: Service Unavailable` khi mở màn hình

**Triệu chứng:** mở màn hình report (ví dụ Property Sales > Sales Administration > Monthly Sales Report) thì ra yellow page ngay, chưa cần bấm Preview:
```
System.Net.WebException: The request failed with HTTP status 503: Service Unavailable.
Common/RdlCommControl.ascx.cs line 217:
foreach (RenderingExtension extension in ReportViewer1.ServerReport.ListRenderingExtensions())
...RSExecutionConnection.GetSecureMethods()
```
`RdlCommControl` (ReportViewer Remote mode) gọi `ListRenderingExtensions()` ngay lúc Load để dựng danh sách Export, nên lỗi SSRS lộ ra ngay khi mở trang.

**Kiểm tra:** mở thẳng `http://localhost/ReportServer`. Nếu cũng báo `HTTP Error 503. The service is unavailable.` (trang trắng của http.sys) thì URL vẫn được reserve (`netsh http show urlacl` có `http://+:80/ReportServer/`) nhưng service SSRS không chạy hoặc bị treo.

**Fix:** restart service **SQL Server Reporting Services** (`services.msc`). Nên đặt Startup type = Automatic (Delayed Start) để SSRS lên sau SQL Server.

Nếu restart vẫn không được: kiểm tra account trên URL reservation (`netsh http show urlacl url=http://+:80/ReportServer/`) có khớp account chạy service (`sc qc <service>` → `SERVICE_START_NAME`) không, và xem log `ReportServerService_*.log`.

### 1b. Biến thể: in report ra **trang trắng**, 503 nằm ở **FileServer** (không phải SSRS) — PLBPG-62, 2026-11-20

**Triệu chứng:** bấm in (vd AR invoice qua `CashFlow/ACPaymentListPrint.aspx?ReportName=...`) → trang trắng, Console chỉ báo `Uncaught SyntaxError: Invalid or unexpected token` ở 1 dòng của HTML render (không bấm vào được). Xem bằng View page source / tab Network > Response thấy `alert('System.Net.WebException: ... HTTP status 503 ... FileServecies.Service1.UploadFile ... DocumentLibrary.UploadFile ... RdlCommControl.ascx.cs:line 191')`.

**Cơ chế:** `RdlCommControl.Page_Load` sau khi set parameter sẽ render thêm 1 bản Excel (`Render("EXCELOPENXML")`, dòng ~186 — bước này OK nghĩa là RDL/dataset chạy được) rồi upload vào "System Documents/Report History" qua File Service (`appSettings FileServecies.Url`, local thường `http://localhost/fileserver/File.asmx`). Upload lỗi → `catch` nhét stack trace nhiều dòng vào `alert('...')` không escape → hỏng JS → trang trắng.

**Fix:** bật lại site/App Pool `fileserver` trong IIS (bị tắt / pool Stopped). Kiểm tra nhanh: mở `FileServecies.Url` trên trình duyệt phải ra trang asmx. Không phải lỗi report, không cần sửa code.

## 2. Report báo `rsAccessDenied` cho `IIS APPPOOL\<AppPool>`

**Triệu chứng (sau khi SSRS đã chạy):**
`The permissions granted to user 'IIS APPPOOL\CMSP_Train' are insufficient for performing this operation. (rsAccessDenied)`

**Fix:** trên Report Manager (web portal):
- Folder report của site (ví dụ `CMSP_Train_Reports`) > Manage > Security > New Role assignment: `IIS APPPOOL\<tên App Pool>`, role **Browser** (đủ để xem/render).
- Nếu vẫn lỗi: Site Settings > Security > thêm cùng account với role **System User** (một số thao tác ReportViewer gọi lúc Load là cấp hệ thống).

**Gotcha:** gõ thừa dấu nháy `'` ở đầu tên user thì SSRS báo `The user or group name ''IIS APPPOOL\...' is not recognized.` Tên phải trùng chính xác tên App Pool trong IIS Manager. Virtual account `IIS APPPOOL\...` chỉ tồn tại trên máy chạy IIS (SSRS khác máy thì không add được).

## 3. Import Data > Download template báo "Template could not be found!"

**Màn hình gặp:** Property Sales > Post Sales > Contract Management > Download → popup `Common/ImportList.aspx` → Download.

### Cơ chế `Common/ImportList.aspx` (dùng chung cho mọi màn hình Import Data, mọi module)

- `ImportNo` = query string `ImportNo` (hoặc `TabNo`). URL popup có thể mã hoá (`?a=...`), không đọc trực tiếp được; muốn biết ImportNo thì debug.
- Config ở 2 bảng:
  - `Sys_ImportType`: `ImportType` (= ImportNo), `ImportTypeStringCode`, `FldUpdate` (câu SQL insert/update khi Import, placeholder `{FldName}`, `{USERID}`, `{AUTOCODE}`, `{@Filter}`), `TempletCmdText` (câu SELECT dữ liệu đổ vào template khi Download), `TempletFilter` (danh sách tên query string dùng làm filter, phân cách dấu phẩy; thay `@<filter>` trong SQL, hoặc nối thêm `and <filter>='<value>'`).
  - `Sys_ImportTypeDetail`: mỗi dòng = 1 cột template. Cột: `ImportType, FldName, FldType` (`S`, `D`, `FM`/`FQ`, `LYN` dropdown Y/N, `DDL` dropdown custom), `FldNameStringCode` (tiêu đề cột), `Sort`, `TempletIsWrite` (`Y` = tiêu đề có `*`), `DocCodeNo`, `IsReadOnly` (`Y` = khoá ô, sheet protect). **Bảng không có khoá chính.**
- **Download template KHÔNG đọc file Excel có sẵn** mà sinh động bằng Syncfusion XlsIO (`btnDownLoad_Click`): đọc config → chạy `TempletCmdText` → `WriteTitle` + `WriteFile` → `workbook.SaveAs("ImportFile.xls", Response)`.
- **Toàn bộ `btnDownLoad_Click` bọc trong `catch { }` không lấy exception.** Mọi lỗi đều hiện `S20071009002` = "Template could not be found!". Message không phản ánh nguyên nhân thật; muốn biết phải debug hoặc sửa tạm catch:
  ```csharp
  catch (Exception exDebug)
  {
      Message msg = new Message(Strings.GetString("S20071009002") + "<br>[DEBUG] ImportNo=" + ImportNo
          + "<br>" + HttpUtility.HtmlEncode(exDebug.Message) + "<br>SQL=" + HttpUtility.HtmlEncode(SQL));
      ...
  }
  ```
- Dropdown "Please Select" (`selSheet`) trên popup = danh sách sheet của file Excel sau khi Upload. Trống trước khi upload là bình thường.
- **Giới hạn code: hàm `RangeName(row, column)` chỉ map cột 1–26 (a–z).** Cột thứ 27 trở đi trả về `"1"` → Syncfusion ném `ArgumentException: name cannot be less then 2 symbols` → bị catch che thành "Template could not be found!". Trong `WriteFile` lỗi này bị catch rỗng nuốt (mất dữ liệu cột > 26 âm thầm). Code còn dùng cột `AZ`, `BA`, `BB`, `BC` làm vùng phụ cho dropdown, `AutofitColumns` hardcode `A1:M10000`.

### Root cause ở CMSD

`Sys_ImportTypeDetail` của `PS.PurchaserProfile` có 34 dòng thay vì 15: các field `BuyerPhone`, `Fax`, `IsGovOrAuth`, `TaxRegistrationNo` bị insert ×5, `IsForeignBuyer` ×4 (dòng giống hệt nhau). Nhiều khả năng script thêm field Buyer/e-Invoice không kiểm tra tồn tại và đã chạy nhiều lần trên DB này. Vượt 26 cột → lỗi `RangeName` như trên. `TempletCmdText` chạy bình thường.

### Fix

```sql
SELECT * INTO Sys_ImportTypeDetail_bak_CMSD_20261021
FROM Sys_ImportTypeDetail WHERE ImportType = 'PS.PurchaserProfile';

;WITH d AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY ImportType, FldName ORDER BY (SELECT NULL)) AS rn
    FROM Sys_ImportTypeDetail WHERE ImportType = 'PS.PurchaserProfile'
)
DELETE FROM d WHERE rn > 1;   -- 19 rows, còn 15 field
```
Kết quả: Download template OK.

### Kiểm tra nhanh khi gặp lại ở client khác

```sql
-- Loại import nào có > 26 field hoặc field trùng
SELECT ImportType, COUNT(*) AS FieldCount, COUNT(DISTINCT FldName) AS DistinctFld
FROM Sys_ImportTypeDetail
GROUP BY ImportType
HAVING COUNT(*) > 26 OR COUNT(*) <> COUNT(DISTINCT FldName);
```
- Có trùng → xoá trùng như trên (lỗi data/setup).
- Không trùng mà thật sự > 26 field → bug code `RangeName`. Fix đề xuất (chưa commit):
  ```csharp
  private string RangeName(int row, int column)
  {
      string sColumn = "";
      while (column > 0)
      {
          int mod = (column - 1) % 26;
          sColumn = (char)('a' + mod) + sColumn;
          column = (column - 1) / 26;
      }
      return sColumn + row.ToString();
  }
  ```

### Jira note (English)

**Root Cause:** The Download Template function in Contract Management (Import Data – `PS.PurchaserProfile`) failed with "Template could not be found!". `Sys_ImportTypeDetail` for `PS.PurchaserProfile` had duplicated field config rows: BuyerPhone, Fax, IsGovOrAuth and TaxRegistrationNo ×5, IsForeignBuyer ×4. That made 34 fields instead of 15. The template generator (`Common/ImportList.aspx.cs` → `RangeName`) supports only up to 26 columns (A–Z), so building the title row threw an exception, and the generic catch showed it as "Template could not be found!".

**Fix:** Removed the duplicated rows from `Sys_ImportTypeDetail` (19 rows deleted, 15 fields remain). Backup saved in `Sys_ImportTypeDetail_bak_CMSD_20261021`.

**Status:** Resolved. The template downloads successfully.

## 4. Trang list lỗi `NullReferenceException` tại `GridBuilderHelper.GetSortString` (clone source/DB giữa 2 client)

**Màn hình gặp:** CMSD_Train (clone từ NAIMPS), MCorp > AR Transaction > Billing — `McAccount/ARChargeBillList_NAIMCAP.aspx` (menu `mcorp-06-07`).

**Triệu chứng:** mở trang ra yellow page ngay khi grid bind:
```
NullReferenceException
IFCA.Framework.UI.Controls.GridBuilderHelper.GetSortString(String lstNo, Int32 lstOrder) +357
IFCA.Framework.UI.Controls.WebDataGridBuilder2.grid_CustomDataBinding(...)
```

### Cơ chế (dùng chung mọi client)

- `SysList2` / `SysCondition` / `SysToolbar` tra config bằng **đúng nguyên chuỗi** `LstNo` khai báo trên `.aspx` → `Sys_List.LstNo` + `Sys_ListDt.LdtLstNo`, theo cặp **(LstNo, LstOrder)** (`LdtLstOrder`). Không có dòng khớp → `GetSortString` trả null → NullReference. Framework không hiểu hậu tố `_<CLIENT>`; `_NAIMCAP` và `_CMSD` là 2 mã khác hẳn nhau.
- Tương tự: `MenuClass`/`MenuNo` → `Sys_ContextMenu`; `Sys_List.LstBseNo` → `Sys_Base.BseNo` → `Sys_BaseDt.BdtBseNo`; tên view hardcode trong code-behind phải tồn tại.
- **Quy ước khi clone source client A sang client B (đã chốt với Stanley cho CMSD):** chỉ đổi tên file DLL customize (`IFCA.Business.Customization.CMSD.dll`); code trong DLL, page, code-behind, view và config Sys_ **giữ nguyên tên client gốc** (`_NAIMCAP`). Đổi tên 1 phía (file hoặc DB) mà không đổi phía kia là lỗi.

### Root cause ở CMSD

File trang đã bị ai đó đổi tên sang CMSD (class `McAccount_ARChargeBillList_CMSD`, query `View_RT_Ar_Trx_CMSD`), trong khi DB không có bất kỳ object/config `_CMSD` nào (`Sys_List`, `Sys_ListDt`, `Sys_ContextMenu`, view đều = 0). Fix: lấy lại source NAIM nguyên bản (`ARChargeBillList_NAIMCAP`) → chạy OK.

Ghi nhận thêm trong lúc điều tra: trên NAIMPS trang này cũng lỗi y hệt (thiếu config `RT.AR_Trx_NAIMCAP`), bản chạy đúng là NAIM_TC. NAIM chia nhiều ứng dụng (NAIM_PS, NAIM_TC...) với config khác nhau. Khi trang clone từ NAIM_PS lỗi, nguồn để lấy config là app NAIM đang chạy đúng trang đó, chỉ copy đúng phạm vi của trang (không copy cả DB).

### Gotcha khi debug

- Debug trên Visual Studio dừng ở `ArgumentOutOfRangeException: startIndex cannot be larger than length of string` tại `ContextMnuNo.Substring(1)`: đây là first-chance exception trong `try { } catch { }` rỗng (do `Sys_ContextMenu` trả 0 dòng), **không phải lỗi làm sập trang**. Bấm Continue để tới lỗi thật.
- DB IFCA dùng collation `Chinese_PRC_CI_AS`, `tempdb` là `SQL_Latin1_General_CP1_CI_AS`, và các cột Sys_ có thể khác collation nhau → `Msg 468 collation conflict`. Thêm `COLLATE DATABASE_DEFAULT` cho cột bảng tạm và **cả 2 vế** mọi phép join/so sánh chuỗi.

### Query kiểm tra nhanh

```sql
DECLARE @LstNo nvarchar(100) = N'<LstNo>', @MnuClass nvarchar(100) = N'<MenuClass>', @MnuNo nvarchar(100) = N'<MenuNo>';
SELECT 'Sys_List' AS Item, COUNT(*) AS Cnt FROM Sys_List WHERE LstNo = @LstNo
UNION ALL SELECT 'Sys_ListDt', COUNT(*) FROM Sys_ListDt WHERE LdtLstNo = @LstNo
UNION ALL SELECT 'Sys_ContextMenu', COUNT(*) FROM Sys_ContextMenu WHERE MnuNo = @MnuNo AND MnuClass = @MnuClass;

-- Tìm file trang bị đổi tên sang client mới ngoài ý muốn (chạy ở thư mục source)
-- findstr /S /I /M "_CMSD" *.aspx *.cs *.ascx *.js
```

### Hệ quả khác của việc DB từng bị đổi tên `_NAIMCAP` → `_CMSD` rồi revert dở (CMSD_Train, 2026-10-29)

Script phân loại (quét `Sys_ListDt/Sys_List/Sys_BaseDt/Sys_Base/Sys_Tab/Sys_Select/Sys_ContextMenu/Sys_ContextMenuClass/Sys_Menu/CF_String` có `CMSD`, so với tên `REPLACE(CMSD→NAIMCAP)`) cho 2 loại:
- **Duplicate** (có cả 2 bản): KHÔNG xoá thẳng — bản `_CMSD` có thể chứa config mới hơn chỉ deploy vào bản CMSD (vd `PS.BillList_CMSD` 14 vs 12 button = thêm EmailEInvoice/PrintEInvoice; `PS.BillNotPay_CMSD` BaseDt 39 vs 32). Phải gộp phần chênh sang NAIMCAP trước rồi mới xoá (chưa làm).
- **CMSD only** (bị đổi tên, bản NAIMCAP mất): đổi tên/copy về NAIMCAP.

Đã xử lý:
1. **Button hiện `<code> - Please Translate`** (Unit Enquiry `sale-01-24` và 8 menu khác, nút `PrintJournal_NAIMCAP`): `Sys_ContextMenu.MnuStringCode` = `..._PrintJournal_NAIMCAP` nhưng `CF_String` chỉ còn `..._PrintJournal_CMSD`. Fix: copy `CF_String` sang tên NAIMCAP (chỉ code được `Sys_ContextMenu` tham chiếu), sau đó xoá bản `_CMSD` sau khi kiểm tra không còn tham chiếu.
2. **Refund Requisition and Approval (`PSAccount/ArRefundIndexList.aspx`, `Sale-11-10`) toolbar không có nút**: `.aspx` khai báo `PS.ArRefundindex` nhưng DLL customize (`clsArRefundIndexList.Init`) ghi đè `objToolbar.MenuClass = "PS.ArRefundindex_NAIMCAP"`; DB chỉ có `PS.ArRefundindex_CMSD` (16 nút). Fix: đổi tên về `_NAIMCAP`, giữ `ContextMenuID` (23422–23437) để không mất phân quyền. → Khi trang không hiện nút, kiểm tra cả DLL customize có ghi đè `MenuClass` không, không chỉ đọc `.aspx`.
   - **Gotcha FK:** `FK_Sys_ContextMenu_Sys_ContextMenuClass` trên `MnuClass` không cascade → đổi tên phải: INSERT dòng `Sys_ContextMenuClass` mới → UPDATE `Sys_ContextMenu` sang class mới → DELETE class cũ. Lỗi `Msg 547` không tự rollback transaction → `ROLLBACK` rồi chạy lại.
3. **Access Rights By Role báo `Column 'ContextMnuNo' does not belong to table Table`** (`System/SysPrivilegeContent.aspx.cs` line 258): query `ctxMenuTable` không select `c.ContextMnuNo`, nhưng nhánh `else` (button có `MnuStringCode` không có trong `CF_String`) lại đọc cột đó → bug code tiềm ẩn, lộ ra khi thiếu `CF_String`. Fix đề xuất: thêm `c.ContextMnuNo` vào 3 câu SELECT (`Cost-07-04`, else, `gl-69-09`) — chưa xác nhận đã áp dụng.

Ghi nhận ngoài phạm vi: nhóm chuẩn `PS.ArRefundindex` có 3 `PrintDraft` trùng (23410, 23807, 23836); `OnBeforeShowContextMenu` của trang Refund bật/tắt menu chuột phải theo index của danh sách NAIMCAP (16) trong khi grid dùng nhóm chuẩn (18) → có thể lệch (thiết kế sẵn của NAIM).

---

## 5. Checklist dựng server mới cho 1 client (WEB + DB tách 2 máy)

Nguồn: dựng CMSD 2026-11 — `DEV-IFCAWEB` (10.10.10.41, IIS) + `DEV-IFCADB` (10.10.10.42, SQL Server 2022 + SSRS), domain `cmsb.my` (NetBIOS `CMSB`), 3 môi trường Train/UAT/Live, domain public `https://ifca-propertydevelopment.cahyamata.com/live|train|uat`. Tên máy/IP/domain dưới đây chỉ là ví dụ của CMSD — thay theo client.

### 5.0 Thông tin cần hỏi IT/khách TRƯỚC khi bắt đầu

- Tên máy + IP của từng server; 2 máy **cùng domain** hay **workgroup** (`systeminfo | findstr /B /C:"Domain"`; tên NetBIOS: `net config workstation` → dòng *Workstation domain*).
- Domain public + **SSL certificate** (.pfx) do ai cấp; có **reverse proxy / load balancer / firewall** đứng trước IIS không (nếu có, cert có thể nằm ở thiết bị đó, IIS chỉ cần http/self-signed).
- License SQL Server (SSRS cài trên máy nào thì máy đó cần license SQL — cài chung máy DB là tiết kiệm nhất).
- Có giới hạn **RDP/VPN theo giờ** không (CMSD: buổi tối không RDP được — lỗi "This computer can't connect to the remote computer" là lỗi tầng mạng, không phải Logon Hours; test `Test-NetConnection <ip> -Port 3389`). Xin ngoại lệ nếu cần deploy ngoài giờ.

### 5.1 Máy DB — SQL Server

1. Bật **SQL Server and Windows Authentication mode** (Server Properties → Security) → restart service.
2. **Bật TCP/IP**: SQL Server Configuration Manager → Protocols for <instance> → TCP/IP = Enabled → Properties → IP Addresses → **IPAll**: TCP Dynamic Ports để trống, TCP Port = `1433` → restart service. Kiểm tra: `netstat -ano | findstr LISTENING | findstr :1433` phải ra `0.0.0.0:1433`.
3. **Firewall** (PowerShell Admin, chỉ mở cho LAN):
   ```powershell
   New-NetFirewallRule -DisplayName "SQL Server 1433 - LAN" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -RemoteAddress LocalSubnet
   ```
   Named instance thì thêm UDP 1434 + bật service **SQL Server Browser**.
4. **Login**:
   - 1 login admin (tương đương `sa`) dùng cho restore/deploy: `CREATE LOGIN ... ; ALTER SERVER ROLE [sysadmin] ADD MEMBER ...` — sysadmin tự là `dbo` ở mọi DB, kể cả DB restore sau này.
   - (Khuyến nghị) 1 login riêng cho connection string web với `db_owner` trên các DB IFCA (script vòng lặp `sys.databases WHERE database_id > 4`, có `ALTER USER ... WITH LOGIN` để nối user mồ côi). **db_owner KHÔNG tự áp cho DB tạo/restore sau** — DB `CREATE` mới thì thêm user vào DB `model`; DB **restore** phải chạy lại script cấp quyền (gắn vào cuối script restore).
   - CMSD hiện dùng login sysadmin `cmsd_admin` cho cả connection string (chưa tách).
5. Nếu `sa` không còn dùng: đặt password mạnh hoặc `ALTER LOGIN [sa] DISABLE` (kiểm tra không còn web.config/job/SSRS data source nào dùng `sa`).

### 5.2 Máy DB — Restore DB

```sql
USE [master];
GO
IF DB_ID(N'<DB>') IS NOT NULL ALTER DATABASE [<DB>] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
RESTORE DATABASE [<DB>] FROM DISK = N'<file.bak>'
WITH FILE = 1, MOVE N'<logical>' TO N'<path>', ..., NOUNLOAD, REPLACE, STATS = 5;
GO
IF DB_ID(N'<DB>') IS NOT NULL ALTER DATABASE [<DB>] SET MULTI_USER;   -- chạy cả khi restore lỗi
GO
```
- `Msg 3101 Exclusive access could not be obtained because the database is in use` → thiếu bước SINGLE_USER, hoặc app kết nối lại ngay. **Stop App Pool** site tương ứng trước khi restore, Start lại sau.
- Tên logical file: `RESTORE FILELISTONLY FROM DISK = N'<file.bak>'`. Bộ DB IFCA chuẩn R3.0 có ~10 file (IFCANet_R3_0, PropertyNetMasterTextImage, Standard_R3_0_Index_1..3, Standard_R3_0_DM_1..2, DM_Standard, 2 log) — mỗi DB phải MOVE sang tên file riêng (vd hậu tố `_CMSD_Uat`) để không trùng DB khác cùng instance.
- Restore bằng GUI SSMS: cột **Restore As** = nơi lưu thật (thư mục data mặc định của instance), **Original File Name** chỉ là vị trí trên server cũ. Kéo rộng cột hoặc Script ra xem đường dẫn đầy đủ.
- Sau restore: nối lại user mồ côi / cấp quyền login web (5.1 bước 4).
- **Collation**: DB IFCA là `Chinese_PRC_CI_AS`, `tempdb` thường `SQL_Latin1_General_CP1_CI_AS`, cột Sys_ có thể lệch nhau → bảng tạm `#temp` và mọi phép join chuỗi phải thêm `COLLATE DATABASE_DEFAULT` (cả 2 vế), nếu không `Msg 468 collation conflict`.
- DB Audit riêng (`IFCANetAudit_...`) phải restore + cấp quyền cùng lúc, nếu không trigger audit làm lỗi mọi thao tác Save.

### 5.3 Máy DB — Reporting Server (SSRS)

- SSRS **không bắt buộc** chung máy SQL (chỉ cần 1 SQL instance chứa DB `ReportServer`/`ReportServerTempDB`), nhưng chung máy: tiết kiệm license, tránh double-hop Kerberos, ít độ trễ. Tách máy khi tải report rất nặng hoặc yêu cầu bảo mật.
- Kiểm tra đã cài: service `SQLServerReportingServices` (SSRS 2017+) / `ReportServer[$Instance]` (2016-) / `PowerBIReportServer`; Start menu có **Report Server Configuration Manager**; `http://localhost/ReportServer` ra danh sách thư mục; `SELECT name FROM sys.databases WHERE name LIKE 'ReportServer%'`.
- Report Server Configuration Manager: cấu hình Database, **Web Service URL** (port 80), Web Portal URL. Service Startup = Automatic (Delayed Start).
- **Firewall port 80** cho máy web (lỗi khi thiếu: yellow page `SocketException (0x274c) ... failed to respond 10.10.10.42:80` tại `RdlCommControl.ascx.cs` line 217 `ListRenderingExtensions()`):
  ```powershell
  New-NetFirewallRule -DisplayName "SSRS HTTP 80 - LAN" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -RemoteAddress LocalSubnet
  ```
- **Quyền cho web gọi SSRS khi SSRS khác máy IIS**: `IIS APPPOOL\<pool>` là virtual account chỉ tồn tại trên máy IIS → add trên SSRS báo `The user or group name 'IIS APPPOOL\...' is not recognized`. Cách đúng:
  - **Cùng domain**: add tài khoản máy web `<NETBIOS>\<TENMAYWEB>$` (CMSD: `CMSB\DEV-IFCAWEB$`, có dấu `$`) — role **Browser** ở folder report + **System User** ở Site settings → Security. Áp dụng cho App Pool chạy LocalSystem / NetworkService / ApplicationPoolIdentity (đều ra mạng bằng tài khoản máy).
  - **Workgroup**: tạo local user cùng tên + cùng password trên cả 2 máy, set App Pool Identity = custom account đó (cấp quyền thư mục site + `Temporary ASP.NET Files`), add `<TENMAYDB>\<user>` trên SSRS.
- SSRS cùng máy IIS: add `IIS APPPOOL\<pool>` (gõ đúng tên pool, không thừa dấu `'`) — xem mục 2.
- Report data source: SSRS cùng máy DB nên không bị ảnh hưởng bởi việc tách WEB/DB.
- web.config các key: `ReportServerUrl` (`http://<máy DB>/ReportServer`, gọi nội bộ — không đổi theo domain public), `ReportServerRoot`, `ReportServerRoot2` (`/<CLIENT>_<ENV>_Reports/`), `ReportServerName`, `ReportDataSource`.

### 5.4 Máy WEB — Windows features + .NET

- IFCA target **.NET Framework 4.8** (`<compilation targetFramework="4.8">`; một số bản web.config còn ghi `4.0` — nên thống nhất 4.8). Server cần .NET Framework 4.8 / 4.8.1 (`HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full` → Release ≥ 528040). Yellow page hiện `.NET Framework Version:4.0.30319` = CLR 4 (mọi bản 4.x), không phải bản cụ thể.
- **Bắt buộc cài WCF HTTP Activation** (Workflow dùng WCF `.svc`):
  ```powershell
  Install-WindowsFeature NET-WCF-HTTP-Activation45
  iisreset
  ```
  Thiếu → mở màn Workflow (`Workflow/WFEntityManage.aspx`) lỗi `(405) Method Not Allowed` tại `svcWorkflow.WorkFlowServiceClient.GetWorkflowRunState` (xem 5.7).
- `Test-NetConnection` là lệnh **PowerShell** (CMD báo không nhận lệnh; từ CMD dùng `powershell -Command "..."`).

### 5.5 Máy WEB — IIS, App Pool, Application

- Mỗi môi trường 1 App Pool riêng (vd `CMSD_Live`, `CMSD_Train`, `CMSD_Uat`): **.NET CLR v4.0**, **Integrated**.
- **Identity**: CMSD đang để `LocalSystem` (chạy được, kể cả gọi SSRS qua tài khoản máy) nhưng quyền quá cao — trước go-live nên đổi sang `ApplicationPoolIdentity` + cấp quyền thư mục (`icacls "<site>" /grant "IIS APPPOOL\<pool>:(OI)(CI)RX"`, Modify cho thư mục upload/temp/export) rồi test lại các chức năng ghi file (đính kèm, import Excel, in letter, export).
- **Alias Application = đường dẫn URL**: domain `.../live|train|uat` → alias phải là `live`, `train`, `uat` (IIS không phân biệt hoa thường). IIS Manager không đổi tên alias được → tạo app mới, test, rồi xoá app cũ (xoá app không xoá file):
  ```bat
  %windir%\system32\inetsrv\appcmd list app
  %windir%\system32\inetsrv\appcmd list vdir "Default Web Site/CMSD_Live/" /text:physicalPath
  %windir%\system32\inetsrv\appcmd add app /site.name:"Default Web Site" /path:/live /physicalPath:"C:\IFCA Software\CMSD_Live" /applicationPool:CMSD_Live
  %windir%\system32\inetsrv\appcmd delete app "Default Web Site/CMSD_Live"
  ```
  Tên App Pool không ảnh hưởng URL, giữ nguyên. Sau khi đổi alias: rà web.config/DB còn URL tuyệt đối chứa tên cũ (`findstr /S /I /N "CMSD_Live CMSD_Train CMSD_Uat localhost" web.config`).
- Các app phụ giữ nguyên: `FileServer` (`File.asmx`), `IFCASearchService` (`IFCASearchService.asmx`), mỗi app có pool riêng.
- **HTTPS**: binding https 443 trên Default Web Site + certificate (cert thật import .pfx: `Import-PfxCertificate ... -CertStoreLocation Cert:\LocalMachine\My`; tạm thời self-signed):
  ```powershell
  $cert = New-SelfSignedCertificate -DnsName "DEV-IFCAWEB","localhost" -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(2)
  New-WebBinding -Name "Default Web Site" -Protocol https -Port 443
  (Get-WebBinding -Name "Default Web Site" -Protocol https).AddSslCertificate($cert.Thumbprint, "my")
  New-NetFirewallRule -DisplayName "IIS HTTPS 443" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
  ```
  **Giữ binding http 80** (app tự gọi WCF qua `http://localhost:80/<app>`, FileServer/SSRS gọi http nội bộ). Không bật redirect http→https toàn bộ (làm hỏng gọi nội bộ localhost) — nếu cần chỉ áp cho host public.

### 5.6 Máy WEB — web.config (rà khi copy từ client/server khác)

- `connectionStrings` (`PropertyNetMasterConnectionString1`, `AuditTrailDB`, `ErrorDB`): `Data Source=<máy DB>` — nên ép TCP `Data Source=tcp:<máy DB>,1433;`.
- `sqlServerCatalogNameOverwrites`: map tên DB gốc trong code (`IFCANet_R2_8`, `IFCANetAudit_R2_8`, `IFCANetDocumentMgmt_R2_8`) sang tên DB thật của môi trường.
- `CachePoolName` (memcached): mỗi website trên cùng máy phải khác nhau (vd = tên môi trường). Cấu hình memcached nằm ở `ConfigFiles\enyim.com.config` / `ConfigFiles\memcached.config`; `sessionState mode="InProc"` (session không dùng memcached). Nếu client dùng memcached thì cài + start service memcached và kiểm tra host/port trong 2 file config đó (chưa kiểm chứng chi tiết ở CMSD).
- `File.Url`, `FileServecies.*`, `IFCASearchService.*`: URL `http://localhost/fileserver/File.asmx` OK nếu FileServer cùng máy; **`*.Domain` phải đổi** từ tên máy cũ (`IFCA-DL380G8V1`) sang domain/tên máy mới, user/password đúng với máy mới (sai → 401).
- Report keys (5.3), `IRBM_API_URL` (e-Invoice: preprod vs prod theo môi trường), SMTP `mailSettings`.
- `<compilation debug="true">` → **`false` trên UAT/Live** (debug=true: chậm, bỏ qua `executionTimeout`, không cache script).
- Không dán password thật (DB, SMTP, FileService) vào chat/Jira.

### 5.7 FileServer / Search Engine / Workflow (WCF)

- **`File.asmx` là ASMX → phải host bằng IIS application `fileserver`**. Windows services `IFCA.SearchEngine.FileService` / `IFCA.SearchEngine.IndexService` là bộ search/index chạy nền, **chạy song song**, không thay thế `File.asmx`. Stop App Pool `FileServer` để "thử Windows service" → `http://localhost/fileserver/File.asmx` trả **503** (http.sys vẫn giữ URL cho pool đã stop). Muốn biết service có tự host HTTP không: `sc qc` → BINARY_PATH → đọc `*.exe.config` (baseAddress/port), `netstat -ano | findstr <PID>`.
- 503 của http.sys nói chung = có đăng ký URL nhưng không ai xử lý (pool stopped/crash, hoặc service self-host đăng ký urlacl nhưng không chạy): `netsh http show servicestate view=requestq`, `netsh http show urlacl`, log `C:\Windows\System32\LogFiles\HTTPERR\`.
- **Workflow WCF** (`WorkFlowService.WorkFlowService`, file `Workflow/WorkFlowService.svc` hoặc `WorkFlowWCFForSL/WorkFlowService.svc` tuỳ client; client `svcWorkflow.WorkFlowServiceClient` tự ghép URL từ query string `URL=http://localhost:80/<app>`):

  | Lỗi | Nguyên nhân | Fix |
  |---|---|---|
  | `(405) Method Not Allowed` (CMSD, server mới) | IIS chưa có handler `.svc` | Cài WCF HTTP Activation (5.4), `iisreset`; test mở `.svc` phải ra "You have created a service" |
  | `Could not find a base address that matches scheme https` | Service khai báo endpoint HTTPS (`WorkFlowServicesBindingHttps`, `mexHttpsBinding`) nhưng site chưa có binding https | Thêm binding https (5.5) hoặc tạm comment 2 endpoint HTTPS |
  | `404 EndpointNotFoundException ... no endpoint listening` (SWIBRACO-697) | Service chỉ còn endpoint HTTPS, endpoint + binding HTTP bị comment, app gọi http | Bỏ comment binding `WorkFlowServicesBinding` + endpoint HTTP, chạy song song https (WSDL `?wsdl` phải có 2 port http/https) |
  | Cùng lỗi 404 nhưng config đã đúng (PLB_UAT_V54) | Config đã sửa/copy nhưng IIS chưa nạp lại | **Recycle App Pool** sau mỗi lần sửa config WCF |

### 5.8 Kết nối giữa 2 máy (WEB ↔ DB)

- **SQL `error: 40 - Could not open a connection` (Named Pipes Provider)** từ máy web: lỗi chưa chạm tới SQL (không phải sai password — sai password báo `Login failed`). SSMS chạy ngay trên máy DB kết nối được **không chứng minh gì** (dùng *Shared memory*: `SELECT net_transport FROM sys.dm_exec_connections WHERE session_id=@@SPID`). Kiểm tra lần lượt: tên instance (default `DEV-IFCADB` vs named `DEV-IFCADB\SQL2K22`), TCP/IP enabled + port 1433 (5.1), firewall 1433, rồi từ máy web `Test-NetConnection <máy DB> -Port 1433` (thử cả tên và IP để loại lỗi phân giải tên — fix bằng IP hoặc file `hosts`). Force TCP trên máy DB: SSMS Server name `tcp:<máy>,1433`.
- Firewall nên giới hạn nguồn: `-RemoteAddress LocalSubnet` (hoặc IP máy web), không mở cho mọi nguồn — đặc biệt khi login là sysadmin.
- Nếu firewall Windows đã mở mà `Test-NetConnection` vẫn `False` → firewall mạng giữa 2 máy (VLAN/subnet khác) → nhờ IT.
- **Share thư mục giữa 2 máy**: `\\<máy>` chỉ hiện thư mục đã share. Lấy nhanh: admin share `\\DEV-IFCADB\D$\<path>` (tài khoản admin của máy đích). Lâu dài: `New-SmbShare -Name "<Share>" -Path "<path>" -FullAccess "<DOMAIN|MÁY>\<user>"` + `icacls ... (OI)(CI)M` (phải cấp cả Share permission lẫn NTFS). Bật Network discovery + File and printer sharing (profile Private/Domain), kiểm tra port 445. BACKUP/RESTORE SQL từ share chạy bằng **tài khoản service SQL** → dùng UNC, không dùng ổ map; workgroup thì copy .bak về local rồi restore.

### 5.9 Thứ tự làm gợi ý

1. Máy DB: SQL (5.1) → restore các DB + DB Audit (5.2) → SSRS + deploy report/data source (5.3) → firewall 1433/80 LocalSubnet.
2. Máy WEB: .NET 4.8 + WCF HTTP Activation (5.4) → copy source, tạo App Pool + Application alias đúng URL, FileServer, IFCASearchService (5.5) → sửa web.config (5.6) → binding https (5.5).
3. SSRS: cấp quyền tài khoản máy web `<NETBIOS>\<WEB>$` (5.3).
4. Test: login từng môi trường → mở 1 list + 1 edit → 1 report (SSRS) → upload/đính kèm (FileServer) → 1 màn Workflow (WCF) → in letter / import Excel.
5. Trước go-live: `debug="false"`, App Pool sang ApplicationPoolIdentity, cert thật, đổi/disable `sa`, tách login web khỏi sysadmin.
