# JESSELTON-282 — Lot Aging Summary vs Detail lệch số (debit adjustment)

## Ticket

Property Sales > AR Reporting > Lot Aging Report: Summary và Detail ra số khác nhau. Ví dụ JTT unit B-39-07, As At 31/10/2026: Summary ra Unallocated -0.60 / Amount Outstanding 0.60, còn Detail ra 0 record.

- Client: **JESSELTON** (Jesselton Properties Sdn Bhd), company 184, project JTT. Ngoài ra còn PJR, The V.
- Consultant: tuần trước Hoa đã sửa report này, kết quả rối nên phải deploy lại bản standard. Lần này yêu cầu deploy Train trước (restore Train từ Live), rồi mới lên Live.

## Report và SP

| Report | ReportNo / ReportDefineID | File | ReadTable (filter) | SP |
|---|---|---|---|---|
| Lot Aging Detail | 711 / 82121 | `PS_AR_LotAgingDetail_EN` | `View_PS_LotAgingFilter` | `PRC_Rpt_LotAgingDetail @CompanyID,@QueryCriteria,@AsAtDate` |
| Lot Aging Summary | 710 / 82120 | `PS_AR_LotAgingSummary_EN` | `view_rpt_LotAgingSummaryReportFilter` | `PRC_Rpt_UnitAgingSummary @AsAtDate,@QueryCriteria,@CompanyID` (thứ tự tham số khác Detail) |

- `ReadTable` chỉ là view của màn hình điều kiện. SP thật nằm trong `<CommandText>` của file report.
- 2 SP gần như copy nhau. Khác nhau: Summary có `IsDebit='Y'` (LBS-1987) và `ABS(..)<>0` (ECO-4060); Detail dùng `>0`. Detail lọc `RecordStatus<>'Voided'` (NAIMCAP-485) ở bước cuối.
- So với TFS: Live chỉ khác 1 điểm ở cả 2 SP, phần `--得到范围内的收款` có `R.RecordStatus not in ('Inactive','Voided')`, TFS chỉ có `'Inactive'`. Giữ nguyên, không thuộc ticket này (nghi do sót lại từ lần fix trước hoặc customize cũ; cần hỏi consultant).

## Logic report (cả 2 SP)

1. `#Temp1`: sale `RecordStatus IN ('Sign','Sale')`, `SaleDate <= AsAt`, debtor `AR_Debtor.RefTable='PS_Sale'`, có Company/Project/Phase/Block/Unit.
2. `#AR_Trx`: `AR_Trx` của debtor, không `New/InActive`, `DocumentDate <= AsAt`, chưa void tính đến AsAt (`VoidDate > AsAt` hoặc NULL).
3. `#Receipt`: `CB_Receipt` trong kỳ, chưa void tính đến AsAt. `#Journal`: `AP_Journal` Approved (refund).
4. `#trxage`: bill **không phải** `Adjustment`, không contra (trừ OtherFee contra; Summary còn lấy thêm `IsDebit='Y'`). Balance = DocumentAmt − allocation (từ receipt trong `#Receipt` + từ adjustment trong `#AR_Trx`). Chia aging theo `GetPSArAge('CF_Company', ...)`.
5. `#Temp2` gồm 2 nguồn:
   - Receipt chưa allocate: DocumentAmt − allocation (vào bill trong `#AR_Trx` + vào refund). Loại receipt bị bounce (`AR_Allocation.RefTable='CB_Receipt'`).
   - Adjustment chưa cấn trừ: `ElementCode='Adjustment' AND (IsContra='Y' OR ItemCode='PR')`, balance theo allocation `AdjustmentID`.
   - Xoá dòng `AllocBalance = 0`.
6. Output: dòng `#trxage` có Age1–7, Outstanding = tổng Age; dòng `#Temp2` có `UnallocationAmount = AllocBalance`, `AmountOutstanding = -AllocBalance`. Summary group theo unit.

## Root cause

Debit note số dương mang ElementCode `Adjustment` (vd PBRD Rounding Adjustment Debit Note, TPDN, DCTB) không nằm trong aging (`#trxage` loại Adjustment), chỉ đi qua `#Temp2`. Ở đây 2 SP tính sai, mỗi SP sai một kiểu. **Bug của bản standard** (TFS giống hệt).

1. **Summary** (`0-DocumentAmt-AllocAmt`): không trừ allocation mà DN nhận được với vai trò `BillID`. DN đã trả hết vẫn ra Unallocated −X / Outstanding +X.
2. **Detail** (`CASE WHEN DocumentAmt<0 ... ELSE 0`): ép DN số dương về 0. DN chưa trả bị mất khỏi report.
3. **Cả 2**: allocation từ receipt vào bill `Adjustment` không được trừ khỏi receipt (`t1.ElementCode<>'Adjustment'`), nên receipt hiện dư ảo.

