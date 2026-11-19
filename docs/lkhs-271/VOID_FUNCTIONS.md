# LKHS-325 - standard receipt void/cancel code of the modules (sent by Gunner 06/11), reference for Cancel Receipt Action

## Rental - McAccount/ArReceiptDelete.aspx(.cs) (popup of button Delete, ContextMnuNo Cancel, MC.Payment, mcorp-06-07)
DataSave: only when CB_Receipt.RecordStatus in ('Active','Verified'):
  DataAccessHelper.ExecuteNonQuery(tran, ArCharge.CancellationCB_Receipt(id, voidDate, voidUserID, voidRemark))
ArCharge (App_Code MCCode):
```csharp
public static string CancellationCB_Receipt(string PstrCBReceiptID, DateTime PstrVoidDate, string PstrVoidByID, string PstrVoidRemark)
{
    string sql = string.Format(@"update CB_Receipt set VoidDate='{1}',VoidUserID='{2}',RecordStatus='{4}', VoidRemark = '{3}' from CB_Receipt a where a.CBReceiptID='{0}'
             ;update AR_Trx set BalanceAmt=(t.BalanceAmt+a.AllocAmt) from AR_Trx t,AR_Allocation a where t.BillID=a.BillID and a.ReceiptID={0}
                and a.recordstatus='{5}' and t.recordstatus='{5}'
             ;update AR_Allocation set RecordStatus='Inactive' from AR_Allocation a where a.billid is not null and a.ReceiptID='{0}'
           ", PstrCBReceiptID, PstrVoidDate, PstrVoidByID, PstrVoidRemark, Constants.RecordStatus.Voided, Constants.RecordStatus.Active);
    return sql;
}
```
Notes: receipt Voided; no MCInterest reversal; UPDATE..FROM join -> 2 alloc rows of one bill (forex row) may add only one.

## Construction - PMReceivable/ARReceiptList.aspx(.cs) (button Cancel f_Cancel, PM.ARFee, PM-10-03; callback)
RaiseCallbackEvent: only when the receipt has NO active allocation ("Kindly unallocate it before Cancel"), then ARVoidTransaction.CancelReceipt(id):
```csharp
public static void CancelReceipt(int iReceiptID)
{
    int iUserID = int.Parse(SysContext.CurrentUserId);
    DateTime dtToday = DateTime.Now;
    string sRecordStatus = PMRecordStatus.Inactive;
    DataAccessAdapter adapter = new DataAccessAdapter();
    adapter.StartTransaction(IsolationLevel.ReadCommitted, "Void Receipt");
    try
    {
        CBReceiptEntity eReceipt = new CBReceiptEntity(iReceiptID);
        eReceipt.RecordStatus = sRecordStatus; eReceipt.ModifyDate = dtToday; eReceipt.ModifyUserID = iUserID; eReceipt.IsNew = false;
        adapter.SaveEntity(eReceipt);
        EntityCollection<ARAllocationEntity> eArAlloc = new EntityCollection<ARAllocationEntity>();
        RelationPredicateBucket iFilter = new RelationPredicateBucket();
        iFilter.PredicateExpression.Add(ARAllocationFields.ReceiptID == iReceiptID);
        iFilter.PredicateExpression.Add(ARAllocationFields.RecordStatus == "Active");
        adapter.FetchEntityCollection(eArAlloc, iFilter);
        foreach (ARAllocationEntity alloc in eArAlloc)
        {
            if (alloc.BillID.HasValue)
            {
                ARTrxEntity eBill = new ARTrxEntity(alloc.BillID.Value);   // NOT fetched
                eBill.BalanceAmt += alloc.AllocAmt; eBill.ModifyDate = dtToday; eBill.ModifyUserID = iUserID; eBill.IsNew = false;
                adapter.SaveEntity(eBill);
            }
            alloc.RecordStatus = sRecordStatus; alloc.ModifyDate = dtToday; alloc.ModifyUserID = iUserID; alloc.IsNew = false;
            adapter.SaveEntity(alloc);
        }
        adapter.Commit();
    }
    catch (Exception ex) { adapter.Rollback(); throw new Exception(ex.Message); }
}
```
Notes: receipt + allocations -> 'Inactive' (not Voided); page blocks allocated receipts, so the loop never runs from the screen;
eBill built without fetch -> BalanceAmt += would start from default, unsafe for allocated receipts -> GIRO must not call it.
PM bill balance rule (PMReceiptBL.UpdateBalanceAmt, used by GIROConstructionHandler): BalanceAmt = DocumentAmt - sum(AllocAmt of Active allocations).

## Property Sales - PS/AccountARReceiptList (Sale-11-17, button Voide f_voidedreceipt -> ReceiptVoid(result))
ReceiptVoid: result "Y" -> message ReceiptBounceCheque (bounced cheque), else popup ../PSAccount/ArReceiptDelete.aspx?CurId=..
PSAccount/ArReceiptDelete.aspx.cs DataSave:
  1. block when VoidDate < AccountSetting.GetAccountMinDate(CompanyID)  (message VoidDateErr: void date before month-end closing)
  2. block when the receipt has a refund: AR_Allocation RefundID not null, BillID null, RecordStatus <> 'InActive' (MC.CurReceiptRefund)
  3. in tran: SysTabEdit1.SaveData -> CB_Receipt RecordStatus 'Voided', AllocBalance 0, VoidDate / VoidUserID / VoidRemark (form)
  4. each allocation RecordStatus <> 'Inactive': pf_SaveCustomization "ArReceiptDelete_SaveArTrxForex" (client hook),
     AR_Allocation -> 'Inactive', AR_Trx.BalanceAmt += BaseAmt   (BaseAmt, not AllocAmt; BillID null row would break the SQL)
  5. after commit: pf_LoadCustomization PostSalesForce, customization API ARRECEIPTDELETE (client hooks, not for GIRO)

## Other Receivable - AccountReceivable/OtherReceiptList f_delete -> popup OtherReceiptDelete.aspx
Save_Click, one tran:
  CB_Receipt RecordStatus 'Voided', VoidUserID, VoidRemark, VoidDate, AllocBalance 0
  AR_Trx BalanceAmt = isnull(BalanceAmt,0) + A.BaseAmt/A.ExchangeRate (UPDATE..FROM, alloc not Inactive/Voided)
  CB_Payment AllocBalance += BaseAmt/ExchangeRate for contra allocations (PaymentID)
  AR_Allocation RecordStatus 'InActive' (all rows of the receipt)

## GIRO implementation (LKHS-325 2c, 06/11): handler.CancelReceipt(tran, GIROCancelContext) per module, in the GIRO transaction
Rental = ArCharge SQL; OR = same SQL (13/11: OR restores bill balance = sum(AllocAmt) per bill); PM = own steps (Voided, alloc Inactive, PM balance rule); PS = same steps incl. 2 checks.
Originals of these standard files are kept in the claude.ai Project at claude/LKHS-271-src/ORIGINAL/ (not copied here).
