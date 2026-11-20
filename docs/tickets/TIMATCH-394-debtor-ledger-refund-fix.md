# TIMATCH-394 — Fix Summary: Loại/hiện đúng Refund trên Debtor Ledger Report (clone từ Debtor Ledger)

## Bối cảnh

View `[dbo].[View_Report_DebtorLedgerReport_TIMATCH]` là bản clone từ report Debtor Ledger gốc, yêu cầu ban đầu: **loại Deposit và Advance** ra khỏi ledger (vì đây là tiền cọc/tạm ứng, không phải công nợ thực).

View gồm 6 block `UNION ALL`, lấy dữ liệu từ nhiều nguồn: `View_RT_Ar_Trx`, `View_MC_Receipt`, `AR_Trx` (2 block), `View_MC_ApJournal`, `View_MC_ApJournal_VoidRefund`.

**Lưu ý quan hệ ticket:** TIMATCH-394 là bản **clone của ticket gốc FPARK-166** ("Rental Mgmt > AR Reporting > Request to create Debtor Ledger (Exclude Deposit and Advance)", client FPARK). Xem `FPARK-166-debtor-ledger-exclude-deposit-advance.md` cho phần điều tra/fix thực hiện bên ticket gốc (vòng 6 trở đi).

## Diễn biến qua nhiều vòng feedback (quan trọng — ghi lại để tránh lặp sai lầm)

### Vòng 1: "Can exclude refund deposit trx?"
Consultant đưa ví dụ vài doc `KSB/RF/...` (PayableType `MCPaymentRefund`) cần loại. Ban đầu **đoán sai hướng**: sửa bằng cách loại toàn bộ theo `PayableType` (`NOT IN ('MCDepositRefund','MCAdjustmentRefund','MCPaymentRefund','MCReceiptRefund')`).

Ngoài ra rà thêm 2 chỗ khác trong view (block AR_Trx) và phát hiện 3 billing item bị lọt do `ItemCode` để trống (`''` thay vì `NULL`): `ABSB DPAJ - Daily Parking Avangio/JMC (Refund)`, `LSB DEP - Deposit Adjustment`, `TBDSB DEP - Deposits Adjustment` — thêm điều kiện loại theo `ItemName` cho 3 item này.

### Vòng 2: "All Refund trx for receivable not include" (phản hồi ngược lại)
Sau khi apply vòng 1, **toàn bộ refund biến mất khỏi ledger**, kể cả các refund đã verify tiền thật — gây lệch balance (case KINDERWELT: balance nhảy sai). Xác định: **loại theo `PayableType` là sai lever** — bản chất phải loại theo **trạng thái verify của payment** (CM > Payment > Payment Verification), không phải theo loại giao dịch.

Sửa lại: bỏ điều kiện `PayableType NOT IN`, thay bằng `OR EXISTS` — cho refund hiện nếu có `AP_Allocation` + `CB_Payment` với `RecordStatus = 'Verified'` link đúng `APJournalID`.

Test lại case KINDERWELT: 8 refund xuất hiện (`KSB/RF/00000027-029` và `073-077`), nhưng balance nhảy từ -2,547.09 lên +8,340.00 — phát hiện thêm 1 vấn đề mới.

### Vòng 3: "Refund of Deposit must be excluded, Refund of receivable/collection must be show" (chốt cuối thời điểm đó)
Phát hiện: trong 8 refund trên, `073-077` có Remark "**Refund of Deposit** of Rental, Service Charge, Utilities & Non-Compliance..." — đây là hoàn tiền cọc, còn `027-029` là "transferred of payment received..." — chuyển tiền receivable giữa các unit, không phải deposit.

Kiểm tra chéo `PayableType` vs nội dung Remark chứa chữ "Deposit" trên toàn bộ data:

| PayableType | Chứa "Deposit" | Không chứa "Deposit" |
|---|---|---|
| MCDepositRefund | 239 | 0 |
| MCPaymentRefund | 163 | 3 |
| MCReceiptRefund | 7 | 92 |
| MCAdjustmentRefund | 0 | 3 |

→ **`PayableType` không phải là tiêu chí phân loại đáng tin** (MCPaymentRefund và MCReceiptRefund đều có lẫn cả 2 loại). Tiêu chí dùng khi đó: **nội dung `Remark` có chứa "Deposit" hay không** — (lưu ý: tiêu chí này sau này ở vòng 5 phát hiện vẫn còn sai sót, xem bên dưới).