Data B-39-07 (DebtorID theo sale Sign): 9 receipt allocate đủ. CR200503 (−87,859.05) cấn PB201013 87,858.45 + DR200129 0.60. **CR200444 (−0.60) cấn JP/DM000031 (+0.60, Rounding DN, 02/02/2026)**. Lot đã tất toán, Detail đúng, Summary sai.

Phạm vi (as at 31/10/2026, sale Sign/Sale):
- Rounding DN đã trả: JTT ~24 lot (21 trả bằng receipt, như A-13A-06; còn lại trả bằng CN, như B-39-07), PJR 2.
- DN chưa trả: A-16-05 (87.50), B-52-01 (0.10), The V D-16-06 (DCTB 12,342, void sau 31/10).
- Lưu ý khi scope: phải lọc sale Sign/Sale và void theo VoidDate như SP. Nếu không sẽ kéo cả DN void (vd B-37-06 JP/DM000042 là DN đảo CN JP/CM000093, cả 2 Voided) và DN trên sale Return (B-30-08), ra con số "unpaid 19 triệu" sai.

## Fix (áp giống nhau cho cả 2 SP)

**Patch 1** — receipt chưa allocate (Summary dòng 270, Detail dòng 260):
```diff
-    INNER JOIN #AR_Trx t1 ON t1.BillID=aa.BillID and t1.ElementCode<>'Adjustment'
+    INNER JOIN #AR_Trx t1 ON t1.BillID=aa.BillID and (t1.ElementCode<>'Adjustment' OR t1.DocumentAmt>0) --JESSELTON-282
```

**Patch 2a** — AllocBalance của adjustment (Summary dòng 315, Detail dòng 305–308):
```sql
  CASE WHEN t.DocumentAmt < 0
       THEN 0-t.DocumentAmt-ISNULL(al.AllocAmt,0)
       ELSE 0-(t.DocumentAmt-ISNULL(ab.AllocAmt,0))
  END as AllocBalance, --JESSELTON-282
```

**Patch 2b** — chèn sau `) AS al ON al.AdjustmentID=t.BillID`, trước `WHERE t.ElementCode='Adjustment'`:
```sql
 --JESSELTON-282: allocations received by debit adjustment (as BillID)
 LEFT JOIN (
   SELECT x.BillID, SUM(x.AllocAmt) AS AllocAmt
   FROM (
     SELECT aa.BillID, aa.AllocAmt
     FROM AR_Allocation aa
     INNER JOIN #Receipt r ON r.CBReceiptID = aa.ReceiptID
     WHERE aa.RecordStatus <> 'InActive' AND aa.BillID IS NOT NULL
     UNION ALL
     SELECT aa.BillID, aa.AllocAmt
     FROM AR_Allocation aa
     INNER JOIN #AR_Trx t2 ON t2.BillID = aa.AdjustmentID
     WHERE aa.RecordStatus <> 'InActive' AND aa.BillID IS NOT NULL
   ) x
   GROUP BY x.BillID
 ) AS ab ON ab.BillID = t.BillID
```

Kết quả: DN đã trả → 0, không hiện. DN chưa trả → Outstanding +X ở cả 2 report (vẫn nằm ở cột Unallocated dạng âm, chưa đưa vào cột aging). Credit adjustment giữ nguyên.

## Test

- Test bằng bản copy SP `_hoanglt` (`PRC_Rpt_UnitAgingSummary_hoanglt`, `PRC_Rpt_LotAgingDetail_hoanglt`), chạy song song với bản gốc.
- B-39-07: Summary cũ −0.60/0.60 → mới không còn dòng; Detail 0 dòng. ✔
- Case chuẩn bị thêm: A-13A-06 (DN trả bằng receipt), A-16-05 / B-52-01 (DN chưa trả), The V D-16-06 (CompanyID khác 184), so tổng toàn project JTT.

## Trạng thái

- 2026-11-18: root cause confirm bằng code + data; test SP OK case B-39-07; consultant test OK, chờ EU test lại. Deploy theo thứ tự Train (restore từ Live) → Live. Sau khi xong nên commit fix lên TFS (bug standard).

## Jira note (English)

**Root Cause:**
Both Lot Aging Summary and Detail handle debit adjustments (e.g. Rounding Adjustment Debit Note) incorrectly. This is a standard issue, not a client customization. For JTT B-39-07, debit note JP/DM000031 (0.60) is already fully knocked off by CR200444, but the Summary still shows it as Unallocated -0.60 / Outstanding 0.60. The Detail is correct for this lot.

**Fix:**
Amended `PRC_Rpt_UnitAgingSummary` and `PRC_Rpt_LotAgingDetail` so debit adjustments are net of their allocations, including allocations from receipts. Both reports now show the same figures.

**Status:**
Tested at SP level: B-39-07 no longer shows -0.60 / 0.60. Will deploy to Train for user testing after Train is restored from Live.
