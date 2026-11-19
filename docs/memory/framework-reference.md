# IFCA framework — bảng, schema, pattern debug (từ bộ nhớ claude.ai)

## Sys_ tables (metadata framework)
- Sys_Base (ReadTable/WriteTable/PK), Sys_BaseDt (field form), Sys_ListDt (cột grid), Sys_Filter (field filter, FltLstNo), Sys_List (metadata).
- Thứ tự thêm cột + filter: CF_String → Sys_BaseDt → Sys_Filter → Sys_ListDt.
- Control SysToolbar/SysCondition/SysList2 — LstNo phải khớp cả 3; lệch thì Search Criteria lưu sai LstNo và filter không hiện.
- Cột thật Sys_BaseDt / Sys_TabDt / Sys_List... xem `docs/ifca-domain-reference.md`. Field name của Sys_BaseDt là `BdtFldName` (không phải FldName).
- Sys_TabDt link Sys_BaseDt qua `TdtBseNo=BdtBseNo AND TdtFldName=BdtFldName` (không có FK số). Layout SysTabEdit do Sys_TabDt quyết định — field thiếu trong Sys_TabDt nhưng bắt buộc trong Sys_BaseDt → triệu chứng "field required nhưng không hiện"; luôn copy dòng mẫu từ client đang chạy đúng thay vì tự dựng.

## CF_Company
- Không có CompanyCode/CompanyName — JOIN `CF_Account` (`CF_Company.AccountID = CF_Account.AccountID`) để lấy AccountNo (mã company) và Name.

## Sys_Report
- Cột: ReportNo, ApplicationCode, ReportNameStringCode (JOIN CF_String ON StringCode=ReportNameStringCode lấy tên), Language, CategoryStringCode, ReportFileName, ReadTable, Order, IsSystem, RecordStatus.
- ReadTable KHÔNG phải nguồn data SP/view — chỉ dựng UI filter; nguồn thật: ReportFileName → tìm RDLC → xem Dataset Query.
- Report mở qua SmartClient/CommonReport.aspx: RDLC nằm trong project WinForm IFCA.ReportViewer, không ở web server.

## CF_Letter
- Dùng CF_Letter (KHÔNG có Sys_Letter/Sys_LetterType) để tìm SP đằng sau 1 Letter print; query `CF_Letter WHERE LetterTypeID=X`.

## CF_DocCodeFormat
- Company mới của client không có dòng CF_DocCodeFormat (check NOT EXISTS) → sinh số chứng từ qua SysCode lúc Save bị timeout thay vì báo lỗi rõ; fix: copy dòng từ company mẫu, chỉnh prefix; luôn kiểm tra cái này với lỗi timeout Save ở client mới trước khi profile SQL sâu.

## e-Invoice (LHDN/MyInvois) pipeline
- 3 tầng: IRBM_Record_Trigger (tín hiệu trigger DB, PROCESSED khi được nhặt) → IRBM_Record (payload đầy đủ, IRBMStatus='NEW' tới khi service nền xử lý) → IRBM_Trx (kết quả API LHDN: EInvoicestatus, EInvoiceNo, EInvoiceQR, SubmissionDate, FailedValidationReason).
- PROCESSED ở IRBM_Record_Trigger KHÔNG có nghĩa doc đã tới LHDN.
- Backlog NEW lớn và tăng ở IRBM_Record = Windows Service nền chết; vài dòng kẹt = lỗi riêng từng doc (xem log service).
- Kẹt ở IRBM_Record NEW = không bao giờ tới IRBM_Trx (khác pattern CN/DN FailedValidationReason vẫn có dòng IRBM_Trx).

### Checklist debug sync e-Invoice (luôn check trước)
- (1) View/SP IRBM của client đã đúng bản TFS mới nhất chưa — path: `$/Property/Dev/BRANCHES/NET4.0_REL/E-Invoice Client Deployment/_Package (Edge)/Versioning/Version [N]/Database/` — view cũ gây lỗi đánh lạc hướng.
- (2) `AR_Trx.TaxID` NULL trên bill cụ thể — có thể làm fail sync; fix bằng UPDATE.
- Chỉ sau khi loại (1) và (2) mới đào sâu (HasValidatedInvoice cho CN/DN...).
- 5 view IRBM query cho mỗi bill: View_IRBM_eInvoice, View_IRBM_eInvoiceItem, View_IRBM_eInvoiceTax, View_IRBM_eInvoiceItemTax, View_IRBM_eInvoiceRefNo — tham số dạng `'CompanyID_Source_BillID'`.
- ID CF_PopupLstElement cho Classification/MSIC phải verify theo từng môi trường.
- CF_CompanyMSIC: setup MSIC theo company, theo module (PSMSICCodeID/RRMSICCodeID/ARMSICCodeID/PMMSICCodeID) — cấp Supplier MSIC Code cho e-Invoice. SP_IRBM_Record_Update khác nhau nhiều theo client (có client còn dùng AR_BillItem.MSICCodeID cũ, có client đã join CF_CompanyMSIC) — luôn xác nhận SP live thật của client dùng cơ chế nào, diff 2 SP trực tiếp thay vì suy luận.

