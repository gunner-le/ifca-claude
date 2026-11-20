# Trạng thái ticket & client (từ bộ nhớ claude.ai — cập nhật tới 19/11/2026)

> Bổ sung cho `docs/ticket-index.md`. Đây là ghi nhớ tích luỹ, một số dòng có thể đã cũ — đối chiếu index (mới hơn) khi mâu thuẫn.

## Client

- Đang hỗ trợ: ASPENPG, SWCHENGLING, NAIMCAP, SWHARTANAH, TIMATCH, SWZECON, FPARK, SWSRIDATAI, LKHS, TH_LIVE, JESSELTON, HCDSB, JBTNPSB, SUNGGUH, SWIBRACO, CMSD, PALMINGTONPG, GRSUMMIT, FARLIMPG, HARIANPG, SUMMERPG...
- LKHS chạy nhánh TFS riêng NET4.0_SG / IFCA.NET 4.0_SG → tính năng LKHS (vd GIRO) là improvement, sửa thẳng source LKHS (không hậu tố `_LKHS`).
- NAIMCAP: DB tách theo module — `Naim_TC_Live` = Tenancy, `Naim_PS_Live` = Property Sales.
- **CMSD**: client mới clone từ NAIMPS (gồm mọi customize NAIM; DLL customize đổi tên `IFCA.Business.Customization.CMSD.dll`, trước tên CMSP). Chỉ đổi DLL; DB, page, report, view giữ tên NAIM (`_NAIMCAP`). Clone từ NAIM_PS; tính năng lỗi trên NAIM_PS nhưng chạy trên NAIM_TC phải lấy chọn lọc từ NAIM_TC, không mang cả NAIM_TC. Gunner deploy CMSD lên server mới cho Train/UAT/Live; Julia test.

## Ticket đang mở / tạm dừng (theo bộ nhớ)

- **TIMATCH-351** (IN PROGRESS): Debtor Aging Report by Transaction Date (Details + Summary), clone từ report Document Date. SP `Pro_MC_BillAge_SQL_ByTrxDate_TIMATCH` + cha `Pro_MC_BillAge_SQL_DebtorDetail_ByTrxDate_TIMATCH` thêm TransactionDate xuyên chuỗi. View `View_MC_Report_BillAgingDetailByTrxDate` / `SumForDebtorByTrxDate` đã có. `Sys_Report` `ReportNo='MCorp.260R.TransDate_TIMATCH'`, `FldName='TransactionDate'`. Details chạy OK; chờ chốt Summary sau khi data được duyệt.
- **TIMATCH-184** (PAUSED): 6 CN tự tạo + tự allocate trong vài giây — quá nhanh cho thao tác tay. Không có ActivityLog/AuditLog. Có thể cần search TFS các chỗ `INSERT INTO AR_Trx` quanh batch/prepaid adjustment. Đã loại: Invoice Auto-Reversal, ReceivableType=NULL.
- **NAIMCAP-952** (URGENT, PAUSED): Manual Allocation báo "not fully completed" — `CB_Receipt.AllocBalance` về 0 nhưng `AR_Allocation` 0 dòng cho ReceiptID. Save không atomic; bug Standard dùng chung, có thể race. Tiếp: lấy code-behind Manual Allocation từ TFS, xem insert `AR_Allocation` và update `AllocBalance` có chung transaction không.
- **JBTNPSB-27** (PAUSED): Common Defects & M&E Checklist thiếu drilldown (+) — `View_PS_DefectContractor1` 0 dòng với BlockID=8. Tiếp: xem bảng `PS_DefectContractor`.
- **JBTNPSB-24** (PAUSED): Unit Transfer / Sales Cancellation — vi phạm `CK_PS_Unit` khi bấm Complete lần 2. Transaction không atomic trong `ChangeUnit.aspx.cs SaveChangeUnit()` (update PS_UnitChange completion nằm ngoài transaction chính). Có patch khôi phục data; code fix (gộp 1 transaction) chưa áp. Conflict check ở nút (WorkflowStart.aspx.cs) chờ test.
- **LKHS-250** (PAUSED): màn Bill Adjustment Edit, tab `MC.AdjustmentEdit`.
- **ASPENPG-690** (CHỜ CONSULTANT): Generate Payment đúng (invoice đã allocate hết qua Set Off Adjustment). Creditor Ledger hiện còn nợ vì Adjustment chưa Approve (`RecordStatus='Active'`) → `TransactionDate` NULL → join khoảng ngày của report fail. Chờ consultant: có bắt buộc Approve trước khi Adjustment được allocate không.
- **SWZECON-66** (PAUSED): fix AR Adjustment Debit (`IsDebit='Y'` trong `#tempARJ001`) đã áp; chờ consultant.
- **FPARK-187** (PENDING): SOA Aging Unallocated đã verify mức SQL; chờ business.
- **SUNGGUH-133** (PAUSED): debug e-Invoice validation — 4 case là lỗi nghiệp vụ/data; chờ consultant.
- Pending khác (08–09/2026): LKHS-176 (Manual Allocation thiếu UnitNo), LKHS-243 (SysListEditor3/grid), TIMATCH-373 (AP Adjustment preview DocumentNo sai, chưa có root cause), JBTNPSB-58 (e-billing thiếu Architect Cert attachment), LKHS-210 (PM SubcontractAccountSummary RetentionReleaseAmt, chờ verify), LKHS-227 (view_rpt_MonthlyRental DocumentAmtBefTax, đã lên Train), TIMATCH-323 (MC_BillSchedule.ExchangeRate chốt lúc setup mặc định 1.00 cho ngày tương lai; fix áp nhưng consultant báo vẫn lỗi), LKHS-208 (in trùng invoice RM AR Print Tax Invoice; root cause `View_MC_Letter_SumBill_Letter` GROUP BY UnitNo ra 2 dòng cho bill GTO RENT có UnitID NULL).

