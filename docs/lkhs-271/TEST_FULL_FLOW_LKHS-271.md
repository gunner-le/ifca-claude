# LKHS-271 GIRO — Nghiệp vụ và test full luồng (LKHS-320 + LKHS-325)

Điều kiện: DB đã chạy đủ script LKHS-320, LKHS-325 và LKHS-326 (DocCode `316_ReceiptGroup`), web đã deploy, đã restart site.
Không cần chạy thêm script update nào. Các query trong file chỉ là SELECT để kiểm tra kết quả.

Nên test lần lượt **4 module**: Rental, Other Receivable, Construction, Property Sales. Rental đã test kỹ, ưu tiên 3 module còn lại.

---

## Phần A — Nghiệp vụ GIRO (đọc trước khi test)

### A1. GIRO là gì, ai làm gì
**GIRO (Interbank GIRO, Singapore)** = ngân hàng **tự trích tiền** từ tài khoản của debtor sang tài khoản công ty, theo uỷ quyền debtor đã ký với ngân hàng. Ngân hàng của công ty ở đây là **DBS**.
- **Debtor** (tenant, khách mua nhà, client...): đã đăng ký GIRO.
- **Công ty** (user IFCA): mỗi kỳ lấy bill đến hạn, tạo file yêu cầu thu tiền (**UFF**), upload lên **DBS portal**.
- **DBS**: trích tiền từng debtor; dòng không trích được (không đủ tiền, sai tài khoản...) trả về **file reject**.
- **IFCA**: dòng thành công → phiếu thu Verified như thu thường; dòng bị reject → huỷ phiếu, trả công nợ lại cho bill.

Khác thu tay: IFCA **tạo phiếu thu trước** (chưa chắc thu được), rồi xác nhận hoặc huỷ theo kết quả ngân hàng.

### A2. Luồng tổng thể
```
Master setup (1 lần)
      ↓
[6] Generate GIRO Collection — chọn bill → tạo phiếu thu GIRO (Generated)
      ↓
[7] Collection Verification
      ├─ GIRO Cancel — huỷ phiếu chưa gửi ngân hàng (Cancel)
      └─ GIRO Batch Generation — gom phiếu thành 1 batch + xuất file UFF (Exported)
                ↓  user upload file lên DBS portal, DBS trích tiền
         GIRO Batch Listing
           ├─ Reset — huỷ batch, phiếu về Generated
           ├─ Import (Success) — DBS thu được hết: mọi phiếu Verified (Success)
           └─ Import (Reject) — có file reject: phiếu bị reject huỷ (Failed), còn lại Verified (Success)
      ↓
Bank-In → GL Import (như phiếu thu thường)
```

### A3. Master setup để làm gì
| Màn | Setup | Tại sao cần |
|---|---|---|
| Number Structure > Cash Management > Receipt Group No | Serial, 5 số | DBS yêu cầu Batch ID là số 00001–99999, không trùng trong cùng ngày + cùng tài khoản |
| Dropdown List > Bank SWIFT Code | Ngân hàng của debtor + SWIFT | File UFF ghi ngân hàng debtor bằng SWIFT (D21) |
| Dropdown List > DBS Purpose Code | Mã mục đích | Field bắt buộc trong file (D43) |
| Dropdown List > Pay Method | Có phần tử "GIRO" | Phân biệt phiếu GIRO với thu tay |
| Cash Book Accounts | Tài khoản DBS của công ty | Tài khoản nhận tiền; số tài khoản + currency vào file |
| Company Structure | Allow GIRO Process; GIRO bank, Organization ID / Name (DBS cấp), AR Export Path, AR Import Path | Company nào dùng GIRO, thu vào tài khoản nào; header file; thư mục trao đổi file |
| Màn debtor 4 module | Allow GIRO Process, GIRO Account No, GIRO Bank | Debtor nào thu bằng GIRO, trích từ tài khoản nào; số tài khoản là khoá khớp file reject |
| Hồ sơ account của debtor | Identity No (NRIC / UEN) | DDA Reference (D35) — mã uỷ quyền GIRO; thiếu thì không xuất file |
| Menu Template Definition | Gắn menu Generate GIRO Collection | User thấy menu |

Thư mục Export/Import được map thành ổ đĩa trên PC user: lấy file UFF ở Export để upload lên DBS portal, bỏ file reject tải từ DBS vào Import.

