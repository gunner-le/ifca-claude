# Gotcha IFCA ERP.NET đã học được (từ bộ nhớ claude.ai)

## Customization policy

- LKHS và TH_LIVE: fix trực tiếp trên Standard code/view — KHÔNG clone hậu tố client (policy của Stanley).
- Client khác: luôn clone view/SP/page với hậu tố client để tách khỏi update Standard.
- Copy trang ASP.NET: tên class phải khớp ở cả `Inherits` của `.aspx` và khai báo class trong `.aspx.cs` (`FolderName_PageName`).

## Chuẩn patch data

- Luôn kiểm tra lại trước khi đề xuất patch — verify bằng query bổ sung.
- Patch đơn giản: ghi giá trị cũ inline, vd `UPDATE t SET col=newval -- oldval WHERE id=x`.
- Patch phức tạp: sinh `UpdateScript` + `RevertScript` dạng cột chuỗi trong 1 `SELECT`.
- WHERE: ưu tiên business key (GRNNo, DocumentNo) hơn ID khi không mơ hồ.
- Có FK thì ưu tiên delete+reinsert thay vì chuỗi UPDATE phức tạp.
- Script patch idempotent: không lọc `WHERE col=OLDvalue` nếu script anh em có thể đã patch trước — lọc bằng so sánh với giá trị đích đúng.
- `PM_ProjectLedger` có trigger `TGR_ProjectLedger_InsertUpdate` tự tính lại `CodeDirect` qua `dbo.PMGetCodeDirect()` mỗi INSERT/UPDATE — không patch `CodeDirect` trực tiếp; patch `CreditAmount`/`BaseDebitAmount`... để trigger tự tính.

## Schema gotcha

