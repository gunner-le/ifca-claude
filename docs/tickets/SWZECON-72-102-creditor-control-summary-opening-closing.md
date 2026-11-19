# SWZECON-72 / SWZECON-102 — Creditor Control Summary (Zecon): Opening vs Closing không khớp

**Client:** SWZECON (company Zecon Medicare Sdn Bhd, CompanyID 181)
**Module:** AP > AP Report > Creditor Control Summary report_zecon (SP `pro_AP_CreditorControlSummary_SWZECON`)
**Liên quan:** SWZECON-63 (tạo report custom). Report AR tương ứng: SWZECON-64/66/98/100 (`pro_AR_DebtorControlSummary_SWZECON`).
**Trạng thái:**
- SWZECON-72: đã fix, test OK, đóng (~08/2026).
- SWZECON-102: root cause confirm bằng code + data, đã patch SP, test PASS ở DB-level (2026-11-13). Chưa chạy test UI; chưa chạy company 211.

---

## SWZECON-72 (tóm tắt, đã đóng)

Triệu chứng: Opening Jan 2026 ≠ Closing 2025, nhiều creditor có số dư 2025 bị mất khỏi report kỳ 2026.

5 fix (đều đánh comment `--SWZECON-72` trong SP):
1. `#temcreditor`: thêm `OR EXISTS (#tempAPJ01 ... OpeningAmt<>0 or OpeningBaseAmt<>0)` → nạp cả creditor chỉ có opening.
2. Chèn dòng placeholder 0/0 vào `#tempAPJ001` cho creditor có opening nhưng không phát sinh trong kỳ (ngày = ngày AsAt cắt 00:00 để không bị `delete ... where not (@QueryCriteria)` xoá).
3. Biến động trong kỳ: `BETWEEN @StartDate AND @AsAtDate` → `> @StartDate AND <= @AsAtDate` (Opening đã lấy `<= @StartDate`, BETWEEN làm cộng trùng ngày ranh giới).
4. Opening, phần trừ `CB_Payment`: join `AP_Journal` mở rộng `PayableType` từ `('Claim','MOS','Invoice')` ra đủ danh sách như phần cộng (thiếu `Adjustment`… làm ZG1400(RTC) Opening dư 4,148,360.20).
5. `HAVING Closing <> 0` → `HAVING Opening<>0 OR Debit<>0 OR Credit<>0` (creditor tất toán trong kỳ vẫn hiện).

---

## SWZECON-102

### Triệu chứng

Creditor `V0036 (SC)` VELLD POWER SYSTEM CONSULT SDN BHD (CreditorID 923):

| Kỳ | Kết quả |
|---|---|
| 01/01/2025 – 31/12/2025 | Opening 0 / Debit 419.52 / Credit 0 / Closing -419.52 |
| 01/01/2025 – 13/11/2026 | giống trên |
| 01/01/2026 – 13/11/2026 | **0 record** (đúng phải là -419.52 / 0 / 0 / -419.52) |

### Data

Creditor chỉ có 1 chứng từ trong company 181 (không có `AP_Journal`, không có `CB_Receipt`):

| CBPaymentID | DocNo | PaymentType | DocumentAmt | AllocBalance | RecordStatus | TransactionDate | SUM(AP_Allocation.PayAllocAmt) |
|---|---|---|---|---|---|---|---|
| 2310 | ZMSB/PV00000426 | Invoice | 419.52 | 419.52 | Verified | 2025-12-31 | NULL |

→ Payment ứng trước, chưa allocate.

### Root cause

`CB_Payment` được tính theo 2 cách khác nhau trong SP:
- **Trong kỳ** (`INSERT INTO #tempAPJ001 ... FROM CB_Payment`): toàn bộ `pay.DocumentAmt` vào Debit, không cần allocate.
- **Opening** (`#tempAPJ01`): `INNER JOIN AP_Allocation` + `AP_Journal`, chỉ lấy `PayAllocAmt` (phần đã allocate).

Payment chưa allocate (hoặc allocate một phần) có trong Debit kỳ trước nhưng mất (hoặc thiếu) ở Opening kỳ sau. Với V0036: Opening 2026 = 0 → `EXISTS` của fix 72 không bắt, không có placeholder → creditor biến mất.

Thêm 1 chỗ lệch cùng dạng: `CB_Receipt` (Refund/PaymentRefund) được cộng vào Credit trong kỳ nhưng Opening không tính.