## Fix vòng 1-3 (đã áp dụng tại thời điểm đó — ĐÃ ĐƯỢC THAY THẾ Ở VÒNG 5, xem bên dưới)

Trong 2 block `View_MC_ApJournal` và `View_MC_ApJournal_VoidRefund`, điều kiện `WHERE`:

```sql
WHERE     (T4.RecordStatus NOT IN ('InActive','Submitted','Active','rejected'))
      AND (T4.Remark NOT LIKE '%Deposit%')          -- loại Refund of Deposit, mọi PayableType
      AND (
            T4.PayableType NOT IN ('MCDepositRefund','MCAdjustmentRefund','MCPaymentRefund','MCReceiptRefund')
            OR EXISTS (
                SELECT 1 FROM AP_Allocation aa
                INNER JOIN CB_Payment cp ON aa.PaymentID = cp.CBPaymentID
                WHERE aa.RecordStatus = 'Verified' AND cp.RecordStatus = 'Verified'
                  AND aa.PayableID = T4.APJournalID
                  AND aa.RefTable IS NULL AND aa.RefRecordID IS NULL   -- block VoidRefund dùng: ISNULL(aa.RefTable,'')='CB_Payment' AND aa.RefRecordID IS NOT NULL
            )
          ) --TIMATCH-394
```

Ngoài ra vẫn giữ 2 fix nhỏ từ vòng 1 ở block `AR_Trx`: loại thêm theo `ItemName` cho `ABSB DPAJ - ... (Refund)`, `LSB DEP - Deposit Adjustment`, `TBDSB DEP - Deposits Adjustment` (do `ItemCode` để trống, không match `RT.Deposit`). **Phần này không đổi, vẫn giữ nguyên qua các vòng sau.**

## Kết quả xác nhận (vòng 1-3, tại thời điểm đó)

Test debtor KINDERWELT SDN BHD (1001-P01_K-1-4/003):
- `KSB/RF/00000073-077` ("Refund of Deposit...") → đã loại đúng.
- `KSB/RF/00000027-029` ("transferred of payment received...") → vẫn hiển thị đúng.
- `TotalDebit = TotalCredit = 7,587.09` → `TotalBalance = 0.00` — ledger tie chính xác.

---

## Vòng 4 (2026-09-23) — Feedback bổ sung: "Advance allocated to Invoice phải hiện lại trên ledger"

### Yêu cầu mới từ consultant

Report vốn tie với GL Receivable control account, phải loại Deposit/Advance vì đi GL account khác. Nhưng khi 1 Advance được allocate sang Invoice thường, phần đã allocate đó **charge back vào đúng GL Receivable control account** mà report tie tới → report phải hiện lại phần này, chỉ đúng phần allocate-to-invoice (không phải toàn bộ Advance, không bao gồm phần allocate-to-refund).

Ví dụ minh hoạ: Advance RM1,000, allocate RM800 sang Invoice + RM200 sang Refund → ledger chỉ nên hiện RM800.

### Điều tra bằng data thật (client TIMATCH, hợp đồng RT_RentalContract=3597, debtor STUDIO ACE PRODUCTIONS SDN BHD)

Test thật (Gunner thao tác offset Deposit→Invoice trên UI, tạo 2 bản ghi mới `KSB/OR/00011069`, `KSB/OR/00011070`) cho thấy cơ chế allocate hiện tại:

