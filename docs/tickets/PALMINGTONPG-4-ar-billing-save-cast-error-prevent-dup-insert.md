# PALMINGTONPG-4 — Other Receivable > AR Transaction > Billing: Save báo "Specified cast is not valid"

- **Client:** PALMINGTONPG (DB/site `PMT_TRAIN`, company PMT — PALMINGTON SDN BHD, CompanyID 17)
- **Module:** Other Receivable > AR Transaction > Billing > Add (Debtor Invoice / DN — `AccountReceivable/OtherBillEdit.aspx`)
- **Ngày:** 2026-11-16
- **Trạng thái:** Root cause xác nhận bằng test (disable trigger → Save OK) trên PMT_TRAIN. Chưa áp dụng Live.

## 1. Hiện tượng

Add một Debtor Invoice/DN mới (debtor AG EYEWEAR - NO.67, 1 dòng Bill Item, Tax Code NA, Tax Rate 0, Department ACCT) rồi bấm Save thì popup báo `Specified cast is not valid.`. Lỗi xảy ra với mọi bill mới, không phụ thuộc dữ liệu nhập.

Stack trace lúc debug:

```
at PMCommonBL.SaveARTrxMod(...) in App_Code\PM\PMCommonBL.cs:line 3203
at AccountReceivable_OtherBillEdit.Save_Click(...) in AccountReceivable\OtherBillEdit.aspx.cs:line 420
```

## 2. Điều tra

1. Dòng 3203 là `throw ex;` trong `catch` của `SaveARTrxMod`. `throw ex` reset stack trace, nên dòng này không phải chỗ lỗi gốc.
2. Đọc code nhánh `DataRowState.Added`: các `int.Parse`/`Decimal.Parse` khi lỗi sẽ ra `FormatException`, không ra `InvalidCastException`. Kiểu cột `AR_Trx` (Tax/Rate/Amt) khớp với code: `ExchangeRate`/`TaxRate` là float ↔ double, các cột Amt là decimal. PMT không có cột `TaxExempt*`, nên loại cơ chế của FARLIMPG-169.
3. So với TFS: bản TFS gọi `pf_SaveCustomization(tranconn, ...)` (SWIBRACO-133), còn bản PMT gọi `(da, ...)`. Từng nghi lỗi cast nằm ở đây, nhưng **giả thuyết này SAI**.
4. Đặt breakpoint thì xác định exception văng ra tại **`da.SaveEntity(artrx, true)`** (dòng 3051, nhánh Added). Đây là nhánh duy nhất INSERT entity mới và phải lấy identity `BillID`.
5. Trigger trên `AR_Trx` (PMT_TRAIN): có **`PREVENT_DUP_INSERT` — INSTEAD OF INSERT, đang enable**. Toàn bộ 7 trigger có cùng `modify_date` 2026-05-21 15:15:30, có vẻ được script lại cùng lúc khi dựng DB.
6. Test: `ALTER TABLE AR_TRX DISABLE TRIGGER PREVENT_DUP_INSERT` rồi Save lại thì **Save thành công**.

## 3. Root cause

Bảng `AR_Trx` của PMT có trigger `PREVENT_DUP_INSERT` kiểu **INSTEAD OF INSERT** đang bật. Khi LLBLGen `SaveEntity` insert `ARTrxEntity` mới, lệnh INSERT bị trigger thay thế, và LLBLGen không lấy được identity `BillID` của dòng vừa insert, nên gán NULL vào field `int` và ra `InvalidCastException`. Exception bị `catch { throw ex; }` bọc lại nên debugger chỉ báo ở dòng `throw ex`.

Đã xác nhận bằng test: disable trigger thì Save OK.

### Nội dung trigger (đã đọc, PMT_TRAIN)

```sql
CREATE TRIGGER [dbo].[PREVENT_DUP_INSERT] ON [dbo].[ar_trx] INSTEAD OF INSERT AS
BEGIN
  SET NOCOUNT OFF;
  IF NOT EXISTS (SELECT 1 FROM dbo.ar_trx a INNER JOIN inserted b
                 ON a.CompanyID=b.CompanyID AND a.BillItemID=b.BillItemID AND a.SeqNo=b.SeqNo
                 AND a.DocumentNo=b.DocumentNo AND a.DocumentDate=b.DocumentDate AND a.TransactionDate=b.TransactionDate
                 AND a.ReferenceNo=b.ReferenceNo AND a.DocumentDesc=b.DocumentDesc AND a.DocumentAmt=b.DocumentAmt
                 AND a.BalanceAmt=b.BalanceAmt AND a.RecFrom=b.RecFrom AND a.ChargeAmt=b.ChargeAmt AND a.TaxAmt=b.TaxAmt
                 AND a.RecordStatus=b.RecordStatus AND a.ModifyUserID=b.ModifyUserID AND a.DeptID=b.DeptID
                 AND a.DocumentAmtBefTax=b.DocumentAmtBefTax)
  BEGIN
    INSERT INTO dbo.ar_trx (<danh sách ~80 cột HARDCODE, kết thúc ở IsDebit, IsVoidedDebit>)
    SELECT <cùng danh sách> FROM inserted
  END
  SELECT [BillID] FROM dbo.ar_trx WHERE @@ROWCOUNT > 0 AND [BillID] = scope_identity();
END
```

