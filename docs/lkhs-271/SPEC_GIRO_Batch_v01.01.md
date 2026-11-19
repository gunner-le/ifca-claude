# Spec Stanley — Generate GIRO Batch Collection v01.01 (06/11/2026) — bước 7 / LKHS-325
(Chuyển từ docx. v01.01 thay v01.00: thêm nút Verify + Upload Screen + Pre-Check Screen; logic Import cũ bị gạch bỏ, chuyển vào Confirm.)
(Thực tế đã triển khai: nút trên Listing = Reset / Import (Reject) / Import (Success) / Close — Import (Success) tương ứng "Verify" không file.)

## Database
**New Table CB_ReceiptGroup**: ReceiptGroupID (PK), GroupNo (GIRO Batch No), DocumentDate, RecordType (Receipt_GIRO), RecordStatus (Generated, Exported, Completed), CompanyID, BankID, Filename, CreatedXXX/ModifiedXXX.
(Thực tế PK = CBReceiptGroupID; thêm ReferenceNo, PurposeCode...; RecordStatus thêm Cancel.)
**New Table CB_ReceiptGroupDetail**: ReceiptGroupDetailID (PK), ReceiptGroupId, ReceiptID, RecordStatus, Created/Modified. (Thực tế thêm ReturnReason.)
**New View View_CB_ReceiptGroup_GIRO**: Select * FROM CB_ReceiptGroup WHERE RecordType = "GIRO"...
**New View View_CB_Receipt_GIRO_Summary**: Total No of Debtor, Total Receipt Amount; Group By GroupNo + DebtorID.
**New Table CB_ReceiptGroup_AuditLog**: AuditLogId (PK), ProcessUserId, Processdatetime, Action, Created/Modified.
**Existing CB_Receipt** new field: GroupNo.
**New Number Structure**: System Setup > Number Structure > Cash Management > Receipt GIRO Batch No (= LKHS-326, DocCode 316_ReceiptGroup).

## Enhancing Page: Cash Management > Receipt > Collection Verification
New menu:
- **GIRO Batch Generation** → popup GIRO Batch Page.
- **GIRO Batch Detail** → popup GIRO Batch Listing Page. Only enable when IsGiroReceipt = Yes, Group No not empty, RecordStatus = Exported.
- **Cancel**: only enable when IsGiroReceipt = Yes, Group No empty, RecordStatus = Generated.
Existing menu:
- **Verify All**: IsGiroReceipt <> Yes → existing action; = Yes → skip.
- **Verification**: IsGiroReceipt <> Yes → existing enable/disable + action; = Yes → disable.
New Criteria: IsGIROReceipt, GIRO Batch No, GIRO Status (Generated, Exported, Completed, Failed).
New Columns: IsGIROReceipt, GIRO Batch No, GIRO Status.

## New Page: GIRO Batch Page
Header: Bank (selection — GIRO bank of company), AccountNo (readonly, from bank), Currency (readonly), Reference No (textbox), Payment Date (datetime), Purpose of Payment (dropdown — DBS Purpose Code). Menu: Save (Generate GIRO Batch), Close.
Detail: Checkbox, Module, Debtor Name, Debtor Account No, Receipt No, Document Date, Reference No, Receipt Amount.
Display: refresh on Bank change; condition IsGiroReceipt = Y, BankID = selected bank, RecordStatus = Active, GIRORecordStatus = Generated.
**Action Generate GIRO Batch**: new Group No → new CB_ReceiptGroup (header info, RecordStatus Exported, RecordType GIRO) → CB_ReceiptGroupDetail rows → update receipt GroupNo + GIRORecordStatus = Exported → Export File → Audit Log (Generate/Export).
Export file = group summary by debtor (not per receipt), from View_GIRO_Summary; text file GIRO format (DBS UFF); write to Export Path.

## New Page: GIRO Batch Listing Page
Menu: Reset, Import, Verify, Close.
Criteria: Account No, Bank Name, Currency, GIRO Batch No, Reference No, Payment Date, Purpose Code.
Columns: Selection, Bank Name, Account No, Currency, GIRO Batch No, Reference No, Payment Date, Purpose Code, Total No Debtor, Total Amount, Created By, Create Date.
**Reset**: selected batch → CB_ReceiptGroup.RecordStatus = Cancel; receipts GIRORecordStatus = Generated; Audit Log (Reset).
**Import**: popup Upload Screen → read attachment (GIRO Batch No, Debtor info) → popup Pre-Check Screen WITH attachment info.
**Verify**: popup Pre-Check Screen WITHOUT attachment info.
**Cancel Receipt Action**: CB_Receipt → Voided; release billing in AR_Allocation; recalculate billing balance.

## New Page: Upload Screen
Menu: Select, Close. Display: Filename — list all files in the company's Import Path. Select → return filename to parent, close.

## New Page: GIRO Batch Pre-Check Screen
Menu: Confirm, Close. Columns: Document No, Debtor Name, Amount, GIRO Status.
With attachment: matched collections → GIRO Status Failed; not matched → Success. Without attachment: all Success.
**Confirm**: CB_ReceiptGroup.RecordStatus = Completed; per receipt: Success → GIROStatus Success + existing Verification Receipt Action; Failed → GIROStatus Failed + Cancel Receipt Action; Audit Log (Import).
