# LKHS-336 — CSM (PM) Debtor Aging Detail by Doc Date không hiện receipt

- **Client:** LKHS (Singapore, sửa thẳng Standard). Test trên LKHS Train, CompanyID 182, debtor `TEST-001`.
- **Menu:** CSM (module PM — Construction) > Reporting > Debtor Aging Detail by Doc Date.
- **Trạng thái (19/11/2026):** Root cause đã xác nhận, fix config đã áp + test PASS trên LKHS Train. Chờ consultant phản hồi, sau đó áp Live.
- Tài liệu consultant: `CSM Aging Reports.xlsx` (tab by doc date / by trx date — chỉ ảnh chụp report). Bản copy SP + Excel ở `work\LKHS-336\` (không commit).

## Bối cảnh

Receipt `LKHS/CM/COR/27-0009` (CBReceiptID 90375, `PM_Receipt`, 2,000, DocDate = TrxDate = 02/10/2026, AllocBalance 820) knock 1,090 vào `LKHS/CM/CIV/27-0006` (BillID 496470, 01/10) và 90 vào `LKHS/CM/CIV/27-0007` (BillID 496471, 05/10).

| Report (As At 19/11/2026) | Kết quả |
|---|---|
| Aging Detail by **Trx Date** (EN291) | CIV-0007 1,000 + receipt Unallocated −820 → Owing 180 (đúng) |
| Aging Detail by **Doc Date** (EN275) | Chỉ CIV-0007 1,000, **mất receipt** → Owing 1,000 (sai) |
| Aging Summary by Doc Date | 1,000 / (820) / 180 (đúng) |

## Report → object

| ReportNo | ReportFileName | ReadTable | SP |
|---|---|---|---|
| EN275 | `PM_DebtorAgingDetailByDocDate` | `VIEW_PM_DebtorAgingDetailByDocDate` | `exec PMDebtorAgingDetail @CompanyID, @Language, 'DocumentDate', @QueryCriteria` |
| EN291 | `PM_DebtorAgingDetailByTrxDate` | | cùng SP, tham số `'TransactionDate'` |

(Còn bản cũ không tiền tố `275`/`291`/`303` và EN303 by Contract, EN361 by Due Date.)

## Root cause (đã xác nhận: code + data + test)

1. SP `PMDebtorAgingDetail` lấy As At bằng `CHARINDEX(@DetailType + '<=', @QueryCriteria)` → cắt ra `@Temp`. Không tìm thấy → `@Temp = ''`, `@AsAtDate = GETDATE()`.
2. Các điều kiện so với `@Temp` (`rec.DocumentDate <= '' + @Temp + ''`, dòng ~154/158/174/187) thành `<= ''` (= 1900-01-01) → receipt bị loại khỏi `#Temp2` (không có dòng Unallocated). Cột Aging của invoice lại dùng `@AsAtDate` nên invoice vẫn hiện → kết quả trông hợp lý, chỉ thiếu receipt.
3. Config `Sys_ReportFilter` EN275 (Standard, tạo 2010):
   - `DocumentDate` (label "Doc"): `FldRange = 0`, `IsAsAtDate = Y`, `FldNeed = N` → sinh `DOCUMENTDATE='2026/11/19'` (dấu **=**) → SP không parse được, và WHERE cuối lọc đúng 1 ngày → report **trống**.
   - `TransactionDate`: `FldRange = 3` (From–To), Active → consultant điền ô này → criteria `TRANSACTIONDATE>=... AND TRANSACTIONDATE<=...` → SP (tham số `'DocumentDate'`) không có As At → mất receipt (case của ticket).
   - EN291 config đúng: `TransactionDate` `FldRange = 2`, `IsAsAtDate = Y` (sinh `<=`), `DocumentDate` Inactive.
4. SP không lỗi. Bug là config Standard → client khác có module PM cũng giống (Gunner thấy TIMATCH cùng config; chưa so SP TIMATCH).

## Fix (Sys_ReportFilter EN275 — theo mẫu EN291)

Trạng thái trước (Train): `7970 DocumentDate N/0/Y/Active`, `7971 TransactionDate N/3/N/Active`.

