# PLBPG-62 — Other Receivable invoice (mẫu mới): bank account fix cứng → lấy theo company

- **Client:** PLBPG (PLB Group, source `PLB_LIVE`). Jira gốc: "Other Receivable - change new format for invoices (Customization)" — Gunner đã làm xong mẫu mới; vòng này là bug consultant báo trên mẫu đó.
- **Yêu cầu consultant:** "the bank for Phoenix Residence Sdn Bhd is hardcoded to PLB Bank, can help to replace the hardcoded value with datasource?"
- **Trạng thái (20/11/2026): FIXED Train — chờ consultant test.** Gunner đã upload RDL lên Report Server + chạy config, in ra đúng tên company; chờ consultant test bank account.
- File: `work\PLBPG-62\AR_DebtorInvoice_PLBPG.rdl` (bản sửa) + `AR_DebtorInvoice_PLBPG_ORIG.rdl` (bản gốc server, dựng lại bằng reverse edit, khớp 228,313 byte). `work\` không commit.

## Bối cảnh

- Invoice `PRSB/AR/INV00000008` (Phoenix Residences Sdn Bhd, CompanyID 3), in qua `CashFlow/ACPaymentListPrint.aspx?ReportName=AR_DebtorInvoice_PLBPG` → control `Common/RdlCommControl.ascx` (SSRS server report).
- Header đã lấy theo company từ dataset `CompanyInfo` (`select CompanyName,Address,Phone,IdentityNo,GSTNO,Fax,STNO,Email from view_cf_company where CompanyID=@CompanyID`) — không có cột bank.
- Footer textbox `Textbox593`, dòng (2) fix cứng: `"(2) All cheques or internet banking should be made payment to <b>PLB Land Sdn Bhd. RHB A/C No : 20702800038540.</b>"` → mọi company đều in PLB Land.

## Root cause (đã xác nhận: RDL + data)

- Chữ fix cứng trong RDL (không phải data).
- Không có chỗ nào trong DB đánh dấu "tài khoản in trên invoice": `CF_BankAccount` không có cờ Default/Print; `CF_Company`/`View_CF_Company` không có cột bank (chỉ `Remark` — không mượn). Mỗi company nhiều bank account (Phoenix: 3 dòng `CIT - …` (inter-company) + `RHB - CA 98098 - PRSB`).
- `CF_Parameter` không có `CompanyID` (cột: ParameterID identity, Class, ApplicationID, Name, TitleCN, TitleEN, Value nvarchar(500), ValueType, RecordStatus, Create/ModifyUserID NOT NULL, Create/ModifyDate).

## Fix v2 (ĐANG DÙNG — 20/11/2026, thay v1 bên dưới)

Consultant chuyển email user: in theo format từng company
1. PLB Land Sdn Bhd - RHB Bank Berhad - Acc No: 2-07028-00038540
2. Phoenix Residences Sdn Bhd - RHB Bank Berhad - Acc No: 2-07028-00098098
3. PLB Cemerlang Sdn Bhd - RHB Bank Berhad - Acc No: 2-07028-00086448

Vì sao bỏ v1 (lấy từ `CF_BankAccount`): `CF_Account.Name` là tên riêng từng tài khoản (vd `RHB - CA 98098 - PRSB`, `RHB BANK BERHAD - HDA ACCOUNT - TDI`), không có tên ngân hàng chuẩn; `AccountNo` không thống nhất (`20702800038540` / `2-07028-00094769` / Phoenix + Cemerlang (BankAccountID 74, 71) = chính mã). Gunner chốt **không sửa `AccountNo`**. `View_CF_Company` không có cột mã company → khoá theo tên company (`TitleEN`), không dùng CompanyID cứng. Đã cân nhắc lấy từ Cash Book Accounts (user tự quản lý) — chỉ khả thi khi consultant làm sạch data bank, để sau.

**Config:** `work\PLBPG-62\CF_Parameter_AR_DebtorInvoice_PLBPG_Bank.sql` (chạy lại được; xoá mọi dòng `AR_DebtorInvoice_PLBPG_Bank_%` rồi insert lại; dòng v1 `AR_DebtorInvoice_PLBPG_BankCode` + dòng `AR_DebtorInvoice_PLBPG_Bank` (không hậu tố) Gunner đã xoá tay trên Train 20/11 — Live chưa từng tạo nên script không cần xoá; 3 dòng `Name='AR_DebtorInvoice_PLBPG_Bank_PLD' / _PRSB / _PLBC`, `Class='ReportPara'`, `ApplicationID=8`, `TitleEN` = tên company, `Value` = `RHB Bank Berhad - Acc No: …`). Thêm/đổi company = thêm/sửa 1 dòng (không có màn hình web — user báo support).
- **Gotcha:** `CF_Parameter` có unique index `IX_CF_Parameter__NameValueStatus` = (Name, Class, RecordStatus) → 3 dòng cùng Name bị lỗi 2601 (lần chạy đầu chỉ vào dòng PLB Land). Hậu tố Name chỉ để không trùng; report khớp theo `TitleEN`, lọc `LEFT(p.Name, 28) = 'AR_DebtorInvoice_PLBPG_Bank_'`.

**RDL (chỉ 2 chỗ so với `_ORIG`):**
- Dataset `BankInfo` (field `BankText`):
```sql
-- PLBPG-62: bank text printed on invoice footer, one CF_Parameter row per company (Name AR_DebtorInvoice_PLBPG_Bank_<suffix>, TitleEN = company name, Value = bank text)
SELECT TOP 1 p.Value AS BankText
FROM CF_Parameter p
JOIN view_cf_company c ON c.CompanyID = @CompanyID
WHERE LEFT(p.Name, 28) = 'AR_DebtorInvoice_PLBPG_Bank_'
  AND p.RecordStatus = 'Active'
  AND LTRIM(RTRIM(p.TitleEN)) = LTRIM(RTRIM(c.CompanyName))