- `Sys_Report` cột thật: `ReportNo`, `ApplicationCode`, `ReportNameStringCode` (KHÔNG có cột "ReportName"), `ReportFileName`, `ReadTable`... Luôn query theo `ReportFileName` hoặc `ReportNameStringCode`.
- Trước khi soi logic SP của report, kiểm tra `Sys_Report.ReportFileName` trỏ đúng RDLC (không phải bản `_Test`/nháp). Kiểm tra cả alias cột trùng trong SP cấp cho report.
- `AR_Trx` có trigger INSTEAD OF INSERT (`PREVENT_DUP_INSERT`) với danh sách cột hardcode. Cột thêm vào `AR_Trx` sau khi viết trigger (vd `IsRefundNote`) bị bỏ âm thầm. Triệu chứng: code/SP gửi đúng giá trị (thấy trong Profiler) nhưng cột NULL trong bảng. Fix: thêm cột vào cả `INSERT INTO(...)` và `SELECT(...)` trong trigger. Chẩn đoán: `SELECT name FROM sys.triggers WHERE parent_id=OBJECT_ID('AR_Trx')`.
- Cùng trigger `PREVENT_DUP_INSERT` (kết thúc `SELECT BillID ... = scope_identity()`) làm hỏng LLBLGen `SaveEntity` khi tạo bill AR mới: INSERT thật chạy trong scope trigger → ORM nhận identity NULL → "Specified cast is not valid" (stack chỉ có `throw ex` trong `PMCommonBL.SaveARTrxMod`). Fix nhanh (PALMINGTONPG-4): `ALTER TABLE AR_TRX DISABLE TRIGGER PREVENT_DUP_INSERT`. Kiểm tra cái này đầu tiên với mọi lỗi "cast not valid" khi Save bill AR mới (SUMMERPG-24 cùng triệu chứng).
- `CF_Company` KHÔNG có `CompanyName` — tên nằm ở `CF_Account` (`CF_Company.AccountID` → `CF_Account.Name`). Tìm CompanyID theo tên: `SELECT c.CompanyID, a.Name FROM CF_Company c JOIN CF_Account a ON a.AccountID = c.AccountID WHERE a.Name LIKE '%...%'`.
- `Sys_TabDt` / Form Layout: user tự thêm field qua UI Form Layout, field mới mặc định editable kể cả khi nghiệp vụ cần readonly. Field bỗng editable → kiểm tra `Sys_TabDt` theo `TdtFldName` + `TdtTabNo`, patch `TdtFldEdit=0`. Cột đúng là `TdtFldDescStringCode` (không phải `TdtCaption`/`TdtStringCode`). TabNo thật khi set động: xem tham số URL khi mở màn hình.
- Bẫy tên field: label "Credit Note" trên `MC.AdjustmentEdit` map vào control `id="...TaxInvoice"` (field `TaxInvoice`), KHÔNG phải `IsContra` — `AR_Trx` không có cột `IsContra`. Không tin tên field; xem id control render thật.
- `dbo.GetUnitNo(@DebtorID)` / `GetUnitID(@DebtorID)` trả TẤT CẢ unit của debtor dạng chuỗi phẩy, không phải 1 unit. Dùng làm fallback khi UnitID của bill NULL — gate fallback theo cột ID NULL, không theo cột text hiển thị.
- Quy ước `SaleLoanID=0`: IFCA dùng 0 làm placeholder cho record mới, nên record migration có SaleLoanID=0 xung đột và phải gán lại (`IDENTITY_INSERT` + cập nhật FK).
- `CB_Receipt` dùng chung nhiều module với ID tự tăng độc lập — ID trùng ngẫu nhiên giữa module làm hỏng join (vd `AP_Allocation.RefundID = CB_Receipt.CBReceiptID`) nếu không lọc `ReceiptType`.
- AP > AP Transaction (Invoice/Adjustment/Misc) bảng chính = `AP_Journal` (PK `APJournalID`, `PayableType`, `DocumentNo`, `DocumentDate`, `TransactionDate`, `RefTable`/`RefRecordID`) — KHÔNG phải `AP_Trx`. Void tạo dòng `AP_Journal` thứ 2 (cùng DocumentNo, tiền âm, `RefTable='AP_Journal'`, `RefRecordID`=ID gốc) có thể mang ngày sai (ngày void). Ticket "patch doc date": patch theo `APJournalID`, không theo DocumentNo. Cột ngày nào patch là do consultant quyết — hỏi trước: SWIBRACO-674 patch `DocumentDate` + `TransactionDate`; SWSRIDATAI-495 chỉ `DocumentDate` (TransactionDate giữ vì quyết định kỳ GL). Kiểm tra `GL_VoucherMain WHERE RefTable='AP_Journal' AND RefRecordID IN (...)` xem status/kỳ voucher trước.
- `TransactionDate` của AP Adjustment chỉ được set lúc Approve, không set lúc tạo — join theo khoảng ngày với Adjustment chưa Approve sẽ fail do NULL và âm thầm bị loại khỏi report.

## Clone report và cấu trúc