```sql
SELECT ReportFilterID, ReportNo, FldName, FldNeed, FldRange, IsAsAtDate, RecordStatus
FROM Sys_ReportFilter
WHERE ReportNo = 'EN275' AND FldName IN ('DocumentDate', 'TransactionDate');

-- LKHS-336: EN275 Doc Date As At must generate "DocumentDate<=" (same as EN291 As At), and be mandatory
UPDATE Sys_ReportFilter
SET FldRange = 2,      -- was 0
    FldNeed = 'Y',     -- was 'N'
    ModifyDate = GETDATE()
WHERE ReportNo = 'EN275' AND FldName = 'DocumentDate' AND RecordStatus = 'Active';

-- LKHS-336: hide TransactionDate range filter on Doc Date aging (EN291 likewise inactivates its DocumentDate)
UPDATE Sys_ReportFilter
SET RecordStatus = 'Inactive',   -- was 'Active'
    ModifyDate = GETDATE()
WHERE ReportNo = 'EN275' AND FldName = 'TransactionDate';
```

WHERE theo `ReportNo + FldName` (không dùng ReportFilterID vì có thể khác Train/Live). Không đổi SP.

## Test (LKHS Train, TEST-001)

- Doc = 19/11/2026 → CRITERIA `DOCUMENTDATE<='2026/11/19'`; CIV-0007 Aging 31–60 1,000; receipt COR/27-0009 Unallocated −820; Owing 180 — khớp by Trx Date. **PASS**.
- Gunner xác nhận các case còn lại OK (Doc = 01/10/2026; màn filter mất ô TransactionDate, Doc bắt buộc).

## Còn mở / rủi ro

- Áp Live LKHS (SELECT kiểm tra trước) sau khi consultant OK.
- Bug Standard: hỏi Stanley có đưa fix vào Update Script cho mọi client không (TIMATCH cùng config). Nếu SP client khác khác bản LKHS thì cần so trước.
- Label "Doc" (`CF_String` `Sys.ReportFilter_EN275_DocumentDate`) khó hiểu — có thể đổi thành "As At (Doc Date)" (chưa làm).
- Ngoài phạm vi: Aging **Summary by Trx Date** ra Owing 1,820 (lẽ ra 180 — RDL trừ Unallocated âm) → đã xử lý ở LKHS-337; EN361 có 5 dòng filter `TransactionDate` trùng.

## Bài học

- Report thiếu/sai record: đọc **dòng CRITERIA đỏ** cuối report trước — nó cho biết chính xác chuỗi `@QueryCriteria` SP nhận. Ở đây chỉ cần so CRITERIA 2 report là ra lệch field ngày.
- SP aging kiểu PM/MC parse As At bằng chuỗi `<Fld><=`: ô As At phải có `FldRange = 2`. `FldRange = 0` trên field Date sinh `=`.
- 2 report dùng chung 1 SP mà 1 bản đúng 1 bản sai → so `Sys_ReportFilter` 2 ReportNo trước khi soi SP.

## Jira note

**[Tech]** Root Cause: EN275 (PM Debtor Aging Detail by Doc Date) and EN291 (by Trx Date) use the same SP `PMDebtorAgingDetail`, which reads the As At date from the criteria string `DocumentDate<=`. In the standard `Sys_ReportFilter` setup, EN275's "Doc" As At filter has FldRange=0, which builds `DocumentDate='...'`, and a TransactionDate range filter is also active. Either way the SP gets no As At date, so receipts are filtered out (invoices still show). EN291 is set up correctly (As At FldRange=2, other date filter inactive). Fix: updated `Sys_ReportFilter` for EN275: DocumentDate FldRange 0→2 and mandatory, TransactionDate filter set to Inactive. No SP change. Status: tested OK in LKHS Train (TEST-001, As At 19/11/2026: receipt LKHS/CM/COR/27-0009 shows Unallocated -820, Owing 180, matching the Trx Date report), pending consultant confirmation and Live.

**[Non-tech]** Root Cause: The date filter on the Debtor Aging Detail by Doc Date report was set up wrongly, so the report could not read the "As At" date and left out receipts. Fix: We corrected the report filter. The screen now has one mandatory "Doc" As At date, and the Transaction Date range was removed as it does not apply to this report. Status: Tested OK in Train (client TEST-001 now shows receipt LKHS/CM/COR/27-0009 correctly, same as the Transaction Date report). Will apply to Live after confirmation.