## View_AC_APAllocSum
- View tổng "đã allocate" mức thấp, dùng lại bởi nhiều view cao hơn.
- Filter RecordStatus quan trọng: allocation 'Active' nguồn Payment (chưa Verified) KHÔNG được tính là đã trả; fix: chỉ tính 'Active' cho dòng nguồn Adjustment/Refund; luôn check `sys.sql_expression_dependencies` trước khi sửa view này.

## TIMATCH SOA Opening/Closing Balance — pattern chung
- (a) Thêm SP + Dataset song song nhỏ cộng giao dịch trước kỳ theo debtor từ cùng view nguồn.
- (b) Copy đúng logic dedup/filter/dấu từ các biểu thức Total/Sum có sẵn (không Sum() trơn).
- (c) Không giả định tham số report tồn tại — xem panel Parameters thật.
- (d) Tái dùng tham số chuỗi kiểu QueryCriteria thì bỏ các điều kiện ngày xung đột nhúng trong đó.
- (e) Dùng Lookup() thay First() để tra giá trị chéo dataset theo debtor.
- (f) Loại dòng Deposit (MC_Deposit_paid/unpaid) cho khớp dataset chính.
- (g) Không thêm field dataset chỉ để format ngày hiển thị — tìm và dùng lại biểu thức parse chuỗi RDLC có sẵn.

## RDLC layout
- Textbox/Rectangle định vị tuyệt đối không reflow trong PDF — dùng dòng Tablix cho layout chảy.
- Biểu thức First() ở PageHeader scope toàn dataset → mọi trang PDF hiện record đầu.
- Report CommonReport.aspx/SmartClient render qua app ClickOnce IFCA.ReportViewer WinForm (không phải web server) — RDLC nằm trong solution SmartClient.
- SmartClient (IFCA.LetterPrinter2) xử lý QR/Draft.
- Report mở qua `CommonReport.aspx?...&lstNo=X` mở WinForm (`IFCA.ReportViewer.application`): không có .rdlc tĩnh — WinForm gọi `ReportViewerService.asmx/GetReportData` (class `IFCA.Framework.ReportViewerBL.ReportViewerService`) dựng RDL động từ SQL của lstNo. Đừng tìm file report cố định.

## RDLC sinh động (RDLGenerator/ReportServicesHelper)
- Một số report (GL Journal Enquiry, report GL CommonReport.aspx khác) KHÔNG có .rdlc tĩnh — code-behind xoá và sinh lại file .rdl DÙNG CHUNG (đặt tên theo lstNo+language+lstOrder — chung mọi user cùng report+ngôn ngữ, không theo session) mỗi request không phải postback, qua RDLGenerator.GenerateRDLForGL()/GenerateRDLStream(). Width cột trong GenerateRDLStream() hardcode 2.4cm bất kể Sys_ListDt.LdtFldWidth (đọc vào field.Width nhưng không áp) — header bị wrap/vỡ với report nhiều cột/tên dài. Bug toàn Standard, không riêng client.
- Kiểu xoá-rồi-sinh có thể ném UnauthorizedAccessException nếu IIS_IUSRS thiếu quyền Modify trên thư mục output RDL — check NTFS trước với lỗi System.IO.File.Delete.

