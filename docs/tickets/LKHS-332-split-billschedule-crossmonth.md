# LKHS-332 — Tách Bill Schedule bị gộp qua 2 tháng (patch data, sub-task LKHS-282)

- **Client / môi trường:** LKHS (Singapore, CompanyID 195 / S36 Paya Lebar Square), Train trước rồi Live. Source: `E:\IFCA Software\LKHS`, `LKHS_Train` (TFS nhánh `NET4.0_SG` / `IFCA.NET 4.0_SG`).
- **Màn hình / menu:** Rental Mgmt > Contract Management > Bill Schedule (Billing Period theo tháng của `ScheduleDate`). Ticket là patch data, không sửa code.
- **Ticket liên quan:** LKHS-282 (gốc: `CF_Parameter.UnPeriodAlgorithm_up` 28 → 0), LKHS-327 (rollout tham số, sửa JS NotRentalColor), LKHS-329 (Lease Commitment, renewal/addendum cùng `DebtorID`).
- **Trạng thái:** ĐÓNG 20/11/2026 — Live không còn dòng gộp (không cần patch); consultant không yêu cầu patch Train. Script rev 20/11 giữ sẵn, chưa chạy DB nào — dùng lại nếu consultant báo cần.
- **Script:** `work/LKHS-332/LKHS-332_Split_BillSchedule_CrossMonth.sql` (bản rev 20/11; `work/` không commit git).
- **TFS:** không áp dụng (patch data, không đụng code/SP).

## Bảng / object
- `MC_BillSchedule` (BillScheduleID, DebtorID, RentalID, RefTable/RefRecordID = charge, BillItemID, ScheduleDate, TrxStartDate, TrxEndDate, DocumentAmt, DocumentAmtBefTax, TaxID/TaxAmt, IsPost, BillID, IsRentFree, IsAmorSchedule, MainBillScheduleID, RecordStatus).
- `CF_Parameter.UnPeriodAlgorithm_up` (cut-off day prorate tháng cuối). `RtContractSum` chỉ INSERT schedule mới, không sửa dòng cũ → dòng sinh lúc tham số = 28 vẫn bị gộp.
- Script: `LKHS-332_Split_BillSchedule_CrossMonth.sql`. Backup `MC_BillSchedule_BK_LKHS332`, log mapping `MC_BillSchedule_LKHS332_Log`.

## Đã XÁC NHẬN
- Lỗi gộp: tháng cuối có ngày kết thúc ≤ 28 bị gộp ngược vào tháng trước (vd 01/03–28/04/2027 thành 1 dòng).
- Công thức đúng (khớp Expected ticket): đơn giá tháng × số ngày / số ngày **của chính tháng đó**, làm tròn 2 số mỗi dòng. Cách cũ = monthly × 59/31 → tổng tiền **SẼ TĂNG** sau tách (ví dụ +345.03).
- In Advance: `ScheduleDate = TrxStartDate` → dòng mới `ScheduleDate` = ngày 1 tháng sau, tự vào đúng kỳ.
- Renewal giữ cùng `RentalID`, đổi charge → sau tách 01/04–28/04 (charge cũ) nằm cạnh 29/04–30/04 (charge mới), không trùng.
- **20/11 consultant:** debtor trong ticket đã được sinh lại đúng sau lease addendum → **KHÔNG patch debtor đó**; vẫn phải **quét toàn bộ** Bill Schedule hiện có và patch các dòng còn gộp.

- **Quét phạm vi 20/11** (mọi dòng vắt qua tháng, theo RecordStatus / ngày bắt đầu):
  - **Live:** 0 dòng Active (Inactive: 139 dòng/9 debtor bắt đầu ngày 1, 48 dòng/3 debtor ngày khác) → **Live không cần patch**.
  - **Train:** Active 181 dòng/16 debtor bắt đầu ngày 1 + 36 dòng/2 debtor bắt đầu ngày khác (có thể chu kỳ lệch ngày kiểu A&P 29→28 → REVIEW). Consultant: không yêu cầu patch Train.
  - Bài học: lần đầu chạy nhầm DB → luôn ghi rõ server/DB khi dán kết quả.

## Script rev 20/11 (so với bản claude.ai)
- (a) Result set đầu: cột `MC_BillSchedule` không có trong INSERT; cột NOT NULL không default → dừng.
- (b) `REVIEW: amount is NULL` — trước đây `DocumentAmtBefTax` NULL lọt xuống OK (so sánh NULL = UNKNOWN).
- (c) `REVIEW: 2nd month is a full month` — dòng 01/03–30/04 là chu kỳ 2 tháng thật, không phải gộp (gộp chỉ khi tháng cuối lẻ ngày); bản cũ sẽ tách nhầm.
- (d) Dòng mới: `TransactionDate`/`DocumentDate` = ngày 1 tháng sau nếu dòng gốc đang = `ScheduleDate` (bản cũ copy nguyên ngày tháng đầu).