## LKHS-271 GIRO
- **19/11: handoff đầy đủ ở `docs/lkhs-271/00-HANDOFF-LKHS-271.md`** (quyết định mới nhất: Stanley ĐÃ xác nhận forex cho 4 module — dòng 12/11 bên dưới đã cũ).
- Xem `docs/tickets/LKHS-271-ar-giro-collection-dbs.md`. Business owner Stanley. Phase 1 LKHS-320 xong, deploy LKHS_Test (changeset 99415). Phase 2 LKHS-325 đang hoàn thiện. LKHS-326 = Jira Stanley cho Number Structure `316_ReceiptGroup`, phải deploy trước LKHS-325. AR GIRO Status Report (spec mục 8) tách Jira sau.
- Stanley 12/10: Generate All theo filter list (bỏ Processing Date); cột mới CB_Receipt.IsGiroReceipt. Stanley 02/11: duyệt bảng CB_ReceiptGroup, CB_ReceiptGroupDetail, CB_ReceiptGroup_AuditLog + CB_Receipt.GroupNo / GIRORecordStatus; file export 1 dòng/debtor; DBS trả 1 file/batch chỉ gồm giao dịch fail.
- 09/11: Rental GIRO giữ ReceiptType MC_Fee; cây Company chưa lọc AllowGiroProcess. 12/11: Gunner CHƯA từng nói 4 module phải theo LKHS-230 (LKHS-230 chỉ là forex cho OR Collection); forex các module khác chưa quyết — hỏi Stanley.
- Tin nhắn cho Stanley: tiếng Anh ngắn, chỉ hỏi (không nói mình sẽ làm gì), bám đúng ý Stanley vừa nêu.

## Ticket đã xong có ghi nhớ chi tiết

