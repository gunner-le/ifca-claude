# FPARK-166 — Debtor Ledger Report (Exclude Deposit and Advance) — ticket gốc, cloned to TIMATCH-394

## Bối cảnh

**Rental Mgmt > AR Reporting > Request to create Debtor Ledger (Exclude Deposit and Advance).**

- Client: **FPARK** (Financial Park (Labuan) Sdn. Bhd., company code **FPL**, CompanyID=181).
- Đây là ticket **GỐC** — yêu cầu ban đầu clone report Debtor Ledger chuẩn, loại Deposit/Advance (đi GL account khác), report phải tie với GL Receivable control account. Ticket **Cloned to: TIMATCH-394** (client TIMATCH) — Gunner đã làm đầy đủ vòng 1-5 fix bên TIMATCH trước (xem `TIMATCH-394-debtor-ledger-refund-fix.md` cho toàn bộ lịch sử điều tra 5 vòng đầu), sau đó clone definition view TIMATCH (đã áp fix vòng 5) sang FPARK để chuẩn bị áp dụng đúng cho ticket gốc này.

View: `[dbo].[View_Report_DebtorLedgerReport_FPARK]` — cùng cấu trúc 6 block UNION ALL với bản TIMATCH:
1. `View_RT_Ar_Trx` (billing thường, loại `ItemCode IN ('RT.Deposit','RT.DestineEarnest')`)
2. `View_MC_Receipt` (`ReceiptType='MC_Fee'` — contra receipt)
3. `AR_Trx` trực tiếp (`RefTable='AR_Trx'` — document loại reversal/CM)
4. `AR_Trx` trực tiếp khác (status khác Active/Voided/InActive)
5. `View_MC_ApJournal` (refund — đã mang fix vòng 5 của TIMATCH-394, dùng `ReceiptType` qua `AR_Allocation` thay vì `Remark`)
6. `View_MC_ApJournal_VoidRefund` (còn giữ logic `Remark` cũ — **ngoài phạm vi ticket này**, note lại để không quên)

## Vấn đề 1: Advance allocate vào Invoice không hiện trên ledger

### Case Julia nêu

Debtor **LYN FAMILY HOUSE** (DebtorAcct `FPL/RMDEBACC00000003`, DebtorID=629): report hiện Balance **RM500**, trong khi Aging/SOA show **RM0**.

Nguyên nhân: receipt `FPL/OR000665` (CBReceiptID=4253, `ReceiptType='MC_Payment'`, `DocumentAmt=1500`, `DocumentDate=12/12/2024`) đã được allocate hết, `AllocBalance=0`:
- RM500 → Invoice `FPL/INV006136` (BillID=14805, AllocID=19674, AllocDate=12/12/2024, `RefundID` NULL).
- RM1000 → Refund qua AP_Journal (AllocID=19958, `RefundID=4416`) — phần này đã hiện đúng qua block `View_MC_ApJournal` (fix vòng 5 clone từ TIMATCH-394).

Phần RM500 allocate vào Invoice KHÔNG hiện, vì receipt gốc là `MC_Payment` (bị loại ở block 2 của view, điều kiện `ReceiptType IN ('MC_Fee')`), và KHÔNG có contra receipt nào đại diện cho phần đã allocate.

Julia xác nhận yêu cầu (chat): *"DocNo = FPL/OR000665 need to show inside this report as document amount rm500, then report will tie"* — đúng phần allocate, không phải full 1500.

### Scope check ban đầu

```sql
SELECT COUNT(*) AS ReceiptsMissingContra, SUM(alloc.TotalAlloc) AS TotalAmt
FROM CB_Receipt r
CROSS APPLY (
    SELECT SUM(aa.AllocAmt) AS TotalAlloc
    FROM AR_Allocation aa
    WHERE aa.ReceiptID = r.CBReceiptID
      AND aa.BillID IS NOT NULL
      AND aa.RecordStatus <> 'InActive'
) alloc
WHERE r.ReceiptType IN ('MC_Deposit','MC_Payment')
  AND r.RecordStatus <> 'InActive'
  AND alloc.TotalAlloc IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM CB_Receipt c2
      WHERE c2.RefRecordID = r.CBReceiptID OR c2.ContraID = r.CBReceiptID
  );
```

