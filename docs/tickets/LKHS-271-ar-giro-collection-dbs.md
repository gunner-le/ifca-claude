# LKHS-271 — SG Localization: AR Collection GIRO for DBS Bank

> **Đọc file này trước khi làm tiếp LKHS-271 / LKHS-320 / LKHS-325.** File được viết lại toàn bộ ngày 18/11/2026 (thay bản 12/10 đã cũ). Kiến thức dùng chung (không riêng LKHS) học được qua task này nằm ở `docs/ifca-cash-receipt-collection-reference.md`.
> Source code + script + bản gốc file chuẩn: trên claude.ai nằm ở Project `claude/LKHS-271-src/...` (xem mục 9). Trong Claude Code: mở thẳng source LKHS trên máy (bản đã deploy) thay vì bản lưu trong Project.

## 0. Tổng quan

| Jira | Nội dung | Trạng thái (18/11) |
|---|---|---|
| **LKHS-271** | Jira cha: AR Collection GIRO (file UFF của DBS) cho 4 module Rental / Other Receivable / Construction / Property Sales | Đang làm |
| **LKHS-320** (Phase 1) | Bước 6 "Generate GIRO Collection" + ẩn phiếu GIRO ở list Collection 4 module + handler forex | **Xong.** Deploy LKHS_Test, changeset **99415** (16/11). Phần ẩn phiếu GIRO commit 16/11 |
| **LKHS-325** (Phase 2) | Bước 7 "GIRO Batch": Collection Verification (nút GIRO), Batch Generation (xuất UFF), Batch Listing (Reset / Import Reject / Import Success), Cancel phiếu GIRO | ~80%. Đã test với Rental; còn test Failed/Cancel 3 module + test thư mục UNC |
| **LKHS-326** (Stanley) | Number Structure `CF_DocCode.DocCodeNo='316_ReceiptGroup'` (ApplicationID 89, System Setup > Number Structure > Cash Management > Receipt Group No; TableName `CB_ReceiptGroup`, PrimaryKey `CBReceiptGroupID`, CodeField `GroupNo`) | Có sẵn. **Bắt buộc deploy trước LKHS-325**; thiếu thì Save batch lỗi "There is no row at position 0". Mỗi company GIRO: Serial only, length 5, pad 0 |
| Report mục 8 (AR GIRO Status Report) | | Tách sang Jira sau (Gunner 16/11) |

- **Client:** LKHS, TFS riêng → GIRO là improvement trên nhánh LKHS (không cần hậu tố `_LKHS`, sửa thẳng file chuẩn của LKHS là hợp lệ, nhưng Gunner muốn hạn chế: file chuẩn có sẵn → đưa hướng dẫn patch before/after có comment `LKHS-271 GIRO` / `LKHS-325 GIRO`; file GIRO mới → gửi nguyên file).
- **DB:** local `LKHS_Train_Testing`; server test `LKHS_Test`; `LKHS_Train` (Train). Test data: company 195 (S36), bank 588, debtor 1812/1818/2156/613/579, SWIFT 12474.
- **Người chốt nghiệp vụ:** Stanley. Consultant: Valerie (làm việc với user/DBS).
- **Chỉ làm DBS** (UOB/OCBC có thể sau → format file tách class riêng theo bank).

## 1. Quy tắc làm việc với Gunner cho task này

- Thêm cột/bảng DB phải bàn và được Stanley/Gunner duyệt trước (config Sys_/CF_String thì OK). Không sửa file chuẩn dùng chung toàn hệ thống (ApproveView, CostCompanyTree, `Prc_splitpage`...).
- Trình bày plan trước khi code; khi chưa rõ thì hỏi, không tự đoán. **Không viết dynamic SQL / dò cột lúc runtime** ("bạn k nên viết kiểu nvay trong IFCA") — chưa chắc tên cột thì đưa query kiểm tra cho Gunner chạy.
- Script SQL chạy lại được nhiều lần; tách 1 object / 1 file theo folder TFS (`Create Table`, `New Table`, `Table Change`, `Views`, `Update Script`, `Stored Procedure(s)`, `Function`, `Trigger`, `User Defined Functions`), gom theo Jira.
- Thay đổi nhỏ gộp vào package đang làm (không gửi zip lẻ); **hỏi trước khi gửi zip cuối**.
- Bỏ qua các hook `pf_` customization khi copy logic.
- Tin nhắn cho Stanley: tiếng Anh, ngắn, chỉ hỏi. Khi Gunner yêu cầu thì kèm hướng định làm.
- Không ghi vào ghi chú một "quyết định của Stanley" nếu không có nguồn (đã từng ghi sai "Stanley chốt áp LKHS-230 cho cả 4 module" → Gunner bác, đã xoá).