### LKHS-274 — Creditor Ledger Detail By Trx Date (`pro_AP_CreditorLedgerDetail_ByTrxDate`)
- Bug dài: report sai khi StartDate ≠ 01/01/1900 (Opening/Closing, Claim/Tax, Owing Balance, Creditor Type Closing).
- v1: `AND cp.RecordStatus <> 'Inactive'` mọi join AP_Allocation→CB_Payment. v2: `AND cr.ReceiptType IN ('PaymentRefund','Refund')` (18 chỗ) chống trùng ID CB_Receipt. v3: field scalar `TaxAmtSummary` cộng cả `#MasterTable` + `#CarryForward` (PayableType NOT IN ('OnBehalfBal','Deposit','Advance','PM_Deposit','RetentionHold','Payment')); RDLC đổi 2/3 textbox Tax Amount sang hằng. v4: block "Verified Payment" refund join thiếu `cr.RecordStatus <> 'Inactive'`. v5: block Adjustment/CN term Refund thiếu `aa.RecordStatus` → thêm `(aa.RecordStatus='Verified' OR (aa.RecordStatus='Active' AND aa.AdjustmentID IS NOT NULL))`. v6–v7: các filter RecordStatus/ReceiptType khác + nhánh CarryForward Forex Gain/Lost.
- v8: ~98 chỗ dùng ngày của chính record đích (cp/aj2/cr.TransactionDate) thay vì `aa.AllocDate` để chia CarryForward/MasterTable → sửa sang `aa.AllocDate`.
- v9: OpeningAmount/owingAmount/creditorTypeOwingBalanceAmt cộng `#CarryForward.BalanceAmt` (đã trừ allocation) trong khi MasterTable dùng gross DocumentAmt → Closing đổi khi giao dịch chuyển phía. Fix: CarryForward BalanceAmt/BalanceBaseAmt lưu gross DocumentAmt/BaseAmt (7 block).
- v10: sửa lỗi lệch số cột do v9 (thiếu `0 AS TaxAmt` ở insert CarryForward Verified Payment) gây rsProcessingAborted.
- Verify với data consultant: CS0147(SA), CA0065(BR), CD0058(BR), CD0059(BR) khớp giữa From-1900 và From-01/09/2025; Creditor Type Closing khớp. Sort theo TransactionDate: sửa ở RDLC (table1_Details_Group sort `=Fields!TransactionDate.Value`), SP đã ORDER BY sẵn.
- Kỹ thuật debug: clone SP thành `_CHECK`, thay DROP bảng tạm cuối bằng `SELECT * INTO dbo.zz_CarryForward_Debug FROM #CarryForward`; tìm record gây lệch bằng query đối chiếu từng CBPaymentID (DocumentAmt vs tổng AP_Allocation) sort ABS(chênh) DESC.
- 02/10: Gunner verify OK, "tạm update" — chờ consultant re-test.
- Ưu tiên chung của Gunner: ổn định & đúng data hơn tối đa hiệu năng (vd chỉ bỏ CONVERT() trong WHERE chặn index, thêm clustered index cho bảng tạm; hoãn refactor pre-aggregation rủi ro).

