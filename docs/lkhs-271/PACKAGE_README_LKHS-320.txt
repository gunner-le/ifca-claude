LKHS-320 - SG Localization: AR Collection GIRO for DBS - Generate GIRO Collection (step 6)
=========================================================================================
21 files + this README. All NEW files (no existing standard file changed). 1 SQL file = 1 object (TFS folders).
Prerequisite: GIRO master setup (CF_Company.AllowGiroProcess, CF_CompanyGiroBank, AR_Debtor GIRO columns).

DATABASE - run in this order (all re-runnable)
 1 Table Change   CB_Receipt_GIRO.sql                             CB_Receipt + IsGiroReceipt / GIRORecordStatus / GroupNo
                                                                  (GroupNo is used by LKHS-325; added here so CB_Receipt changes once)
 2 New Table      CB_GIROTempDetail.sql                           working table of the Generate popup
 3 Views          View_CB_GIROCollectionPending.sql               bills to collect
 4 Views          View_CB_GIROCollectionGenerate.sql              popup header
 5 Views          View_CB_GIROCollectionTempDetail.sql            popup detail (needs 2, 3)
 6 Update Script  LKHS-320_01_Config_CB_GIROCollection.sql        Sys_ / CF_String: Generate GIRO Collection list (needs 3)
 7 Update Script  LKHS-320_02_Config_CB_GIROCollectionGenerate.sql Sys_ / CF_String: Generate popup (needs 4, 5)

WEB (copy into the web site, same folders)
  App_Code/GIROCode/GIROCollectionGenerator.cs     common part: lock / validate / group / doc no / CB_Receipt (IsGiroReceipt Y, Generated)
  App_Code/GIROCode/GIROModuleHandlers.cs          Rental / Other Receivable / Construction handlers (+ CancelReceipt, used by LKHS-325)
  App_Code/GIROCode/GIROPropertySalesHandler.cs    Property Sales handler (+ CancelReceipt, used by LKHS-325)
  App_Code/GIROCode/GIROModels.cs                  models (+ GIROCancelContext, used by LKHS-325)
  CashFlow/ARGIROCollection*.aspx(.cs)             5 pages: menu page, list, select, Generate popup, popup detail

NOTE: the 3 App_Code files above are the LATEST version: they already contain the CancelReceipt code added for LKHS-325
(Cancel Receipt Action). They compile on their own (no reference to LKHS-325 files).

LATER ADDITIONS TO LKHS-320 (after 09/11):
  - 13/11 forex (GIROForexSetting.EnableForexRow) in GIROModuleHandlers.cs; PS foreign-currency bill refused in GIROPropertySalesHandler.cs
  - 16/11 hide GIRO receipts in 4 module Collection lists (4 views + 4 pages) - PATCH_LKHS-320_HideGIRO.md
  - 19/11 ARGIROCollectionGenerate.aspx.cs strip CR/LF from error messages
