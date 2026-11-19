# PALMINGTONPG-1 — Collection Posting > Bank-In: "Failed to save record!"

- **Client:** PALMINGTONPG (environment PMT_TRAIN, company PMT, CompanyID 17)
- **Module:** Cash Management > Receipt > Collection Posting > Bank-In (`CashFlow/ACReceiptBankIn.aspx(.cs)`, `saveButton_Click`)
- **Status:** Root cause confirmed, data patched, Bank-In retested OK (2026-11-16). The message-display fix is outside the ticket scope (diff below), applied by Gunner.

## Symptom
Collection Posting > tick receipt `PMT/CT/ARRN/0000001` (CBReceiptID 336869, 67,800.00, bank AMBANK 12345678, BankAccountID 585) > Bank-In > Save → popup "Error / Failed to save record!" with no further detail.

## Investigation (summary)
- `saveButton_Click` can show `SaveFailed` from several branches. The investigation first ruled out the two `sys_error` checks on the assumption that the first parameter is the visible message. **That assumption was wrong:** `sys_error('<long text>', '<SaveFailed>')` shows only the 2nd parameter, so the real reason was hidden.
- Data checked along the way (all OK, not the cause): `CB_Receipt` 336869 `CBTrxID` NULL / `RecordStatus` Verified; cash-flow split `CB_TrxAlloc` 100%; `GL_AccountPeriod` for books 775/776 covers 2025–2027, Nov-2026 period Active and not closed.
- Gunner confirmed the failing branch is the master-book check (L377–388).

## Root cause
The master-book check:
```sql
SELECT count(1) FROM CF_Company a INNER JOIN GL_AccountSetting b ON a.CompanyID = b.CompanyID
WHERE a.RecordStatus = 'Active' AND b.RecordStatus = 'Activated' AND a.CompanyID = 17 AND ISNULL(b.IsMasterBook,'N') = 'Y'
```
The accounting books for company 17 were all created on 2026-11-16 17:44–17:51 by user 263, with **`GL_AccountSetting.RecordStatus = 'Active'`** instead of the standard **`'Activated'`**. The check therefore returned 0 and Save stopped with "no default main book".

| AccountSettingID | Code | Year | IsMasterBook | RecordStatus (before) |
|---|---|---|---|---|
| 773 | ifca01 | 2026 | N | Inactive |
| 774 | ifca01 | 2026 | N | Inactive |
| 775 | ifca01 | 2025 | N | **Active** |
| 776 | ifca02 | 2025 | **Y** | **Active** |

Standard convention, checked on the TIMATCH DB:
- `GL_AccountSetting.RecordStatus`: `Activated` / `Closed` / `Inactive`
- `GL_AccountPeriod.RecordStatus`: `Active` (different from the setting table; the PMT_TRAIN periods are correct)

→ **This is a data setup error, not a code bug.** The code check follows the standard convention, so the code is not changed. How the 'Active' values were created (inserted by hand vs. saved by the Accounting Books screen) was not confirmed. If more books show up with 'Active', check the audit log `IFCANetAudit_R2_8` for `GL_AccountSetting` (APP_NAME).

## Fix
### 1. Data patch (PMT_TRAIN) — done, Bank-In retested OK
```sql
UPDATE GL_AccountSetting SET RecordStatus = 'Activated' WHERE AccountSettingID = 775;  -- ifca01 2025, was Active
UPDATE GL_AccountSetting SET RecordStatus = 'Activated' WHERE AccountSettingID = 776;  -- ifca02 2025 (Master), was Active
```

### 2. Clearer error message (outside the ticket scope) — `ACReceiptBankIn.aspx.cs`
The two `sys_error` calls pass the descriptive text as the 1st parameter, which is not displayed, so the user only sees "Failed to save record!". Switch to the `Message` class (the same way the rest of the page shows errors).

**Before (L369–388):**
```csharp
if (temInt > 0)
{
    Page.ClientScript.RegisterStartupScript(GetType(), "js", "<script>sys_error('There are some records have already banked in!','" + Strings.GetString("SaveFailed") + "')</script>");
    return;
}
...
if (tempStr==0)
{
    Page.ClientScript.RegisterStartupScript(GetType(), "js", string.Format("<script>sys_error('{0}','{1}')</script>"
        , "There is no default main book set, please proceed to Generel Ledger > GL Master Files > Accounting Books."
        , Strings.GetString("SaveFailed")));
    return;
}
```
**After:**
```csharp
if (temInt > 0)
{
    Message msgBanked = new Message("There are some records have already banked in!");
    msgBanked.MsgType = Message.EnumMsgType.OKOnly;
    Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgBanked.GetHtml());
    return;
}
...
if (tempStr==0)
{
    Message msgBook = new Message("There is no default main book set, please proceed to General Ledger > GL Master Files > Accounting Books.");
    msgBook.MsgType = Message.EnumMsgType.OKOnly;
    Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgBook.GetHtml());
    return;
}
```

## Notes for future tickets
- "Failed to save record!" with no detail on Bank-In → check the master book first (`GL_AccountSetting` with `IsMasterBook='Y'` and `RecordStatus='Activated'`), especially in an environment / company whose books were just set up.
- `sys_error(a, b)` shows only `b` → do not judge which branch fired from the message text when the code calls `sys_error`.

## Jira note (English)
**Root Cause:**
Bank-In Save validates that the company has an active master accounting book (`GL_AccountSetting`: `IsMasterBook = 'Y'` and `RecordStatus = 'Activated'`). For PMT (CompanyID 17) on PMT_TRAIN, the accounting books set up on 16/11/2026 (ifca01 – ID 775, ifca02 master – ID 776) were saved with `RecordStatus = 'Active'` instead of the system standard `'Activated'` (verified against another client DB, which uses Activated/Closed/Inactive). The validation therefore found no master book and blocked the save. The popup only showed the generic "Failed to save record!" because the descriptive message was passed in a parameter that the error dialog does not display.

**Fix:**
- Data: updated `GL_AccountSetting.RecordStatus` from 'Active' to 'Activated' for AccountSettingID 775 and 776. No code change is required for the validation.
- Improvement (outside ticket scope): the Bank-In page now shows the actual reason (e.g. "There is no default main book set, please proceed to General Ledger > GL Master Files > Accounting Books.") instead of the generic "Failed to save record!".

**Status:** Fixed on PMT_TRAIN, Bank-In retested OK. Please ensure Accounting Books on other environments (UAT/Live) use status 'Activated' before go-live.