- Clone report sang field ngày khác: thêm cột mới thật sự xuyên TOÀN BỘ chuỗi SP (DDL bảng tạm, danh sách cột INSERT, SELECT của SP con, bảng staging, GROUP BY, SELECT/ORDER BY ngoài). Giữ `Sys_ReportFilter.FldName` = tên field mới thật cho cả parse `@SDate`/`@EDate` lẫn match `@QueryCriteria`. KHÔNG alias field cũ thành tên mới — ra đúng tên cột nhưng sai data. `@QueryCriteria` được nối thô `WHERE 1=1 AND <criteria>` vào subquery cuối, nên FldName phải khớp cột thật có ở đó, nếu không lỗi "Invalid column name".
- Pattern report Opening+detail (Ledger/Statement): chia data thành bảng tạm CarryForward trước kỳ (gom thành 1 Opening) + MasterTable chi tiết trong kỳ. Chạy từ StartDate rất cũ đẩy gần hết lịch sử vào detail, che lỗi các cột tổng quên cộng CarryForward — bug chỉ lộ với StartDate gần thực tế. Kiểm tra MỌI cột tổng có cộng cả 2 bảng không. `Sum()` RDLC theo field từng dòng không bao giờ gồm CarryForward; fix cần 1 field scalar mới trong SP cộng cả 2 nguồn, RDLC trỏ vào hằng đó.
- Chuỗi report/letter âm thầm loại record thiếu entity tuỳ chọn: chuỗi view lồng nhau mỗi tầng INNER JOIN thêm (Unit, e-Invoice, Property Area…) làm record thiếu entity biến mất ở tầng có INNER JOIN. Debug: trace SQL thật lúc Print (Profiler), test từng view top-down với ID record tới khi 1 view trả 0 dòng. Fix: LEFT JOIN + fallback `ISNULL(x.Field, alt_source.Field)`. Thường phải sửa nhiều tầng.
- `Sys_ReportFilter` FldRange=3 truyền nguyên chuỗi `"Fld>='MM/dd/yyyy' AND Fld<='MM/dd/yyyy'"` vào tham số — SP phải parse và `CONVERT` format 101.
- Report thiếu/sai record: đọc dòng **CRITERIA đỏ** cuối report trước — đó là `@QueryCriteria` SP nhận thật. SP aging PM/MC (`PMDebtorAgingDetail`...) parse As At bằng `CHARINDEX('<Fld><=', @QueryCriteria)`; không thấy → `@Temp=''` → điều kiện `<= ''` âm thầm loại receipt/allocation mà invoice vẫn hiện. Ô As At phải `FldRange=2` (FldRange=0 trên Date sinh `=`). 2 report chung 1 SP mà 1 đúng 1 sai → so `Sys_ReportFilter` 2 ReportNo trước khi soi SP (LKHS-336).
- Report Summary sai số mà Detail cùng SP đúng (CRITERIA giống) → data đúng, lỗi ở biểu thức RDL: so ô tổng với report anh em đang đúng (bản Doc Date / bản Malaysia). Field âm (vd `UnallocedAmt` của aging PM) phải CỘNG vào Owing (LKHS-337).
- LKHS dùng nhánh TFS SG riêng: fix ở nhánh Malaysia không tự sang SG. Bug report LKHS → so file cùng tên ở `Rel\IFCA.NET 4.0\Source\Reports`; Malaysia đúng thì chỉ port đoạn sửa, KHÔNG đè cả file (RDL SG khác chỗ khác, vd nhãn aging `PM_Company` vs `CF_Company`) (LKHS-337).

## e-Invoice (LHDN/MyInvois)

- Pattern CN/DN lệch: submit CN/DN yêu cầu Original Invoice `EInvoiceStatus='COMPLETED'` trước. Submit khi gốc còn pending → LHDN reject và handler lỗi của IFCA tự Inactive `AR_Allocation` của CN — trông như "CN tự unallocate". Debug: (1) BillID của CN; (2) `AR_Trx.InvoiceID` → BillID invoice gốc; (3) `SELECT * FROM AR_Allocation WHERE AdjustmentID=@CNBillID` tìm dòng Inactive; (4) `SELECT * FROM IRBM_Trx WHERE RefRecordID=@CNBillID AND RefTable='AR_TRX'` xem timestamp `FailedValidationReason` so với (5) `EInvoiceDate` của invoice gốc. Tự hết khi trigger lại sau khi invoice gốc completed.
- Câu hỏi còn mở cho Stanley: có nên chặn Approve CN khi Original Invoice chưa `COMPLETED`?
- Gotcha INNER JOIN IRBM: SP report/letter INNER JOIN `IRBM_DocumentNo_Summary` hoặc `IRBM_Trx` loại nhầm bill chưa có e-Invoice completed — kiểm tra đầu tiên khi SP ra rỗng bất thường cho template in không phải e-Invoice.

## QR code

