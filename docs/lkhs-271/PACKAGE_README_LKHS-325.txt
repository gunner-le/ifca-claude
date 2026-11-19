LKHS-325 - SG Localization: AR Collection GIRO for DBS - GIRO Batch (step 7, Stanley doc v01.01)
===============================================================================================
26 files + this README. 1 SQL file = 1 object (TFS folders).
PREREQUISITES: LKHS-320 installed first; LKHS-326 (Stanley) = CF_DocCode DocCodeNo '316_ReceiptGroup' (ApplicationID 89,
System Setup > Number Structure > Cash Management > Receipt Group No). Without it GIRO Batch Generation Save fails with
"There is no row at position 0". Then set the Number Structure of each GIRO company (Serial only, length 5, pad 0).
GIRO Batch Generation (DBS UFF file) / GIRO Batch Reset / Import (Reject) / Import (Success) -> Pre-Check -> Confirm,
Cancel Receipt Action (4 modules), Collection Verification: Cancel button + GIRO columns / criteria, D35 Identity No.

DATABASE - run in this order (all re-runnable)
 1 New Table      CB_ReceiptGroup.sql                         GIRO batch
 2 New Table      CB_ReceiptGroupDetail.sql                   receipts of a batch (+ ReturnReason)
 3 New Table      CB_ReceiptGroup_AuditLog.sql                Generate / Reset / Import / Verify / Cancel
 4 Views          View_CB_GIROLookup.sql                      SWIFT / DBS Purpose Code lists
 5 Views          View_CB_Receipt_GIRO.sql                    GIRO receipts + DBS file data, D35 = CF_Account.IdentityNo (needs 4)
 6 Views          View_CB_ReceiptGroupGenerate.sql            GIRO Batch Generation header (needs 1)
 7 Views          View_CB_ReceiptGroup_GIRO.sql               GIRO Batch Reset / Import listing (needs 1, 2)
 8 Views          View_AC_Receipt.sql                         STANDARD view (Collection Verification) + 3 GIRO columns
                                                              -> update the EXISTING file in TFS (ALTER VIEW)
 9 Update Script  LKHS-325_01_Config_CB_GIROBatchGenerate.sql GIRO Batch Generation popup + Collection Verification button (needs 5, 6)
10 Update Script  LKHS-325_02_Config_CB_GIROBatchList.sql     GIRO Batch Reset / Import + Collection Verification button (needs 7)
11 Update Script  LKHS-325_03_Config_CB_GIROBatchImport.sql   Upload / Pre-Check popups + Collection Verification button Cancel
12 Update Script  LKHS-325_04_Config_AC_Receipt_GIRO.sql      Collection Verification GIRO columns / criteria (needs 8)

WEB (copy into the web site, same folders) - all NEW files
  App_Code/GIROCode/GIROBatchService.cs     batch create / reset / pre-check / confirm, Cancel Receipt Action, Verification cancel
                                            (AllowBlankIdentityNo = false: debtor without Identity No blocks the batch)
  App_Code/GIROCode/GIROUffDbs.cs           DBS UFF CSV builder (68 fields)
  App_Code/GIROCode/GIROReturnFileDbs.cs    DBS return file (CSV) parser / matcher
  CashFlow/ARGIROBatchGenerate(Detail).aspx(.cs), ARGIROBatchLst, ARGIROBatchImport, ARGIROBatchPreCheck  (10 files)

EXISTING STANDARD FILE - EDIT BY HAND (not replaced)
  PATCH_LKHS-325_ACReceiptVerify.md         CashFlow/ACReceiptVerify.aspx + .aspx.cs, items 1-9 (comments "LKHS-325 GIRO")

LKHS-320 files changed by LKHS-325: GIROModuleHandlers.cs, GIROPropertySalesHandler.cs, GIROModels.cs (CancelReceipt) -
their latest version is in the LKHS-320 folder.

LATER ADDITION (19/11): ARGIROBatchGenerate.aspx.cs helper JsMessage (strip CR/LF, split <br>, escape) so error popups show.
