# IFCA — Context nghiệp vụ các Jira đã làm (bản rút gọn, không kèm code)

> Rút từ các file chi tiết ticket trong claude.ai Project. Chỉ giữ: màn hình/menu, bảng/view/SP, luồng nghiệp vụ, root cause, quyết định, trạng thái, bài học. Code fix đầy đủ xem source/TFS. Các ticket có file chi tiết đầy đủ nằm trong `docs/tickets/`.

## SWZECON

### SWZECON-90 — Print PV(OP): ẩn dòng Journal DR=0/CR=0 (đóng 03/11)
- CM > Payment > Payment Verification > PV(OP). Report `CB_PVWithoutChequeOP_SWZECON`, subreport `..._Sub1_SWZECON` → WebMethod `GetPreviewJournalData3` (thêm ở SWZECON-75 để fix thứ tự). Luồng: `ACPaymentListPrint.aspx` → `GLDoubleEntryPreviewGenerator.GetPreviewJounals` → SeqNo (Debit trước, Credit sau) → UNION ALL + GROUP BY AccountCode/CodeName/Dept/Project.
- Fix: thêm `HAVING SUM(DebitAmt)<>0 OR SUM(CreditAmt)<>0` vào câu SQL cuối (không lọc trong foreach vì chuỗi rỗng sẽ lỗi `Substring(10)`; không đụng hàm dùng chung). Lưu ý: mọi report gọi method này đều ẩn dòng 0.

### SWZECON-98 — Debtor Control Summary lệch do cặp OD_Adjustment Voided (đóng 26/10)
- Other Receivable > Report > Debtor Control Summary (`AR_CUS_DCS01_SWZECON`, SP `pro_AR_DebtorControlSummary_SWZECON`). Company Parkyocar (prefix `PYCSB/`), debtor PYC CONSOL - TNG.
- Cặp Voided ARCM00000007 (+31,582.10, IsDebit N) / ARDM00000014 (−31,582.10, IsDebit Y) net 0 — dấu ngược chứng từ thường. CASE SWZECON-66 bên Credit dùng `ABS()` mất dấu → Closing trừ 2 lần.
- Fix: Credit = `-DocumentAmt`; loại cặp OD_Adjustment Voided tự triệt tiêu (cùng debtor, tiền đối nhau, nối qua ReferenceNo/DocumentNo, cả 2 trong kỳ). Summary SUM theo DocumentAmt, khác Ledger Detail dùng Allocation/Balance.
- Đối chiếu đúng: report Debtor Ledger Detail By Trx Date.

### SWZECON-99 — Patch Other Payment → Bill Payable (đóng 26/10)
- CM > Payment > Payment Verification (`CashFlow/ACPaymentBookEdit.aspx`). Consultant Edward. 2 payment BF: SSB/PV00000040 (CBPaymentID 53, company 182), ZCS/PV00000002 (59, company 183).
- Nghiệp vụ: popup "Default Pay Type" khi tạo Payment có Other Payment / Invoice (= Bill Payable). Other Payment KHÔNG allocate được vào invoice.
- DB: `CB_Payment.PaymentType` `'CBOtherPayment'` vs `'Invoice'`; `CB_Trx.TrxType='AccountPayment'` chung cả 2; field "Advance" = `CB_Payment.AllocBalance`; payment BF có `GLRefTable1='GL_SubLedgerInitContra'` (GL từ Sub-Ledger Init Contra → không đụng GL).
- Patch PaymentType + `CBUpdateAccountBalance` (609, 615). Payment không phải BF có thể đã ghi GL thẳng vào chi phí → đổi loại phải consultant review.

### SWZECON-100 — Debtor Control Summary mất debtor chỉ có Opening (đóng 27/10)
- Cùng SP với SWZECON-98. Company Zecon Construction Services. Kỳ 2026 mất 9 debtor có số dư cuối 2025 nhưng không phát sinh.
- Root cause: tập dòng do giao dịch trong kỳ quyết định (`#temDebtor` + `FROM #tempARJ001 LEFT JOIN #tempOpening`).
- Fix: `#temDebtor` thêm debtor có Opening ≠ 0 + dòng placeholder 0/0. Gotcha: ngày placeholder phải cắt về 00:00 (criteria UI `<='yyyy/mm/dd'` = 00:00, nếu dùng 23:59:59 bị `delete where not (@QueryCriteria)` xoá).
- Cùng pattern đã sửa ở AP: SWZECON-72/102 (`pro_AP_CreditorControlSummary_SWZECON`).

### SWZECON-82 — Collection Other Receivable post GL sai Department (đóng 11/09)
- Zecon Berhad (CompanyID 187, ZB). Voucher Import `ZB_CB00000086` từ Misc Receipt `ZB_AR/OR00000018`: dòng Bank Debit lấy Dept GEN (Default Apportion Department) thay vì BM như dòng Other Receivables.
- Đã loại: receipt trộn department (cả 6 bill item cùng DeptID 967). `CB_Receipt` header không có cột Department; detail journal là `GL_Voucher`.
- Root cause: chỉ xảy ra trên 1 máy user — IE/Edge IE-mode Trusted Sites > Custom level > .NET Framework chưa Enable (Loose XAML, XBAP, XPS; "Permissions for components with manifests" = High Safety). Không sửa code. Data đã post sai → user làm Manual JV.

### SWZECON-75 — Print PV (without Cheque) thiếu bảng Double Entry (đóng 29/09)
- CM/Payment > Payment Verification > Print. Subreport `CB_PVWithoutCheque_Sub1_SWZECON`, Data Source Type=XML gọi SOAP `GetPreviewJournalData2` (`GLAccount/BusinessJournalReportsWebService.asmx`) → `GLSubLedgerJournalPreview.GetPreviewJounals(SubLedgerCategory.CB_Payment, ...)`. Không đọc thẳng `GL_Voucher`.
- Đã loại lần lượt: code/SQL (debug SQL runtime đúng), mapping Fields/Parameters RDLC, Credentials (lỗi riêng ở local), code server vs local (giống 100%).
- Bước quyết định: gọi thẳng `.asmx?op=GetPreviewJournalData2` trên server → ra đủ data → lỗi ở config report.
- Root cause: Report Parameter `ServiceURL` (expression của connection string) trên Report Server Live có default trỏ sang Train. Fix: sửa default = `http://localhost/SWZECON_Live/GLAccount/BusinessJournalReportsWebService.asmx`.

## SWIBRACO

### SWIBRACO-733 — Print Tax Invoice "Parameter 'BillID' was specified multiple times" (đóng 02/11)
- AR / Print Tax Invoice (`CashFlow/ACPaymentListPrint.aspx`), report `AR_DebtorTaxInvoice_SWIBRACO` (cùng dạng `AR_DebtorTaxEInvoice_SWIBRACO`). Local chạy, server lỗi.
- Root cause: server có thêm điều kiện `_SWIBRACO` (comment SWIBRACO-553, không có trên TFS) đưa report vào nhánh đã add `BillID`; customize `clsACPaymentListPrint.ReportParameter` add `BillID` lần nữa không Remove. TFS đi nhánh `else`.
- Fix: bỏ 2 điều kiện `_SWIBRACO` trên server (theo TFS). Rủi ro: chưa rõ mục đích SWIBRACO-553, `CF_ReportPrintHistory` có thể không còn ghi. File server cũ hơn TFS — không chép đè cả file.
- Pattern: lỗi "Parameter X specified multiple times" → kiểm tra trang đã add X trước `pf_CustomizationChangeValue(..., "ReportParameter")` chưa và customize có Remove không.

### SWIBRACO-716 — In séc Public Bank lệch dòng kẻ (đóng 16/10)
- CM > Payment > in séc, `CB_PaymentVoucherSummaryCheque_SWIBRACO.rdl` (dataset `pro_AC_GetPaymentVoucherSummaryCheque @PaymentID, 8, @Language`). Report không có hình phôi, chỉ textbox đặt tọa độ trên trang 7in×3.5in.
- Root cause: Payee `CanGrow=true` trong row 1 dòng → payee dài đẩy 2 dòng Ringgit xuống; vị trí Date/Amount lệch vài mm; Date căn giữa + space lệch ô.
- Fix: Payee row cố định 2 dòng + VerticalAlign Bottom, chỉnh spacer row (giữ tổng chiều cao tablix), Date Left + Space(6). Payee tối đa 2 dòng.
- Kinh nghiệm: report in phôi sẵn không để CanGrow nếu có item bên dưới; đo lệch bằng ảnh chụp thẳng có thước.

