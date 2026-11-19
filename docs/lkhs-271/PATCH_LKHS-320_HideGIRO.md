# LKHS-320 GIRO - hide GIRO receipts in module Collection lists (spec v01.2: "Exclude display collection CB_Receipt.IsGiroReceipt = Y")
Done & tested 16/11 (Gunner applied on LKHS_Train).

Approach: add column IsGiroReceipt (from CB_Receipt) to each list view (no row change -> other screens/reports unaffected),
filter in the page with a FLAT condition: isnull(IsGiroReceipt, 'N') <> 'Y'.
Why not a subquery in the page: list paging SP Prc_splitpage lower-cases @sql, takes the LAST ' where ' / ' from ' and checks
bracket balance after them -> a subquery (... not in (select ... from ... where ...)) breaks it (cuts last 2 chars / bad SQL).
Why not filter inside the standard view: View_PM_Receipt is also read by Sys_Base PM.ARFeeNO / PM.ARPreReceiptDelete (View form, delete).
(Temporary View_PM_Receipt_NoGIRO was dropped: IF OBJECT_ID('dbo.View_PM_Receipt_NoGIRO','V') IS NOT NULL DROP VIEW dbo.View_PM_Receipt_NoGIRO)

| Module | View (ALTER: add column, comment -- LKHS-271 GIRO) | Page |
|---|---|---|
| Construction | View_PM_Receipt: `,Cb.IsGiroReceipt` after `,Cb.IsAdvancePayment AS IsCbAdv` | PMReceivable/ARReceiptList.aspx.cs (Page_Load) |
| Rental | View_MC_Receipt_List: `,CB_Receipt.IsGiroReceipt` | McAccount/ARFeeList.aspx.cs (OnInit) |
| Other Receivable | View_CB_ReceiptOfOtherDebtor: IsGiroReceipt of CB_Receipt | AccountReceivable/OtherReceiptList.aspx.cs (Page_Load) |
| Property Sales | View_PS_cbReceiptList: IsGiroReceipt of CB_Receipt | PSAccount/ARReceiptList.aspx.cs (class PSAccount_ARDepositList; BuildListData, 2 branches) |

## Construction - PMReceivable/ARReceiptList.aspx.cs
Before: SysList1.SelectCommandText = "select * from View_PM_Receipt where ReceiptType = 'PM_Receipt' and CompanyID=" + Request.QueryString["CompanyID"].ToString();
After:  SysList1.SelectCommandText = "select * from View_PM_Receipt where ReceiptType = 'PM_Receipt'"
            + " and isnull(IsGiroReceipt, 'N') <> 'Y'"   // LKHS-271 GIRO: hide GIRO receipts
            + " and CompanyID=" + Request.QueryString["CompanyID"].ToString();

## Rental - McAccount/ARFeeList.aspx.cs
Before: string sql = " select distinct * from View_MC_Receipt_List  where  ReceiptType='MC_Fee' and voiddate is null and VoidUserID is null";
After:  string sql = " select distinct * from View_MC_Receipt_List  where  ReceiptType='MC_Fee' and voiddate is null and VoidUserID is null"
            + " and isnull(IsGiroReceipt, 'N') <> 'Y'";   // LKHS-271 GIRO: hide GIRO receipts

## Other Receivable - AccountReceivable/OtherReceiptList.aspx.cs
Before: this.SysList1.SelectCommandText = "SELECT * FROM View_CB_ReceiptOfOtherDebtor WHERE RecordStatus NOT IN ('Voided','Inactive') AND CompanyID = " + CompanyID;
After:  this.SysList1.SelectCommandText = "SELECT * FROM View_CB_ReceiptOfOtherDebtor WHERE RecordStatus NOT IN ('Voided','Inactive')"
            + " AND ISNULL(IsGiroReceipt, 'N') <> 'Y'"   // LKHS-271 GIRO: hide GIRO receipts
            + " AND CompanyID = " + CompanyID;

## Property Sales - PSAccount/ARReceiptList.aspx.cs (class name inside = PSAccount_ARDepositList; BuildListData)
Open branch Before: string SelectCommandTextSQL = "Select * from View_PS_cbReceiptList (NOLOCK)"; ... SelectCommandTextSQL += " WHERE " + plusFilter;
Open branch After:  string SelectCommandTextSQL = "Select * from View_PS_cbReceiptList (NOLOCK) WHERE isnull(IsGiroReceipt, 'N') <> 'Y'";   // LKHS-271 GIRO
                    ... SelectCommandTextSQL += " AND " + plusFilter;   (WHERE -> AND, else 2 WHERE: "Incorrect syntax near 'where'")
Search branch After: string.Format("Select * from View_PS_cbReceiptList (NOLOCK) where {0} and isnull(IsGiroReceipt, 'N') <> 'Y' order by DocumentDate desc", strfilter);

Note 16/11: PSAccount/ARReceiptList_SDPB.aspx (view View_PS_cbReceiptList_SDPB) = SDPB customization, not used by LKHS now -> not changed. If LKHS menu ever points to it: same change (add IsGiroReceipt to the _SDPB view + filter in the page).