1. **Deposit/Advance gốc thu vào**: nằm trong `View_MC_Receipt` với `ReceiptType = 'MC_Payment'`/`'MC_Deposit'` (VD: `KSB/OR/00004493` DEPOSIT-RENTAL RM5,850) — **không khớp** filter `T2.ReceiptType IN ('MC_Fee')` ở block 2 của view → tự động bị loại, đúng ý muốn ban đầu.
2. **Khi Deposit được offset/allocate sang Invoice** (qua màn hình Advance/Deposit của Rental module): hệ thống sinh 1 bản ghi contra riêng trong `View_MC_Receipt` với **`ReceiptType = 'MC_Fee'`** (VD: `KSB/OR/00011069`, Remark "Being offset the rental deposit (RM5,850.00) against the Invoice No. KSB/IV/00010095 (RM1,000.00)", `DocumentAmt = 1000` — đúng bằng phần allocate, không phải RM5,850 toàn bộ) — bản ghi này **đã tự động lọt vào report ngay** (do block 2 include `ReceiptType='MC_Fee'` không điều kiện gì thêm) và **hiện đúng số tiền allocate** (Credit 1,000 và 80, khớp đúng invoice `KSB/IV/00010095` và `KSB/IV/00009739` tie về 0).
3. **Refund của Deposit/Advance**: không tìm thấy `ReceiptType` riêng nào cho Refund bên `View_MC_Receipt`. Refund Deposit/Advance đi qua đường `View_MC_ApJournal`/`View_MC_ApJournal_VoidRefund` (xem vòng 1-5).

### Kết luận vòng 4

Cơ chế "hiện phần allocate-to-invoice" của Advance/Deposit (bên Receipt, block 2) đã đúng sẵn **khi allocate đi qua thao tác Offset chuẩn trên UI** (tạo contra receipt), không cần sửa gì ở block này cho trường hợp đó. Phần phân loại Refund (block 4/5) sau đó được phát hiện còn sai ở vòng 5 — xem bên dưới. Tuy nhiên vòng 6 phát hiện: khi allocate KHÔNG đi qua Offset chuẩn (không tạo contra), cơ chế này không còn đúng — xem vòng 6.

---

## Vòng 5 (2026-10-06) — Julia phát hiện case thật: ledger lệch RM545 vì 1 nhóm refund bị loại SAI do tiêu chí Remark không đáng tin

### Vấn đề Julia nêu

Julia hỏi lại cơ chế "link dựa vào gì" của phần loại refund, và đưa 1 case thật (client LSB trong TIMATCH): debtor có Aging/SOA = 0 (đúng), nhưng Debtor Ledger Report hiện RM545 balance lệch, tất cả đến từ 4 document refund `LSB/RF/00000006-009`.

### Điều tra bằng data thật

- 4 document `LSB/RF/00000006-009` (`PayableType = MCReceiptRefund`) có Remark: **"Refund of Deposit of excess payment for rental for Lot: TB4241..."** → chứa chữ "Deposit" nên bị điều kiện `Remark NOT LIKE '%Deposit%'` loại.
- Nhưng trace qua `AR_Allocation.RefundID = AP_Journal.APJournalID` → `AR_Allocation.ReceiptID` → `CB_Receipt`: receipt gốc có `ReceiptType = 'MC_Fee'`, Remark **"Payment for Rental - ..."** — đây là tiền thuê thu dư (excess payment), **không phải deposit thật**. Chữ "Deposit" trong Remark của refund chỉ là cách hành văn quen miệng của người nhập liệu ("refund of the deposit/payment of excess amount"), không phản ánh đúng bản chất.
- Tổng `AllocAmt` của 4 dòng `AR_Allocation` = 165+165+165+50 = **545** — khớp chính xác RM545 Julia báo. Xác nhận đây chính là nguyên nhân.

### Kiểm chứng trên toàn bộ data TIMATCH (tránh lặp sai lầm "chỉ xem vài ví dụ" của vòng 1)

Cross-check `Remark LIKE '%Deposit%'` (4 PayableType refund) vs `ReceiptType` của receipt gốc (qua `AR_Allocation.RefundID` → `ReceiptID` → `CB_Receipt`):

| Nhóm theo Remark hiện tại | ReceiptType gốc | Số lượng |
|---|---|---|
| Remark CÓ "Deposit" (đang bị loại) | MC_Deposit | 302 |
| Remark CÓ "Deposit" (đang bị loại) | MC_Payment | 163 |
| Remark CÓ "Deposit" (đang bị loại) | **MC_Fee** | **7** ← bug: refund receivable thật nhưng bị loại sai (gồm case LSB của Julia) |
| Remark KHÔNG có "Deposit" (đang hiện) | MC_Fee | 124 |
| Remark KHÔNG có "Deposit" (đang hiện) | **MC_Payment** | **1** ← bug ngược: refund deposit thật nhưng đang hiện sai |