## 2. Master GIRO (Stanley làm, đã lên Train)

| Đối tượng | Ghi chú |
|---|---|
| `CF_Company.AllowGiroProcess` char(1) | Company dùng GIRO (cây Company của màn GIRO **chưa lọc** cột này — để sau) |
| `CF_CompanyGiroBank` | `CompanyGiroBankID, CompanyID, GiroBankAccountID` (→ `CF_BankAccount`), `OrganizationID` (H03), `OrganizationName` (H04), **`ARExportPath`, `ARImportPath`** varchar(500), `RecordStatus` ('Active'). 1 company có thể nhiều GIRO bank |
| `AR_Debtor.AllowGiroProcess / GiroAccountNo` (D16) `/ GiroBankSwiftCodeID` (D21) | Debtor dùng GIRO |
| `CF_Account.IdentityNo` | **D35 (DDA Reference)**. Mặc định chặn khi trống: `GIROUffBatch.AllowBlankIdentityNo = false` (gán trong `GIROBatchService`). Không kiểm tra độ dài. Đổi chặn/không chặn = đổi true/false |
| SWIFT (D21) | `CF_PopupLst` Type `SWIFTCode` (ElementCode = Bank Code, Title = Bank Name, **TitleCN = SWIFT BIC**) |
| Purpose Code (D43) | `CF_PopupLst` Type `DBSPurposeCode` |
| `CB_Receipt.IsGiroReceipt / GIRORecordStatus / GroupNo` | Cột mới (LKHS-320 / LKHS-325) |

**Thư mục file (Stanley 16/11, đã hỏi consultant):** `ARExportPath` / `ARImportPath` là thư mục trên server, và thư mục đó lại là **ổ map từ 1 server khác**; user map thư mục thành ổ đĩa trên PC, dùng DBS portal trên PC.
→ Không cần FTP, không cần nút Download/Upload. Code `System.IO` hiện tại dùng được.
→ **Setup phải nhập đường dẫn UNC** (`\\FILESERVER\GIRO\Export`), không nhập ký tự ổ map (IIS không thấy ổ map của phiên đăng nhập). App pool account cần quyền đọc/ghi trên share (ApplicationPoolIdentity đi qua mạng bằng tài khoản máy `DOMAIN\<WEBSERVER>$`).
→ Path test Train hiện tại: `E:\IFCA Software\LKHS_Train\UpLoad\GIRO\Export` / `...\Import`. Gunner định tạo thư mục share trên DB server để test UNC.

## 3. Bước 6 — Generate GIRO Collection (LKHS-320)

**Trang:** menu `Cash-03-20` (Cash Management > Receipt). `CashFlow/ARGIROCollection.aspx` (cây Company `CostCompanyTree.aspx` + `BankTree.aspx`) → `ARGIROCollectionLst.aspx` (list bill) → popup `ARGIROCollectionGenerate.aspx` (+ `ARGIROCollectionGenerateDetail.aspx`, `ARGIROCollectionSelect.aspx`).
**App_Code/GIROCode:** `GIROModels.cs`, `GIROCollectionGenerator.cs` (luồng chính), `GIROModuleHandlers.cs` (interface `IGIROModuleHandler`, base `GIROHandlerBase`, Rental / Other Receivable / Construction), `GIROPropertySalesHandler.cs` (PS, gọi BL trong DLL).

**Nghiệp vụ đã chốt:**
- List = bill `AR_Trx` chưa thu của debtor GIRO, cùng company + GIRO bank + **currency của GIRO bank** (view `View_CB_GIROCollectionPending`).
- Generate = bill tick; Generate All = toàn bộ bill theo filter hiện tại.
- Popup: Account No / Bank / Currency read-only, Payment Method khoá GIRO, Payment Date + Reference No bắt buộc.
- Gom phiếu theo **Module + Debtor + Currency** → 1 `CB_Receipt` Active, `IsGiroReceipt='Y'`, `GIRORecordStatus='Generated'`, `Remark='GIRO Generation'`, PayMethod = phần tử chứa "GIRO". 1 transaction, `UPDLOCK` + đọc lại balance, lệch → rollback.
- Tỷ giá phiếu = `Currency.GetCurrencyExchange(CurrencyID, CompanyID, DateTime.Now)` (ngày Generate, không cho sửa).

