# LKHS-337 — CSM (PM) Debtor Aging Summary by Trx Date: Owing sai

- **Client:** LKHS (Singapore, nhánh TFS `NET4.0_SG` / `IFCA.NET 4.0_SG`). Test trên LKHS Train, debtor `TEST-001`.
- **Menu:** CSM (module PM — Construction) > Reporting > Debtor Aging Summary by Trx Date.
- **Trạng thái (20/11/2026): ĐÓNG.** Gunner test OK Train 19/11 (Owing 180), consultant OK Train, Gunner đã áp Live 20/11. TFS Dev SG 99594, Rel SG 99614.
- Tài liệu consultant: `CSM Aging Reports.xlsx` tab "by trx date" (bản copy ở `work\LKHS-336\`). File RDL server + bản gốc ở `work\LKHS-337\` (không commit).
- Lỗi đã thấy từ LKHS-336 (mục "ngoài phạm vi").

## Bối cảnh

Cùng data LKHS-336: invoice `LKHS/CM/CIV/27-0007` còn 1,000; receipt `LKHS/CM/COR/27-0009` Unallocated −820 → Owing đúng = 180.

| Report (As At 19/11/2026) | Outstanding | Unallocated | Owing |
|---|---|---|---|
| Aging Detail by Trx Date (EN291) | 1,000 | −820 | 180 (đúng) |
| Aging Summary by Doc Date | 1,000 | (820) | 180 (đúng) |
| Aging **Summary by Trx Date (EN292)** | 1,000 | (820) | **1,820 (sai)** |

## Report → object

| ReportNo | ReportFileName | ReadTable | SP |
|---|---|---|---|
| EN292 | `PM_DebtorAgingSumByTrxDate` | `VIEW_PM_DebtorAgingSumByTrxDate` | `exec PMDebtorAgingDetail @CompanyID, @Language, 'TransactionDate', @QueryCriteria` (cùng SP với EN291/EN275) |

## Root cause (đã xác nhận: RDL server + TFS + test)

- CRITERIA đúng (`TRANSACTIONDATE<='2026/11/19'`), SP trả đúng 2 dòng, `UnallocedAmt = -820` (số âm) — data không sai.
- RDL `PM_DebtorAgingSumByTrxDate.rdl`, 3 ô Owing (dòng debtor, Debtor Type Total, Grand Total), mỗi ô 3 chỗ (điều kiện IIF, số dương, số âm trong ngoặc) tính
  `Sum(Age1Amt + … + Age7Amt - Fields!UnallocedAmt.Value)` → 1,000 − (−820) = 1,820.
- Bản đúng `PM_DebtorAgingSumByDocDate.rdl` (SG) dùng `+ Fields!UnallocedAmt.Value`.
- So TFS (bản copy trên máy Gunner, 19/11):

| Nhánh | Ô Owing |
|---|---|
| Server LKHS Train | `- UnallocedAmt` (sai) |
| `Dev\BRANCHES\NET4.0_SG\Reports`, `Rel\IFCA.NET 4.0_SG\Reports` | `- UnallocedAmt` (sai) |
| `Rel\IFCA.NET 4.0\Source\Reports`, `Dev\BRANCHES\NET4.0_REL\Reports` (Malaysia) | `+ Sum(Fields!UnallocedAmt.Value)` (đúng) |

→ Bug của nhánh SG: Malaysia đã sửa, chưa port sang SG. Không phải lệch deploy (TFS SG cũng sai).
- Không đè nguyên file Malaysia sang SG: 2 file khác ~40 dòng ngoài Owing (vd nhãn aging SG dùng `PMGetAgingString('PM_Company', …)`, Malaysia dùng `'CF_Company'`).
- Một số bản snapshot client Malaysia trong TFS (`E-Invoice Client Deployment\<client>\Pre-Deployment Source\Reports`, `Customized Version\MRCB`) vẫn còn dấu `-` — ngoài phạm vi LKHS.

## Fix (RDL — chỉ đổi dấu, giữ nguyên phần còn lại)

File: `PM_DebtorAgingSumByTrxDate.rdl` (bản tải từ report server LKHS Train). 9 chỗ, ở 3 textbox Owing (bản server dòng ~3389–3391, ~4336–4338, ~5401–5403):

- Tìm: `- Fields!UnallocedAmt.Value`
- Thay: `+ Fields!UnallocedAmt.Value`

Sau sửa: 0 chỗ `-`, 9 chỗ `+`, chỉ 9 dòng thay đổi, giữ UTF-8 BOM + CRLF. RDL không comment được JiraID trong biểu thức → ghi ở Jira/doc. Bản gốc server: `work\LKHS-337\PM_DebtorAgingSumByTrxDate_ORIG_server.rdl`.

## Test (LKHS Train, TEST-001, As At 19/11/2026)

- Outstanding 1,000.00 / Unallocated (820.00) / Owing **180.00** — khớp Detail by Trx Date. **PASS** (Gunner 19/11).

## Changeset TFS

| Nhánh | Changeset | Ngày | File/object | Ghi chú |
|---|---|---|---|---|
| `Dev\BRANCHES\NET4.0_SG` | 99594 | 2026-11-19 | `Reports\PM_DebtorAgingSumByTrxDate.rdl` | Owing `- Fields!UnallocedAmt.Value` → `+` (9 chỗ) |
| `Rel\IFCA.NET 4.0_SG` | 99614 | 2026-11-20 | `Reports\PM_DebtorAgingSumByTrxDate.rdl` | như trên |

## Còn mở

- ~~Áp Live LKHS~~ — đã áp 20/11 (Gunner).
- ~~TFS SG~~ — Dev 99594, Rel 99614 (xem bảng Changeset).
- (Tuỳ chọn) Báo Stanley: snapshot RDL của vài client Malaysia trong TFS vẫn còn công thức cũ.

## Bài học

- Report Summary sai mà Detail cùng SP đúng → data đúng, soi biểu thức RDL (so với bản anh em đúng: Doc Date / Detail) trước khi đụng SP.
- LKHS dùng nhánh SG riêng: fix của nhánh Malaysia không tự sang SG. Gặp bug report/LKHS → so luôn file cùng tên ở nhánh Malaysia; nếu Malaysia đã đúng thì chỉ port đúng đoạn sửa, không đè cả file.

## Jira note

**[Tech]** Root Cause: In the SG version of report `PM_DebtorAgingSumByTrxDate.rdl` (EN292), the Owing Amount formula subtracts the Unallocated amount: `Sum(Age1..Age7 - UnallocedAmt)`. The SP `PMDebtorAgingDetail` returns Unallocated as a negative value (-820), so Owing became 1,000 - (-820) = 1,820. The SP data and criteria are correct (Aging Detail by Trx Date shows Owing 180). The Doc Date summary report and the Malaysia standard version already add the Unallocated amount; this fix was not in the SG branch. Fix: changed the Owing formula in the 3 Owing cells (debtor line, Debtor Type Total, Grand Total) from `- Fields!UnallocedAmt.Value` to `+ Fields!UnallocedAmt.Value`. No SP or config change. Status: tested OK in LKHS Train (TEST-001, As At 19/11/2026: Outstanding 1,000.00, Unallocated (820.00), Owing 180.00), pending Live deployment and TFS SG update.

**[Non-tech]** Root Cause: The Owing Amount on the Debtor Aging Summary by Trx Date report used the wrong formula: it added the unallocated receipt amount to the outstanding amount instead of deducting it, so the Owing figure was too high. Fix: We corrected the formula in the report. Status: Tested OK in Train (client TEST-001 now shows Owing 180.00, the same as the Debtor Aging Detail by Trx Date report). Will apply to Live after confirmation.