100% các `AP_Journal` thuộc 4 `PayableType` refund đều trace được qua `AR_Allocation.RefundID` (0 dòng thiếu link) — `ReceiptType` là tiêu chí có cấu trúc, phủ đủ toàn bộ data, đáng tin hơn hẳn so với text tự do `Remark`.

Đã soi chi tiết cả 8 case lệch:
- 7 case `MC_Fee` bị loại sai: đều là "Refund of Deposit of excess payment for rental..." ở nhiều company khác nhau (KSB, ABSB, LSB) nhưng receipt gốc đều là "Payment for Rental/Season Parking..." — xác nhận đều là refund receivable thật.
- 1 case `MC_Payment` hiện sai: `ABSB/RF/00000035` ("Refund for Perdana Park Unit 3A", Remark không nhắc Deposit) nhưng receipt gốc là "**Opening Balance for Rental Charges Deposit**" — xác nhận đúng là refund deposit thật, đang hiện sai.

Đã test lại regression với case KINDERWELT (đã confirm đúng ở vòng 3) bằng tiêu chí mới — khớp hoàn toàn, không gây sai lệch:
- `KSB/RF/00000027-029` (phải hiện) → `ReceiptType = MC_Fee` ✓.
- `KSB/RF/00000073-077` (phải loại) → `ReceiptType = MC_Payment`, receipt gốc đều là "...Charges Deposit" ✓.

Đã kiểm tra thêm: `Remark LIKE '%Deposit%'` còn ảnh hưởng tới các `PayableType` KHÁC ngoài 4 loại refund (`CBOtherPayment` 121, `Invoice` 27, `Adjustment` 21, `Deposit` 1 — tổng 170 dòng) — những dòng này hiện chỉ bị loại nhờ đúng điều kiện Remark này (do pass qua nhánh `PayableType NOT IN (...)` không cần check EXISTS). **Chưa kiểm chứng gì về các PayableType này, ngoài phạm vi ticket** — nên fix phải tách riêng, không đụng tới phần Remark áp dụng cho các PayableType này.

### Fix đề xuất (đã đưa Gunner, ĐÃ APPLY & CONFIRM — xem Trạng thái)

Thay tiêu chí "Remark có chữ Deposit" bằng "ReceiptType của receipt gốc qua AR_Allocation", chỉ áp dụng cho đúng 4 PayableType refund; giữ nguyên 100% hành vi Remark cho các PayableType khác.

```sql
-- TRƯỚC (block View_MC_ApJournal):
WHERE     (T4.RecordStatus NOT IN ('InActive','Submitted','Active','rejected'))
      AND (T4.Remark NOT LIKE '%Deposit%')
      AND (
            T4.PayableType NOT IN ('MCDepositRefund','MCAdjustmentRefund','MCPaymentRefund','MCReceiptRefund')
            OR EXISTS (
                SELECT 1 FROM AP_Allocation aa
                INNER JOIN CB_Payment cp ON aa.PaymentID = cp.CBPaymentID
                WHERE aa.RecordStatus = 'Verified' AND cp.RecordStatus = 'Verified'
                  AND aa.PayableID = T4.APJournalID
                  AND aa.RefTable IS NULL AND aa.RefRecordID IS NULL
            )
          ) --TIMATCH-394

-- SAU:
WHERE     (T4.RecordStatus NOT IN ('InActive','Submitted','Active','rejected'))
      AND (
            (
              T4.PayableType NOT IN ('MCDepositRefund','MCAdjustmentRefund','MCPaymentRefund','MCReceiptRefund')
              AND T4.Remark NOT LIKE '%Deposit%'
            )
            OR
            (
              T4.PayableType IN ('MCDepositRefund','MCAdjustmentRefund','MCPaymentRefund','MCReceiptRefund')
              AND EXISTS (
                  SELECT 1
                  FROM AR_Allocation aa
                  INNER JOIN CB_Receipt cb ON cb.CBReceiptID = aa.ReceiptID
                  WHERE aa.RefundID = T4.APJournalID
                    AND cb.ReceiptType = 'MC_Fee'
              )
            )
          ) --TIMATCH-394 (vòng 5: refund dùng ReceiptType của receipt gốc qua AR_Allocation thay vì Remark)
```