### A4. Bước 6 — Generate GIRO Collection
1. Chọn **Company** → **GIRO Bank**: list bill chưa thu của debtor GIRO thuộc company, cùng currency với tài khoản DBS, cả 4 module.
2. Tick bill → **Generate** (hoặc **Generate All** theo filter). Nhập **Payment Date** (ngày ngân hàng trích tiền) và **Reference No** (nội dung trên sao kê debtor).
3. Save → tạo phiếu thu theo logic màn thu tiền của từng module, **1 phiếu / debtor (cùng module, currency)**, thu **đủ balance**; bill thành đã thu.

Phiếu: Active, GIRO Status **Generated** (đã tạo, chưa gửi ngân hàng). Phiếu GIRO **không hiện ở list Collection của module** để tránh sửa/xoá nhầm; mọi xử lý đi qua Collection Verification.

### A5. Bước 7 — Collection Verification và GIRO Batch
- Lọc **IsGiroReceipt = Y**; grid có GIRO Batch No, GIRO Status.
- **Verify / Verify All không áp dụng cho phiếu GIRO** — chỉ Verify qua kết quả Import.
- **GIRO Cancel**: huỷ phiếu chưa vào batch (Generated) → Voided, GIRO Status Cancel, gỡ allocation, bill có balance lại.
- **GIRO Batch Generation**: popup trống → chọn Bank → grid phiếu Generated → tick → nhập Reference No, Payment Date, Purpose (chỉ đi vào file, không sửa phiếu) → Save: số batch mới, phiếu Exported + số batch, file UFF ghi vào Export, **1 dòng / debtor** (tổng tiền, danh sách invoice). Thiếu dữ liệu bắt buộc → báo hết lỗi 1 lần, không tạo batch.
- User upload file lên DBS portal; DBS trích tiền vào Payment Date.

### A6. Ghi nhận kết quả — GIRO Batch Listing
Nút chỉ sáng khi tick đúng 1 batch Exported.
- **Reset**: batch Cancel, phiếu về Generated (bỏ số batch) để vào batch khác.
- **Import (Success)**: DBS thu được hết thì không trả file → xác nhận cả batch: phiếu Verified, GIRO Status Success, batch Completed.
- **Import (Reject)**: bỏ file reject vào thư mục Import → chọn file → **Verify** → Pre-Check (phiếu của debtor có trong file = Failed + lý do; còn lại Success; khớp theo số tài khoản debtor; chặn số tài khoản lạ hoặc dạng `E+`) → **Confirm**: Failed → Voided (logic xoá phiếu của module), bill có balance lại, lưu lý do reject; Success → Verified; batch Completed.
- Bill của debtor bị reject hiện lại ở màn Generate để thu đợt sau.
- Mọi thao tác ghi audit log của batch.

### A7. Sau đó
Phiếu Verified đi tiếp Bank-In → GL Import Sub-Ledger như phiếu thu thường. Phiếu Voided không sinh bút toán.

### A8. Vòng đời trạng thái
| | Phiếu (`CB_Receipt`) | GIRO Status | Batch |
|---|---|---|---|
| Sau Generate | Active | Generated | — |
| GIRO Cancel | Voided | Cancel | — |
| Batch Generation | Active | Exported | Exported |
| Reset | Active | Generated (bỏ số batch) | Cancel |
| Import — thành công | Verified | Success | Completed |
| Import — bị reject | Voided | Failed | Completed |

Chờ Stanley quyết (đang tạm giữ): bill ngoại tệ thu theo logic màn gốc từng module (PS ngoại tệ bị chặn); lãi trả chậm không tính lại tới Payment Date.

### A9. Data test trên UI (company 195 / S36, GIRO bank 588 đã setup)
| Module | Debtor | Việc cần làm trên màn debtor |
|---|---|---|
| Rental | 1812, 1818 (6 bill mỗi debtor) | Bật Allow GIRO Process, nhập GIRO Account No (số, khác nhau), chọn GIRO Bank; kiểm tra Identity No |
| Other Receivable | 2156 (1 bill) | Đã setup sẵn |
| Construction | 613, 579 (1 bill mỗi debtor) | Như Rental |
| Property Sales | — | Company 195 không có bill PS → cần company khác có bill PS (vd S43) + setup GIRO bank cho company đó trên Company Structure |

Case lỗi có sẵn: debtor 2207 (OR) thiếu GIRO Account No; debtor 291 (PS) chưa chọn GIRO Bank.

---

# Phần B — Các bước test

## 0. Master setup (làm 1 lần cho company test, theo sheet *Retrieval Location* của `DBS_GIRO_Specification.xlsx`)

Màn 1–5 do Stanley làm. Tên field dưới đây suy ra từ cột DB, nhãn trên màn hình có thể khác một chút.