| Module (`AR_Debtor.RefTable`) | ReceiptType | Doc code | Logic copy từ |
|---|---|---|---|
| Rental (`RT_RentalContract`) | `MC_Fee` (chốt giữ MC_Fee như màn Collection > Receivable, không dùng MC_Payment) | 036 | `McAccount/ArFeeAdd2.aspx.cs`; bill Interest → `MCInterest.PaidBill` |
| Other Receivable (`CF_Company`) | `OD_Receipt` | 313 | `AccountReceivable/OtherReceiptEditSG.aspx.cs` (logic forex LKHS-230) |
| Construction (`CF_Client`) | `PM_Receipt` | 400 | `PMReceiptBL` trong `PMReceivable/ArFeeAdd.aspx.cs`, `Supply='T'`, balance tính lại = DocumentAmt − tổng AllocAmt Active |
| Property Sales (`PS_Sale`) | `PS_Payment` | 036 | BL `IFCA.Framework.PS.BL.Collection.Alloction.AddCBAndBill` (như `PSAccount/PSReceiptAdd.aspx.cs`) |

**Chỗ phiếu GIRO khác màn tay (comment `LKHS-271 TEMP`), đã soạn câu hỏi Stanley 17/11:**
- Rental: `PaymentDescID` / `Supply` để trống; không tính lại lãi trả chậm tới Payment Date (nút "Calculate"), chỉ trả bill lãi có sẵn.
- PS: không tính lãi thả nổi (`SaleInterest.ReCalc` / `PostFloatBill`).
- OR: `Supply` để trống (chỉ dùng khi advance payment).
- Đề xuất của Claude: giữ như hiện tại (GIRO thu đúng hạn; tính lãi lúc Generate làm đổi số tiền trong file UFF). Chưa có câu trả lời.

## 4. Ẩn phiếu GIRO khỏi list Collection 4 module (LKHS-320, xong 16/11)

Spec v01.2: "Exclude display collection CB_Receipt.IsGiroReceipt = Y". Cách làm: thêm cột `IsGiroReceipt` (của `CB_Receipt`) vào view của list (không đổi số dòng, màn/report khác không ảnh hưởng) + lọc phẳng ở trang `isnull(IsGiroReceipt,'N') <> 'Y'`. Chi tiết diff: `claude/LKHS-271-src/PATCH_LKHS-320_HideGIRO.md` (trong Project claude.ai).

| Module | View thêm cột | Trang |
|---|---|---|
| Construction | `View_PM_Receipt` (`,Cb.IsGiroReceipt`) | `PMReceivable/ARReceiptList.aspx.cs` (Page_Load) |
| Rental | `View_MC_Receipt_List` (`,CB_Receipt.IsGiroReceipt`) | `McAccount/ARFeeList.aspx.cs` (OnInit) |
| Other Receivable | `View_CB_ReceiptOfOtherDebtor` | `AccountReceivable/OtherReceiptList.aspx.cs` (Page_Load) |
| Property Sales | `View_PS_cbReceiptList` | `PSAccount/ARReceiptList.aspx.cs` (class bên trong tên `PSAccount_ARDepositList`; `BuildListData` có 2 nhánh: mở trang và Search) |

- Không lọc bằng subquery ở trang: SP phân trang `Prc_splitpage` không xử lý được (xem file reference).
- Không lọc trong WHERE của view chuẩn: `View_PM_Receipt` còn là `BseReadTable` của `PM.ARFeeNO` / `PM.ARPreReceiptDelete` (form View, màn xoá) → phiếu GIRO sẽ không mở xem được.
- Trang `PSAccount/ARReceiptList_SDPB.aspx` (view `View_PS_cbReceiptList_SDPB`) là customize SDPB, LKHS không dùng → không sửa.

## 5. Bước 7 — GIRO Batch (LKHS-325)