- Field QR mail-merge Word phải là `{ MERGEBARCODE FieldName QR \s 50 }` KHÔNG có nháy quanh FieldName.
- SP report gộp nhiều dòng bằng `SUM` + `GROUP BY` thường comment bỏ field ID nguồn (như `BillID`) cần cho lookup QR/IRBM vì vướng GROUP BY — fix bằng `MAX()`, không bỏ; NULL ở đó làm hỏng cả chuỗi lookup IRBM_Trx.
- 2 lớp xử lý QR trùng trong SmartClient (`WordLetterProvider.MailMerge()` scan text thủ công + callback `HandleMergeField.FieldMerging`) xung đột. Fix: bỏ phần QR trong `WordLetterProvider.MailMerge()`, chỉ giữ ở `HandleMergeField.FieldMerging`.
- Fallback QR rỗng phải là `" "` (dấu cách), không phải `"DRAFT"`. Regex `GetSwitchValue` cho `\t` cần ít nhất 1 ký tự giữa nháy — `\t ""` không chặn được text.
- SP có thể có 2 cột cùng alias — ADO.NET chỉ giữ cột đầu; triệu chứng là QR hiện cho record không nên có, hoặc quét ra URL placeholder.

## Gotcha query khác

- GL Import Sub-Ledger: `PaymentTypeID`/`ElementCode` route tới class importer qua `GLPaymentImporterFactory`. DLL compile trên server có thể khác source TFS — debug không trúng breakpoint thì dùng dnSpy/ILSpy trên DLL thật của server.
- `clsClientScript`/`RegisterStartupScript`: tag `<%=...%>` KHÔNG render trong `RegisterStartupScript` — dùng `FormatObject` với `{0}`, `{1}`. Control trong `ContentPlaceHolder`: `objPage.Master.FindControl("ListContent")` rồi `.FindControl(controlId)`.
- SOA/deposit: loại contra receipt bằng `AND CB.DocumentAmt > 0`. Balance invoice mở dùng logic point-in-time theo AR_Allocation, không dùng `BalanceAmt` live.
- Lẫn data sale đã huỷ: lọc `AND SaleID IN (SELECT SaleID FROM PS_Sale WHERE RecordStatus IN ('Book','Sale','Sign'))`.

## Auto Code / Number Structure (SysCode)

- Reference đầy đủ: `docs/ifca-autocode-syscode-reference.md`.
- `SysCode.ToString()` trả "" (không exception) = không có dòng Number Structure trong `View_CF_DocCode` cho DocCode đó ở company đã resolve. Fix qua System Setup > Number Structure (`/System/SysAutoCodeAM.aspx`). `DocAnchorType` bị SysCode bỏ qua.
- Menu Template No = DocCode `017` (module Common), luôn anchor SystemOwner trong `SysMenuTemplateAM.aspx.cs`; setup: Serial, length 8, pad 0, fixed Yes (`0000000x`).
- Popup chỉ hiện "undefined": kiểm tra `sys_error()` gọi đủ 2 tham số `(title, message)`.

## Report "user không thấy chứng từ" (TIMATCH-443)

- Trước khi nghi quyền Company/Unit: so **Criteria** (dòng đỏ cuối report) + `ReportDefineID` trên URL của 2 login. Mỗi user lưu filter riêng; TIMATCH-443 `KSB/CN/00000132`: 1 login lọc TRANSACTIONDATE, 1 login lọc DOCUMENTDATE → chứng từ có TransactionDate = ngày sửa (sau khoảng lọc) bị loại. Xin screenshot report của cả 2 login.
- Lọc refund trên Debtor Ledger theo nguồn: xét cả 2 đường `AR_Allocation.ReceiptID` (receipt) và `AR_Allocation.AdjustmentID` (CN) — chỉ xét receipt `MC_Fee` sẽ bỏ sót refund của CN (Rental Rebate).

## Report trắng trang + SyntaxError (PLBPG-62, SWHARTANAH-358)

- View page source → tìm `alert(` → đọc stack trace thật trước khi nghi RDL/SP. Report thường đã render (`TotalPages`), chỉ JS vỡ do message không escape.
- Lỗi chỉ 1 user → nghi dữ liệu riêng của user (tên employee có `'`) bị ghép chuỗi SQL/JS. `RdlCommControl` dùng `SysContext.CurrentEmpName` (tên employee, không phải login) trong path Report History.