## GIẢ THUYẾT chưa chốt
- Train: bao nhiêu dòng OK / SKIP / REVIEW — chờ preview.
- Có dòng chịu thuế (GST) không — nếu có phải bổ sung tính `TaxAmt` (cần code tính tax trong `RtContractSum`).
- A&P renewal (charge 5508) bill chu kỳ 29→28: là setup, không phải lỗi gộp — script không đụng; nếu consultant muốn theo tháng dương lịch thì là việc sửa setup riêng.

## Đã sửa gì
- Chưa sửa code. Script patch đã viết, **CHƯA chạy trên DB nào** (tới 20/11).
- Logic script: quét dòng Active vắt qua cuối tháng, dài > 1 chu kỳ tháng → phân loại OK / SKIP / REVIEW. Chỉ patch OK. SKIP/REVIEW: đã post AR (`IsPost='Y'` hoặc có `BillID`), có tax/discount, Rent Free, amortization/`MainBillScheduleID`, không bắt đầu ngày 1, > 2 tháng, công thức cũ không khớp, lệch đơn giá với dòng nguyên tháng gần nhất, trùng kỳ cùng charge.
- Patch: backup → INSERT dòng tháng sau (`ScheduleDate = TrxStartDate` = ngày 1) → UPDATE dòng gốc kết thúc cuối tháng đầu → kiểm mapping 1-1 (lệch thì rollback). `@Commit = 0` mặc định (preview + rollback). Cuối file có đoạn rollback (comment).

## Query quan trọng
```sql
-- Phạm vi: Bill Schedule Active còn vắt qua 2 tháng, gom theo debtor
SELECT b.DebtorID, COUNT(*) AS CrossMonthRows,
       SUM(CASE WHEN ISNULL(b.IsPost,'N') = 'Y' OR b.BillID IS NOT NULL THEN 1 ELSE 0 END) AS PostedRows,
       MIN(b.TrxStartDate) AS FirstStart, MAX(b.TrxEndDate) AS LastEnd, COUNT(DISTINCT b.RentalID) AS Contracts
FROM dbo.MC_BillSchedule b
WHERE b.RecordStatus = 'Active'
  AND (YEAR(b.TrxStartDate) <> YEAR(b.TrxEndDate) OR MONTH(b.TrxStartDate) <> MONTH(b.TrxEndDate))
  AND DATEPART(DAY, b.TrxStartDate) = 1
GROUP BY b.DebtorID
ORDER BY CrossMonthRows DESC;
```

## ID / chứng từ test
- Ví dụ ticket (**KHÔNG patch nữa**): The Bust Specialist, unit #01-24,#01-25 (764 sqft), debtor 2104, RentalID 378; charge cũ → mới: 5495→5496, 5503→5504, 5507→5508; BillScheduleID 68621, 68513, 68567 (dòng gộp), 68622 (29/04 renewal).
- Expected: A&P 229.20 / 213.92; Service Chrg 1,298.80 / 1,212.21; Base Rent 9,932.00 / 9,269.87 (Rate 0.3 / 1.7 / 13.0).

## Chờ ai / câu hỏi mở
- Chờ Gunner chạy query phạm vi.
- Báo consultant khi có danh sách: tổng tiền tăng sau tách; dòng đã post AR bị SKIP (cần hướng xử lý riêng); dòng có thuế (nếu có).

## Bước tiếp theo
1. ~~Chạy query phạm vi~~ — xong 20/11 (Live sạch, Train 16+2 debtor).
2. Chạy script rev với `@Commit = 0` trên **Train** (kiểm debtor 2104 có trong OK không — nếu có, hỏi consultant) → xem bảng tổng hợp theo Status + danh sách chi tiết OK/SKIP/REVIEW.
3. Gửi consultant danh sách + lưu ý tổng tiền tăng → được đồng ý thì chạy `@Commit = 1` trên Train, test màn Bill Schedule, rồi Live.

## Đóng 20/11/2026
- Live sạch (0 dòng Active vắt qua tháng, toàn bộ đã Inactive do sinh lại) → không patch Live.
- Consultant không yêu cầu patch Train → đóng ticket, không chạy script. Nếu sau này cần patch Train: chạy `work/LKHS-332/LKHS-332_Split_BillSchedule_CrossMonth.sql` với `@Commit = 0` trước (bước 2–3 ở trên).