### 5.1 DB (Stanley duyệt 02/11)
- `CB_ReceiptGroup` (CBReceiptGroupID, GroupNo [DocCode 316_ReceiptGroup, 5 số], DocumentDate (Payment Date, D08), RecordType 'GIRO', RecordStatus, CompanyID, BankAccountID, Filename, ReferenceNo, PurposeCode, CurrencyID, 4 cột chuẩn).
- `CB_ReceiptGroupDetail` (ReceiptGroupID, ReceiptID, RecordStatus, **ReturnReason**).
- `CB_ReceiptGroup_AuditLog` (ReceiptGroupID, ProcessUserID, ProcessDateTime, Action, Remark).
- `CB_Receipt.GroupNo`, `CB_Receipt.GIRORecordStatus`: **Generated → Exported → Success / Failed**, hoặc **Cancel** (huỷ trước khi vào batch).
- `CB_ReceiptGroup.RecordStatus` (hằng số trong `GIROBatchService`): **Exported** → **Completed** (sau Import) hoặc **Cancel** (Reset).
- View: `View_CB_Receipt_GIRO` (có `a.IdentityNo` cho D35), `View_CB_ReceiptGroup_GIRO` (SQL thường, `CreatedBy = COALESCE(View_CF_User.UserName, CF_User.LoginName)`), `View_AC_Receipt` (thêm `IsGiroReceipt/GroupNo/GIRORecordStatus` vào cả 4 nhánh UNION; sửa lỗi ngắt dòng 255 ký tự của `sp_helptext`).

### 5.2 Màn hình và luồng
- **Collection Verification** (`CashFlow/ACReceiptVerify.aspx`, file chuẩn → patch `PATCH_LKHS-325_ACReceiptVerify.md`, mục 1–9): criteria/cột IsGiroReceipt, GIRO Batch No, GIRO Status (Sys_Select `CB.GIROYesNo`, `CB.GIROReceiptStatus`); Verify / Verify All bỏ qua phiếu GIRO; nút **GIRO Batch Generation**, **GIRO Batch Listing**, **GIRO Cancel** (WebMethod `GIROCancelReceipt`, JS `f_GIROCancel`, `OnBeforeMenu` bật khi phiếu tick là GIRO Generated).
- **GIRO Batch Generation** (`ARGIROBatchGenerate.aspx` + `ARGIROBatchGenerateDetail.aspx`): popup mở trống, user chọn Bank → grid phiếu GIRO `Generated` của bank đó → tick → nhập Reference No (D34), Payment Date (D08), Purpose (D43) → Save: GroupNo mới, batch Exported, phiếu Exported + GroupNo, ghi file UFF vào `ARExportPath` (ghi lỗi → rollback, không tạo batch), audit log. Reference No / Payment Date **không ghi đè** lên phiếu. Lỗi ghi file (vd path không tồn tại: "The device is not ready") hiện popup và không tạo batch; 19/11 sửa popup không hiện khi thông báo lỗi có xuống dòng (helper `JsMessage` trong `ARGIROBatchGenerate.aspx.cs`, cùng fix ở `ARGIROCollectionGenerate.aspx.cs`).
- **File UFF gom theo DEBTOR**: mọi phiếu của 1 debtor trong batch = 1 dòng (cộng tiền, D64 = danh sách invoice). Tên file: `UFF_COL_<OrgID>_<BatchID 5 số>_<yyyyMMddHHmmss>.csv`.
- **GIRO Batch Listing** (`ARGIROBatchLst.aspx`): hiện tất cả batch của company (Exported lên đầu); nút chỉ sáng khi tick đúng 1 batch Exported. Wording theo Stanley: **Import (Reject)**, **Import (Success)**, **Reset**. Popup URL có tham số `t=` timestamp để tránh cache.
  - **Reset**: batch Cancel (ẩn khỏi xử lý), phiếu về Generated, xoá GroupNo.
  - **Import (Success)**: không cần file (Stanley: DBS không trả file khi thành công hết) → mọi phiếu của batch Verified (verify chuẩn, không Bank-In) + Success.
  - **Import (Reject)**: màn Upload (`ARGIROBatchImport.aspx`) liệt kê file trong `ARImportPath` (mới nhất lên đầu) → chọn → **Verify** mở Pre-Check (`ARGIROBatchPreCheck.aspx`: grid phiếu + GIRO status + Return Reason, lỗi màu đỏ) → **Confirm** (WebMethod trả `OK|msg` / `ERR|msg`): dòng Failed → Cancel phiếu theo module + `GIRORecordStatus='Failed'` + `CB_ReceiptGroupDetail.ReturnReason`; dòng không có trong file → Verified + Success. Tên file **không** phải chứa Batch ID (Stanley).
