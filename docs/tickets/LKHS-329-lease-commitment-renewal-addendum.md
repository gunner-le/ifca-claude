# LKHS-329 — Lease Commitment Report sai số với lease có Renewal/Addendum

- **Client:** LKHS (CompanyID 195, Paya Lebar Square)
- **Module:** Rental Management > Reporting > Lease Commitment Report
- **SP:** `pro_Rental_Tenant_Report_Forecasting` (view `View_Rental_Tenant_Report_Forecasting` không sửa)
- **Trạng thái:** ĐÃ XONG (2026-11-18) — SP đã apply Live, patch data Live xong, consultant verify OK trên Train Testing.

## 1. Nghiệp vụ

Lease Commitment = tiền thuê còn phải thu theo hợp đồng từ ngày báo cáo (As At) đến hết hạn lease, chia theo năm (≤1 năm, 1–2, … >6 năm). LKHS là bên cho thuê.

- Report đọc `MC_BillSchedule` (`RecordStatus='Active'`, item `RentalFee`/`OtherFee`), tiền = `DocumentAmt - TaxAmt`, xếp năm theo `ScheduleDate`.
- **Renewal** = gia hạn, hợp đồng mới nối tiếp sau hợp đồng cũ. **Addendum** = phụ lục sửa hợp đồng đang chạy. Cả hai tạo **`RT_RentalContract` mới cùng `DebtorID`**; hợp đồng cũ chuyển `Contract Closed`.
- KH tính cả hợp đồng Renewal/Addendum ký sau ngày báo cáo (xác nhận qua Expected Results As At 31/10/2025), và muốn 1 dòng/tenant.

## 2. Root cause (SP)

1. `#BillScheme` join `RT_RentalContract` theo `DebtorID` → mỗi dòng schedule lặp theo số hợp đồng của debtor (×2, ×3, ×4, kể cả hợp đồng InActive/Closed).
2. Schedule sinh sau go-live có `UnitID = NULL` (dòng migration 03/12/2025 có đủ UnitID) → `INNER JOIN MC_Unit` loại mất tiền hợp đồng mới. `PropertyID` có đủ mọi dòng.
3. `GROUP BY LeasedArea` tách #01-77,#01-80 thành 2 dòng (1,163 và 2,326), mỗi dòng cùng số tiền.
4. Phụ: INSERT `#BillScheme` đảo cột `BillType`/`ItemCode` (56 item OtherFee có ItemCode khác ElementCode bị thiếu ở ConservancyAmount); bucket năm dùng `BETWEEN` để hở mốc.

## 3. Fix SP (comment `LKHS-329`)

- Bỏ join `RT_RentalContract`, dùng `B.RentalID`; bỏ `DISTINCT`.
- `LEFT JOIN MC_Unit`; `MC_Property` join theo `B.PropertyID`.
- Đổi lại thứ tự `P.ElementCode AS BillType, AR.ItemCode`.
- `ForeCastTime` dùng `>= ... AND < ...` thay `BETWEEN`.
- Sau `EXEC (@SQL)`: UPDATE `#ForeCast.LeasedArea` = `TotalRentalArea` của hợp đồng mới nhất (bỏ Rejected/InActive) → mỗi debtor 1 dòng.