Kết quả: **1281 receipts, tổng RM 6,108,976.75** — quy mô lớn, không phải thiếu sót cá biệt do migration.

### Vòng 1 — Fix ban đầu (SAI — gây balance nhảy 4→6 số, đã thay thế ở Vòng 2)

Thêm 1 block UNION ALL mới vào view, ngay sau block 2 (`View_MC_Receipt ... ReceiptType IN ('MC_Fee')`), lấy mọi `AR_Allocation` allocate vào Invoice (`BillID IS NOT NULL`) từ receipt Deposit/Advance (`ReceiptType IN ('MC_Deposit','MC_Payment')`) chưa có contra receipt đại diện.

Test case chính (debtor LYN FAMILY HOUSE) **PASS**: `FPL/OR000665` hiện đúng Credit 500, `TotalBalance=0.00` khớp Aging/SOA.

**Nhưng khi Julia review lại, phát hiện SAI phạm vi:** fix này chỉ nên áp dụng cho **Advance** allocate vào Invoice thường — KHÔNG áp dụng cho **Deposit** allocate vào **Deposit Billing** (hoá đơn tiền cọc). Nguyên văn Julia: *"This request only applied for advance, not deposit, deposit leave it as how u done it previously, now all deposit collection allocated to deposit billing all come out"* + báo thêm: **balance 1 số debtor nhảy từ 4 số lên 6 số**.

#### Root cause lỗi vòng 1

`ReceiptType` (`MC_Payment`/`MC_Deposit`) **không phân biệt được Advance vs Deposit** — bằng chứng: cả `FPL/OR000509` ("ADVANCE RENTAL") và `FPL/OR000665` ("RENTAL DEPOSIT") đều cùng `ReceiptType='MC_Payment'`. Nên block vòng 1 vô tình lấy luôn cả các khoản Deposit allocate vào **Deposit Billing** (Invoice có `AR_BillItem.ItemCode = 'RT.Deposit'`) — loại Invoice mà chính block 1 của view (billing thường) đã loại từ đầu (`ItemCode NOT IN ('RT.Deposit', 'RT.DestineEarnest')`). Kết quả: show Credit "mồ côi" (không có Debit tương ứng vì Debit bị loại), cộng dồn hàng loạt → balance nhảy rất lớn.

Kiểm chứng bằng data thật (group-by toàn bộ 1443 dòng mà block vòng 1 thêm vào, theo `AR_BillItem.ItemCode` của Invoice đích):

| Nhóm | Số dòng | Tổng tiền |
|---|---|---|
| `ItemCode = 'RT.Deposit'` (Deposit Billing — SAI, không được show) | ~1182 | RM 5,877,627.69 (96%) |
| Còn lại (RentalFee/MeterFee/Interest/OtherFee — ĐÚNG, cần giữ) | ~261 | RM 231,349.06 (4%) |

Riêng `RT.Deposit` có 1 dòng `DMA1-DEPOSIT MIGRATION ADJUSTMENT` chiếm tới 893 dòng/RM 4,820,170.07 — rõ ràng là dữ liệu điều chỉnh migration hàng loạt, càng khẳng định không phải nghiệp vụ Advance thật.

### Vòng 2 — Fix đã áp dụng & test PASS (2026-10-12)

Thêm join `AR_Trx`/`AR_BillItem` vào block mới, loại các allocation có Invoice đích là Deposit Billing — dùng đúng điều kiện `ItemCode` mà block 1 của view đã dùng, để đảm bảo nhất quán (không show Credit nếu Debit tương ứng vốn không được show):