## Property Sales (PS)
- PS_Sale (SaleID, UnitID, RecordStatus: Sale/Sign/Book/Return/Cancel) KHÔNG có DebtorID — join qua AR_Debtor (RefTable='PS_Sale', RefRecordID=SaleID). PS_Unit.LandArea hay NULL/không tin được; PS_Unit.InteriorArea mới được điền — có client (NAIMCAP) map ô UI "Land Area" vào cột InteriorArea, luôn xác nhận ô UI ghi vào cột nào.
- Other Debtor Aging/Ledger: pro_AR_ODDebitorLedgerDetail_ByTrxDate / _ByTrxDate2 (Ledger, nguồn chuẩn) gọi bởi wrapper AR_OtherDebtorAgingDetail. Bug hay gặp ở nhánh UNION OD_Adjustment: join inv theo aji.AdjustmentID=inv.BillID (ngày của Adjustment) thay vì aji.BillID=inv.BillID (ngày invoice đích) — zero-out allocation sớm. Fix chuẩn (SWSRIDATAI-126 / "PPLUS migration issue"): thêm `INNER JOIN AR_Trx ab ON ab.BillID=aji.BillID AND ab.TransactionDate<=@AsAtDate`.
- AR_Allocation: BillID = bill đích được trả, AdjustmentID = adjustment nguồn trả, ReceiptID = receipt nguồn. Bug hay gặp: bill bị Inactive (thay bằng bản sửa cùng DocNo+'.'), các AR_Allocation KHÔNG bị inactive theo — còn allocation Active mồ côi trỏ bill chết, double-count khi receipt áp lại vào bill thay thế. Tìm: allocation Active có BillID trỏ AR_Trx Inactive.
- RT_ContractCharges.ExtraCreditTerms/ExtraGracePeroid = setup cấp hợp đồng theo billing item. MC_BillSchedule.CreditTerms/GracePeriod = giá trị chốt 1 lần lúc sinh schedule qua RentalCommon.GetCreditTerms/GetGracePeriod. View_AR_CreateBill có 2 block UNION (nguồn MC_BillSchedule vs MC_DebtorBillItem); bug đã biết: block MC_BillSchedule hardcode DebtorBillItemCreditTerms=0 thay vì join RT_ContractCharges (block MC_DebtorBillItem đúng). RentalCommon.GetCreditTerms/GetGracePeriod còn bỏ qua hẳn tham số DebtorBillItemCreditTerms/DebtorBillItemGracePeriod (param chết) — fix đầy đủ cần sửa CẢ join view LẪN logic hàm (ưu tiên giá trị cấp hợp đồng khi >0). Ô "Extra Credit Term"/"Extra Grace Period" trên màn Generate Billing cộng thêm, mặc định 0.

## Fixed Assets (FA)
- FA_ChangeNote ghi mọi thay đổi asset qua CF_PopupLstElement.ElementCode ('FA.Chg.Logout' = Disposal/WriteOff, 'FA.Chg.SettleDepreciate', 'FA.Chg.CardImport'...). Disposal/Logout tạo HAI dòng: "cha" (RefTable='FA_AssetReduction') giữ số dư cuối THẬT (đã về 0), "con" (RefTable='FA_ChangeNote', RefRecordID=ChangeNoteID cha) chỉ giữ DELTA âm. Subquery Opening Balance của FA_AssetsReport (Bf cho Original Cost, DeBf cho Accum. Depreciation) lấy "mới nhất theo ChangeNoteID" mà không lọc RefTable — lấy nhầm dòng con, asset đã thanh lý vẫn có Opening ≠ 0. Fix: thêm `(PE1.ElementCode <> 'FA.Chg.Logout' OR CN1.RefTable = 'FA_AssetReduction')` — kiểm tra RIÊNG cả Bf/CteBf và DeBf/CteDeBf (SP cũ của client có thể chưa fix cái nào dù TFS mới đã fix 1).
- FA_AssetsReport bản TFS mới có thể cần FA_AssetTypeChange() mới (thêm cột NextChangeNoteID) — kiểm tra signature trước khi deploy nguyên SP mới lên DB client cũ.

## Construction Management / Project Accounting (PM)
- PM_LedgerMain = HEADER (LedgerMainID, CompanyID, DocumentNo, ReferenceNo, DocumentDate, TransactionDate, JournalType, RecordStatus, BaseDebitAmount). PM_ProjectLedger = DETAIL (LedgerID, LedgerMainID FK, ProjectID, AccountCodeID, DebitAmount, CreditAmount, BaseDebitAmount/BaseCreditAmount, LedgerType: Direct/Summary/Apportion) — tên ngược trực giác.
- PM_ProjectBalance = cache số dư (ProjectID+AccountCodeID+AccountPeriodID+CurrencyID+AccountType), dựng lại từ PM_ProjectLedger bằng `Prc_PM_RecalculateProjectBalance(@ProjectIDs varchar(4000), @CompanyIDs varchar(1000)='0')` — PHẢI chạy sau mọi patch tay PM_LedgerMain/PM_ProjectLedger. Kỳ xác định từ TransactionDate join pm_AccountPeriod.
- View_PM_Journal (Sys_Base PM.Journal) CHỈ gồm entry nguồn PM_ProfitRecognise — không dùng để tra PM_LedgerMain bất kỳ (vd Subcontract Claims).
- "Patch data + PM Recalculate" (SWHARTANAH-322/323): chứng từ nguồn (PO_GRN Goods Return...) có bản MIRROR ở Project External Journal (PM_LedgerMain + PM_ProjectLedger) — phải patch CẢ 2 khớp nhau (tìm PM_LedgerMain qua ReferenceNo/DocumentNo khớp chứng từ nguồn, không qua RefTable/RefRecordID). Patch PM_LedgerMain.BaseDebitAmount VÀ dòng PM_ProjectLedger (DebitAmount/CreditAmount/BaseDebitAmount/BaseCreditAmount), rồi `EXEC Prc_PM_RecalculateProjectBalance @ProjectIDs='<ProjectID>', @CompanyIDs='<CompanyID>'`.