Phân tích:

1. **Vì sao vỡ với LLBLGen.** INSERT thật chạy *bên trong* trigger (scope khác). LLBLGen lấy identity bằng `SCOPE_IDENTITY()` ở scope của nó, nên nhận về NULL. Dòng `SELECT [BillID] ... = scope_identity()` cuối trigger trả về một **result set**: kiểu bù này hợp với code INSERT bằng SQL tay + `ExecuteScalar` (như khối PLBPG-34 đã comment trong `SaveARTrxMod` TFS), nhưng LLBLGen không đọc result set đó. Vì vậy mọi chỗ insert `AR_Trx` qua `SaveEntity` đều vỡ khi trigger bật, không riêng PMT. Phần "trigger sinh ra cho pattern ExecuteScalar" là suy luận từ cấu trúc trigger.
2. **Điều kiện "trùng" gần như không bao giờ khớp với bill mới.** Điều kiện so `=` trên nhiều cột nullable (`RecFrom`, `ChargeAmt`, `ReferenceNo`...). Gặp NULL thì `NULL = NULL` không đúng, nên `NOT EXISTS` luôn true và trigger vẫn insert bình thường. Lỗi không đến từ việc trigger bỏ qua INSERT. Ngoài ra điều kiện không so `DebtorID`.
3. **Danh sách cột hardcode.** Mọi cột thêm vào `AR_Trx` sau khi trigger được viết (TaxExempt*, IsRefundNote, cột e-Invoice...) sẽ **bị mất âm thầm**, bị NULL/default khi trigger bật. Cùng gotcha đã gặp với `IsRefundNote`.

→ Trigger này **không tương thích** với code hiện tại (LLBLGen `SaveEntity`) và còn làm mất cột mới. Disable là hướng đúng. Không nên "sửa trigger" để giữ lại.

## 4. Fix

```sql
ALTER TABLE AR_TRX DISABLE TRIGGER PREVENT_DUP_INSERT
```

Không sửa code.

## 5. Kết quả test

- PMT_TRAIN: disable trigger → Add Billing → Save thành công (Gunner xác nhận 2026-11-16).

## 6. Checklist xử lý nhanh lần sau

Triệu chứng: Save AR bill mới (Other Receivable / bất kỳ màn nào insert `AR_Trx` qua LLBLGen) báo "Specified cast is not valid", stack chỉ tới `throw ex` trong `PMCommonBL.SaveARTrxMod`.

```sql
SELECT t.name, t.is_instead_of_trigger, t.is_disabled
FROM sys.triggers t
WHERE t.parent_id = OBJECT_ID('dbo.AR_Trx') AND t.is_instead_of_trigger = 1;
-- Có PREVENT_DUP_INSERT, is_disabled = 0  →
ALTER TABLE AR_TRX DISABLE TRIGGER PREVENT_DUP_INSERT;
```

Áp dụng cho cả Train và Live của client đó.

## 7. Còn mở / lưu ý

- **Live chưa áp dụng.** Cần chạy cùng lệnh trên Live của PALMINGTONPG (kiểm tra trigger ở Live trước).
- Nên so trạng thái `PREVENT_DUP_INSERT` ở 1–2 client khác đang chạy bình thường (`sys.triggers.is_disabled`) để chắc disable là chuẩn chung, không phải chỉ workaround riêng PMT.
- Disable trigger thì mất cơ chế chặn insert trùng ở tầng DB. Nếu sau này gặp bill AR trùng ở PMT, xem lại điểm này.
- **SUMMERPG-24** (12/10/2026, Other Receivable > AR Transaction > Add Billing, "Specified cast is not valid") có triệu chứng y hệt và chưa có root cause ghi nhận. Nhiều khả năng cùng nguyên nhân, nên kiểm tra `PREVENT_DUP_INSERT` trên DB SUMMER.
- Ngoài phạm vi: `PMCommonBL.SaveARTrxMod` dùng `throw ex;` làm mất stack trace gốc. Đổi thành `throw;` thì lần sau debug nhanh hơn.

## 8. Jira note (English)

**Root Cause:** On PALMINGTONPG (PMT_TRAIN), table `AR_Trx` has the INSTEAD OF INSERT trigger `PREVENT_DUP_INSERT` enabled. When saving a new Debtor Invoice/DN, `PMCommonBL.SaveARTrxMod` inserts the bill line via LLBLGen `SaveEntity`; the actual INSERT is performed inside the trigger (a different scope), so the ORM's `SCOPE_IDENTITY()` returns NULL, the new BillID cannot be retrieved, and the save fails with "Specified cast is not valid". The trigger also uses a hardcoded column list, so any column added to `AR_Trx` later would be silently dropped on insert while it is enabled.

**Fix:** Disabled the trigger: `ALTER TABLE AR_TRX DISABLE TRIGGER PREVENT_DUP_INSERT`. No code change.

**Status:** Verified on PMT_TRAIN — new billing saves successfully after disabling the trigger. Pending the same change on Live.