Block `View_MC_ApJournal_VoidRefund`: áp dụng pattern tương tự (thay `AP_Allocation`/`CB_Payment` bằng `AR_Allocation`/`CB_Receipt` y hệt). **Chưa có data thật để test riêng block này** (nhánh cho refund đã Void/Reverse) — cần test riêng trước khi apply, chưa chắc `AR_Allocation.RefundID` còn giữ nguyên quan hệ sau khi refund bị void. **Vẫn CHƯA làm tới thời điểm hiện tại (2026-10-09)** — xác nhận qua definition view `_FPARK` đọc được: block này vẫn còn logic `Remark` cũ.

**Trạng thái:** Đã apply lên view thật, Julia xác nhận "Its showing now" (case RM545 đã hiện đúng). Xác nhận đây là report/script amendment (sửa view), không phải data fix.

## Bài học rút ra

Với các view dùng cờ/loại enum (`PayableType`, `ItemCode`...) để phân loại nghiệp vụ, **không nên giả định 1 enum = 1 bản chất nghiệp vụ duy nhất** — cùng 1 `PayableType` có thể chứa lẫn nhiều bản chất khác nhau (ở đây: cùng là "Payment Refund" nhưng vừa có deposit vừa có receivable). Khi cần phân loại chính xác theo bản chất nghiệp vụ, nên kiểm chứng bằng cách đối chiếu chéo enum với nội dung text mô tả (Remark/Description) trên toàn bộ data trước khi chốt điều kiện lọc, thay vì suy luận từ vài ví dụ mẫu.

Ở vòng 4, bài học thêm: trước khi kết luận "report thiếu logic", nên **tạo/tìm 1 case thật rồi chạy thẳng qua view** để xem hành vi hiện tại là gì — nhiều khi 1 yêu cầu tưởng là "feature mới cần code" hoá ra đã được đáp ứng sẵn bởi thiết kế data có từ trước, tránh code thêm 1 lớp lọc trùng lặp hoặc sai. Nhưng (xem vòng 6) kết luận này chỉ đúng cho đúng case đã test — không nên suy rộng ra "mọi case tương tự đều ổn" khi chưa chạy scope check trên toàn bộ data.

Ở vòng 5, bài học quan trọng nhất: **`Remark` là free-text do người dùng gõ tay, KHÔNG đáng tin để làm tiêu chí phân loại bản chất nghiệp vụ**, kể cả khi đã cross-check và có vẻ khớp ở 1 thời điểm (như vòng 3 từng làm) — luôn ưu tiên tìm 1 trường dữ liệu có cấu trúc (ở đây là `ReceiptType` của receipt gốc, trace qua `AR_Allocation.RefundID`) thay vì suy luận từ câu chữ mô tả. Khi đổi tiêu chí lọc trong 1 view dùng chung nhiều `PayableType`/nhiều mục đích, phải tách riêng phạm vi thay đổi (chỉ áp dụng đúng nhóm liên quan), tránh đụng chạm tới các nhánh khác chưa được kiểm chứng.

---

## Vòng 6 (2026-10-08 ~ 10-09) — Case LSB: Advance/Deposit allocate hết vào Invoice (không có phần refund) nhưng KHÔNG hiện trên ledger

Julia hỏi tiếp: 2 document Opening Balance `LSB/OR/00000015` (RM6,000) và `LSB/OR/00000027` (RM3,000) là Advance đã allocate HẾT vào các Invoice thật (7 invoice tổng đúng 6,000; 3 invoice tổng đúng 3,000 qua `AR_Allocation`, không có `RefundID` nào — tức không có phần refund), nhưng KHÔNG hiện trong ledger.

Khác với vòng 4 (STUDIO ACE): ở đó allocate qua thao tác Offset trên UI nên hệ thống tự sinh contra receipt (`ReceiptType='MC_Fee'`) đại diện đúng phần allocate — nên hiện đúng. Ở đây (2 document LSB), kiểm tra không thấy bất kỳ contra receipt nào trỏ về chúng (`CB_Receipt.RefRecordID`/`ContraID` = CBReceiptID của 2 document này) → xác nhận: phần allocate-vào-Invoice của 2 Advance này **không đi qua cơ chế Offset chuẩn** nên không tạo contra, nên ledger coi như "chưa thanh toán" dù `AR_Allocation` + Aging/SOA đã coi là đã clear.