```sql
-- TRƯỚC (vòng 1):
FROM    dbo.AR_Allocation aa
        INNER JOIN dbo.CB_Receipt cb ON cb.CBReceiptID = aa.ReceiptID
        INNER JOIN dbo.AR_Debtor AS W2 ON cb.DebtorID = W2.DebtorID
        INNER JOIN dbo.MC_Property AS W3 ON W2.RefProjectRecordID = W3.PropertyID
WHERE   (cb.RecordStatus NOT IN ('Voided', 'InActive'))
    AND (W2.RefProjectTable = 'MC_Property')
    AND (cb.ReceiptType IN ('MC_Deposit','MC_Payment'))
    AND aa.BillID IS NOT NULL
    AND aa.RecordStatus <> 'InActive'
    AND NOT EXISTS (
        SELECT 1 FROM dbo.CB_Receipt c2
        WHERE (c2.RefRecordID = cb.CBReceiptID OR c2.ContraID = cb.CBReceiptID)
          AND c2.ReceiptType = 'MC_Fee'
    )

-- SAU (vòng 2):
FROM    dbo.AR_Allocation aa
        INNER JOIN dbo.CB_Receipt cb ON cb.CBReceiptID = aa.ReceiptID
        INNER JOIN dbo.AR_Debtor AS W2 ON cb.DebtorID = W2.DebtorID
        INNER JOIN dbo.MC_Property AS W3 ON W2.RefProjectRecordID = W3.PropertyID
        INNER JOIN dbo.AR_Trx art ON art.BillID = aa.BillID
        INNER JOIN dbo.AR_BillItem bi ON art.BillItemID = bi.BillItemID
WHERE   (cb.RecordStatus NOT IN ('Voided', 'InActive'))
    AND (W2.RefProjectTable = 'MC_Property')
    AND (cb.ReceiptType IN ('MC_Deposit','MC_Payment'))
    AND aa.BillID IS NOT NULL
    AND aa.RecordStatus <> 'InActive'
    AND (bi.ItemCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))  --FPARK-166 (vòng 2): chỉ show Advance allocate vào Invoice thường, loại Deposit allocate vào Deposit Billing
    AND NOT EXISTS (
        SELECT 1 FROM dbo.CB_Receipt c2
        WHERE (c2.RefRecordID = cb.CBReceiptID OR c2.ContraID = cb.CBReceiptID)
          AND c2.ReceiptType = 'MC_Fee'
    )
```

(SELECT list không đổi so với vòng 1 — vẫn lấy `aa.AllocDate` làm TransactionDate/DocumentDate, `aa.AllocAmt` làm CreditAmount.)

#### Test sau khi apply fix vòng 2 trên Train — PASS

1. **Group-by lại toàn bộ sau fix** (cùng query group-by theo `ItemCode` ở vòng 1, thêm điều kiện mới): không còn dòng `RT.Deposit`/`RT.DestineEarnest` nào, tổng = **RM 231,349.06** — khớp chính xác tuyệt đối với phần "còn lại" đã tính ở vòng 1 (RentalFee, MeterFee, Interest, OtherFee).
2. **Regression debtor LYN FAMILY HOUSE (DebtorID=629)**: `TotalDebit=3000.00`, `TotalCredit=3000.00`, `TotalBalance=0.00` — không đổi so với lần test vòng 1 (case này không dính RT.Deposit nên không bị ảnh hưởng bởi fix vòng 2, đúng như kỳ vọng).

**Còn mở, chờ Julia confirm trước khi apply Live:**
- 2 dòng `OtherFee` còn mơ hồ: `FORFEIT DEPOSIT` (7 dòng, RM 66,502.17) và `TRANSFER DEPOSIT/OR` (1 dòng, RM 18,068.40) — không có `ItemCode='RT.Deposit'` nên hiện đang được show, nhưng về bản chất vẫn liên quan Deposit (forfeit/transfer). Cần Julia xác nhận show hay loại.
- Chưa verify GL Receivable control account thật (mục tiêu gốc ticket) có tie đúng không, hay chỉ khớp bề mặt Aging/SOA.
- Chưa áp dụng fix tương tự cho block `View_MC_ApJournal_VoidRefund` (ngoài phạm vi ticket này).
- Ticket clone TIMATCH-394 (case LSB) chưa chạy scope check riêng, chưa biết có dính lỗi Deposit Billing giống vòng 1 không nếu áp dụng.