### LKHS-290/292 — Bank Forex Revaluation thiếu auto-reversal (RESOLVED, chờ rollout)
- Root cause: `CBUnrealizedGainOrLossSG.GenerateTrxData()` (namespace `IFCA.Business.Finance.Cashiering.Service`, TFS `$/Property/Dev/BRANCHES/NET4.0_SG/Common Library/Business/Finance/IFCA.Business.Finance.CB/Cashiering/Service`) chỉ tạo 1 dòng CB_Trx khi Approve — thiếu dòng auto-reversal kỳ sau mà GL có qua cờ IsCreateNextPeriodVoucher của GLCBUnrealizedImporterSG.
- Fix Approve: tạo thêm `eTrxReversal` CB_Trx — DocBseAmt đảo, DocDate = ngày 1 tháng sau, `DocNo = code` (dùng lại giá trị SysCode đã cache). Description `string.Format("Auto Reversal on {0} on {1:d/M/yy}", remark, RevaluationDate)`.
- Fix gọi `.Code` 2 lần (mỗi lần tiêu 1 serial qua Proc_CF_GetAutoCode trên transaction riêng đã commit → nhảy số): `string code = autoCode.Code; if (code.IsEmpty()) return false;`.
- Fix Void (v2 đúng): bước 1 dựng voidEntity + vrd → SaveEntity; bước 2 `GenerateTrxData` chạy TRƯỚC (tạo dòng offset bản gốc với DocNo MỚI); bước 3 tạo dòng huỷ auto-reversal dùng CÙNG DocNo mới đó (`cancelReversal.DocNo = newCancelTrx.DocNo` — v1 dùng nhầm DocNo cũ của auto-reversal, Valerie bắt lỗi). `DocDate/TrxDate = autoReversalDate`, `DocBseAmt = -autoReversalTrx.DocBseAmt`, `Description = "Cancellation: " + rl.Remark`, `CurrencyRate = rd.ExchangeRate.ToDecimal()` (ép double→decimal), `OpeningAmt = AccountTrx.GetBankAccountBalanceAmt(...) - autoReversalTrx.DocBseAmt`. `voidEntity.Remark = "Cancellation: " + rl.Remark` (theo Valerie).
- Nguồn nhảy số thứ 2: WebMethod `Approve(int keyId, int userId)` trong .aspx.cs tạo `new SysCode("099", ...)` chỉ để check config → đổi sang `SysCodeUtil.CheckSysCodeIsSetted("099", revaluation.CompanyID.ToString())` (không tiêu số). Sau fix: TEST 001 = 0022/0023, TEST 002 = 0024/0025 liên tục.
- Kết quả 4 dòng CB_Trx/bank account sau Approve→Void (BankAccountID=600, RefRecordID 834 Approve, 835 Void): +X (ngày Approve), −X (1st tháng sau, Auto Reversal), −X (ngày Approve, Cancellation, 835), +X (1st tháng sau, Cancellation, 834). Net 0. Query cả chu kỳ: lọc BankAccountID + khoảng CreateDate, KHÔNG theo 1 RefRecordID.
- Patch lịch sử Live: RevaluationDetailID 824 (Feb, −3.19) và 827 (Mar, +42.43) — thêm dòng reversal DocNo 0013, 0014. Train: script 8 case 820–823, 825–826, 828–829 (DocNo 0021–0029, BankAccountID=600) đã soạn, CHƯA xác nhận đã chạy. Verify: `SELECT RefRecordID, COUNT(*), SUM(DocBseAmt) FROM CB_Trx WHERE BankAccountID=600 AND TrxType='RealizedForexGainOrLoss' AND RecordStatus='Active' GROUP BY RefRecordID HAVING SUM(DocBseAmt)<>0` → 0 dòng là sạch.
- Kiến trúc: GL auto-reversal tạo 2 voucher (gốc RefTable='FN_Revaluation' + reversal RefTable='GL_VoucherMain' tháng+1) qua bước tay "GL Closing > Import Sub-Ledger > Forex Gain or Loss" (GLUnImportForexGainOrLossList() + GLCBUnrealizedImporterSG), không tự động lúc Approve. Setter `FNRevaluationViaRevaluationID` set lặp an toàn (đã loại trừ). Bank test: BankAccountID=600 (UOB-USD, 772-962-438-5, Company M02 = CompanyID 206, CurrencyID=27).
- Còn lại: xác nhận script 8 case Train đã chạy; Valerie/Stanley retest UI; deploy Live; có port sang HQ `CBRealizedGainOrLoss` không (Stanley: class SG tách riêng có chủ đích, có lẽ chỉ SG).

### LKHS-337 — PM Debtor Aging Summary by Trx Date Owing sai (ĐÓNG 20/11 — consultant OK, đã áp Live)
- RDL `PM_DebtorAgingSumByTrxDate` nhánh SG: Owing trừ UnallocedAmt (âm) → đổi 9 chỗ `- Fields!UnallocedAmt.Value` → `+`. CS Dev SG: 99594 · Rel SG: 99614. Chi tiết `docs/tickets/LKHS-337-pm-debtor-aging-sum-trxdate-owing.md`.

### LKHS-336 — PM Debtor Aging Detail by Doc Date mất receipt (ĐÓNG 20/11 — consultant OK, đã áp Live)
- Fix config `Sys_ReportFilter` EN275 (DocumentDate FldRange 0→2 + FldNeed Y, TransactionDate Inactive). Còn: hỏi Stanley fix Standard (TIMATCH cùng config), đổi label "Doc" (tuỳ chọn). Chi tiết `docs/tickets/LKHS-336-pm-debtor-aging-docdate-filter.md`.