- **File kết quả DBS** (CSV, chỉ chứa giao dịch bị reject): khớp theo **Account number (D16)**; Reject Reason → ReturnReason; tách tiền dạng `3167.43(SGD)`; báo lỗi khi TK dạng `E+` (Excel làm mất số). Parser: `GIROReturnFileDbs.cs`.
- **GIRO Cancel** (Collection Verification): chỉ phiếu `IsGiroReceipt='Y'`, Generated, chưa vào batch, Active → cancel theo module, `GIRORecordStatus='Cancel'`, audit 'Cancel'. Phiếu thu tay bị chặn.

### 5.3 Cancel phiếu theo module (`IGIROModuleHandler.CancelReceipt`, chạy trong transaction GIRO)
| Module | Logic (copy từ màn xoá/void của module) |
|---|---|
| Rental | `ArCharge.CancellationCB_Receipt(...)` (như `McAccount/ArReceiptDelete.aspx`): phiếu Voided, bill += AllocAmt, allocation Inactive |
| Other Receivable | SQL như `AccountReceivable/OtherReceiptDelete.aspx`, **sửa trả balance = tổng AllocAmt theo từng bill** (13/11) |
| Construction | Riêng: phiếu Voided + void info, allocation Active → Inactive, balance = DocumentAmt − tổng AllocAmt Active (không gọi `ARVoidTransaction.CancelReceipt` của trang `ARReceiptList`) |
| Property Sales | Như `PSAccount/ArReceiptDelete.aspx.cs`: kiểm tra `AccountSetting.GetAccountMinDate` (VoidDateErr) và refund; phiếu Voided, AllocBalance 0, bill += tổng BaseAmt; allocation Inactive |

### 5.4 Class thuần (không DB)
- `GIROUffDbs.cs`: build file UFF (header H01–H05, detail 68 field D01–D68, trailer), validate gom lỗi 1 lần (Org ID/Name, TK bank, currency, Ref ≤35, Purpose ≤4, TK debtor trống/trùng giữa 2 debtor, SWIFT, Identity No D35, tiền ≤0). `FormatBatchID`: GroupNo phải là số 1–99999.
- `GIROReturnFileDbs.cs`: parse CSV kết quả + `Match()` với dòng đã xuất.

## 6. Forex gain/loss (phân tích 09–13/11)

- Cơ chế realized forex chuẩn của IFCA SG (LKHS-230, OR Collection): bill ngoại tệ thu ở tỷ giá khác → 2 dòng `AR_Allocation`: dòng chính (AllocAmt = amt, BaseAmt = round(amt × tỷ giá bill), ExchangeRate = tỷ giá bill) + dòng chênh lệch (AllocAmt 0, BaseAmt = round(amt × tỷ giá thu) − BaseAmt chính, ExchangeRate = tỷ giá thu). GL (`View_GL_ReceiptItemsF`, `View_GL_ForexGainOrLoss`, `GLArAllocationRealizedImporterSG`) đọc chung cho mọi ReceiptType → không cần sửa GL. Chi tiết: file reference.
- Data LKHS (12/11): bill ngoại tệ có ở CF_Client (Construction) 123 AUD + 1 USD, CF_Company (OR) 6 AUD; Rental và PS = 0. Ví dụ test: debtor 812 (Construction), bill SI103389 (AUD 1.0236, bal 28.71), SI103200 (0.9867, 10.24), SI103046 (1.0821, 10.19).
- **Đã làm (13/11, LKHS-320, `GIROModuleHandlers.cs` / `GIROPropertySalesHandler.cs`):**
  - Công tắc `GIROForexSetting.EnableForexRow` (`static readonly`, **mặc định false** = mỗi module giữ logic màn gốc). `true` = Rental và Construction dùng hàm chung `InsertAllocationWithForex` (kiểu LKHS-230, BaseAmt làm tròn 2 số). Sửa thẳng trên server, App_Code tự compile lại.
  - OR CancelReceipt: trả balance = tổng AllocAmt theo bill (CROSS APPLY), luôn bật.
  - PS: chặn bill ngoại tệ ("Property Sales bill in foreign currency is not supported by GIRO (...)") vì BL `AddCBAndBill` dùng tiền quy đổi cho balance bill, AllocBalance phiếu và AllocAmt (sai cả ở màn PS chuẩn). `GetBaseCurrencyID` đổi `protected` → `internal`.