| # | Màn hình (menu) | Setup | Dùng cho |
|---|---|---|---|
| 0.1 | **System Setup > Number Structure > Cash Management > Receipt Group No** (LKHS-326) | Tạo cho company test: Serial only, length 5, pad 0 (ra `00001`) | GroupNo / Batch ID (D07). Thiếu → Save batch lỗi "There is no row at position 0" |
| 0.2 | **Cash Management > Customized Setup > Dropdown List >> Bank SWIFT Code** (màn 4) | Mỗi ngân hàng của debtor 1 dòng: Code = Bank Code, Title = Bank Name, cột SWIFT BIC (lưu ở `TitleCN`) | D21 — GIRO Bank của debtor |
| 0.3 | **Cash Management > Customized Setup > Dropdown List >> DBS Purpose Code** (màn 5) | Mã Purpose (≤ 4 ký tự) + mô tả | D43 — chọn trên popup Batch Generation |
| 0.4 | **Cash Management > Customized Setup > Dropdown List >> Pay Method** | Có phần tử tên chứa chữ "GIRO" | Payment Method của phiếu GIRO |
| 0.5 | **Cash Management > Cashiering Setting > Cash Book Accounts** (màn 2) | Bank account DBS của company: Account No, Currency (SGD), Active | D03 (TK GIRO bank), D04/D06 (currency) |
| 0.6 | **System Setup > Company Structure** (màn 1) | `Allow GIRO Process` = Y. Tab/khung GIRO bank: chọn GIRO Bank Account (0.5), **Organization ID** (H03), **Organization Name** (H04), **AR Export Path**, **AR Import Path** | Bank hiện ở cây Bank; header file UFF; thư mục xuất / nhận file |
| 0.7 | Thư mục Export / Import trên server | Tạo 2 thư mục, cấp quyền đọc/ghi cho app pool. Path local (`E:\...`) hoặc UNC (`\\<server>\<share>\Export`), **không** dùng ký tự ổ map | Ghi file UFF, đọc file kết quả |
| 0.8 | Debtor của từng module (màn 3a–3d): **Rental Mgmt > Account Receivable > Debtor Information**; **Other Receivable > Customized Setup > Other Debtor Profile**; **Construction Mgmt > Contract Management > Client Profile**; **Property Sales > Post Sales > Contract Management > Purchaser Profile** | `Allow GIRO Process` = Y, **GIRO Account No** (D16, khác nhau giữa các debtor), **GIRO Bank** (dropdown 0.2) | Debtor có bill hiện ở màn Generate GIRO Collection |
| 0.9 | Hồ sơ account của debtor (`CF_Account`) | **Identity No** có giá trị | D35. Trống → Save batch báo lỗi |
| 0.10 | **System Setup > Menu Template Definition** | Gắn menu **Generate GIRO Collection** (`Cash-03-20`, nhóm Cash Management > Receipt) vào template của user test → Save | Menu hiện trên cây. Các nút GIRO trên Collection Verification không cần cấp quyền riêng |
| 0.11 | Restart site / recycle App Pool | Sau khi chạy script config hoặc đổi master | Menu và chuỗi CF_String mới được nạp |

Chuẩn bị data: mỗi module ít nhất 2 debtor GIRO có bill chưa thu (balance > 0) cùng currency với GIRO bank (SGD); nên có 1 debtor nhiều bill. Ghi lại DocumentNo + balance của bill trước khi test.

Query kiểm tra nhanh master (chỉ SELECT):
```sql
SELECT c.CompanyID, c.AllowGiroProcess, g.GiroBankAccountID, g.OrganizationID, g.OrganizationName, g.ARExportPath, g.ARImportPath, g.RecordStatus
FROM CF_Company c LEFT JOIN CF_CompanyGiroBank g ON g.CompanyID = c.CompanyID
WHERE c.CompanyID = <CompanyID>;

SELECT d.DebtorID, d.RefTable, d.AllowGiroProcess, d.GiroAccountNo, d.GiroBankSwiftCodeID, a.IdentityNo
FROM AR_Debtor d JOIN CF_Account a ON a.AccountID = d.AccountID
WHERE d.AllowGiroProcess = 'Y';
```

---

## 1. Generate GIRO Collection (LKHS-320)

Menu: Cash Management > Receipt > **Generate GIRO Collection**.

| # | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1.1 | Chọn Company → chọn GIRO Bank | List hiện bill chưa thu của debtor GIRO, đúng currency của bank, đủ 4 module |
| 1.2 | Tick 1–2 bill của 1 debtor → **Generate** | Popup: Account No / Bank / Currency read-only, Payment Method = GIRO, No. of Documents và Total đúng |
| 1.3 | Bỏ trống Payment Date hoặc Reference No → Save | Báo lỗi bắt buộc |
| 1.4 | Nhập đủ → Save | Báo đã tạo N receipt (số DocNo theo module). Bill biến mất khỏi list |
| 1.5 | **Generate All** (theo filter đang có) | Tạo phiếu cho toàn bộ bill theo filter, gom 1 phiếu / Module + Debtor + Currency |

Kiểm tra DB (thay DocNo):
```sql
SELECT CBReceiptID, DocNo, ReceiptType, RecordStatus, IsGiroReceipt, GIRORecordStatus, GroupNo, DocumentAmt, AllocBalance
FROM CB_Receipt WHERE DocNo IN ('<DocNo1>', '<DocNo2>');
-- Mong đợi: Active, IsGiroReceipt = Y, GIRORecordStatus = Generated, GroupNo NULL

SELECT a.ReceiptID, t.DocumentNo, a.AllocAmt, a.BaseAmt, a.ExchangeRate, a.RecordStatus, t.BalanceAmt
FROM AR_Allocation a JOIN AR_Trx t ON t.BillID = a.BillID
WHERE a.ReceiptID IN (<CBReceiptID1>, <CBReceiptID2>);
-- Mong đợi: allocation Active, bill BalanceAmt = 0 (thu đủ)
```

## 2. Phiếu GIRO bị ẩn ở list Collection của module (LKHS-320)

| Module | Màn hình | Mong đợi |
|---|---|---|
| Rental | Collection > Receivable | Không thấy phiếu GIRO vừa tạo; phiếu thu tay vẫn hiện |
| Other Receivable | Collection | Như trên |
| Construction | Receivable > Receipt/Collection | Như trên |
| Property Sales | AR Transaction > Receivable | Như trên; test cả lúc mở trang và lúc bấm Search |

## 3. Collection Verification — cột/criteria GIRO, Verify, Cancel (LKHS-325)

Menu: Cash Management > Receipt > **Collection Verification**.

| # | Thao tác | Mong đợi |
|---|---|---|
| 3.1 | Search với criteria IsGiroReceipt = Y | Ra phiếu GIRO; cột GIRO Batch No trống, GIRO Status = Generated |
| 3.2 | Tick phiếu GIRO → **Verify** / **Verify All** | Phiếu GIRO bị bỏ qua (không Verify được bằng nút thường) |
| 3.3 | Tick 1 phiếu **thu tay** → GIRO Cancel | Nút không sáng / báo không phải phiếu GIRO |
| 3.4 | Tick 1 phiếu GIRO Generated → **GIRO Cancel** → xác nhận | Phiếu Voided, GIRO Status = Cancel, bill có balance trở lại |

Kiểm tra 3.4:
```sql
SELECT DocNo, RecordStatus, GIRORecordStatus, VoidDate, VoidRemark FROM CB_Receipt WHERE DocNo = '<DocNo>';
SELECT t.DocumentNo, t.BalanceAmt, a.RecordStatus
FROM AR_Allocation a JOIN AR_Trx t ON t.BillID = a.BillID WHERE a.ReceiptID = <CBReceiptID>;
-- Mong đợi: Voided / Cancel; allocation Inactive; BalanceAmt = số trước khi Generate
```
Sau đó tạo lại phiếu GIRO cho bill đó (bước 1) để dùng cho bước 4.

## 4. GIRO Batch Generation — xuất file UFF (LKHS-325)

Trên Collection Verification bấm **GIRO Batch Generation**.

| # | Thao tác | Mong đợi |
|---|---|---|
| 4.1 | Popup mở trống → chọn Bank | Account No / Currency theo bank; grid = phiếu GIRO Generated của bank |
| 4.2 | Tick phiếu (nên ≥ 2 debtor, 1 debtor có ≥ 2 phiếu) → nhập Reference No, Payment Date, chọn Purpose → Save | Báo tạo batch `000xx` |
| 4.3 | Thử debtor thiếu Identity No (nếu có) | Báo lỗi D35, không tạo batch |
| 4.4 | Mở thư mục Export | Có file `UFF_COL_<OrgID>_<BatchNo>_<yyyyMMddHHmmss>.csv` |
| 4.5 | Mở file (Notepad, **không** Save bằng Excel) | 1 dòng HEADER; **1 dòng PAYMENT / debtor** (debtor nhiều phiếu = 1 dòng cộng tiền, D64 = các invoice); 1 dòng TRAILER đúng số dòng và tổng tiền |