### LKHS-298 — Other Debtor SOA hiện AllocDate thay DocumentDate (FIXED, chờ consultant)
- Report "Other Debtor Statement of Account" (LKHS, OR > Reporting). SP chính `AR_OtherDebtorAccountStatement2` (@CompanyID, @Language, @QueryCriteria) đúng — không phải nguồn lỗi.
- Bug ở SUBREPORT (RDLC tên `AR_ODebtorAccountStatementSub`, SP `AR_OtherDebtorAccountStatement2Sub`, params @DocumentNo, @TransactionType, @AsAtDate, @CompanyID, @DocumentID = BillID invoice).
- Root cause: dùng `a.AllocDate` cho cột "DocumentDate" ở cả 2 nhánh UNION. Fix: `FORMAT(a.AllocDate, 'dd/MM/yyyy')` → `FORMAT(b.DocumentDate, 'dd/MM/yyyy')` cả 2 nhánh (b = CB_Receipt / AR_Trx).
- Verify: DocumentNo='SI46 (R)', AsAtDate='2026-07-31', CompanyID=199, DocumentID=495856 → S46/AR/OR/26-0002 = 25/05/2026, S46/AR/OR/26-0003 = 15/06/2026 (trước sai 29/06, 13/07).

## Đã xong (tóm tắt 06–09/2026)
- FPARK-201 (LEFT JOIN debtor không có Unit), JBTNPSB-65 (QR/Draft do 2 đường QR trùng + IRBM views Version 43), JBTNPSB-48 (PREVENT_DUP_INSERT bỏ cột mới; LAD CN không đọc IsRefundNote), LKHS-293/294 (AR aging quy đổi base currency + UnallocatedAmt), ASPENPG SSL cert e-Invoice hết hạn, FARLIMPG-165 (không phải bug), ASPENPG-686 (View_AC_APAllocSum RecordStatus), JBTNPSB-49 (thiếu Sys_TabDt, copy từ client OK), JBTNPSB-7 (SOA Reversal: Adjustment block dùng DebtorID thay RefRecordID làm AnalysisTypeID), TIMATCH-356 (FormatException DataTable.Compute → ToString → Parse theo culture; dùng Convert.ToDecimal), TIMATCH-92 (Opening/Closing SOA qua SP + Dataset song song), STARKPG-62 (Sys_Filter trùng → "Multiple controls with same ID"), LKHS-241 (ARInterest.aspx SysToolbar LstNo "AR.MCInterest"), LKHS-130, LKHS-247 (Contract Renewal DebtorAcct bị ghi đè: TextBox ReadOnly postback rỗng kích SysCode), LKHS-129 (Lot Aging Detail thêm 'Voided'), LKHS-240 (SOA Opening thêm AllocBalance>0), LKHS-244 (Audit Log sai ModifyUser khi unassign CompanyImpower.aspx), SWSRIDATAI-471, FARLIMPG-147 (AR_Allocation mồ côi double-count), NAIMCAP-839 (InteriorArea vs LandArea), SBHSKG-232 (FA_AssetsReport), SWCHENGLING-74 (Sales Cancellation crash: Bill Item Inactive + UnitChangeID trùng), ASPENPG-689 (PSChooseHouse thiếu return sau validate), TIMATCH-206 (View_AR_CreateBill hardcode 0 CreditTerms), SWZECON-64/74 (DebtorTypeClass, CallFloat() tràn số).

## Đồng nghiệp
- Stanley — senior/lead/architect; chốt policy, hiểu framework sâu. Escalate khi điều tra DB bế tắc.
- Julia — consultant/QA (TIMATCH, FPARK, SWZECON, CMSD).
- Heah Pei Juin — consultant LKHS, ASPENPG.
- Valerie — LKHS internal/consultant (làm với user/DBS).
- WP Lim — consultant JBTNPSB.
- Edward — đồng nghiệp (SWZECON-99...).
- Zac Ng — developer ASPENPG.
- Nguyen Quoc Viet — lead/consultant phía Việt Nam, Gunner hỏi nghiệp vụ.