Fix 72 (#4) chỉ mở rộng `PayableType` trên join allocation, chưa xử lý việc Opening tính theo allocation còn trong kỳ tính theo chứng từ.

### Fix (chỉ đoạn Opening `#tempAPJ01`)

1. Phần `CB_Payment`: bỏ `INNER JOIN AP_Allocation` / `AP_Journal`, lấy `pay.DocumentAmt` (giống phần trong kỳ):
   ```sql
   --ISNULL(al.PayAllocAmt, 0) as DebitAmount,                                     --SWZECON-102 (old)
   --ISNULL(al.PayAllocAmt, 0) * ISNULL(pay.ExchangeRate, 0) as DebitBaseAmount   --SWZECON-102 (old)
   ISNULL(pay.DocumentAmt, 0) as DebitAmount,                                      --SWZECON-102
   ISNULL(pay.DocumentAmt, 0) * ISNULL(pay.ExchangeRate, 0) as DebitBaseAmount     --SWZECON-102
   FROM CB_Payment (NOLOCK) AS pay
   --INNER JOIN AP_Allocation ...   --SWZECON-102 (old)
   --INNER JOIN AP_Journal ...      --SWZECON-102 (old)
   WHERE ... (giữ nguyên PaymentType / Verified / TransactionDate <= @StartDate)
   ```
2. Thêm `UNION all` cho `CB_Receipt` Refund trước kỳ (cùng điều kiện với block trong kỳ), vào Credit:
   ```sql
   --SWZECON-102: refund receipts before period (same condition as in-period block)
   UNION all
   SELECT pay.CreditorID, pay.CurrencyID,
         ISNULL(pay.DocumentAmt, 0) as CreditAmount,
         ISNULL(pay.DocumentAmt, 0) * ISNULL(pay.ExchangeRate, 0) as CreditBaseAmount,
         0 as DebitAmount, 0 as DebitBaseAmount
   FROM CB_Receipt (NOLOCK) AS pay
   WHERE pay.CompanyID=@CompanyID
     and pay.ReceiptType in ('Refund','PaymentRefund')
     and exists(select top 1 1 from AP_Allocation (NOLOCK) B inner join CB_Payment A on B.PaymentID=A.CBPaymentID
          where B.RefundID=pay.CBReceiptID and A.CompanyID=@CompanyID
            and A.PaymentType IN ('Retention','Hold','Claim', 'MOS', 'Invoice') AND A.RecordStatus='Verified')
     AND pay.RecordStatus='Verified'
     and pay.TransactionDate<=CONVERT(nvarchar,@StartDate,121)
   --SWZECON-102
   ```

Các đoạn SWZECON-72 còn lại (EXISTS, placeholder, `>` StartDate, HAVING) giữ nguyên.

### Kết quả test (2026-11-13, DB-level)

Script: chạy SP 3 kỳ (1990–31/12/2025, 01/01/2026–13/11/2026, 1990–13/11/2026) vào bảng tạm, so Closing kỳ trước = Opening kỳ sau và Closing 2026 = Closing toàn kỳ theo từng creditor.

| Test | Kết quả |
|---|---|
| V0036 kỳ 2026 | -419.52 / 0.00 / 0.00 / -419.52 — PASS |
| 181: Closing 2025 = Opening 2026 | 102,374,476.79 = 102,374,476.79 — PASS |
| 181: Closing 2026 = Closing toàn kỳ | 102,256,841.98 = 102,256,841.98 — PASS |
| 220: 2 cặp tổng | 6,308.02 = 6,308.02; 10,089.02 = 10,089.02 — PASS |
| 181 hồi quy SWZECON-72: chuỗi Jan→Feb→Mar 2026 | khớp từng creditor; ZG1400(RTC) Jan -823,656.56 → Feb Opening, Feb -4,972,016.76 → Mar Opening — PASS |

Chưa chạy: test UI (report V0036 kỳ 2026), company 211.

### Rủi ro / ghi chú

- Fix đổi Opening của mọi creditor có payment chưa allocate / allocate một phần trước kỳ — đây là thay đổi đúng (khớp với Closing kỳ trước), đã kiểm chứng bằng phép đối chiếu toàn company.
- `@StartDate` cắt về 00:00 ngày trước ngày bắt đầu → Opening `<= 2025-12-31 00:00`, kỳ `> 2025-12-31 00:00`. Payment V0036 ngày `2025-12-31 00:00` rơi đúng vào Opening. Chứng từ ngày cuối kỳ trước có giờ ≠ 00:00 sẽ vào kỳ sau thay vì Opening (không mất, chỉ lệch kỳ) — cùng rủi ro đã ghi ở SWZECON-100.

## Root Cause / Fix note (English, Jira)

**Root Cause:**
In `pro_AP_CreditorControlSummary_SWZECON`, payments were counted differently in the Opening balance and in the period movement. Within the period, the full payment amount (`CB_Payment.DocumentAmt`) is shown as Debit. In the Opening balance, payments were only counted through `AP_Allocation`, i.e. only the portion already allocated to invoices. Unallocated (advance) or partially allocated payments were therefore included in the previous period's Closing but missing from the next period's Opening. Creditor V0036 (SC) has a single unallocated payment ZMSB/PV00000426 (419.52, 31/12/2025), so its Opening for 2026 was calculated as 0 and, with no transaction in 2026, it was dropped from the report. Refund receipts had the same inconsistency (counted in the period, not in the Opening). The earlier fix in SWZECON-72 handled opening-only creditors but did not cover this case.

**Fix:**
The Opening balance now uses the same rules as the period movement: payments are taken at their full document amount (not via allocation), and refund receipts before the period are included. No change to the rest of the report logic from SWZECON-72.

**Status:**
Fixed and verified on Zecon Medicare Sdn Bhd. V0036 (SC) for 01/01/2026 – 13/11/2026 now shows Opening -419.52 / Closing -419.52. For all creditors, Closing as at 31/12/2025 equals Opening for 2026 (102,374,476.79), and Closing for 2026 equals Closing from 01/01/1990 (102,256,841.98). Regression for SWZECON-72 (month-to-month carry-forward Jan–Mar 2026) passed.