- **Chờ Stanley** (câu hỏi đã gửi trong tin cập nhật tiến độ 16/11): GIRO bank có ngoại tệ không? Rental/Construction có theo LKHS-230 không (Rental màn chuẩn ArFeeAdd2 ghi dòng chính theo tỷ giá thu, khác LKHS-230)? Tỷ giá theo ngày Generate hay Payment Date? → Stanley đồng ý thì bật `true` + test debtor 812; không thì giữ `false`.
- Rủi ro ghi nhận: Rental Cancel dùng SQL chuẩn `CancellationCB_Receipt` (UPDATE…FROM) có thể trả balance sai nếu sau này có 2 dòng allocation/bill. Màn Delete chuẩn của OR cũng có cùng rủi ro (có thể báo IFCA).

## 7. Đã test

- Bước 6 cả 4 module (local 07–12/10): Rental `S36/CT/OR/26-1092/1093/1095`, OR `S46/AR/OR/26-0005`, PM `HTHREE/CM/COR/26-0002`, PS `S43/CT/OR/26-0299`.
- Bước 7 với Rental: batch 00001/00002 Reset, 00003 Complete (05/11); batch 00005 Import Reject: phiếu 90375 Verified/Success, 90376 Voided/Failed, bill 26-1038 balance trả về 41.75.
- Collection Verification GIRO Cancel: `S36/CT/OR/26-1097` → Voided + status Cancel; phiếu thu tay `S36/CT/OR/26-0281` bị chặn.
- 09/11: Gunner restore DB mới nhất, deploy LKHS-326 + package theo cấu trúc TFS mới từ đầu → OK.
- 16/11: ẩn phiếu GIRO ở list 4 module OK.

## 8. Việc còn lại (18/11)

1. Test Failed/Cancel cho Other Receivable, Construction, Property Sales (tạo phiếu GIRO, Import Reject 1 dòng Failed, GIRO Cancel 1 phiếu; kiểm tra Voided, balance bill, không hiện ở list module).
2. Test thư mục UNC (share từ DB server sang app server) cho Save batch và màn Import.
3. Regression bản forex 13/11 với bill SGD (nếu chưa test).
4. Chờ Stanley: câu hỏi forex (mục 6) + câu hỏi lãi trả chậm / field để trống (mục 3).
5. Đóng task: zip cuối LKHS-320 / LKHS-325 (hỏi Gunner trước), note Jira tiếng Anh, cập nhật `ticket-index.md` + `ifca-domain-reference.md`.
- Để sau: cây Company lọc `AllowGiroProcess`; nút Listing tự lọc theo batch của phiếu đang tick; trang `_SDPB` của PS.

## 9. Package / source (bản trong claude.ai Project)

- Thư mục `claude/LKHS-271-src/`: `App_Code/GIROCode/*.cs`, `CashFlow/ARGIRO*.aspx(.cs)`, `SQL/` (script đánh số 01–13, 98 test data server), `gen/gen*.py` (sinh script config Sys_), `ORIGINAL/` (bản gốc file chuẩn đã đọc: McAccount/PMReceivable/PSAccount/AccountReceivable delete/list, CashFlow/ACReceiptVerify, SQL View_AC_Receipt / View_GL_*, GL/*.cs SG importer), `DOC/` (spec Batch v01.00/v01.01).
- Ghi chú package: `PACKAGE_TFS_LKHS-320_325.md` (mapping script đánh số → file TFS, prerequisite, change log, rule), `PACKAGE_README_LKHS-320.txt`, `PACKAGE_README_LKHS-325.txt`, `SQL_TFS_RUN_ORDER.txt`, `PATCH_LKHS-325_ACReceiptVerify.md`, `PATCH_LKHS-320_HideGIRO.md`, `TEST_FULL_FLOW_LKHS-271.md`.
- Zip gần nhất: `LKHS-271_TFS_LKHS-320_LKHS-325.zip` (cấu trúc `LKHS-320/` và `LKHS-325/`, mỗi cái có `Database/<folder TFS>` + `Web/App_Code` + `Web/CashFlow`). View 4 module (mục 4) do Gunner tự ALTER file view có sẵn trên TFS, không gen trong package.
- Trong Claude Code: làm việc trực tiếp trên source LKHS ở máy (App_Code/GIROCode, CashFlow/ARGIRO*), không cần bản copy trong Project.