```sql
SELECT g.CBReceiptGroupID, g.GroupNo, g.RecordStatus, g.Filename, g.ReferenceNo, g.DocumentDate, g.PurposeCode
FROM CB_ReceiptGroup g WHERE g.GroupNo = '<BatchNo>';
SELECT r.DocNo, r.GIRORecordStatus, r.GroupNo, d.RecordStatus
FROM CB_ReceiptGroupDetail d JOIN CB_Receipt r ON r.CBReceiptID = d.ReceiptID
WHERE d.ReceiptGroupID = <CBReceiptGroupID>;
-- Mong đợi: batch Exported; phiếu Exported + GroupNo; Reference No / DocumentDate của phiếu KHÔNG đổi
```

## 5. GIRO Batch Listing (LKHS-325)

Trên Collection Verification bấm **GIRO Batch Listing**.

### 5.1 Reset
| Thao tác | Mong đợi |
|---|---|
| Tick batch Exported → **Reset** → xác nhận | Batch = Cancel; phiếu về Generated, GroupNo trống; phiếu xuất hiện lại trong popup Batch Generation |

Tạo lại batch (bước 4) để test tiếp.

### 5.2 Import (Success) — cả batch thành công
| Thao tác | Mong đợi |
|---|---|
| Tick batch Exported → **Import (Success)** → xác nhận | Batch = Completed; mọi phiếu trong batch RecordStatus = **Verified**, GIRO Status = **Success** |

### 5.3 Import (Reject) — có dòng bị ngân hàng từ chối
Chuẩn bị file kết quả (CSV, Notepad) bỏ vào thư mục **Import**, ví dụ `DBS_Result_test.csv`. Chỉ liệt kê dòng bị reject; Account number = GIRO Account No của debtor bị reject (đúng như trong file UFF):
```
Payee/Nickname,Bank/SWIFT BIC,Account number,Status,Reject Reason,Amount,Purpose Code,Reference for payee,Payment date,Message
<Tên debtor>,<SWIFT>,<GIRO Account No>,Bank Rejected,1209:Please contact the receiving bank,<Số tiền>(SGD),<Purpose>,<Reference No>,<dd/MM/yyyy>,
```

| # | Thao tác | Mong đợi |
|---|---|---|
| a | Tick batch Exported → **Import (Reject)** | Màn Upload liệt kê file trong thư mục Import (mới nhất trên cùng) |
| b | Chọn file → **Verify** | Màn Pre-Check: debtor trong file = Failed + Return Reason; debtor còn lại = Success |
| c | Thử file có Account number không có trong batch | Báo không khớp, không cho Confirm |
| d | Thử sửa Account number thành dạng `5.88E+11` | Báo lỗi định dạng số tài khoản |
| e | File đúng → **Confirm** | Báo OK; batch Completed |

```sql
SELECT r.DocNo, r.RecordStatus, r.GIRORecordStatus, d.ReturnReason
FROM CB_ReceiptGroupDetail d JOIN CB_Receipt r ON r.CBReceiptID = d.ReceiptID
WHERE d.ReceiptGroupID = <CBReceiptGroupID>;
-- Failed: Voided / Failed / có ReturnReason; Success: Verified / Success
SELECT t.DocumentNo, t.BalanceAmt FROM AR_Trx t WHERE t.DocumentNo IN ('<bill của debtor Failed>');
-- Mong đợi: balance trở lại như trước khi Generate
SELECT Action, Remark, ProcessDateTime FROM CB_ReceiptGroup_AuditLog
WHERE ReceiptGroupID = <CBReceiptGroupID> ORDER BY ProcessDateTime;
```

## 6. Sau Import

| # | Kiểm tra | Mong đợi |
|---|---|---|
| 6.1 | Collection Verification | Phiếu Success hiện Verified (như verify thường); phiếu Failed không còn xử lý được |
| 6.2 | List Collection của module | Phiếu GIRO (kể cả Verified) vẫn bị ẩn |
| 6.3 | Generate GIRO Collection | Bill của debtor Failed xuất hiện lại để tạo phiếu mới |
| 6.4 | Bank-In / GL Import Sub-Ledger (nếu muốn) | Phiếu GIRO Verified đi tiếp như phiếu thu thường |

---

## Ghi nhận kết quả

| Module | 1 Generate | 2 Ẩn list | 3 Cancel | 4 Batch/UFF | 5.1 Reset | 5.2 Success | 5.3 Reject | Ghi chú |
|---|---|---|---|---|---|---|---|---|
| Rental | | | | | | | | |
| Other Receivable | | | | | | | | |
| Construction | | | | | | | | |
| Property Sales | | | | | | | | |
