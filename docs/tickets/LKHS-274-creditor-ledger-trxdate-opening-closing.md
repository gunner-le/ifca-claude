# LKHS-274 — Creditor Ledger Detail By Trx Date: Opening/Closing sai khi StartDate ≠ 01/01/1900

- Client: LKHS (nhánh TFS SG — sửa thẳng Standard)
- Màn hình: AP > Reporting > Creditor Ledger Detail By Trx Date — `Sys_Report` 270 / **EN270**, ReadTable `VIEW_AP_CreditorLedgerDetailByTrxDate`, RDL SSRS `AP_CreditorLedgerDetailByTrxDate.rdl`, SP `pro_AP_CreditorLedgerDetail_ByTrxDate` (@QueryCriteria)
- Consultant: Valerie Loh
- Lịch sử v1–v10 (logic Opening/Closing/CarryForward): xem `docs/memory/ticket-status.md` mục LKHS-274. File này ghi từ vòng Reopen 20/11/2026.

## Changeset TFS

| Nhánh | Changeset | Ngày | File/object | Ghi chú |
|---|---|---|---|---|
| `$/Property/Dev/BRANCHES/NET4.0_SG` | 98161 | 2026-09-13 | `pro_AP_CreditorLedgerDetail_ByTrxDate` | v1–v7 |
| `$/Property/Dev/BRANCHES/NET4.0_SG` | 98590 | 2026-10-02 | `pro_AP_CreditorLedgerDetail_ByTrxDate` | v8–v10 (121 dấu LKHS-274) |
| `$/Property/Dev/BRANCHES/NET4.0_SG` | 99689 | 2026-11-24 | `pro_AP_CreditorLedgerDetail_ByTrxDate` | fix filter Supplier Type `SUPPLIERTYPECODE=` |
| `$/Property/Rel/IFCA.NET 4.0_SG` | 99699 | 2026-11-24 | `pro_AP_CreditorLedgerDetail_ByTrxDate` + `AP_CreditorLedgerDetailByTrxDate.rdl` | lên Live |

## Đóng 2026-11-24
- Consultant (Valerie) test OK trên Train_Testing. Gunner deploy Live: SP (Dev SG bản mới nhất, bỏ dòng `USE`) + RDL lên SSRS Live. Không đổi config `Sys_ReportFilter` (Live đã có ô Supplier Type dropdown từ 2025-12-08).

## Reopen 2026-11-20 — Creditor Type Closing không khớp (Train_Testing)

- Valerie: CS0147(SA) Creditor Type Closing 01/09/2025–30/06/2026 ≠ 01/01/1900–30/06/2026. Train_Testing vừa restore từ DB Live.
- **Root cause (đã xác nhận): lệch deploy, không phải lỗi logic.** SP trên Train_Testing: `modify_date` 2026-08-03, DefLen 77325, 26 dấu LKHS-274 (bản Live cũ). File deploy v10 có dòng 1 `USE [LKHS_Live_Testing]` → lần chạy 20/11 ALTER nhầm Live Testing.
- Fix: bỏ dòng USE, redeploy v10 lên Train_Testing (24/11). Valerie kiểm ngẫu nhiên → Closing OK.
- Kiểm: `SELECT o.modify_date, LEN(m.definition), (LEN(m.definition)-LEN(REPLACE(m.definition,'LKHS-274','')))/8 FROM sys.objects o JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.name='pro_AP_CreditorLedgerDetail_ByTrxDate'`.

## Yêu cầu thêm 2026-11-24

### (a) Sort theo Transaction Date
- Đã có trong RDL Dev SG: group `table1_Details_Group` sort `=Fields!TransactionDate.Value` (Rel SG vẫn `DocumentNo`). Group: `table1_Group1` = SupplierTypeID (Creditor Type), `table1_Group2` = CreditorID, Details = giao dịch.
- Gunner upload lại RDL Dev SG lên SSRS Train_Testing, đã kiểm SSRS đúng bản mới. Không đổi code.

### (b) Filter "Creditor Type" không lọc
- Trên màn filter (`ReportFilter2.aspx`) ô consultant gọi "Creditor Type" có label **"Supplier Type"** = `Sys_ReportFilter` EN270 `SupplierTypeCode`, `FldType = L` (dropdown), user 269 sửa 2025-12-08.
- CRITERIA thật: `... and SUPPLIERTYPECODE='SA/BILL REGISTER - SA'` (dấu `=`, giá trị = `CF_SupplierType.Code + '/' + Description`).
- **Root cause (đã xác nhận):** SP chỉ parse `CHARINDEX('SUPPLIERTYPECODE LIKE ', @QueryCriteria)` (kiểu ô text) → với dropdown `@SupplierTypeCode` NULL → điều kiện `cst.Code + '/' + cst.Description LIKE @SupplierTypeCode` bị bỏ qua → ra mọi type (2514 dòng, có RO).
- **Fix** — SP `pro_AP_CreditorLedgerDetail_ByTrxDate`, chèn SAU khối `IF ( @SupplierCodeInt > 0 ) BEGIN ... SUPPLIERTYPECODE LIKE ... END`:

```sql
-- LKHS-274 start: Supplier Type filter is a dropdown (FldType L), criteria comes as SUPPLIERTYPECODE='...' instead of LIKE
IF ( @SupplierCodeInt = 0 AND CHARINDEX('SUPPLIERTYPECODE=', @QueryCriteria) > 0 )
BEGIN
 SET @SupplierCodeInt = CHARINDEX('SUPPLIERTYPECODE=', @QueryCriteria)
 SET @End = CHARINDEX('''', @QueryCriteria, @SupplierCodeInt + LEN('SUPPLIERTYPECODE=') + 1)
 SET @SupplierTypeCode = SUBSTRING(@QueryCriteria, @SupplierCodeInt + LEN('SUPPLIERTYPECODE=') + 1, @End - @SupplierCodeInt - LEN('SUPPLIERTYPECODE=') - 1)
END
-- LKHS-274 end
```

- Giữ nhánh LIKE cũ; parse giống khối `SUPPLIERTYPECLASS=`. Kiểm trước: `CF_SupplierType` SA → `SA/Bill Register - SA` (khác hoa/thường, collation CI nên LIKE khớp), không Description nào có `'`.
- Test Train_Testing 2026-11-24: Supplier Type = SA chỉ ra type SA → OK (Gunner).

## Bài học
- Trước khi chạy file `.sql` deploy: mở xem dòng `USE` đầu file. `modify_date` ≠ ngày deploy → bản deploy không nằm trên DB đó.
- Consultant restore DB Live xuống môi trường test → mọi SP/fix chỉ có ở Train bị mất, phải deploy lại.
- Ô filter đổi S → L (dropdown) thì criteria đổi `X LIKE '%..%'` → `X='..'`; SP parse bằng CHARINDEX theo chuỗi cố định sẽ âm thầm bỏ filter. Đọc dòng CRITERIA đỏ + grep chuỗi CHARINDEX trong SP.