## Procurement (PO)
- PO_GRN = HEADER cho CẢ Goods Received Note LẪN Goods Return (GRNID, CompanyID, GRNNo, GRNType 'Receipt'/'Return', SupplierID, GRNDate, POID, DocumentAmt, BaseAmt, TaxAmt, RecordStatus). PO_GRNItem = DETAIL (GRNItemID, GRNID, ItemID, Quantity, BalanceQty, VerifiedBalanceQty, UnitPrice, POItemID, ScheduleItemID, Amount, DocumentAmtBefTax, RefGRNItemID). Goods Return không có bảng riêng — cùng bảng với GRNType='Return'.
- Patch PO_GRN đã có GL_VoucherMain Approved (RefTable='PO_GRN', RefRecordID=GRNID, RecordStatus='Accounted'): thứ tự bắt buộc: (1) consultant Reverse voucher qua UI (→ 'Inactive' — không UPDATE tiền voucher Accounted); (2) xác nhận Inactive rồi mới patch PO_GRN/PO_GRNItem. Reverse voucher KHÔNG đụng PO_GRN/PO_GRNItem.

## Bug data cây tự tham chiếu (loading vô hạn, không phải bug code)
- Màn dựa trên view đệ quy cha-con (vd FA_AssetType qua View_FA_AssetType + UDF GetAssetTypeIDs leo ParentID) treo ở 1 môi trường (Train) mà không treo ở môi trường khác. Thường do 1 dòng ParentID = chính ID (tự tham chiếu) hoặc vòng A→B→A. Kiểm tra: SELECT ID+ParentID cả bảng nhỏ. Fix bằng patch data (ParentID=NULL hoặc cha đúng).

## Cash Management: Cash Flow Item Mapping
- Mục đích: Cash Flow Statement phân loại mọi dòng tiền vào Operating/Investing/Financing × In/Out; mỗi loại giao dịch phải map trước qua **Cash Management > Cashiering Setting > Cash Flow Item Mapping** (CashFlow/CashItemAlloc.aspx, bảng CB_CashItemAlloc, Sys_Base 'CB.CashItemAlloc'). Tab: Expenses, Bill Item, Project, Transaction Type, PO Items — "Transaction Type" liên quan lỗi Receipt/Collection (map CF_PopupLstElement.ElementCode, vd 'PS_Payment'/'Collection').
- Bẫy: tab Transaction Type hiện giá trị mặc định (vd "OPERATING INFLOW") cạnh mọi dòng kể cả dòng CHƯA lưu — trông như đã setup. Phải tick/click đúng dòng và Save mới ghi CB_CashItemAlloc; chưa thì Bank-In lỗi "Cash Item for unallocate amount(Receipt Type: X) not yet setup!" (từ CashFlowAllocation.AutoAllocateReceiptCashFlow). Verify: `SELECT * FROM CB_CashItemAlloc WHERE TrxType='<ElementCode>'`.
- Tên menu tiếng Anh có thể là placeholder "Translate Please" (Sys_Menu.MnuNameEN) dù tính năng chạy bình thường — xem Sys_Menu.MnuProgram.