## Vấn đề 2: Document Voided vẫn hiện trên ledger (double-void chain + block 1 không lọc Voided) — ĐÃ FIX & TEST PASS (2026-10-12)

### Case Julia nêu

Julia test report mới, phát hiện 3 Credit Memo (`FPL/CM000255` x2, `FPL/CM000574`) đều có `RecordStatus='Voided'` trong màn Invoice Adjustment, nhưng vẫn xuất hiện trên ledger report. Hỏi: "can amend?"

### Root cause #1 — Block 3 (`AR_Trx` trực tiếp, `RefTable='AR_Trx'`): logic "double-void" cho phép CM Voided hiện khi invoice gốc cũng Voided

Block 3 có 1 derived table `VoidInfo`, match 1 CM/reversal row (Voided, `RefTable='AR_Trx'`, trỏ `RefRecordID` về invoice gốc) với trường hợp invoice gốc ĐÓ CŨNG `RecordStatus='Voided'` độc lập — khi match, CM Voided được phép hiện (bypass filter `RecordStatus='Active'` bình thường) qua điều kiện `(T3.RecordStatus='Voided' AND VoidInfo.IBillID IS NOT NULL) OR T3.RecordStatus='Active'`.

```sql
-- TRƯỚC:
LEFT JOIN (
    SELECT Void.BillID AS VBillID, Inv.BillID AS IBillID
    FROM AR_Trx AS Void
    INNER JOIN AR_Trx AS Inv ON Void.RefRecordID = Inv.BillID AND Inv.RecordStatus = 'Voided'
    WHERE Void.RecordStatus = 'Voided' 
    AND Void.RefTable = 'AR_Trx' AND Void.RefRecordID IS NOT NULL
) AS VoidInfo ON T3.BillID = VoidInfo.VBillID OR T3.BillID = VoidInfo.IBillID AND T3.RecordStatus = 'Voided'

WHERE  (T3.RecordStatus in ('Active','Voided')) AND (ISNULL(T3.RefTable, '') = 'AR_Trx') AND (W6.RefProjectTable = 'MC_Property') AND     
(W9.ItemCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))     
AND ((T3.RecordStatus = 'Voided' AND VoidInfo.IBillID IS NOT NULL) OR T3.RecordStatus = 'Active')

-- SAU (bỏ hẳn LEFT JOIN VoidInfo, chỉ còn Active):
WHERE  (T3.RecordStatus = 'Active') AND (ISNULL(T3.RefTable, '') = 'AR_Trx') AND (W6.RefProjectTable = 'MC_Property') AND     
(W9.ItemCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))
```

**Kiểm chứng an toàn trước khi fix:** dùng audit/trace query join trực tiếp `AR_Trx` (Void JOIN Inv ON RefRecordID=BillID AND Inv.RecordStatus='Voided') để liệt kê toàn bộ cặp Void/Invoice bị ảnh hưởng — tất cả đều đối xứng tuyệt đối (`VoidAmt = -InvAmt`, cả 2 phía cùng Voided), ví dụ debtor 397 (2 cặp, business case "gộp nhiều invoice thành 1 theo yêu cầu KH", invoice gốc bị Void + thay thế bằng invoice gộp mới cùng ngày) và debtor 56 (6 cặp tương tự, các case "huỷ do sai thông số đồng hồ nước/điện" hoặc "sai module"). Vì luôn đối xứng net = 0, bỏ hẳn điều kiện double-void không ảnh hưởng số dư thực — chỉ loại bỏ noise.