2 document này có `ReferenceNo` dạng `OB 31.12.2024` — nghi ngờ ban đầu là dữ liệu migrate (Opening Balance) thiếu bước replay contra receipt. Đã chuẩn bị query scope check cho TIMATCH nhưng **CHƯA chạy xong** (rẽ sang kiểm tra case tương tự Gunner phát hiện ở FPARK trước — xem bên dưới). **Cần quay lại chạy scope check này cho TIMATCH** khi có thời gian, để biết phạm vi thật của vấn đề (ít / nhiều) trước khi quyết định hướng fix (data-patch từng case vs sửa view).

### Liên hệ ticket gốc FPARK-166

TIMATCH-394 **là bản clone của ticket gốc FPARK-166** ("Rental Mgmt > AR Reporting > Request to create Debtor Ledger (Exclude Deposit and Advance)", client FPARK). Gunner đã clone view TIMATCH (sau khi áp dụng fix vòng 5) sang FPARK để chuẩn bị fix tương tự cho ticket gốc.

Khi kiểm tra 1 case thật bên FPARK (debtor LYN FAMILY HOUSE, company FPL — Financial Park Labuan): phát hiện ĐÚNG pattern giống hệt 2 document LSB trên (`FPL/OR000665`, Advance 1500, allocate 500 vào Invoice `FPL/INV006136` + 1000 refund qua AP_Journal, KHÔNG có contra receipt cho phần 500). Nhưng khi chạy scope check đầy đủ ở FPARK thì phát hiện **quy mô rất lớn: 1281 receipts / RM 6,108,976.75** — lớn hơn hẳn số case rải rác đã thấy ở TIMATCH, cho thấy ở FPARK đây không phải lỗi migration cá biệt mà có thể là cách vận hành phổ biến (allocate Deposit/Advance vào Invoice không qua thao tác Offset chuẩn).

Toàn bộ phần điều tra + fix cho case FPARK được ghi chi tiết ở **`FPARK-166-debtor-ledger-exclude-deposit-advance.md`** (ticket gốc). Cùng 1 hướng fix (thêm 1 block UNION ALL lấy trực tiếp từ `AR_Allocation` cho các receipt Deposit/Advance chưa có contra) nhiều khả năng cũng áp dụng được cho TIMATCH (để xử lý luôn 2 case LSB và scope rộng hơn nếu có) — NHƯNG CHƯA chạy scope check riêng cho TIMATCH để xác nhận, nên chưa áp dụng bên TIMATCH. Việc này để ngỏ, làm sau khi fix FPARK-166 xong và có thời gian.

**Trạng thái:** Case LSB (TIMATCH) xác nhận cùng root cause với FPARK-166 nhưng CHƯA fix/CHƯA chạy scope check riêng cho TIMATCH. Xem tiến độ fix tại `FPARK-166-debtor-ledger-exclude-deposit-advance.md`.

---

## Vòng 7 (2026-11-19) — Julia: report mới phải giữ y bản chuẩn cho chứng từ Voided (ĐANG DỞ — tạm dừng 2026-11-20)

### Thông tin report (đã tra `Sys_Report` trên DB local `TIMATCH_LIVE`)
| | Report mới | Report chuẩn |
|---|---|---|
| ReportNo | `401_TIMATCH` | `401` (Rental), thêm `66`/`532` (MCorp) |
| ReportNameStringCode | `Rpt_Mcorp_DebtorLedgerReport_TIMATCH` | `Rpt_Mcorp_DebtorLedgerReport` |
| ReportFileName | `MC_DebtorInforTotalTwo_TIMATCH` (trên SSRS, không có .rdl trong source) | `MC_DebtorInforTotalTwo` |
| ReadTable | `View_Report_DebtorLedgerReport_TIMATCH` | `view_Report_DebtorLedgerReport` |

### Feedback Julia
Cặp `KSB/IV/00002159` (BillID 10343/10344, Voided, từ `MC_BillSchedule`, 2,135) ↔ `KSB/CN/00000408` (BillID 29291/29292, Voided, auto reversal, `RefTable='AR_Trx'`) hiện trên Debtor Ledger chuẩn nhưng không hiện trên report mới. Ý Julia: report mới lấy script chuẩn, chỉ được sửa 3 chỗ (loại Deposit, loại Advance→Refund, hiện Advance→Invoice), phần còn lại giữ như chuẩn.