```
- `Textbox593` dòng (2):
```vb
& "(2) All cheques or internet banking should be made payment to <b>" & CStr(First(Fields!CompanyName.Value, "CompanyInfo")) & IIf(IsNothing(First(Fields!BankText.Value, "BankInfo")), "", " - " & CStr(First(Fields!BankText.Value, "BankInfo"))) & ".</b>"
```
In ra: "… payment to **PLB Land Sdn Bhd - RHB Bank Berhad - Acc No: 2-07028-00038540.**" (giữ dấu chấm cuối như bản cũ / dòng (1)). Company không có dòng config → chỉ in tên company.

## Fix v1 (ĐÃ BỎ — giữ để tham khảo)

### 1. Config `CF_Parameter` (chạy lại được)
```sql
-- PLBPG-62: list of BankCode (CF_BankAccount.BankCode) printed on AR_DebtorInvoice_PLBPG footer, one per company, comma separated
IF EXISTS (SELECT TOP 1 1 FROM CF_Parameter WHERE Name = N'AR_DebtorInvoice_PLBPG_BankCode')
BEGIN
    DELETE FROM CF_Parameter WHERE Name = N'AR_DebtorInvoice_PLBPG_BankCode';
END

INSERT INTO CF_Parameter (Class, ApplicationID, Name, TitleCN, TitleEN, Value, ValueType, RecordStatus, CreateUserID, CreateDate, ModifyUserID, ModifyDate)
VALUES (N'ReportPara', 8, N'AR_DebtorInvoice_PLBPG_BankCode', NULL, N'Invoice Bank Account (BankCode list)', N'', 'String', 'Active', 1, GETDATE(), 1, GETDATE());
```
Giá trị đã set trên Train:
```sql
UPDATE CF_Parameter SET Value = N'RHB - CA 98098 - PRSB,RHB - CA 38540 - PLD' -- was N'RHB - CA 98098 - PRSB,RHB - CA 98098 - PRSB'
WHERE Name = N'AR_DebtorInvoice_PLBPG_BankCode';
```
(`RHB - CA 38540 - PLD` = PLB Land, tìm theo `AccountNo` chứa `20702800038540`.)

- `Class='ReportPara', ApplicationID=8` theo 2 dòng mẫu có sẵn (`WeekBegin`, `MonthBegin`). **Không hiện trên màn System > System Parameter** — `SystemParameter.aspx.cs` code cứng từng tham số (`switch` Name, load dòng ~312, save ~1782) → sửa Value bằng SQL. Muốn sửa trên web phải thêm control + 2 `case` (file chuẩn) — chưa làm.

### 2. RDL `AR_DebtorInvoice_PLBPG.rdl` — chỉ 2 chỗ (đã diff với `_ORIG`)
**a) Thêm dataset `BankInfo`** ngay sau `CompanyInfo` (data source `PropertyNetMaster`, `@CompanyID = Parameters!CompanyID.Value`, fields `BankName`, `AccountNo`):
```sql
-- PLBPG-62: bank account printed on invoice footer, chosen per company via CF_Parameter AR_DebtorInvoice_PLBPG_BankCode (comma separated BankCode list)
SELECT TOP 1 a.Name AS BankName, ba.AccountNo
FROM CF_BankAccount ba
LEFT JOIN CF_Account a ON a.AccountID = ba.AccountID
JOIN CF_Parameter p ON p.Name = 'AR_DebtorInvoice_PLBPG_BankCode' AND p.RecordStatus = 'Active'
WHERE ba.CompanyID = @CompanyID
  AND ba.RecordStatus = 'Activated'
  AND ',' + REPLACE(p.Value, ' ', '') + ',' LIKE '%,' + REPLACE(ba.BankCode, ' ', '') + ',%'