**Không** thêm điều kiện loại schedule có bill Inactive: debtor 2114 (#B1-10, 5 Little Bears) có schedule 387 InActive nhưng bill Active, schedule 404 Active nhưng bill Inactive → lọc theo bill làm mất tiền đúng (13,036.80).

## 4. Data lỗi (ngoài SP) — đã patch

Report đọc đúng logic; các lệch còn lại do bill schedule sai:

| Unit | Lỗi | Train Testing | Live |
|---|---|---|---|
| #01-83 | `BillScheduleID 74428` (A&P 01/08/2028) `ScheduleDate` = 01/08/2027 → 39.05 sai cột năm | Patch | Đã đúng sẵn (ai đó sửa, không có audit) |
| #B1-07 | RentalID 390 (Renewal từ 29/03/2026) còn 226 dòng `Active` cho 29/03/2020–28/03/2026, trùng RentalID 22; bill đã `Inactive` | Patch 226 dòng | Đã `Inactive` sẵn |
| #B1-11,#B1-12 | RentalID 34 (1 Fusion) 6 dòng 01–02/2026 trùng GKE Retails (RentalID 379); bill Inactive | Patch | **Patch 6 dòng** (50426, 67816, 19719, 50427, 67817, 19720) |
| #01-50 | `BillScheduleID 71027` Base Rent 10/2030 `DocumentAmt` 6,626 (các tháng 6,226, BefTax 6,226) | Patch | **Patch 1 dòng** → 6,226 (consultant xác nhận) |

Không patch:
- #B1-11 tháng 12/2025 (RentalID 34, bill `RB114875` Voided): GKE được bill tay (`S36/CT/GSTN/26-0015/16/17`) không gắn schedule → inactive sẽ mất tháng 12 khỏi report.
- #B1-10 RentalID 404: là dòng đúng.
- #02-21 (73831): chỉ `DocumentAmtBefTax` lệch (2,480.50), `DocumentAmt` 2,501 khớp các tháng → không ảnh hưởng report.
- Query 3 (BefTax mismatch) còn nhiều dòng 2015–2025 đã post (GTO Rent, rebate...) — trước kỳ báo cáo, bỏ qua.

Lưu ý môi trường: Train Testing restore từ backup Live 00:02 ngày 12/11/2026; các query điều tra ngày 05/11 thực tế chạy trên Train nên có lúc kết luận nhầm trạng thái Live.

## 5. Kết quả (As At 31/10/2025)

Khớp Expected Results: #01-32 254,904.00; #01-50 402,100.33; #01-64 197,146.75; #01-77/80 819,915.00 (1 dòng); #01-82 594,391.30; #01-83 233,559.68 (61,977.60/61,977.60); #01-88 999,652.50; #01-89 1,881,176.37; #02-05 327,350.40; #B1-20 678,197.38; #B1-44 363,706.45; #B1-07 100,298.00. #B1-51 6,105,319.61 (gồm Licence Fee, consultant chấp nhận). Tenant 1 hợp đồng không đổi (#01-22 420,688.26). Report hiện thêm 14 tenant mới bắt đầu sau 31/10/2025.

## 6. Query rà soát dùng lại

```sql
-- Schedule Active nhưng bill Inactive/Voided (cần xem từng case, không phải dòng nào cũng thừa)
SELECT B.DebtorID, B.RentalID, T.RecordStatus, COUNT(*) Cnt, MIN(B.TrxStartDate), MAX(B.TrxEndDate),
       SUM(B.DocumentAmt - ISNULL(B.TaxAmt,0))
FROM MC_BillSchedule B JOIN AR_Trx T ON T.BillID = B.BillID
WHERE B.RecordStatus='Active' AND T.RecordStatus IN ('InActive','Voided') AND B.ScheduleDate >= '2025-10-01'
GROUP BY B.DebtorID, B.RentalID, T.RecordStatus;

-- ScheduleDate lệch kỳ thu
SELECT * FROM MC_BillSchedule
WHERE RecordStatus='Active' AND ABS(DATEDIFF(MONTH, TrxStartDate, ScheduleDate)) > 2;
```

## 7. Jira note (English)

**Root Cause:** The Lease Commitment Report (`pro_Rental_Tenant_Report_Forecasting`) linked bill schedules to rental contracts by tenant. A Renewal/Addendum creates a new contract under the same tenant, so the old contract's amounts were counted once per contract. New contract amounts were dropped because their bill schedule lines have no Unit, and leases whose contracts have different areas appeared on 2 lines. Some remaining differences were caused by bill schedule data (overlapping lines whose bills were cancelled, a wrong schedule date, a wrong amount).

**Fix:** Updated the report to count each bill schedule line once, include new contract amounts and show 1 line per tenant using the latest contract's area. Corrected bill schedule data on Live: #B1-11,#B1-12 (6 overlapping lines set to Inactive) and #01-50 (October 2030 Base Rent corrected to 6,226.00). #01-83 and #B1-07 were already correct on Live.

**Status:** Verified by consultant on Train Testing; applied to Live.
