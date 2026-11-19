# GIRO deliverable package by Jira (TFS layout) - how to regenerate

Zip name: `LKHS-271_TFS_LKHS-320_LKHS-325.zip` - folders `LKHS-320/` and `LKHS-325/`, each with
`Database/{New Table, Table Change, Views, Update Script}` (1 SQL file = 1 object, file name = object name) and `Web/{App_Code/GIROCode, CashFlow}`.
Source of every file = latest files in `LKHS-271-src/` (numbered SQL scripts are split per object as below). READMEs: `PACKAGE_README_LKHS-320.txt`, `PACKAGE_README_LKHS-325.txt`.

## Mapping numbered script -> package file
| Numbered script | Package file |
|---|---|
| 05 | LKHS-320/Database/Table Change/CB_Receipt_GIRO.sql (incl. GroupNo used by 325) |
| 03 (part 1) | LKHS-320/Database/New Table/CB_GIROTempDetail.sql |
| 01 | LKHS-320/Database/Views/View_CB_GIROCollectionPending.sql |
| 03 (part 2, 3) | LKHS-320/Database/Views/View_CB_GIROCollectionGenerate.sql, View_CB_GIROCollectionTempDetail.sql |
| 02, 04 | LKHS-320/Database/Update Script/LKHS-320_01_Config_CB_GIROCollection.sql, LKHS-320_02_Config_CB_GIROCollectionGenerate.sql |
| 06 | LKHS-325/Database/New Table/CB_ReceiptGroup.sql, CB_ReceiptGroupDetail.sql, CB_ReceiptGroup_AuditLog.sql |
| 07 | LKHS-325/Database/Views/View_CB_GIROLookup.sql, View_CB_Receipt_GIRO.sql, View_CB_ReceiptGroupGenerate.sql |
| 09 | LKHS-325/Database/Views/View_CB_ReceiptGroup_GIRO.sql |
| 12 | LKHS-325/Database/Views/View_AC_Receipt.sql (standard view: update existing TFS file) |
| 08, 10, 11, 13 | LKHS-325/Database/Update Script/LKHS-325_01..04_Config_*.sql |
| 98 test data, LOCAL_ONLY | not packaged |

Web: LKHS-320 = GIROCollectionGenerator, GIROModels, GIROModuleHandlers, GIROPropertySalesHandler (latest, incl. CancelReceipt for 325) + CashFlow/ARGIROCollection* (10).
LKHS-325 = GIROBatchService, GIROUffDbs, GIROReturnFileDbs + CashFlow/ARGIROBatch* (10) + PATCH_LKHS-325_ACReceiptVerify.md (items 1-9).
Split files: headers say "Requires: ..." instead of "run script NN"; dependent views start with an existence check (RAISERROR + NOEXEC).

## Prerequisites (not in the package)
- GIRO master setup (CF_Company.AllowGiroProcess, CF_CompanyGiroBank, AR_Debtor GIRO columns) - before LKHS-320.
- LKHS-326 (Stanley): CF_DocCode DocCodeNo '316_ReceiptGroup' (ApplicationID 89, Number Structure > Cash Management > Receipt Group No,
  TableName CB_ReceiptGroup / PrimaryKey CBReceiptGroupID / CodeField GroupNo) - before using LKHS-325.
  Missing -> GIRO Batch Generation Save: "There is no row at position 0" (seen 09/11 after DB restore).
  Then Number Structure per GIRO company: Serial only, length 5, pad 0.

## Change log (after the package was first generated 09/11)
- 09/11: View_CB_ReceiptGroup_GIRO rewritten as plain SQL (no dynamic SQL): CreatedBy = COALESCE(View_CF_User.UserName, CF_User.LoginName). Source 09 updated; package file updated; sent to Gunner as single file.
- 13/11 (LKHS-320 Web/App_Code, GIRO forex): GIROModuleHandlers.cs - GIROForexSetting.EnableForexRow (default false = unchanged behaviour;
  true = Rental / Construction allocation at bill rate + forex row, LKHS-230 logic, helper InsertAllocationWithForex);
  OR CancelReceipt restores bill balance = sum(AllocAmt) per bill (always on); GetBaseCurrencyID protected -> internal.
  GIROPropertySalesHandler.cs - foreign-currency PS bill refused (PS BL AddCBAndBill uses converted amount; wrong also on PSReceiptAdd).
  Not decided by Stanley yet: foreign-currency GIRO bank? forex per module? rate at generate date or Payment Date?
- 16/11: Stanley: ARExportPath / ARImportPath = local folders on the server, mapped as a drive on user PCs (DBS portal used from the PC). No FTP. Setup: enter the SERVER path (not the user's mapped drive letter); IIS app pool needs read/write on both folders.
- 16/11 (LKHS-320): hide GIRO receipts in 4 module Collection lists: 4 standard views get column IsGiroReceipt + 4 pages filter isnull(IsGiroReceipt,'N')<>'Y' - see PATCH_LKHS-320_HideGIRO.md. View scripts = Gunner's own ALTER of the existing TFS view files (not generated here). Prc_splitpage cannot take a subquery in SelectCommandText.
- 19/11: error popup not shown (page only reloads) when the message has CR/LF (IOException 'The device is not ready.\r\n'): LKHS-325 ARGIROBatchGenerate.aspx.cs helper JsMessage (strip CR/LF, split <br>, escape); LKHS-320 ARGIROCollectionGenerate.aspx.cs strip CR/LF in both catch.

## Rules (Gunner)
- IFCA SQL: plain SQL like standard views; never dynamic SQL / run-time column probing. Unknown column -> ask Gunner to run a check query first.
- Small changes go into the package in progress (no separate mini zips); always ask before sending a final zip.
- 09/11: README LKHS-325 + this note: prerequisite LKHS-326 (DocCode 316_ReceiptGroup).
- 09/11: Gunner restored latest DB, deployed LKHS-326 + this package (LKHS-320, LKHS-325) from scratch: tested OK.