```
**b) `Textbox593`** — dòng (2), thay (1 dòng, giữ nguyên dòng (1) và `<br/>`):
```vb
& "(2) All cheques or internet banking should be made payment to <b>" & CStr(First(Fields!CompanyName.Value, "CompanyInfo")) & IIf(IsNothing(First(Fields!AccountNo.Value, "BankInfo")), ".", ". " & CStr(First(Fields!BankName.Value, "BankInfo")) & " A/C No : " & CStr(First(Fields!AccountNo.Value, "BankInfo")) & ".") & "</b>"
```
Dòng cũ: `& "(2) All cheques or internet banking should be made payment to <b>PLB Land Sdn Bhd. RHB A/C No : 20702800038540.</b>"` (RDL không comment được trong expression → ghi ở đây).
Company chưa có BankCode trong list → chỉ in tên company.

## Gotcha trong lúc làm

- Upload RDL báo `[BC30277] Type character '&' does not match declared data type 'Object'` khi expression xuống dòng sau `First(...)` rồi dòng sau bắt đầu `&` → đưa phần mới về 1 dòng + `CStr()` thì upload được.
- Lần đầu `LIKE` chỉ bỏ dấu cách phía tham số, BankCode thật có dấu cách (`RHB - CA 98098 - PRSB`) → không khớp; sửa bỏ dấu cách cả 2 phía.
- Lần đầu Gunner UPDATE nguyên chữ mẫu `<BankCode Phoenix>,…` → đưa mã thật, không để placeholder trong câu chạy được.
- In ra trang trắng (`SyntaxError` ở HTML) = FileServer local tắt (503 ở `DocumentLibrary.UploadFile`, `RdlCommControl.ascx.cs` ~191) — không phải report. Ghi `ENV-setup-checklist.md` mục 1b.

## Data cần consultant xử lý

- **Phoenix `AccountNo` = "RHB - CA 98098 - PRSB"** (nhập trùng BankCode, không phải số TK thật) → invoice in "A/C No : RHB - CA 98098 - PRSB". PLB Land nhập đúng (`20702800038540`). Consultant sửa AccountNo ở Cash Management > Cash Book Accounts.
- Company khác dùng mẫu này: consultant chọn tài khoản → nối BankCode vào `Value`.

## Test v2 (20/11/2026)

- Máy Gunner (DB PLB_LIVE local): chạy script config → 3 dòng `_PLD/_PRSB/_PLBC`; upload RDL v2; in invoice → footer đúng format. **PASS.** Tiếp theo: Gunner áp lên Train → consultant test.

## Test v1 (Train, 20/11/2026)

- Upload RDL OK; in `PRSB/AR/INV00000008` → tên Phoenix đúng. Bank: sau khi set Value + sửa `LIKE` — chờ consultant test (Phoenix / PLB Land / company chưa cấu hình).

## Changeset TFS

| Nhánh | Changeset | Ngày | File/object | Ghi chú |
|---|---|---|---|---|
| (chưa ghi nhánh) | 99624 | 2026-11-20 | `AR_DebtorInvoice_PLBPG.rdl` (+ script `CF_Parameter_AR_DebtorInvoice_PLBPG_Bank.sql`?) | v2: footer bank theo company qua CF_Parameter `AR_DebtorInvoice_PLBPG_Bank_*` |

## Jira note (English) — v2 (dùng bản này)

**Tech:** Root Cause: In the customized invoice report `AR_DebtorInvoice_PLBPG`, the payment line in the footer (textbox `Textbox593`) was hardcoded as "PLB Land Sdn Bhd. RHB A/C No : 20702800038540", so every company printed PLB Land's bank account. The bank master (`CF_BankAccount`) cannot be used because the bank name and account no are not stored in the required format. Fix: The payee name now uses `CompanyName` from the existing `CompanyInfo` dataset. A new dataset `BankInfo` reads the bank text from `CF_Parameter` (Name `AR_DebtorInvoice_PLBPG_Bank`, one row per company, `TitleEN` = company name, `Value` = e.g. "RHB Bank Berhad - Acc No: 2-07028-00038540"). Rows are set for PLB Land, Phoenix Residences and PLB Cemerlang. A company without a row prints the company name only. Status: Deployed to Train, pending consultant testing.

**Non-tech:** Root Cause: The invoice always printed PLB Land's name and bank account in the payment note, for every company. Fix: The invoice now prints the issuing company's own name and bank account, in the format "PLB Land Sdn Bhd - RHB Bank Berhad - Acc No: 2-07028-00038540", for PLB Land, Phoenix Residences and PLB Cemerlang. Other companies print the company name only. To add a company or change an account, please inform IFCA support. Status: Ready on Train for testing.

## Jira note (English) — v1 (đã bỏ)

**Tech:** Root Cause: In the customized invoice report `AR_DebtorInvoice_PLBPG`, the payment line in the footer (textbox `Textbox593`) was hardcoded as "PLB Land Sdn Bhd. RHB A/C No : 20702800038540", so every company printed PLB Land's bank account. Fix: The payee name now uses `CompanyName` from the existing `CompanyInfo` dataset. A new dataset `BankInfo` takes the bank name (`CF_Account.Name`) and `AccountNo` from `CF_BankAccount` of the invoice company, where the `BankCode` is listed in the new parameter `CF_Parameter` `AR_DebtorInvoice_PLBPG_BankCode` (comma separated, one code per company; currently `RHB - CA 98098 - PRSB,RHB - CA 38540 - PLD`). A company with no code in the list prints the company name only. Status: Deployed to Train, pending consultant testing. Note: Phoenix's bank account has Account No "RHB - CA 98098 - PRSB" instead of the real account number.

**Non-tech:** Root Cause: The invoice always printed PLB Land's company name and RHB account number in the payment note, for every company. Fix: The invoice now prints the issuing company's own name and its bank account from the system. Which bank account to print for each company is set in one system setting; companies not set yet will print the company name only. Status: Ready on Train for testing. Please update the Account No of Phoenix Residences' RHB account in Cash Book Accounts to the real account number, and tell us the bank account to use for any other company that uses this invoice format.