### Đã CHỐT (có data)
- View TIMATCH trên server (`TIMATCH_LIVE`, modify_date **2026-10-15 21:16**) đã mang fix Voided của FPARK-166: block 1 `RecordStatus = 'Active'`, block 3 comment bỏ `LEFT JOIN VoidInfo` → lệch bản chuẩn, ẩn cặp IV/CN trên.
- Bản server cũng có block Advance→Invoice (`AR_Allocation`, loại `RT.Deposit`/`RT.DestineEarnest`) — đúng yêu cầu, giữ nguyên.
- **Julia chọn A = theo bản chuẩn** (hiện cặp Voided auto reversal). Đã báo Julia: điều này đảo lại yêu cầu cũ FPARK-166 vấn đề (2) (CM Voided `FPL/CM000255` x2, `FPL/CM000574` sẽ hiện lại ở FPARK). Balance không đổi (cặp Voided net 0).
- Gunner đã kéo view server về local rồi áp **revert 2 chỗ** trên DB local `TIMATCH_LIVE` (block 1 về `RecordStatus in ('Active','Voided')`; block 3 khôi phục `LEFT JOIN VoidInfo` + `AND ((T3.RecordStatus = 'Voided' AND VoidInfo.IBillID IS NOT NULL) OR T3.RecordStatus = 'Active')`, comment `-- TIMATCH-394`, dòng cũ giữ dạng comment). Chép đúng từng chữ từ view chuẩn.
- Test local: cặp IV/CN hiện đủ 4 dòng như chuẩn → PASS.

### Lỗi mới phát hiện — có sẵn trong CẢ view chuẩn
- Chuỗi void nhiều tầng IV Voided → CN Voided → DN Voided: `LEFT JOIN VoidInfo ON T3.BillID = VBillID OR T3.BillID = IBillID ...` khớp 2 lần → CN in 2 lần.
- Case: debtor 4433 NBIOTEK (M) SDN BHD, `KSB/IV/00004120` → `KSB/CN/00000130` → `KSB/DN/00000039/40`; CN/130 ra 4 dòng (440) thay vì 2 → lệch **RM220**. View chuẩn ra y hệt.
- Quy mô DB local: 2 BillID / 1 debtor / 220 (server có thể nhiều hơn).
- **Xác nhận bằng data + GL (2026-11-20, DB clone Live mới trên server):** chuỗi IV 17950/17951 → CN 19104/19105 (RefRecordID → IV) → DN 19798/19799 (RefRecordID → CN), cả 6 Voided. `GL_Voucher` (RefTable='AR_Trx') tài khoản Receivable `AccountCodeID 7906`: IV Dr 220, CN Cr 220, DN Dr 220 → **GL net +220**. Report hiện tại (CN x2) ra 0 → lệch GL 220; fix `EXISTS` ra +220 = khớp GL. Aging bỏ Voided → 0 → chuỗi void-của-void này làm Aging ≠ GL thật 220 (chế độ filter Active khớp Aging, All khớp GL).
- Kiểm chứng fix: block 3 logic cũ 954 dòng/952 BillID/−587,738.40 → logic `EXISTS` 952/952/−587,518.40 — không mất/thêm chứng từ, chỉ bỏ đúng 2 dòng nhân đôi.
- Lưu ý test: query tổng Voided phải lọc theo `BillID`, không theo `DocumentNo` (lọc DocumentNo kéo nhầm dòng Active của invoice nhiều dòng → 2 case +170 giả ở debtor 4552, 4532).
- Fix đề xuất (CHƯA áp, chờ Julia): bỏ `LEFT JOIN VoidInfo` (comment lại), thay điều kiện cuối block 3 bằng
  `AND (T3.RecordStatus = 'Active' OR (T3.RecordStatus = 'Voided' AND (EXISTS (SELECT 1 FROM dbo.AR_Trx Inv WHERE Inv.BillID = T3.RefRecordID AND Inv.RecordStatus = 'Voided') OR EXISTS (SELECT 1 FROM dbo.AR_Trx Rev WHERE Rev.RefRecordID = T3.BillID AND Rev.RefTable = 'AR_Trx' AND Rev.RecordStatus = 'Voided'))))  -- TIMATCH-394`
  Bản find→replace đầy đủ nằm trong lịch sử phiên `59c5aab6-d224-4e1e-b785-808446f64050` (19/11).