Scope: **494 dòng / 287 debtor** bị ảnh hưởng bởi logic double-void ở block 3 (trước khi phát hiện thêm vấn đề #2 ở block 1).

### Root cause #2 — Block 1 (`View_RT_Ar_Trx`): không có điều kiện gì cả, cho TẤT CẢ document Voided hiện ra vô điều kiện

Trong lúc kiểm chứng fix #1, phát hiện các invoice GỐC bị Void (vd `FPL/INV002094`, `FPL/INV002310`...) vẫn hiện trên ledger dù block 3 đã fix xong — vì chúng đến từ block 1, không phải block 3. Block 1 dùng:

```sql
WHERE (T1.RecordStatus in ('Active','Voided')) AND (ISNULL(T1.RefTable, '') <> 'AR_Trx') AND (T1.ElementCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))
```

— cho `RecordStatus='Voided'` hiện **vô điều kiện**, không có logic double-void gì để giới hạn (khác hẳn block 3). Đây là bug độc lập, rộng hơn nhiều: **280 debtor / 470 dòng / RM 674,025.98** (toàn bộ là DebitAmount, không có Credit tương ứng) — và chính con số RM 674,025.98 này là phần "thiếu debit" đã quan sát thấy khi scope-check block 3 ở vòng đầu (TotalCredit 753,898.26 vs TotalDebit chỉ 79,872.28) — 2 bug cộng hưởng trên cùng 1 tập chứng từ.

```sql
-- TRƯỚC:
WHERE     (T1.RecordStatus in ('Active','Voided')) AND (ISNULL(T1.RefTable, '') <> 'AR_Trx') AND (T1.ElementCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))

-- SAU:
WHERE     (T1.RecordStatus = 'Active') AND (ISNULL(T1.RefTable, '') <> 'AR_Trx') AND (T1.ElementCode NOT IN ('RT.Deposit', 'RT.DestineEarnest'))
```

### Test sau khi apply cả 2 fix (block 1 + block 3) trên Train — PASS

1. Check đích danh toàn bộ DocumentNo đã biết là Voided (CM + invoice gốc liên quan) → **0 dòng**, không còn lọt qua view.
2. Check tổng quát (join `View_Report_DebtorLedgerReport_FPARK` với `AR_Trx.RecordStatus='Voided'` theo DocumentNo, không giới hạn danh sách cụ thể) → **0 dòng**.
3. Regression debtor 397: `TotalBalance` giảm đúng 89,737.76 so với trước fix (từ 160,676.64 → **70,938.88**) — khớp chính xác phần CM Voided/Invoice Voided đã loại.
4. Regression debtor 56: `TotalDebit=TotalCredit=652,465.16`, `TotalBalance=0.00` — về đúng cân bằng (6 cặp Void/Invoice đối xứng đã biến mất gọn, không lệch).
5. Regression 3 debtor không liên quan (17, 48, 162): `TotalBalance=0.00` không đổi — không có side-effect ngoài phạm vi.

## Vấn đề 3: Invoice/billing thường biến mất hoàn toàn khỏi ledger do contract gốc `RecordStatus='InActive'` — KHÔNG phải bug report, Julia đã confirm (2026-10-15)

### Case Julia nêu

Receipt `FPL/OR165818` ("Is Advance" checked, deposit UNIT 1A015, debtor "FAITH FAST FOOD EATER") allocate RM4.30 vào invoice `IN10006210` (Billing Item "N1-INTEREST BILLING"). Report mới chỉ hiện đúng 1 dòng Credit 4.30 (từ block Advance vòng 2), KHÔNG hiện dòng Debit của invoice Interest `IN10006210` dù Julia xác nhận `RecordStatus` Active/Approved, allocation date hợp lệ (2025).

### Điều tra

- `AR_Trx` của `IN10006210`: `RecordStatus='Active'`, `BalanceAmt=0` (đã allocate hết), nhưng `RefTable = 'GL_SubLedgerInitContra'` (khác hẳn `MC_BillSchedule` của billing thường hay `AR_Trx` của reversal/CM) — dấu hiệu chứng từ phát sinh từ GL Sub-Ledger Init/Opening Balance.
- `View_RT_Ar_Trx` (nguồn của block 1): `SELECT * FROM View_RT_Ar_Trx WHERE DocumentNo = 'IN10006210'` → **0 dòng**. Document hoàn toàn vắng mặt khỏi view gốc (không phải lỗi filter của ledger report).
- Đọc definition `View_RT_Ar_Trx`: điều kiện `RecordStatus` không loại (Active hợp lệ), nhưng có thêm `AND EXISTS(SELECT TOP 1 * FROM View_MC_GetAllDebtorInfo_2 as b WHERE b.DebtorID = a.DebtorID)`.
- `SELECT * FROM View_MC_GetAllDebtorInfo_2 WHERE DebtorID = 511` (debtor của invoice này) → **0 dòng**. Debtor 511 hoàn toàn vắng mặt khỏi view này → kéo theo MẤT TOÀN BỘ billing thường của debtor 511 khỏi `View_RT_Ar_Trx`, không riêng gì invoice Interest.
- `AR_Debtor` của DebtorID 511: `RefTable='RT_RentalContract'`, `RefRecordID=511`.
- Đọc definition `View_MC_GetAllDebtorInfo_2`: nhánh đầu tiên (rental contract) yêu cầu `RT_RentalContract.RecordStatus IN ('Contract Closed','contract verified','Contract Signed','Contract Terminated')`.
- `RT_RentalContract` (RentalID=511, unit 1A015, FPL/MK/SL/LO/23-0015): `RecordStatus = 'InActive'` — KHÔNG nằm trong danh sách status được view chấp nhận.

**Root cause xác định:** contract `RecordStatus='InActive'` không thuộc vòng đời chuẩn mà `View_MC_GetAllDebtorInfo_2`/`View_RT_Ar_Trx` (2 view nền tảng dùng chung toàn hệ thống, không riêng report này) chấp nhận → debtor bị loại hoàn toàn khỏi 2 view đó → mất billing thường trên MỌI report dựa vào `View_RT_Ar_Trx`, không riêng Debtor Ledger Report mới.

### Scope check

```sql
SELECT COUNT(DISTINCT rc.DebtorID) AS DebtorCnt
FROM RT_RentalContract rc
WHERE rc.RecordStatus = 'InActive'
  AND EXISTS (
      SELECT 1 FROM AR_Trx t 
      WHERE t.DebtorID = rc.DebtorID 
        AND t.RecordStatus NOT IN ('New','InActive','Voided')
  );
```

Kết quả: **21 debtor** có contract `RecordStatus='InActive'` nhưng vẫn còn `AR_Trx` Active/chưa Voided — cùng cảnh ngộ với case này.

### Kết luận

Đây **KHÔNG phải bug của Debtor Ledger Report** (view mới làm đúng những gì 2 view nền tảng `View_RT_Ar_Trx`/`View_MC_GetAllDebtorInfo_2` trả về) — mà là vấn đề ở dữ liệu/trạng thái contract gốc (`RT_RentalContract.RecordStatus='InActive'`), nằm ngoài phạm vi code report. Đã báo Julia kèm số liệu scope (21 debtor); **Julia đã confirm với business/data team: report đang hiển thị đúng** (2026-10-15) — không cần sửa gì thêm ở report cho vấn đề này.

**Lưu ý để dành cho sau (không thuộc phạm vi FPARK-166):** 21 debtor này có khả năng đang bị ẩn billing khỏi NHIỀU report/màn hình khác (không chỉ Debtor Ledger) vì cùng phụ thuộc `View_RT_Ar_Trx`/`View_MC_GetAllDebtorInfo_2` — nếu sau này có ticket liên quan đến 1 trong 21 debtor đó bị "thiếu dữ liệu không rõ lý do", đây là nơi cần kiểm tra trước.

## Việc còn mở trước khi đóng ticket

- Vấn đề 1 (Vòng 2 — Advance/Deposit): đang chờ Julia confirm 2 dòng OtherFee mơ hồ (FORFEIT DEPOSIT, TRANSFER DEPOSIT/OR) + review tổng thể trước khi apply Live.
- Vấn đề 2 (Voided CM/Invoice — block 1 + block 3): đã fix & test PASS đầy đủ trên Train, sẵn sàng apply Live.
- Vấn đề 3 (contract InActive ẩn billing): đã xác định root cause, Julia confirm report đúng, KHÔNG cần fix gì thêm trong phạm vi ticket này — đóng.
- Câu hỏi GL Receivable control account thật (mục tiêu gốc ticket) vẫn còn mở.
- Chưa áp dụng fix cho block `View_MC_ApJournal_VoidRefund` (ngoài phạm vi ticket này — xem TIMATCH-394).
- Ticket clone **TIMATCH-394**: có cùng cấu trúc block 1/block 3 — rất nên kiểm tra xem có dính 2 bug Voided này không (chưa làm, chưa thông báo).

## Trạng thái

- 2026-10-12: Vấn đề 1 (Vòng 2) đã áp dụng lên Train, test PASS, đang chờ Julia confirm trước khi apply Live. Vấn đề 2 (Voided CM/Invoice ở block 1 + block 3) đã fix & test PASS đầy đủ trên Train, sẵn sàng apply Live.
- 2026-10-15: Vấn đề 3 (invoice ẩn do contract InActive) — xác định root cause không phải bug report, Julia đã confirm với business, đóng mục này.

## Jira note (English — sẵn sàng paste)

**Issue 2 (Voided documents showing on ledger) — ready:**

> **Root Cause:**
> Two separate issues caused Voided documents to still appear on the new Debtor Ledger Report (`View_Report_DebtorLedgerReport_FPARK`):
> 1. The AR_Trx-sourced block (reversal/Credit Memo documents) contained a "double-void" exception that let a Voided reversal document show whenever its original target document was also independently Voided (e.g. invoices voided and replaced by a combined invoice, or voided due to meter/data correction).
> 2. The main billing block (sourced from `View_RT_Ar_Trx`) had no RecordStatus restriction at all beyond `Active`/`Voided`, so ANY Voided invoice was shown unconditionally, regardless of the above exception. This affected 280 debtors / 470 rows (RM 674,025.98) on its own.
>
> **Fix:**
> - Removed the double-void exception entirely from the AR_Trx reversal block; it now only includes `RecordStatus = 'Active'` rows.
> - Removed `'Voided'` from the RecordStatus filter on the main billing block; it now only includes `RecordStatus = 'Active'` rows.
>
> **Test Result:**
> Verified on Train: all previously-reported Voided documents (including the 3 Credit Memos originally flagged: FPL/CM000255 x2, FPL/CM000574) no longer appear on the report. A broader check confirms zero Voided documents remain across the whole view. Spot-checked debtor balances before/after the fix tie out exactly to the removed amounts, with no change to unaffected debtors (regression clean).
>
> **Status:** Fixed and tested PASS on Train. Ready to apply to Live.

**Issue 3 (Interest invoice IN10006210 not showing) — ready:**

> **Root Cause:**
> Not a report defect. The invoice's debtor has a rental contract (`RT_RentalContract`) with `RecordStatus = 'InActive'`, a status outside the lifecycle accepted by the shared system views `View_MC_GetAllDebtorInfo_2` / `View_RT_Ar_Trx` (`'Contract Closed'`, `'contract verified'`, `'Contract Signed'`, `'Contract Terminated'`). This excludes the debtor entirely from those base views, so all of that debtor's regular billing — not just this invoice — is hidden from any report built on `View_RT_Ar_Trx`, including this one. 21 debtors system-wide are in the same situation.
>
> **Status:** Confirmed with business — report is working as intended given the current contract data. No report-side fix required.

**Issue 1 (Advance/Deposit exclusion) — chưa paste, chờ Julia confirm xong mới viết bản cuối.**