## SWHARTANAH PO_GRNItem.BalanceQty corruption (Duplicate Invoice) — SWHARTANAH-97/294/324/325
- SWHARTANAH-324 (ĐÃ FIX, DEPLOY): tính năng "Duplicate Invoice" customize (clsAPJournalList.cs, namespace IFCA.Business.Customization.SWHARTANAH.payable, override f_Duplicate → APInvoiceEntry_SWHARTANAH.aspx?action=duplicate) để invoice duplicate có GRN trừ lại PO_GRNItem.BalanceQty (UpdateGRNItemDetail, case Added) như nhận hàng mới. Tích luỹ làm hỏng ~1,500 dòng. Công thức tính lại: `BalanceQty = Quantity - SUM(PO_PurchaseItem.Quantity WHERE GRNItemID=X AND RefTable='AP_Journal' AND RecordStatus='Active')`. Đã patch Live.
- SelectGRN_SWHARTANAH.aspx.cs filter header sai: `GRNNo IN (SELECT ... FROM View_AP_JournalItem_SWHARTANAH WHERE quantity>0)` (view gồm cả dòng Voided). Fix: `EXISTS (SELECT 1 FROM PO_GRNItem gi WHERE gi.GRNID=a.GRNID AND gi.BalanceQty > 0)` (áp sau data patch).
- SWHARTANAH-325: consultant làm rõ — Duplicate được copy tự do (kể cả invoice có GRN); hạn chế DUY NHẤT là trùng Supplier+DocumentNo; kiểm tra lúc SAVE, không lúc Page_Load. Fix chặn Duplicate ở Page_Load là SAI, đã revert — không đưa lại. Hướng đúng: ở UpdateGRNItemDetail case Added, `if (grnItem.BalanceQty < Convert.ToDecimal(row["Quantity"])) throw ...` trước khi trừ. (Trạng thái mới nhất xem ticket-index: fix 325 đã test PASS kịch bản chính trên Live Testing, guard đặt theo RowState Unchanged/Modified.)
- Bug phụ đã gặp: `int.Parse(DataAccessHelper.ExecuteScalar("SELECT AccountID FROM View_AP_Journal WHERE APJournalID = " + sKey))` NullReference (~line 486) — nghi do ExecuteScalar dùng connection khác ngoài transaction của `da` (ReadCommitted). Chưa chứng minh; bài học: cần bằng chứng runtime (Profiler/debugger) thay vì đoán từ đọc code tĩnh file 1468 dòng.
- Bug nhỏ chưa xử lý: field "Inter-Company" bị copy từ dòng invoice gốc khi duplicate (pre-fill phía client grid binding, chưa tìm thấy).
- Kỹ thuật: grep `Action.ToLower() == "duplicate"` ra 3 chỗ (~300 Page_Load reset key, ~606 Save_PO_PurchaseItem — red herring, ~1093 UpdateGRNItemDetail — chỗ quan trọng). `delGrnItem(isCleanAll)` (JS) xoá dòng gắn GRN khỏi grid.

## Report dataset chính vs subreport lồng — 2 nguồn SQL riêng (LKHS-298)
- Report hiện chứng từ (Invoice) với payment/receipt allocate lồng bên dưới thường từ HAI SP riêng: SP chính (danh sách phẳng, vd AR_OtherDebtorAccountStatement2) + SP subreport cho phần "allocate vào chứng từ này" (vd AR_OtherDebtorAccountStatement2Sub, params @DocumentNo/@TransactionType/@AsAtDate/@CompanyID/@DocumentID). SP chính đúng mà bug nằm ở SP subreport — luôn xem thiết kế RDLC (tên vùng subreport) để tìm SP thứ 2.
- Bug hay gặp: SP subreport join AR_Allocation → CB_Receipt/AR_Trx hiển thị nhầm `AllocDate` thay vì `DocumentDate` của receipt/adjustment.

## Cash Management: Misc/Other Receipt (CM_OtherReceipt) — SWZECON
- Màn: Cash Management > Receipt > Misc Receipt ("Miscellaneous Receipt"), `CashFlow/ACOtherReceiptEditN.aspx`, class `CashFlow_ACOtherReceiptEditN`, Sys_Tab `AC.OtherReceipt`. Số `<CompanyCode>/OR/<seq>`.
- Header: `CB_Receipt` (PK `CBReceiptID`), `ReceiptType='CM_OtherReceipt'`.
- Detail (grid Receipt Detail): dùng lại `AR_Trx` với `AR_Trx.IsFromAC='Y'` (DocumentDesc, BillItemID, DocumentAmt, ChargeAmt, TaxID/TaxRate/TaxAmt, DeptID, InterCompanyID).
- Bảng nối: `AR_Allocation` (ReceiptID → CB_Receipt.CBReceiptID, BillID → AR_Trx.BillID). Grid đọc qua `View_AR_OtherTrxItem WHERE ReceiptID=<CBReceiptID>`.
- Query verify: `SELECT cbr.CBReceiptID, cbr.DocNo, art.BillID, art.DocumentDesc, art.BillItemID, art.DocumentAmt, art.TaxID, art.TaxRate, art.TaxAmt, art.DeptID FROM CB_Receipt cbr JOIN AR_Allocation aa ON aa.ReceiptID=cbr.CBReceiptID AND aa.RecordStatus<>'Inactive' JOIN AR_Trx art ON art.BillID=aa.BillID WHERE cbr.DocNo=@DocNo`