### File làm việc (`work\TIMATCH-394\`)
`view_Standard.sql` (view chuẩn), `view_TIMATCH_current.sql` (local trước 19/11, bản 06/10), `view_TIMATCH_server_20261015.sql` (đầu bản server), `view_TIMATCH_local_now.sql` (local sau khi kéo bản server về), `view_TIMATCH_local_after.sql` (local sau revert).

TFS Live: chưa so `View_Report_DebtorLedgerReport_TIMATCH` / `view_Report_DebtorLedgerReport` với TFS (chỉ so với view chuẩn trong DB).

### Việc còn mở / bước tiếp theo
1. ~~Áp revert 2 chỗ lên server~~ — ĐÃ ÁP (Gunner xác nhận 2026-11-20), đang chạy Live Testing. Gunner đã clone DB Live mới nhất (20/11) về máy để fix/test vòng 8.
1e. **Vòng 8 (fix EXISTS + filter Record Status) đã tách sang Jira mới TIMATCH-443** (Julia tạo theo đề nghị Gunner, 2026-11-20). Changeset/note Jira của 2 phần này ghi theo TIMATCH-443 (comment JiraID trong view/script hiện đang ghi `TIMATCH-394` — khi áp Train/Live đổi thành `TIMATCH-443`).
1d. **Trạng thái 2026-11-20: Gunner đã áp lên Live Testing** (view: A + B dạng CASE; config `work\TIMATCH-394\Config_401_TIMATCH_RecordStatus.sql` — Sys_ReportFilter `401_TIMATCH`/`RecordStatus` L, RelationFld=RecordStatus theo mẫu DebtorAcct + CF_String "Record Status") → **chờ Julia test UI**. Julia OK → áp Train/Live theo danh sách đoạn thay đổi (không chạy nguyên file), viết note Jira, hỏi Stanley sửa view chuẩn. Báo Julia: NBIOTEK GL còn nợ 220 mà Aging = 0 (data void-chồng-void).
1c. Vòng 8 test trên DB clone (2026-11-20): fix `EXISTS` (A) đã áp → chuỗi NBIOTEK IV +220 (2 dòng) / CN −220 (2 dòng) / DN/39, DN/40 +110 mỗi cái → PASS. Đã thêm cột `RecordStatus` (B) vào 7 block; view trả ra 4 giá trị: Active 30,443 dòng (AR_Trx), Verified 17,850 (Receipt), Approved 132 (AP Journal refund), Voided 1,037 (net +120) → filter không thể lọc thẳng `='Active'` (mất Receipt/Refund) → gom thành Active/Voided bằng CASE.
1b. Vòng 8 (2026-11-20) Julia phản hồi: (a) `KSB/CN/00000130` hiện 4 dòng = đúng case NBIOTEK RM220 → áp fix `EXISTS`; (b) xin thêm filter `RecordStatus` (Active → khớp Aging; All → khớp GL), lý do: IV Voided ngày 2027 còn CN reversal ngày 2026 → ledger lệch Aging. Cần: thêm cột `RecordStatus` vào 6 block view + 1 dòng `Sys_ReportFilter` (`401_TIMATCH`) + sửa RDL `MC_DebtorInforTotalTwo_TIMATCH` (lấy từ SSRS).
2. Gửi Julia tin case NBIOTEK (RM220), chờ Julia chọn: sửa trong report mới (áp bản `EXISTS`) hay giữ như chuẩn.
3. Hỏi Stanley có sửa view chuẩn `view_Report_DebtorLedgerReport` trên TFS không (bug sản phẩm).
4. FPARK-166: revert tương tự theo lựa chọn A (chưa làm, làm sau TIMATCH).
5. Các việc mở cũ: vòng 6 scope check TIMATCH (Advance thiếu contra — bản server 15/10 đã có block Advance, cần xác nhận lại case LSB `LSB/OR/00000015`, `00000027`), block `View_MC_ApJournal_VoidRefund` còn logic `Remark` cũ.
6. Chờ Gunner note phản hồi mới của Julia (2026-11-20).
