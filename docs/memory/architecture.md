# IFCA ERP.NET — data model cốt lõi (từ bộ nhớ claude.ai)

## AR → GL

- Luồng: `AR_Trx` (bill/receivable) → `GL_VoucherMain` (header journal, không có tiền) → `GL_Voucher` (dòng double-entry).
- 1 Bill AR tạo 3 dòng GL: DR AR Receivable (tổng), CR Revenue (trước thuế), CR Tax Payable (tiền thuế nằm ở `CreditAmt`, không phải `TaxAmt`).
- `GL_Voucher` link qua `RefTable`/`RefRecordID` trực tiếp — bảng này KHÔNG có `GLRefTable1`/`GLRefRecordID1`.
- `GL_VoucherMain` cột: VoucherMainID, AccountSettingID, Year, Month, VoucherCategory, VoucherTypeID, VoucherNo, Attachments, ApprovedUserID, ApprovedDate, PostUserID, PostDate, CashierUserID, CashierDate, BaseDebitAmt, BaseCreditAmt, DebitAmt, CreditAmt, DebitQty, CreditQty, InsertDate, RecordStatus, CreateUserID, CreateDate, ModifyUserID, ModifyDate, ChargeTo, IsInternalVoucher, RefTable, RefRecordID, RefVoucherMainID, Digest, VoucherMainTransID. `RefVoucherMainID` link voucher đảo/liên quan về voucher gốc.

## Project costing

- Luồng: `PO_GRN`/`PO_GRNItem` → `PM_LedgerMain` → `PM_ProjectLedger` → `PM_ProjectBalance`.
- PO Purpose: Project (charge WBS), Expense (Dept), Stock (kho), PurchaseOnBehalf (subcontract).
- Purpose=Project: `PO_PurchaseItem` → `PM_CostAlloc` (ScheduleItemID = WBS item) → `PM_ProjectLedger` → `PM_ProjectBalance`.
- Committed tăng lúc Approve PO; Actual lúc Approve GRN.
- Sau khi patch `PM_CostAlloc.ScheduleItemID` phải chạy `Prc_PM_RecalculateProjectBalance`.
- Budget = Workplan PlanCost; Balance = Budget − Committed − Actual.

## Progress Billing

- Luồng: `PS_Sale` (Book→Sale→Sign) → `AR_Trx` → `CB_Receipt` → `AR_Allocation`.
- Loan routing: `SaleManage.cs LoanPostEven()` chia bill giữa Buyer và Financier theo `_TotalBuyerBillAmt >= _DebtorAmt`.

## CB / Bank

- `CB_Trx` = bảng giao dịch cash/bank.
- Account Transfer tạo 2 dòng `CB_Trx` — chuyển đi (`CreditAmt`) và chuyển vào (`DebitAmt`) — link qua `RefTable='CB_Trx'` + `RefRecordID`.
- Cash flow phân bổ qua `CB_TrxAlloc`. File: `CashFlow/ACLedgerTransfer.aspx.cs`.

## Bảng & control chính

- Bảng: `AR_Trx` (bill; TaxAmt/TaxRate/TaxID), `GL_VoucherMain` (VoucherNo/MainDigest), `GL_Voucher`, `CB_Trx`, `CB_TrxAlloc`, `PS_Sale` (Book/Sale/Sign/Return), `AR_Debtor`, `PS_Unit`, `CF_Tax`, `CF_Supplier`, `AP_Journal`, `PO_PurchaseOrder`, `PO_PurchaseItem`, `PM_CostAlloc`, `PM_ProjectScheduleItem` (WBS), `PM_ProjectBalance`.
- UI control: `SysHierList2`, `Sys_ListDt`, `Sys_BaseDt`, `Sys_List`, `Sys_ContextMenu`, `Sys_Report`, `Sys_Filter`, `CF_String`.
- e-Invoice: `IRBM_Trx`, `IRBM_Record`, `IRBM_Record_Detail`.