### SWIBRACO-587 — Print PV (without Cheque) sai A/C Code (TAX10030_IC / N/A-AP) (đóng 01/10)
- CM > Payment > Payment Verification > Print PV (without cheque). SP `PRC_AC_PaymentVoucher_Report_SWIBRACO_V2` (in nhiều PV, từ SWIBRACO-166) → `Pro_CB_PVWithoutCheque_SWIBRACO` (#MAIN, phía AP) + `PRC_AC_PaymentVoucher_SWIBRACO` (#CODE, phía GL gồm cả dòng TAX 0 đồng).
- Nghiệp vụ: dòng phiếu là phía AP, mã TK ở phía GL; không có khoá nối từng dòng → SP đoán theo số tiền/mô tả. GL: mỗi dòng chi phí kèm 1 dòng `TAX10030_IC` 0 đồng (ParentID trỏ dòng chính).
- Root cause: bảng thật `TempJournalDetails_SWIBRACO` (không SP nào INSERT, nguồn ghi chưa rõ) không có data → fallback: `View_AP_JournalItem_SWIBRACO.ItemNo` (item code `N/A-AP`, không phải TK) hoặc `TOP 1` không ORDER BY trúng dòng TAX 0. Thêm: bước 1 không scope theo payment khi in nhiều phiếu.
- Fix: scope theo CBPaymentID; fallback từ #CODE theo PV+remark+amount bỏ dòng 0, invoice tách nhiều dòng → TK dòng lớn nhất. Giới hạn: 1 dòng/invoice.

### SWIBRACO-681 — SST Payable and Tracking: dropdown Module trống (đóng 17/09)
- GL > Reporting, `ReportNo='SSTPayable'`. Chi tiết cơ chế `ReportFilter2.aspx.cs` + `Sys_ReportFilter`: xem nhóm bug #11 trong `ifca-domain-reference.md`.
- Root cause: `BuildCell()` dùng `"year,startmonth,endmonth,month,moduletype".Contains(fldName)` → `module` khớp substring → route sang `InputGLSelect()`. Fix: `Array.IndexOf(...Split(','), fldName) >= 0`. Bug standard; dòng ~658 (report AP) cùng pattern chưa sửa.

### SWIBRACO-686 — Print Listing Other Payment thiếu record khi lọc Payee (fix DB-level, chờ consultant UI)
- CM > Payment > Other Payment > Print, report `CB_OtherPaymentHeader` (dynamic SQL + `@QueryCriteria`). Company ICN (226), Payee "msig": list 10, print 6.
- Root cause: WHERE áp lên `View_CB_OtherPayment` (PayTo raw), cột hiển thị lấy subquery từ `View_CB_OtherPayment_SWIBRACO` (PayTo = tên Creditor qua `CreditorID` → `view_ap_creditor`, fallback raw). 4 payment có CreditorID nhưng PayTo raw trống.
- Fix: đổi FROM sang view `_SWIBRACO` (superset cột), bỏ subquery. Lưu ý: `CB_Payment.IsCreditor/CreditorName` là cột legacy, không dùng để kết luận.

## TIMATCH

### TIMATCH-436 — Letter Bill Adjustment (Credit Memo): TaxRate in rỗng (đóng 27/10)
- Rental Management > Customized Setup > Standard Letter > Bill Adjustment (Credit Memo), LetterID 1192 "Kilanas SB - E-CN". Master `View_MC_LetterAdjustment_Report` (TaxCode của chính CN + `AR_Trx.TaxRate`), Sub `View_MC_LetterAdjustment_Sub_Report` (TaxCode của invoice allocate, không có TaxRate).
- Data đúng (TaxRate 0, TaxID 867 = 'NA'). Root cause: `{ MERGEFIELD "TaxRate" }` không có numeric switch → Word in 0 thành rỗng. Fix template: `\# "0.00"` (dùng `0` không dùng `#`; Ctrl+A → F9). Cùng lỗi TIMATCH-157. Đề xuất rà các letter CN/DN khác.
- Thứ tự loại trừ field Letter in trống: data → view Master/Sub → query thật lúc in (Profiler, `PrintService` có `mainSql` riêng) → field code (Alt+F9).

### TIMATCH-375 — AP Unallocation: grid Invoice không cuộn dọc (đóng 23/10)
- Account Payable > AP Unallocation (menu `CB-15-31`). Cha `CashFlow/ACPaymentDirectUnAllocationPV.aspx` (SysList2 50% + SysContainer tab + iframe `dnFrame` 50%), con `ACPaymentDirectUnAllocationIN.aspx` (SysListEditor2 `CB.PaymentUnAllocationIN`).
- Root cause layout: grid con không có Height/Width (không scrollbar riêng, `Master1row` cắt), 50%+tab+50% > 100%. Phụ: `f_init()` nạp nhầm trang AP Allocation.
- Fix chốt theo TFS: grid `Height="50%" noResize="Y" Width="100%"`; sửa `f_init()`. Phương án `calc(50% - 32px)` test OK nhưng không dùng.
- Debug F12: app chạy trong frame của `loading.aspx` → đổi context Console sang đúng frame hoặc dùng `$0`.

### TIMATCH-399 — Rental Invoice Letter: ReferenceNo in sai (đóng 24/09)
- Standard Letter > Rental > Invoice, LetterID 1180 (Master `View_MC_Bill_Letter_Main_OK` có `'' as ReferenceNo` placeholder, Sub `View_MC_Bill_Letter_One`); ~10 letter dùng chung view.
- Root cause trong `PrintService` `mainSql` (NAIMCAP-336): `select top 1 ReferenceNo from View_MC_Bill where BillID = BillID` không qualify → luôn đúng → giá trị rác giống nhau cho mọi invoice. Bản TFS "fix" vẫn sai (vế phải vẫn resolve về cột trong subquery).
- Fix: `(select t.ReferenceNo from AR_Trx t where t.BillID = aa.BillID)`. Cùng lỗi chưa fix ở `case "114"`/`"1114"` (meter bill: ProjectName/ReferenceNo).
- Placeholder `''` trong view Master Letter → giá trị thật gán trong `mainSql` của PrintService (search mã ticket trong code).

### TIMATCH-414 — Print Credit Memo (OR AR Adjustment): TOTAL sai (đóng 23/09)
- Other Receivable > AR Adjustment > Print Credit Memo, `AR_ARAdjustmentCM_TIMATCH.rdlc`: Header `View_AR_AdjustmentOfOtherDebtorPrint`, Detail `View_AR_AdjustmentDetailOfOtherDebtor`.
- Root cause: changeset TIMATCH-386 bind TOTAL vào `TotalAllocatedAmt` (tổng allocate lũy kế của invoice đích) thay vì `AdjustmentAmt` (Allocated Amount của chính CM). Fix: `=FormatNumber(Sum(Fields!AdjustmentAmt.Value), 2)`.
- RDLC local mode: `<CommandText>` trong .rdlc KHÔNG chạy — data do C# đẩy qua `ReportDataSource`; field không có cột → Nothing (0.00) không báo lỗi.
- Ticket mới ngược với ticket cũ cùng chức năng → xem changeset ticket cũ trước.

### TIMATCH-396 — PV bị revert Verified → Active, không verify lại được (data fix sẵn, code fix đề xuất)
- CM > Payment > Payment Verification, `PFSB/CBPV/00000026` (CBPaymentID 18108, BankAccountID 684 HSBC). Lỗi "already verified, can not verify again!".
- Data: `GL_VoucherMain` Accounted + `CB_Trx.IsVerified='Y'` nhưng `CB_Payment.RecordStatus='Active'` (ModifyDate muộn hơn 18 ngày, cùng user).
- Root cause: `CashFlow_ACPaymentBookEdit_TIMATCH.aspx.cs` `saveButton_Click` rẽ nhánh theo biến `recordstatus` lấy từ URL lúc OnInit (tab/link cũ) → rơi vào nhánh Save toàn bộ, ghi đè RecordStatus cũ. Hàm `SaveData()` cũ trong cùng file làm đúng (đọc DB).
- Data fix: UPDATE RecordStatus='Verified' + `CBUpdateAccountBalance 684`. Code fix: điều kiện theo `orginalPayment.RecordStatus` vừa fetch. Chưa merge.

## SWHARTANAH

> Màn AP Invoice Entry của Hartanah: `Payable/APInvoiceEntry_SWHARTANAH.aspx(.cs)`, grid Invoice Detail `SysListEditor LstNo=AP.JournalItem_SWHARTANAH` (view `View_AP_JournalItem_SWHARTANAH`, BseIdField `POItemID`, write `PO_PurchaseItem`), popup `SelectGRN_SWHARTANAH.aspx`. Duplicate qua `clsAPJournalList.cs` → `?action=duplicate`. Chuỗi ticket 97/294/324/325/350. Bản GRSUMMIT gần như clone bản này (xem GRSUMMIT-220 trong ticket-index).

### SWHARTANAH-350 — Save invoice lỗi "POItemID constrained to be unique, '-1'" (đóng 26/10)
- Lỗi nổ lúc Infragistics nạp client state (`GridBot.LoadAdditionalClientState`), TRƯỚC `SaveDataMethod` → không liên quan code save C#.
- Root cause JS: ID tạm âm lấy từ biến global `lastPOItemId`; `ImportApplyDetails` reset về 0 kể cả khi popup Import GRN Select rỗng (`f_choose()` vẫn gọi opener với mảng rỗng) → cấp lại ID trùng dòng đang có hoặc dòng đã Add-rồi-Delete (grid vẫn gửi transaction add+delete).
- Tái hiện: Add → Import GRN Select rỗng → Add → Save.
- Fix JS: `f_GetNextTempPOItemId()` = min(bộ đếm, poitemid trên grid) − 1; bỏ reset. Ngoài phạm vi chưa sửa: `AfterCellUpdateHandler` nhánh taxamt gọi `GetSelectedRow()` null; popup Import GRN trống khi ≥2 dòng tay (`grnitemid not in (null,null)`); `UpdatePO_PurchaseItem_SWHARTANAH` luôn INSERT kể cả Modified → trùng bảng `_SWHARTANAH`.

### SWHARTANAH-325 — Duplicate Invoice có GRN: guard đặt sai nhánh RowState (test PASS kịch bản chính trên Live Testing, còn regression)
- Nghiệp vụ (Edward): khi Duplicate, dòng còn giữ GRN kế thừa từ invoice nguồn (Unchanged, hoặc Modified không đổi GRN) phải bị CHẶN (GRN đã bị invoice nguồn tiêu thụ); GRN user chủ động chọn lại (Added) là hợp lệ. Hạn chế thật chỉ là trùng Supplier+DocumentNo.
- Root cause: `UpdateGRNItemDetail` đọc RowState thật, guard 324 đặt ở `Added` → chặn nhầm GRN mới, bỏ qua GRN kế thừa. `Save_PO_PurchaseItem` ép mọi row thành Added khi duplicate, nhưng gán `RefTable` theo RowState thật → dòng Deleted bị ép INSERT với RefTable NULL.
- Fix: guard chuyển sang `Unchanged`/`Modified` khi duplicate; `Deleted` khi duplicate không restore balance; `Save_PO_PurchaseItem` skip dòng Deleted khi duplicate.
- Chưa chạy: no-touch Duplicate phải bị chặn; sửa qty phải bị chặn; Duplicate không GRN không chặn; kiểm BalanceQty GRN cũ/mới; luồng Edit thường.

### SWHARTANAH-333 — GRN cho chọn lại PO đã nhận đủ (fix đề xuất, chờ test)
- PO `HCSB/PO00001254`: GRN000048 nhận đủ → Goods Return (user DARREN, qua app) → `PO_PurchaseItem.BalanceQty` 0 → 14 (đúng 7) → GRN thứ 2 chọn lại được.
- Root cause: `PurchaseOrder_GoodsReturnEdit.aspx.cs` gán cùng `SaveData()` cho 2 SysListEditor (item + file đính kèm) → chạy 2 lần/Save; biến `IsReturn` gán ngoài nhánh `RowState.Added` → khối UPDATE restore balance (qua `CF_XRef` GRN return ↔ GRN gốc) chạy 2 lần.
- Fix: dời gán `IsReturn` vào nhánh Added. Root cause tìm bằng trace audit log (quy trình trong domain reference).
- Popup chọn PO khi tạo GRN: `View_PO_PurchaseOrder_PurchaseItem_Select`, điều kiện `BalanceQty > 0`.

### SWHARTANAH-327 — PO Remark hiện `<br/>` sau Save (đóng 08/09)
- PO > Detail > popup Item Description (`ItemDescriptionAdd.aspx`). Data lưu sạch (CR/LF). Root cause: view customize `View_PO_PurchaseOrder_PurchaseItem_AllDeptName` có `REPLACE(a1.Remark, CHAR(10), '<br/>')`; grid không render HTML. TFS: `substring(REPLACE(a1.Remark,'<br/>',''),0,2000)`. Fix theo TFS.
- Dead code: JS `replace('/(\n|\r\n)$/', '<br>')` regex trong nháy, không tác dụng. Hook `pf_CustomizationChangeValue(..., "PORemark")` không đổi gì.

### SWHARTANAH-324 (đã deploy Live 02/09) / 97 / 294
- Duplicate Invoice có GRN trừ lại `PO_GRNItem.BalanceQty` như nhận hàng mới → ~1,500 dòng hỏng. Công thức tính lại: `BalanceQty = Quantity − SUM(PO_PurchaseItem.Quantity WHERE GRNItemID=X AND RefTable='AP_Journal' AND RecordStatus='Active')`. Filter popup SelectGRN đổi sang `EXISTS (PO_GRNItem.BalanceQty > 0)`. Chi tiết trong `docs/memory/framework-reference.md`.

## FPARK (Financial Park Labuan, company FPL, CompanyID 181)

### FPARK-197 — Other Receivable Billing: Duplicate copy BalanceAmt → invoice Balance âm (đóng 27/10)
- Other Receivable > AR Transaction > Billing (`AccountReceivable/OtherBillList.aspx`), nút Duplicate → `f_Duplicate()` → WebMethod `DuplicateOR` (không confirm).
- Root cause: `DuplicateOR` copy `BalanceAmt` của invoice gốc (đã thu → 0/âm) thay vì = `DocumentAmt`. Đúng ra Balance = 0 (consultant ghi "phải 50" là sai). TFS đã có fix; FPARK chạy bản cũ — chỉ áp 1 dòng (không kéo Param-2148 DocNo `-Clone`, TaxExempt*...).
- Nhận diện dòng do Duplicate: `CreateDate` tròn giây (.000), `CreateUserID=1`, `DocumentDate` copy từ gốc. Unallocate/allocate lại không sửa được → patch 6 dòng Live (MI001654/1656/1660/1777/1812/1898).
- Chưa trace: vì sao chỉ 1 số dòng lộ lỗi (giả thuyết: dòng user sửa Amount được tính lại balance).

### FPARK-207 — Invoice Letter: thêm datasource Unallocated Amount (đóng 30/09)
- Rental > Customized Setup > Standard Letter > Invoice, LetterID 1228 "FPL - Invoice with Statement" (LetterTypeID 53). Master `View_MC_Bill_Letter_Main_ok` (chung), Sub `View_MC_Bill_Letter_One_FPARK`.
- Kiến trúc letter Invoice FPARK (từ FPARK-183, TFS changeset 96330): DLL `IFCA.Business.Customization.FPARK` — `ChangeBseReadTable` đổi sang view `_FPARK`; `SWCustomizationChange` (letterType 53) → `clsPrintService.SWCustomizationChange_53` trả full mainSql (derived `aa` + GROUP BY, cột FPARK bọc MAX()). **Thêm field mới phải sửa 2 chỗ**: cột trong view `_FPARK` + `SWCustomizationChange_53`.
- UnallocatedAmount = SUM `CB_Receipt.AllocBalance` (MC_Fee, Active/Verified, DocumentAmt>0, DocumentDate ≤ Invoice Date) — theo logic aging `Pro_MC_BillAge_SQL_DebtorDetail_ByDocDate_FPARK` (`#RECEIPTTABLE`; SP con `Pro_MC_BillAge_SQL_ByDocDate_FPARK` luôn trả 0 UnallocAmt; dùng AllocBalance hiện tại, không as-at).
- Amend: TotalAmountDue = Remaining + Current − Overpayment (chỉ sửa view). Còn lỗi kiểu TIMATCH-399 trong `SWCustomizationChange_53` (ReferenceNo).

### FPARK-208 — Invoice Letter: Remaining Unpaid Balance trừ tiền trả trước vào invoice hiện tại (đóng 01/10)
- Cùng letter/view với FPARK-207. Nghiệp vụ Summary of Charges (as at Invoice Date): Total = Remaining + Current − Overpayment; Remaining = nợ invoice KHÁC − tiền đã allocate vào invoice này (receipt/CN ngày ≤ Invoice Date), có thể âm. Theo hệ cũ PowerBuilder `wr_ar_schbill_invoice`.
- Gotcha: view tính theo từng BillID, nhưng `SWCustomizationChange_53` lọc `ranks = 1` (1 dòng/invoice/unit, không MAX) → mọi BillID cùng invoice phải ra cùng giá trị → tính ở mức invoice (OUTER APPLY `Inv`: MinBillID, InvAmt; `PrePaid` theo logic aging subquery b + d).
- Bài học deploy: Live từng chạy bản view trung gian thiếu phần nhiều dòng → kiểm `DB_NAME()` + so `OBJECT_DEFINITION` Live vs Train trước khi ALTER. Data Train khác Live. Query `DISTINCT` cả view rất chậm — lọc invoice mẫu vào bảng tạm trước.
- EU confirm tính as at Invoice Date (DN ngày sau không cộng).

### FPARK-166 / FPARK-187 / FPARK-201 — xem `docs/tickets/FPARK-166-...md` và `docs/memory/ticket-status.md`.

## JESSELTON

### JESSELTON-272 — Payment Verification: Cash account PC-ADMIN_JP không hiện trong cây Bank Selection (đóng 03/10)
- CM > Payment > Payment Verification, company JP (184). PV CASH BankAccountID 618.
- Root cause data: CashAccount 618 bị gắn `CF_BankAccount.AccountID = 247393` ("ngân hàng giả" PETTY CASH tạo lúc migration). Cây: nhánh Bank = BankAccount có `CF_Account`; nhánh Cash = CashAccount có `AccountID IS NULL` (suy từ data + test). Đã loại: `ReconciliationMode 'M'` vs `'Munual'`, `OverdraftLimit` NULL (record PALI giống vẫn hiện).
- Fix: `AccountID = NULL` (không xoá CF_Account; không cần CB recalculate). Chi tiết bảng `CF_BankAccount` trong domain reference.
- JESSELTON-282: xem `docs/tickets/`.

## LKHS (Singapore — nhánh TFS NET4.0_SG / IFCA.NET 4.0_SG, sửa thẳng Standard, không hậu tố)

### LKHS-327 — Rental System Parameters: tab Rental không Save được (đóng 21/10, sub-task rollout LKHS-282)
- Rental Management > System Parameters, tab Rental. JS `f_save()` dùng `getElementById("ctl00_RightContentPlace$NotRentalColor")` (`$` = UniqueID, phải `_` = ClientID) → null → TypeError → không submit. Chỉ tab Rental bị. Fix 1 ký tự. Chưa so TFS.
- Mapping UI ↔ `CF_Parameter` (Class Rental): "First month prorated billing Cut-Off Day" = `UnPeriodAlgorithm`; "Last month prorated billing Cut-Off Day" = `UnPeriodAlgorithm_up`; giá trị 0 hiển thị "Please Select".

### LKHS-282 — Bill Schedule gộp sai kỳ khi đổi rate giữa tháng (fix tham số, đã verify Train)
- RM > A/c Receivable > Bill Schedule. Hợp đồng có 2 dòng Schedule Billing nối tiếp (đổi rate 25/09) → tháng 08 bị gộp tới 24/09, thiếu dòng 01–24/09. Đối chứng Edge23 (TFS baseline).
- Code sinh `MC_BillSchedule` cho Rental Charge: `RentalCommon.RtContractSum` (đọc `RT_ContractCharges`) → `GetSysEndDate`: rule gộp phần dư cuối kỳ khi `EndDate.Day <= UnPeriodAlgorithm_up`. Đã loại: `ArCreateBill.aspx.cs`, `ArCharge.CreateArBill` (chỉ post schedule có sẵn), `McArBill.AddBillScheduleItem` (MaintainFee/OtherFee), code comment chết.
- Root cause: tham số `UnPeriodAlgorithm_up = 28` (quá cao). Fix: = 0 qua UI. Code chuẩn giống client khác (client e-invoice có hook `GetChangeValueUnPeriodAlgorithm` ép 0 — LKHS không cần).
- Mẹo test hợp đồng Approved: Cancel → về New → Edit → Save tab Schedule Billing → Submit → Approve → regenerate. Đổi tham số không tự sửa schedule cũ; CF_Parameter cache RAM → recycle app pool.

### LKHS-317 — Tax Adjustment Journal Posted nhưng không lên GL (đóng 12/10; lặp ở 196/270/311 + S37/GL/TXADJ/27-0009)
- GL > GST Tax Apportionment > Tax Adjustment Journal. Pattern: `GL_VoucherMain` (VoucherCategory 'TaxAdjustment') = Accounted nhưng 0 dòng `GL_Voucher`; `PM_LedgerMain`/`PM_ProjectLedger` (RefTable 'PM_LedgerMain') = New.
- Xử lý (theo dev LKHS-311): đưa về trước Approve — GL_VoucherMain → Active, PM → New (nếu khác) → user Approve lại + Journal Posting lại. KHÔNG dùng cách LKHS-270 (Reverse). Root cause code chưa trace (nghi `TaxAdjustmentJournalVoucher.Approve()`/`PostProjectLedger()` lỗi giữa chừng) — nên mở ticket riêng.

### LKHS-303 — Reversal Posted JV: đổi dấu thay vì hoán đổi + Digest cũ (test pass DB clone, chờ Production)
- GL > Journal Processing > Reversal Posted JV (`GLVoucher.aspx.cs`, `action=eliminations`, `LoadEliminationsData`, `SaveVouchers`). JV reversal link `RefVoucherMainID`.
- Fix: SELECT hoán đổi cột Debit↔Credit; Digest dòng chi tiết build lại lúc Save = `[GL.Annul]<JV gốc><GL.NoVoucher><mô tả hiện tại>`. Lỗi có ở cả TFS. Chưa sửa `SaveCashFlows()`/`LoadCashFlowXml()` (cùng kiểu đổi dấu). Chữ "Reverse" lấy từ resource string.

### LKHS-231 — Print Journal Listing (Audit Adjustment) không phản hồi (đóng 25/08)
- GL > Journal Management > Audit Adjustment, chuột phải → Print Journal Listing. Lỗi 1: JS hardcode `ctl00_search_SysCondition1_condition` → dùng `<%=SysCondition1.ClientID%>_condition`. Lỗi 2: `f_GetConditionFilter` đọc dropdown ẩn (không có `name`) của popup lịch → `='August'...` → thêm `if (!select.name) continue;`.
- `accountid=-1` = chọn node Group (xem mọi công ty) — report listing chỉ nhận 1 CompanyID, không phải bug.

### LKHS-336 — PM Debtor Aging Detail by Doc Date mất receipt (đóng 20/11, đã áp Live)
- EN275 và EN291 (by Trx Date) dùng chung SP `PMDebtorAgingDetail`; SP lấy As At từ chuỗi `<DetailType><=` trong criteria. `Sys_ReportFilter` EN275 (Standard 2010): ô "Doc" `FldRange=0` → `DOCUMENTDATE='..'`, ô TransactionDate khoảng vẫn Active → SP không có As At → receipt bị loại (Unallocated mất), invoice vẫn hiện.
- Fix: DocumentDate `FldRange` 0→2 + `FldNeed=Y`, TransactionDate Inactive (theo mẫu EN291). Bug Standard — TIMATCH cùng config, hỏi Stanley. Chi tiết `docs/tickets/LKHS-336-pm-debtor-aging-docdate-filter.md`.
- Ngoài phạm vi: Aging Summary by Trx Date ra Owing 1,820 (lẽ ra 180) → đã làm ở LKHS-337; EN361 trùng 5 dòng filter TransactionDate.

### LKHS-337 — PM Debtor Aging Summary by Trx Date: Owing sai (ĐÓNG 20/11 — consultant OK, đã áp Live; CS Dev SG: 99594 · Rel SG: 99614)
- EN292 `PM_DebtorAgingSumByTrxDate`, cùng SP `PMDebtorAgingDetail`; data/criteria đúng. RDL nhánh SG: 3 ô Owing `Sum(Age1..7 - UnallocedAmt)` mà UnallocedAmt âm → 1,000 − (−820) = 1,820.
- Bản Doc Date (SG) và bản chuẩn Malaysia đã dùng `+` → fix Malaysia chưa port sang SG. Fix: đổi 9 chỗ `-`→`+`, không đè file Malaysia. Chi tiết `docs/tickets/LKHS-337-pm-debtor-aging-sum-trxdate-owing.md`.

### LKHS-329, LKHS-271/320/325/326, LKHS-274, LKHS-290/292, LKHS-298, LKHS-322, LKHS-336, LKHS-337 — xem `docs/tickets/` và `docs/memory/ticket-status.md`.

## HARIANPG

> Màn chung: Property Sales > Loan Management > Loan Application (`PSFinance/LoanApply.aspx`), grid `LstNo='View.LN.SaleLoan'`, bảng `LN_SaleLoan`, view `View_LN_SaleLoan` (`'PS_'+RecordStatus AS RecordStatusStringCode`). JS `changeButtonState()` (AfterRowActivate) bật/tắt nút theo `gridManager2.GetValueByName(row, ...)` — **chỉ đọc được cột đang có trên grid**.
> Nút (`Sys_ContextMenu` MnuClass `PS.LN.SaleLoan`): Cancel = `Voided` → `LoanApplyVoid.aspx` (status → cancelling); Cancel Approval = `cancelling` → `LoanApplyApprove.aspx`; Loan Reinstatement = `Reinstatement`; Renotice = `Renotice` → `PSLoanRenotice.aspx`; Print Renotice Billing = `PrintBilling` (Letter TypeID 35). Status: New(Active)/Signed/Cancelling/Cancelled(Voided).

### HARIANPG-45 — Nút Cancel Approval dim (đóng 07/10)
- Unit Plot 68 / PT 5844, SaleLoanID 1033, status đúng `cancelling`. Root cause: cột Status (`RecordStatusStringCode`) bị ẩn trên grid → status rỗng → nhánh else disable `cancelling`. Fix: bật lại cột Status trong layout. Không sửa code/data. `accessvalue="_accessdenied"` có trên mọi nút — không phải cờ phân quyền.

### HARIANPG-46 — Nút Print Renotice Billing dim (đóng 07/10)
- Cùng loan. Layout LstOrder 1 thiếu field `RenoticeDate` (LstOrder 2 có) → JS đọc rỗng → disable. Fix: thêm RenoticeDate qua List Layout Configuration. `IsDocCompleted` cũng không có trên layout (nhánh Signed&&Y không bao giờ khớp, không ảnh hưởng). Đề xuất chưa làm: JS lấy status từ server theo SaleLoanID.

## ASPENPG (Aspen Vision City, CompanyID 12, prefix AVC/)

### ASPENPG-637 — Misc Invoice không hiện trên Project Ledger (không phải bug, 30/09)
- PM > Reporting > Project Ledger: `Pro_PM_ProjectLedger` đọc `View_PM_RPTProjectLedger` = `PM_ProjectLedger` ⨝ `PM_LedgerMain` (không lọc loại chứng từ; `lm.AccountType='Actual'`, `pl.LedgerType<>'Summary'`...).
- Nghiệp vụ: chỉ AP Invoice (→ `PM_Invoice`) và AP Adjustment (→ `PM_SAdjustment`) tự vào Project Ledger. Misc Invoice/Payment (`AP_Journal.PayableType='Miscellaneous'`, `CB_Payment` Miscellaneous) chỉ vào khi user tạo **Project External Journal** (PEJ, `RefTable='CB_Payment'`, `SourceTable='AP_Journal'`) thủ công. Payment Voucher cũng vào nếu có PEJ.
- Query: `SELECT RefTable, COUNT(*) FROM PM_LedgerMain GROUP BY RefTable` để xem nguồn nào vào PM.
- ASPENPG-684/686/689/690: xem ticket-index / ticket-status.

## FARLIMPG

### FARLIMPG-167 (+150) — Periodic Sales Report: Collection This Period chỉ tính Progress Billing (đóng 29/09)
- Property Sales > Reporting > Periodic Sales Report, dataset `PeriodicDataSet` = dynamic SQL nhúng trong report (`@AsAtDate`, `@CompanyID`, `@QueryCriteria`). Project Impiana Upeh.
- Nghiệp vụ report: nhóm Project→Phase→Block→Property Type; Sale `RecordStatus IN ('Sale','Sign')` (Sale = booking, Sign = đã ký SPA; Period Sale theo SaleDate, Sign theo ContractDate). This Period = ngày 1 tháng As At → As At. Billing This Period loại Interest/IsContra/IsRebate (FARLIMPG-150). CN/Rebate coi như "đã thu" → cộng vào Collection. Todate Billing = UnitFee − Purchase Rebate (`ItemCode='PR'`). Outstanding = Todate Billing − Todate Collection. Chuẩn đối chiếu: cột Progress Billing của Daily Collection Report (tách receipt theo allocation: Progress Billing / Misc / Interest / Unallocated).
- Root cause: lấy header `CB_Receipt.DocumentAmt` theo ngày receipt → gồm Interest + Unallocated. Fix: block `PBOR` = AllocAmt của receipt trong kỳ vào bill `ElementCode='UnitFee'` + `CNRF.PeriodCNRFDocAmt`.
- Ngoài phạm vi: Todate Collection còn dư Unallocated; có thể dính lãi khi bill Interest có ngày > As At (OtherOR lọc theo ngày bill); advance chưa allocate không vào kỳ; dùng allocation hiện tại.

### FARLIMPG-169 — Auto Reversal AR Adjustment lỗi cast Double/Decimal (đóng)
- Client FGMB. Other Receivable > AR Adjustment > Auto Reversal → popup "Adjustment Void" → Save → "The value 0 is of type 'System.Double' while the field is of type Nullable<Decimal>".
- Điểm throw: `ARVoidTransaction.VoidAdjBill` (App_Code/PM) → `ClassUtil.EntityClone<ARTrxEntity>` (reflection, không ép kiểu). `AR_Trx` chỉ 3 cột float: ExchangeRate, TaxRate, TaxExemptRate. Bill lỗi có `TaxExemptRate = 0`, bill OK = NULL. 51 bill OD_Adjustment cùng pattern.
- Nguồn: `AccountReceivable_OtherAdjustmentEdit.aspx.cs` `Save_Click` ghi `TaxExemptRate` vô điều kiện qua NameValue (giống TFS). Không set NULL được qua `SysTabEdit1.SaveData` extendData (`SqlExpression.String`, '' → 0); field `TdtFldEdit=0` ở tab `AR.AdjustmentOfOtherDebtor`.
- Fix chốt: trong `VoidAdjBill`, sau `SaveEntity(adjTrx)` và trước `EntityClone`, set `adjTrx.Fields["TaxExemptRate"].CurrentValue = null` khi TaxExempt≠'Y' và giá trị = 0. Không patch data, không sửa Save_Click. Nghiệp vụ: 0% exempt = không exempt.

### FARLIMPG-126 — Sale Status Report (A3): Rebate Amount chỉ tính LOT - DISCOUNT ALLOWED (chờ business về biến thể)
- Property Sales > Reporting > Sale Status Report (A3), view `View_PS_Sales_Status_Report_FARLIMPG_Final`, cột `RebateAmount` (subquery `CNRebate`: AR_Trx ⨝ AR_BillItem `IsRebate='Y' AND IsContra='Y'`, ElementCode 'Adjustment', WFRecordStatus Approved).
- Nghiệp vụ: LOT DISCOUNT ALLOWED = chiết khấu giá lot; Interest Rebate = hoàn lãi theo dòng tiền — khác bản chất, `IsRebate` gộp cả 2.
- Fix: thêm `t2.ItemName = 'LOT - DISCOUNT ALLOWED'` (BillItemID 992 Active, 1127 InActive). Chưa gộp biến thể (COMMERCIAL)/(SG)/(VL) (993–995) — nếu business muốn thì `LIKE 'LOT - DISCOUNT ALLOWED%'`.
- FARLIMPG-147/150/165: xem ticket-index / ticket-status.

## SUMMERPG

### SUMMERPG-20 — Area Variance Management: Compensate yellow page (đóng 24/09)
- Property Sales > Account Receivable > Area Variance Management (`PSContract/PSBalance.aspx`). Nghiệp vụ: chênh diện tích SPA vs diện tích thực tế (Actual Built-up Area) → developer bù tiền buyer; nút Compensate sinh chứng từ AR dùng Bill Item `ItemCode='Compensate'` (BillItemID + TaxID).
- Root cause: Bill Item Compensate bị InActive → query 0 dòng → `Rows[0]` lỗi. Fix data: active lại. Query không lọc company; guard code chưa áp.
- SUMMERPG-24 ("Specified cast is not valid" khi Add Billing OR): nhiều khả năng giống PALMINGTONPG-4 (trigger `PREVENT_DUP_INSERT`).

## GRSUMMIT

### GRSUMMIT-204 — Patch Document/Balance Amount âm cho OD Adjustment (đóng 10/09)
- OR > AR Adjustment (tab `AR.AdjustmentOfOtherDebtor`), `GSDEVP/ARDM/26/09/0001` (BillID 10401), hiển thị 0 thay vì −776,115.20.
- `Sys_Base`: read `View_AR_AdjustmentOfOtherDebtor` (ĐẢO DẤU `-(DocumentAmt)`, `-(BalanceAmt)`, `ABS(DocumentAmtBefTax)`), write `AR_Trx`. Patch lần 1 sai dấu (giả định raw = hiển thị). Đúng: raw = +776,115.20.
- Bài học: luôn đọc definition view đọc trước khi patch (nhóm bug #5).
- GRSUMMIT-220/176: xem ticket-index.

## HKB

### HKB/PV/00000149 — Patch DocumentDate bản ghi reversal Cancel Payment (đóng 04/09)
- CM > Payment. 1 DocNo = 2 bản ghi `CB_Payment`: gốc 18761 (+5,550, CB_Trx `IsCancelled='Y'`) và reversal 18773 (−5,550, Remark "WRONG DATE", DocumentDate sai = ngày tạo). `CB_Trx.TrxType='CancelPayment'`, `RefRecordID=18761`. Consultant Edward xác nhận hợp lệ, chỉ patch ngày reversal + `CBUpdateAccountBalance 631`.
- Phát hiện ngoài phạm vi: `GL_VoucherMain 43765` (payment gốc) vẫn Accounted, không bị đảo khi Cancel → GL có thể overstate 5,550.
- Bài học: 1 DocNo nhiều dòng CB_Payment → kiểm `CB_Trx.TrxType` trước khi kết luận duplicate.

## SWCHENGLING

### SWCHENGLING-76 — Progress Billing Statement in chậm ~1 phút (đóng 24/09)
- Property Sales > Letter Printing > Progress Billing Statement, view `View_PSLetter3233_Master_SWCHENGLING` (401 cột, ~60 join) — compile 66–72s, execution 1,6s; filter literal từ `PrintService` → đổi unit là compile lại.
- Fix: SP `usp_PSLetter3233_Master_SWCHENGLING_v4 @SaleIDs` (tính trước vào bảng tạm chỉ cho Sale đang in) + nhánh riêng trong `PrintService.GetMainDataTable` cho view này. View giữ cho Edit Template (`SELECT TOP 0 *`) — sửa view phải sửa SP. 3 câu Sub chưa tối ưu.
- Chi tiết cách đo compile/execution + pattern: nhóm bug #12 và mục `PrintService.cs` trong `ifca-domain-reference.md`.
- SWCHENGLING-74: Sales Cancellation crash do Bill Item Inactive + UnitChangeID trùng.

---

# PHẦN B — Ticket chỉ có trong chat (chưa có file chi tiết / chưa vào index)

> Tóm từ lịch sử chat claude.ai (tới 19/11/2026). Ticket ghi "đang dở" = chưa có kết quả cuối; khi Gunner nhắc lại, dùng đây làm điểm xuất phát, KHÔNG coi giả thuyết là kết luận.

## LKHS
- **LKHS-271 (GIRO) — xem đầy đủ `docs/lkhs-271/00-HANDOFF-LKHS-271.md`. Trạng thái mới nhất 19/11:** LKHS-320 (screen 6 Generate GIRO Collection) + LKHS-325 (GIRO Batch: Batch Generation → file DBS UFF, Batch Listing Reset/Import(Reject)/Import(Success)/Close, Pre-Check→Confirm, Cancel Receipt) đã build end-to-end, test OK trên DB restore. Quyết định: GIRO bank lưu bảng `CF_CompanyGiroBank` (nhiều bank/company); file export/import qua folder server, user upload tay lên portal DBS (không API); Payment Date/Reference No nhập ở step 6 KHÔNG bị batch ghi đè; D35 Identity No lấy `CF_Account.IdentityNo`, thiếu thì chặn tạo batch; status receipt GIRO "Success"/"Failed" (không "Completed"); Rental giữ ReceiptType `MC_Fee`; cây Company chưa lọc. Cancel/Void receipt Failed: tái hiện logic void của từng module TRONG transaction GIRO (Rental dùng `ArCharge.CancellationCB_Receipt`; OR/Construction/PS dùng SQL tương đương) vì gọi màn hình thật không an toàn. **Stanley đã xác nhận** forex gain/loss realized (theo OR Collection LKHS-230) áp cho cả 4 module, gộp vào LKHS-320: GL importer module-agnostic → chỉ sửa allocation handler Rental + Construction (OR đã đúng; PS chưa có data ngoại tệ, hoãn). Còn mở: ẩn receipt GIRO khỏi list collection từng module (3 file nữa), implement forex Rental/Construction, test lại Cancel/Confirm-with-Failed cho 3 module không phải Rental, câu hỏi business (report, FTP/path prod, filter status GIRO trên cây). AR GIRO Status Report = Jira riêng sau.
- **LKHS-335 (đang dở, 17/11):** GL > Journal Posting — Tax Adjustment `LKHS/GL/TXADJ/26-0004` POSTED nhưng không có dòng GL. Lặp lại pattern LKHS-196/270/311/317/319: `GL_VoucherMain` 'Accounted' nhưng 0 dòng `GL_Voucher` (VoucherMainID 1713522; PM_Status New, 8 dòng PM đã có). Xử lý: patch 1 câu đưa header về trạng thái chờ → user re-approve (GL > GST Tax Apportionment > Tax Adjustment Journal) → re-post (GL > Journal Management > Journal Posting). Xem LKHS-317 file. Nghi root cause trong `TaxAdjustmentJournalVoucher.Approve()/PostProjectLedger()` nuốt exception giữa transaction — chưa điều tra code. Chờ xác nhận re-post OK.
- **LKHS-333 (đang dở, 16/11):** McAccount Billing Adjustment (`ArAdjustmentEdit.aspx`) — DN Due Date không sửa được sau Save trên Live; fix đã có trên Train thuộc **LKHS-203** (cho sửa Amount khi Debit Adjustment, sửa DN Due Date, ẩn Add/Delete grid Adjustment Detail). Consultant đồng ý deploy. Config Sys_TabDt/Sys_BaseDt Train=Live → chỉ deploy .cs. Rủi ro đã nêu (chưa sửa): ghép `DNDueDate.Value.ToString()` vào SQL (lệch ngày/tháng theo language login), null khi để trống, ReferenceNo có dấu nháy. Test: S36/CT/GSTA/26-0054 ngày ≤12 + để trống.
- **LKHS-332 (ĐÓNG 20/11):** sub-task LKHS-282 — tách `MC_BillSchedule` gộp cross-month. Quét 20/11: Live 0 dòng Active vắt qua tháng (đã sinh lại) → không patch; Train còn 181+36 dòng nhưng consultant không yêu cầu patch. Script rev giữ ở `work/LKHS-332/`. Chi tiết: `tickets/LKHS-332-split-billschedule-crossmonth.md`.
- **LKHS-328 (đang dở, 13/11):** RM Statement of Account (3 report: Customisation SOA Opening Balance, AR SOA Details, AR SOA Opening Invoice) — Opening/Closing sai khi chạy kỳ ngắn 01/09–01/11/2026 (đúng khi từ 1900); 3 chứng từ `S36/CT/GSTA/26-0040/41/42` (Credit, overbilling) bị xếp vào "Deposit Billing". Nghi cùng kiểu LKHS-274 (CarryForward vs MasterTable). Chưa có SP.
- **LKHS-322 (15/10):** FA Detail Report sai Accumulated Depreciation — `FA_ChangeNote.BefChgAccumulateDepr = 0` từ lần chạy thứ 2; root cause DLL `IFCA.Business.Finance.FA.dll` (`Depreciation.GetAccuDeprChangeAmt` chỉ tìm change note đúng kỳ hiện tại) — TFS Standard đã fix, LKHS chưa deploy DLL (LKHS không có source FA riêng). GL import sẽ overstate nếu chạy trước fix.
- **LKHS-318 (09/10):** Manual JV bị lưu 2 bản (VoucherMainID 1713483/84, cùng VoucherNo, cách 9s). VoucherNo sinh client-side (`getmax()`), insert/update dựa query-string action không refresh sau save (bug cả TFS) → nghi F5 re-POST. Fix A đề xuất: chặn insert nếu VoucherNo đã tồn tại cùng AccountSettingID. Đang test tái hiện trên Train: Save 1 lần → không trùng (LKHS/DMJV/2700000001); bước tiếp: F5 resubmit / Back-Forward / double-click Save. Server LKHS chạy giờ Singapore (UTC+8, nhanh hơn VN 1 tiếng).
- **LKHS-312 (01/10):** Receipt SGD gắn bank UOB-AUD (BankAccountID 13) → không hiện ở Collection Posting (`ACReceiptBook.aspx` lọc theo currency bank, logic ở JS `f_filter`; cây `BankTree.aspx` isFilterTrx chỉ check BankAccountID). Không phải bug. CF_BankAccount (không phải CB_BankAccount); CurrencyID 27=SGD, 40=AUD. Hỏi Valerie ý định nghiệp vụ.
- LKHS-233 (AR refund debtor ledger), LKHS-229 (bill schedule termination date): chat cũ không đọc được nội dung — hỏi Gunner nếu gặp lại.

## CMSD (clone NAIM_PS)
- **Môi trường/clone:** giữ tên NAIMCAP trong code/DB, chỉ đổi DLL customize thành CMSD (Stanley chốt). Bug lặp lại: page `_NAIMCAP` bản mới nhưng config Sys_ của CMSD cũ, hoặc config bị nhân đôi/đổi tên `_CMSD` ↔ `_NAIMCAP` → so `Sys_List/ListDt/BaseDt/ContextMenu/CF_String` với `NAIM_PS_Live` (luôn qualify `[DB].dbo.`). Không clone lại DB NAIM (Gunner từ chối: dữ liệu/bảo mật). Bug code chưa sửa: `SysPrivilegeContent.aspx.cs` đọc `ContextMnuNo` nhưng query không select.
- **Server:** cũ VIFCASWK9 (DB, instance SQL2K22) / VIFCASWK91 (SSRS); backup `C:\BackupDB`; RS.exe SSRS 2022 ở `C:\Program Files\Microsoft SQL Server Reporting Services\Shared Tools\RS.exe`; bat upload report `CMSD_Train_Reports_Upload.bat`. Mới: DEV-IFCAWEB + DEV-IFCADB (domain cmsb.my), Train/UAT/Live — chi tiết `docs/ENV-setup-checklist.md` mục 5.
- **CMSD-61 (đang dở, 18/11):** PS Receivable Collection (`PSReceiptAdd_NAIMCAP.aspx`) không tick được allocation — nghi giống CMSD-60 (JS đọc cột grid thiếu) hoặc giống CMSD-13 (cần nhập Receipt Amount trước). Đang tìm unit còn bill nợ để test.
- **CMSD-65 (đang dở, 17/11):** Sales Tasks (`PSFinance/LoanTodoEdit.aspx`) còn task NAIM. Luồng: PS_Unit → PS_Sale → `PS_SaleToDo` (template `CF_ToDoList`/`CF_Todo`, loại `CF_PopupLstElement` ToDoType) → CF_Document. Rủi ro: ToDoType `IFSysToDo=1` dùng làm mốc billing (`SaleManage.UpdateTrxAndToDoDate`) → chỉ InActive. Chờ quyết định xoá hết hay chỉ phần NAIM.
- **CMSD-24 (đang dở, 12/11):** yêu cầu invoice từ Schedule Billing Generation phải `WFRecordStatus='Approved'` (theo NAIMCAP-187 Item 1) — chưa bắt đầu phần chính. Đã sửa phụ: nút trùng `PS.ArReceipt_NAIMCAP` (xoá ContextMenuID 23801-23806), thiếu Edit/Delete `PS.Adjustment_NAIMCAP` (insert từ NAIM + CF_String), `OA_WorkflowEntity` "AR Billing Approval" trùng (giữ EntiID 270, xoá 272/273). Trùng khác (PMC.RFVBQ_WF 268/269...) chỉ sửa khi có Jira.
- **CMSD-21:** in report trang trắng trên server mới (JS syntax error `ReportShow.aspx`) — nghi ReportViewer version/handler hoặc chuỗi lỗi SSRS chèn vào JS.
- **CMSD-20:** template import `RT.AccountInfor` (`Common/ImportList.aspx`) so TIMATCH: config giống, chỉ khác `CF_String PS.Account_TIN` ("Buyer TIN" → "TIN Number", dùng chung toàn hệ thống). TIMATCH có Sheet4 — nghi khác DLL.
- **CMSD-5:** xoá 129+ agent NAIM (`PS_AgentEmployee`, AgentCompanyID 14 không tồn tại, email @naim.com.my) — đã chạy Live, còn TRAIN/UAT. Menu template "NAIM PS Menu" → đổi tên.
- **CMSD-6, 13, 18, 40, 60, 66:** xem index/docs/tickets.

## NAIMCAP
- **NAIMCAP-953 (đang dở, 20/10):** ORA report (`OverdueReceivableAging_NAIMCAP`) Over Payment unit A2-05-03 (34-KPSP0200) = 29,521.50, đúng là 14,760.75 theo Lot Aging. Chứng từ: CN10000752 (BillID 181021, −29,521.50), PS10000323 (181495), bill 207170 (34K/PS/26/0303, post 26/05/2026 bởi user 2632 → allocation cũ 196137 InActive + tạo lại ngày mới, CN knock hết).
  - Phân tích mới nhất trong chat: nghi đoạn tính `BalanceAmt` của **NAIMCAP-823** trong `#AR_Trx` — subquery `alc` chỉ group theo `AL.BillID`, mà CN là phía đi knock-off (`AR_Allocation.AdjustmentID = 181021`) → alc.AllocAmt luôn 0 → nếu `AR_Trx.IsRebate='N'` thì Balance = −29,521.50, `ABS` → 29,521.50. Thêm: `WHERE at.BalanceAmt > 0` dùng balance HIỆN TẠI, trái logic as-at (chạy As At 17/04 thì CN bị loại hẳn). ORA đã loại bill New.
  - Có lúc fix bị rút lại khi data cho thấy `IsRebate` NULL → **chưa chốt**; cần xác nhận `AR_Trx.IsRebate` của 181021 + data CB_Receipt (UnAllocatedAmtDrCr) + thời điểm/param in report.
- **NAIMCAP-943:** PB Statement — Loan Amount 0 nhưng Total Payable by Financier = by Buyer. Chưa có view.
- NAIMCAP-952: xem docs/memory (Manual Allocation không atomic).

## TIMATCH
- **TIMATCH-443 — phản hồi sau deploy (đang dở, 23/11).** 443 gốc đã DONE (CS Dev 99606 · Rel 99615, xem index + file `TIMATCH-394-...md`). Julia gửi list của Hijrah (không reconcile được AR vs GL). Report `401_TIMATCH`, view `View_Report_DebtorLedgerReport_TIMATCH`. Query Gunner chạy trên **Live**.
  - Trả lời "voided allocation ở đâu" — CHỐT: không xoá, vẫn ở `AR_Allocation` với `RecordStatus='InActive'` (CN/130: 2 dòng 110, AdjustmentID 19104/19105 → BillID 17950/17951, InActive 14/10/2025).
  - `KSB/CN/00000130` x2 — CHỐT: đã fix ở 443.
  - `KSB/RF/00000184, 250, 251` thiếu trên Ledger — CHỐT root cause: KHÔNG void (Approved, APJournalID 31233/38121/38122), `PayableType=MCAdjustmentRefund`, refund của CN Rental Rebate `KSB/CN/00000414/442/443` (ItemCode `OtherFee`, qua `AR_Allocation.AdjustmentID`→`RefundID`, ReceiptID NULL). Block `FROM dbo.View_MC_ApJournal AS T4` chỉ nhận refund có `EXISTS AR_Allocation→CB_Receipt ReceiptType='MC_Fee'` (vòng 5 TIMATCH-394) → refund từ CN bị loại, CN "treo" trên Ledger. Scope Live: đúng 3 refund, tổng 10,250, không lẫn deposit.
  - Fix ĐÃ SOẠN, CHƯA ÁP: block trên (bản server = bản local, đã đối chiếu 23/11) đổi `AND EXISTS (...MC_Fee...)` → `AND (EXISTS (...MC_Fee...) OR EXISTS (AR_Allocation aa JOIN AR_Trx adj ON adj.BillID=aa.AdjustmentID JOIN AR_BillItem bi ... WHERE aa.RefundID=T4.APJournalID AND bi.ItemCode NOT IN ('RT.Deposit','RT.DestineEarnest')))`. Test: SELECT view lọc 6 chứng từ (3 RF + 3 CN) → RF Debit khớp CN Credit, số dư 3 khách về 0.
  - `KSB/CN/00000132` — CHỐT: KHÔNG void; Active, Approved, OB -678 (DocDate 30/11/2024, BalanceAmt -678, chưa allocate, CompanyID 181, DebtorID 44, Unit B-0-7), Create + Modify bởi UserID 262, sửa lần cuối 19/11/2026. GIẢ THUYẾT login Hijrah không thấy: trước 19/11 chờ workflow (chỉ người tạo thấy) hoặc quyền Company/Unit — chờ Julia trả lời user 262 là ai, Hijrah giờ thấy chưa.
  - Còn mở khác: NBIOTEK GL 220 vs Aging 0 (data void-of-void, chưa báo Julia); block `_VoidRefund` chưa xử lý refund-từ-CN bị void (hiện 0 case); hỏi Stanley view chuẩn `view_Report_DebtorLedgerReport`.
  - TFS: view TIMATCH không so (customize `_TIMATCH`); bỏ qua.
  - **Bước tiếp:** Gunner gửi comment 443 cho Julia (đã soạn: 4 mục + xin Jira mới cho fix RF) → có JiraID (hoặc Julia bảo làm trong 443 → Reopen 443) → áp fix lên Live Testing, chạy query test 6 dòng → Hijrah reconcile lại AR vs GL → ghi index/file chi tiết + changeset.

## Khác
- **SWCHENGLING-79 (28/10):** Progress billing chia sai Purchaser/Financier — do fix cũ **SWCHENGLING-67 của chính Claude** đổi `>` thành `>=` trong `LoanPostEven()` (`SaleManage.cs`, 2 overload có/không `DbTransaction`) → diff 0 bị bill toàn bộ cho financier. Fix: trả lại `>` ở cả 2 overload + patch data unit 07 (Sale 2458). Triệu chứng gốc SWCHENGLING-67 (bill cuối không vào bank) vẫn chưa tái hiện. Bài học: không loại bill hiện tại khỏi tổng, phải đối chiếu runtime/data chưa patch. DB SWCHENLING_LIVE compat level 100 → không có `STRING_AGG`; tìm `PRIMARY_KEY_DATA LIKE '%=value'` (neo cuối).
- **FPARK-216 (28/10):** `View_MC_Bill_Letter_One_FPARK` RemainBal loại bill item `ItemCode='RT.Deposit'` (kể cả 1073 DMA1) — LEFT JOIN AR_BillItem `ISNULL(bi.ItemCode,'')<>'RT.Deposit'`; chỉ ALTER VIEW. Sau fix Total Amount Due không khớp Aging với debtor bị ảnh hưởng — báo consultant. `FPL/DIN000186` 6 dòng trùng (migration?) ngoài phạm vi.
- **FPARK-214:** Collection Verification nút không chạy — JS `get_cellByColumnKey("ActualAmt")` null vì cột không trên layout → bật cột. Cùng pattern HARIANPG-45/46, CMSD-60.
- **JESSELTON-223 (đang dở, 07/11):** Sales, Lot Billing and Collection Report — SP Train chưa có fix cũ (#Temp5 Rebate). Unallocated: INNER JOIN AR_Trx mất receipt allocate vào refund + cộng trùng AllocBalance theo số dòng allocation → 1 dòng/receipt. Rebate: KHÔNG hardcode BillItemID 1345-1349; chưa tách được bằng thuộc tính (983 DPBC cũng IsRebate + "DISCOUNT ALLOWED") → hỏi Julia. RDLC Overall Payment/6 textbox chưa làm.
- **SWIBRACO-730:** Import Sub-Ledger receipt cancel lỗi null — DLL Live (16/07/2025) cũ hơn fix SWIBRACO-678 (cast importer `clsGLReceiptImporter` vs `GLReceiptImporter`) → deploy DLL mới, không viết code.
- **SWIBRACO-698:** "IsConsolSelfBilled isn't known in ApJournalEntity" — deploy e-Invoice Consolidated Self-Billed thiếu (PMCommonBL.cs lên Live nhưng thiếu DB script + `BusinessEntity.dll`/`DBAdapter.dll`). Copy ORM DLL mang định nghĩa mọi entity → DB Live phải có đủ cột trước.
- **SWIBRACO-599:** revert changeset 90341 (SST Report copy sang OR > Report): xoá ReportNo 12026 khỏi Sys_Report/ReportDefine/ReportFilter + 6 CF_String; `tf rollback /changeset:90341 /recursive`.
- **SWZECON-84:** tái phát SWZECON-81 (Inclusive tax) vì fix 81 chưa commit TFS bị deploy đè. `PMCommonBL.SaveARTrxMod` nhánh Added (`isInclusive = IsInclusive=="y"`, bỏ `bool` tránh CS0128) + Modified lấy theo TFS Live; giữ JBAMED-50, TaxExempt, LM-1320.
- **SWHARTANAH-349:** Import GRN popup (`SelectGRN_SWHARTANAH.aspx`, AP.GRNSelect) Next không chuyển trang — JS guard `cacheCheckbox` đã fix lỗi console; còn nghi pager tính sai khi tổng record chia hết PageSize 20 (bug framework?) — chưa chốt.
- **PLBPG-106:** Invoice Adjustment CN đã approve workflow nhưng list vẫn Pending Approval — mới gửi query khảo sát.
- Chat cũ chỉ còn tiêu đề (không đọc được): TIMATCH-417 (AR Transaction USD), SUMMERPG-19 (Receipt collection posting), GRSUMMIT-208 (Payment verification cash flow), SWIBRACO-693 (GRN entry amount), LKHS-229, LKHS-233.

---

# PHẦN C — Lịch sử cũ 04–09/2026 (từ tóm tắt chat; ticket đã đóng hoặc tạm dừng)

> Dùng để nhận diện pattern khi gặp lại cùng client/màn hình. Chi tiết code/data ban đầu không còn — nếu cần, hỏi Gunner mở chat cũ.

## TIMATCH
- **TIMATCH-323:** `MC_BillSchedule.ExchangeRate` khoá lúc setup hợp đồng, mặc định 1.00 khi chưa có rate cho ngày tương lai. Fix đúng chỗ = `ArBillEnterWithAttachment` (nút Post gọi qua `McAccount/ArBillEnterSubmit.aspx`, KHÔNG phải overload `ArBillEnter`): thêm `BaseCurrencyID` vào `View_MC_ArBillEnter_TIMATCH` (LEFT JOIN CF_Company), gọi `Currency.GetCurrencyExchange()` lúc tạo invoice. Bài học: xác nhận đúng call chain từ nút UI trước khi sửa.
- **TIMATCH-157 / 436:** Word mail-merge hiển thị trống cho số 0 nếu không có switch → `{ MERGEFIELD "TaxRate" \# "0.00" }`. Audit các template CN/DN khác.
- **TIMATCH-92:** SOA đổi filter 1 ngày → khoảng ngày: `Sys_ReportFilter`, thay page standard, SP parse `@Date` format 101 (MM/dd/yyyy), sửa RDLC expression.
- **TIMATCH-351:** Debtor Aging by Transaction Date (Details + Summary) clone từ bản Document Date — thêm TransactionDate xuyên suốt chuỗi SP (`Pro_MC_BillAge_SQL_ByTrxDate_TIMATCH`, parent `..._DebtorDetail_ByTrxDate_TIMATCH`), `Sys_Report` `MCorp.260R.TransDate_TIMATCH`, FldName giữ `TransactionDate`.
- **TIMATCH-216:** `VIEW_GL_VoucherPrint_TIMATCH` TaxAmt = `CASE WHEN TaxID IS NOT NULL THEN ISNULL(NULLIF(TaxAmt,0), ISNULL(CreditAmt,DebitAmt)) END`; Total Dr/Cr chỉ SUM Debit/Credit.
- **TIMATCH-25:** BI Analysis yellow page CS1038 thiếu `#endregion` trong `rentalFrame.aspx.cs` (không phải `rentalFrameNew`).
- **TIMATCH-24:** nút "Print Journal Listing" trên `DebtorInfor.aspx` = framework `SysList2Print('MC.DebtorInforTotal',...)`, `Sys_Report` ReportNo 101 `MC_DebtorInforTotalTwo`, ReadTable `View_MCDebtorInforTotal`, MnuNo `mcorp-06-18`; report render bằng WinForm viewer (file ở thư mục client, không ở web).
- **TIMATCH-184 (tạm dừng):** 6 CN tự tạo + auto-allocate trong vài giây — không có ActivityLog; cần tìm call site `INSERT INTO AR_Trx` batch/prepaid. Đã loại Invoice Auto-Reversal.
- Notification Blasting Email: `File.Delete` sau `SendEmail` ghi đè `sClientScript` → bọc try-catch riêng; URL SMTP web service http redirect https gây "Object Moved".
- TEST thiếu thay đổi LIVE ở `PropertyNet/Themes/Default/ChildMenusXML.aspx.cs` (`pf_CustomizationChangeValue` chuyển `ACPaymentBook.aspx` → `ACPaymentBook_TIMATCH.aspx`) — Changeset 94940.

## FPARK
- **FPARK-183 → 207 → 208 → 216:** letter "FPL - Invoice with Statement" (LetterID 1228, LetterTypeID 53), view `View_MC_Bill_Letter_One_FPARK`, DLL `IFCA.Business.Customization.FPARK` `SWCustomizationChange_53` (mainSql riêng, `ranks = 1` → mọi BillID của 1 invoice phải trả cùng giá trị). 183: thêm Last Payment / Remaining Unpaid Balance / Total Amount Due (`ChangeBseReadTable` trong `clsInitialize` cho Edit Template). 207: `UnallocatedAmount` = `CB_Receipt.AllocBalance` MC_Fee ≤ Invoice Date (khớp `Pro_MC_BillAge_SQL_DebtorDetail_ByDocDate_FPARK`), TotalAmountDue trừ Overpayment. 208: OUTER APPLY `Inv` (MinBillID, InvAmt), `RemainBal` loại DocumentNo hiện tại, `PrePaid` theo DocumentNo; sự cố deploy Live thiếu `Inv.InvAmt` → redeploy view Train. DN sau ngày invoice không vào Remaining = đúng thiết kế as-at.
- **FPARK-187:** SOA Aging Unallocated: `UNALLOCAMTDN` hardcode 0 → AllocBalance; WHERE lọc mất debtor chỉ có Unallocated; RDLC Outstanding = Age1–7 − UNALLOCAMTDN (`sp_rpt_MC_StatementOfAccountDetail_FPARK`). Chờ sign-off.
- SOA Deposit: loại contra `AND CB.DOCUMENTAMT > 0`; loại deposit refund (`CB_Receipt.RefTable='CB_Receipt'`). SOA Open: clone SP + view dùng BalanceAmt as-at theo AR_Allocation (không dùng BalanceAmt hiện tại), bỏ Deposit Billing, Contra.
- Auto Reversal Rental AR Billing (`FPL/CTARINV00000142`): cột `TaxInvoice` không tick trong Customize List Layout → JS `OnBeforeMenu` null. Fix: tick cột; code an toàn `(GetValueByName(row,"TaxInvoice")||'').toLowerCase()`.
- Billing Management `RT.AR_Trx` thêm filter CreateBy/CreateDate: insert CF_String (StringType='Field', RefTable='Sys_BaseDt' đúng hoa thường) → Sys_BaseDt → Sys_Filter → Sys_ListDt (thứ tự FK).
- Report 404 toàn bộ: typo `FilesSever` trong Web.config.

## SWZECON
- **SWZECON-64:** Debtor Control Summary `pro_AR_DebtorControlSummary_SWZECON` = clone nguyên `pro_AR_ODDebitorLedgerDetail_ByTrxDate2`, chỉ thay `@sql5` bằng SELECT GROUP BY. Quy ước `ReportFilter2.aspx.cs`: report AR customize đặt ReportNo prefix `AR_CUS_` (`AR_CUS_DCS01_SWZECON`). → 66 (IsDebit), 98 (ABS + cặp void), 100 (debtor chỉ có opening).
- **SWZECON-72:** Creditor Control Summary — 5 lỗi: thiếu creditor chỉ có opening (EXISTS `#tempAPJ01` + dòng placeholder 0), BETWEEN đếm trùng ngày biên (đổi `>`), Opening trừ CB_Payment chỉ PayableType Claim/MOS/Invoice (mở rộng, ZG1400(RTC) lệch 4,148,360.20), HAVING đổi sang Opening<>0 OR Debit<>0 OR Credit<>0. → 102.
- Credit Note report: routing customName sai, `PayablePrint.aspx.cs` thiếu tên report SWZECON; RDL dùng AllocatedAmt thay Amount, thiếu `<Group>` detail.
- Override `f_print` qua `clsClientScript.RegisterStartupScript`: `<%= %>` không render → dùng `FormatObject` `{0}`; HiddenField trong ContentPlaceHolder → `Master.FindControl("ListContent").FindControl(...)`.

## SWHARTANAH
- **SWHARTANAH-274 / 288:** GRN → Project External Journal Remark lấy `GRNItem.Remark` thay `GRNTitle`: `POTransferredProjectCosts_SWHARTANAH.cs` override `GRNCostTransterToProject()`, `PMApproveOtherPage_SWHARTANAH.aspx` + JS `pf_CustomizationChangeValue`. Patch `PM_ProjectLedger.Remark` bằng ROW_NUMBER partition GRNID+CostCodeID/AccountCodeID+ScheduleItemID+AccountType+GRNType order LedgerID/GRNItemID (C# insert theo thứ tự GRNItemID); chỉ Receipt, CompanyID 181, CreateDate < 2026-05-30. GR item có CostCodeID NULL ở bảng gốc (lấy qua `View_PO_GoodsReturnItem`/CF_XRef).
- SWHARTANAH-287: GRN DO-031481 không sinh Project Journal → trả RecordStatus Active để approve lại.

## JBTNPSB (client Standard mới, không customize)
- **24:** Unit Transfer/Sales Cancellation lỗi `CK_PS_Unit` — `ChangeUnit.aspx.cs SaveChangeUnit()` không atomic (update PS_UnitChange ngoài transaction chính). Patch: PS_UnitChange Completed + NewSaleID. Sau thêm chặn Submit trong `WorkflowStart.aspx.cs` khi unit đã có bản Approved/Submitted. Code bọc transaction chưa làm.
- **25:** Loan Amount dim — record migrate `SaleLoanID=0` trùng quy ước placeholder → IDENTITY_INSERT sang 203 + update FK LN_LoanPayable. (Điều tra dài: Sys_TabDt/BaseDt đều đúng — khi DB cụt thì decompile/hỏi Stanley.)
- **19:** Area Variance thiếu bill item = `AR_BillItem 'Compensate'` Inactive (giống SUMMERPG-20). **28:** LoanAmountIncTax sửa được do thêm qua Form Layout → `TdtFldEdit=0`. **3:** LineSeq hở = không lỗi. **26:** SPA Reminder timeout do compat level 100 trên SQL 2025 → `OPTION(FORCE ORDER, OPTIMIZE FOR UNKNOWN)` trong `SP_GET_PSLetterSPAReminder` (nâng compat 160 cũng OK). **41:** upload Excel ACE OLEDB + AccountNo có `|` → `encodeURIComponent`/`Uri.UnescapeDataString`. **9:** Premium = UDMONEY001. **44:** SP letter lệch version. **52:** Interest nhiều DocumentNo → khôi phục dòng bị comment trong `Interest.cs` từ TFS. **50:** HttpRequestValidationException email template → `requestValidationMode="2.0"`. **53:** Renotice timeout → `IN (list)` thay range SaleLoanID trên `View_PSLetter35_sub2`. **46 (PINE):** Late Payment Interest không ra — `GetBillCollection()` lọc bill item InterestRate=0 (decompile SaleInterest DLL). **27 (tạm dừng):** drilldown (+) Common Defects — `View_PS_DefectContractor1` 0 dòng BlockID 8. **49:** chỉ còn tiêu đề.

## SWCHENGLING / NAIMCAP
- **SWCHENGLING-66/72:** letter 32/33 in 2 buyer cho 1 unit → `View_PSLetter3233_Master_SWCHENGLING` thêm `PS_Sale.RecordStatus NOT IN ('Return')`; 72: lọc mất buyer chưa post → `RecordStatus <> 'New'`.
- **SWCHENGLING-67:** đổi `>` thành `>=` trong `LoanPostEven` — **SAI, đã revert ở SWCHENGLING-79**.
- **NAIMCAP-972:** `View_PSLetter3233_Sub_NAIMCAP` lọc `Debtor.SaleID IN (SELECT SaleID FROM PS_Sale WHERE RecordStatus IN ('Book','Sale','Sign'))` (Claude từng sửa nhầm master view — khi thiếu thông tin phải hỏi). **NAIMCAP-973:** giữ `a.ChargePercent > 0` trong sub view.
- NAIMCAP DB tách theo module: `Naim_TC_Live` (Tenancy), `Naim_PS_Live` (Property Sales). NAIMCAP-952 (Manual Allocation không atomic) tạm dừng.

## ASPENPG / SWSRIDATAI / LKHS / khác
- **ASPENPG-671:** Reversal E-CN/E-DN không in (sale Return bị `View_PS_LetterUnit` loại) + thời gian validate sai → `View_PSLetter25_Master_DN_ASPENPG` (gồm return, `ValidatedDateTime = IRBM.EInvoiceSigningTime`, `DigitalSign`), `SP_GET_PSLetter25Master_ASPENPG`, `CF_LetterType` 79 IsCustomiseLetter/MainTable = Y, hook `ChangeBseReadTable` + `clsPrintService.GetMaintable` case "79". Template do Heah Pei Juin sửa. **ASPENPG-681:** `Sys_List.LstSort='UnitNo'` cho `PS.LetterEInvoice` (LstOrder −1). **ASPENPG-654:** CNRebate gồm sale đã cancel → EXISTS trong `View_PS_Sales_Status_Report_Final`. **ASPENPG-635:** Late Payment Interest tạo lại bằng đổi loại bill item (consultant). Lỗi lưu customer: "String or binary data would be truncated" → so `Sys_BaseDt.BdtFldMaxLen` với cột DB.
- **SWSRIDATAI-453:** AP Aging CN còn outstanding: AP_Allocation BaseAmt/PayAllocAmt = 0 (AllocID 508350) và header AllocAmt = 0 nhưng AP_AllocationDetail đúng. **467:** `AP_Journal.PayTo` trống → lấy tên creditor từ CF_Account. Official Receipt subreport `ItemsDataSet` còn `SELECT TOP 10 *` test.
- **LKHS-228:** PO approval chậm — `PMProjectAccount.GenerateAccount()` không lọc CompanyID → full scan `View_PM_LedgerSourceMain`. **LKHS-261:** letter Credit Adjustment dùng tổng header → `aa.allocAmt` + TaxRate từng dòng. **LKHS-270/311/317/319/335:** Tax Adjustment Journal posted không có dòng GL (pattern lặp). **LKHS-225, 194, 229, 233:** chỉ còn tiêu đề.
- **SWIBRACO-678:** GL Import Sub-Ledger crash khi import CM_OtherReceipt voided — kiểm kiểu importer trước cast (liên quan 730). **SWIBRACO-677:** in HTTPS lỗi do TLS 1.0/1.1 tắt ở Schannel, `IFCA.ReportViewer.exe` (.NET 2.0) mặc định TLS 1.0.
- **JESSELTON-240:** email billing cho Solicitor crash → null guard `SMSReplace()`.
- **HARIANPG-41:** Bank Reconciliation không hiện bank (chi tiết bị cắt).
- **SUNGGUH-134:** GL Detail `GLGeneralLedgerDetail2_SUNGGUH` nhân dòng carry-forward theo tháng → đưa điều kiện Year/Month vào `INNER JOIN #accountcode` (không phải LEFT JOIN; ẩn dòng RDLC vẫn bị cộng vào Sum).
- **STARKPG-54:** billing sai ~10 lần (66,625.58 vs 6,670.57), dev trước chỉ patch data — chưa có root cause.
- **BDBPG-219/220:** company BDB project ParentID NULL → `View_ProjectLedgerByCostandContract` INNER JOIN PM_Project parent → LEFT JOIN; 220 `View_PM_ProjectCostAnalysisByActivity` (bị cắt).
- **PLBPG-79:** nâng E-Invoice v34 → v54: TFS `_Package (Edge)/Versioning/Version XX` (Database: Scripts to Run chạy tay theo version, SP/View bằng tool deploy IFCA; Reports lên Report Server; copy PropertyNet/SmartClient/Windows Service). Tool `merge.bat` + `config.cfg` gom file nhiều version. Thiếu bảng `irbm_einvoice` → hỏi Stanley. IRBM Windows Service connection PLB_UAT `PLBGROUP\SQL2019`.
- Hạ tầng: restore Live → LiveTesting bằng SSMS (Overwrite + Close connections + đúng file path); Docker SQL 2025 restore dùng `RESTORE FILELISTONLY` + `WITH MOVE` path Linux `/var/opt/mssql/data/`; QRCoder DLL đăng ký GAC + `rsreportserver.config` CodeModules; email chậm: `View_MC_Letter_SumBill_Letter` lồng 3 tầng không đẩy được predicate BillID → viết CTE lọc AR_Trx trước.
- Chỉ còn tiêu đề (không đọc được): "Payment verification sequence fix" (≈SWZECON-75), "Duplicate invoice GRN error" (≈SWHARTANAH-325), "Hardware ID for IFCA license", "SubcontractEdit syntax error", "Client e-app transaction sync issues".
