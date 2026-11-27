# LKHS-271 — AR GIRO Collection (DBS) — HANDOFF sang Claude Code (19/11/2026)

> ĐỌC FILE NÀY TRƯỚC khi làm tiếp bất cứ gì của LKHS-271 / LKHS-320 / LKHS-325 / LKHS-326.
> Đây là Jira lớn ĐANG LÀM DỞ — tiếp tục đúng trạng thái dưới đây, KHÔNG làm lại từ đầu, KHÔNG đổi quyết định đã chốt.
> Tài liệu nghiệp vụ đầy đủ: `docs/tickets/LKHS-271-ar-giro-collection-dbs.md` (spec bước 6, quyết định, lịch sử).

## 1. Cấu trúc Jira
| Jira | Nội dung | Trạng thái 19/11 |
|---|---|---|
| **LKHS-271** | Jira cha: SG Localization — AR Collection GIRO cho DBS, 4 module: Rental, Other Receivable (OR), Construction (PM), Property Sales (PS). Business owner **Stanley**; consultant **Valerie** (làm việc với EU/DBS) | Đang làm |
| **LKHS-320** | Sub-task bước 6: **Generate GIRO Collection** (menu `Cash-03-20`, Cash Management > Receipt) + **ẩn phiếu GIRO khỏi list Collection của 4 module** + **forex gain/loss** cho GIRO | Xong, deploy LKHS_Test (changeset 99415). Ẩn list xong & test 16/11. Forex: code có cờ (xem §3) |
| **LKHS-325** | Sub-task bước 7: **GIRO Batch** — Batch Generation (file DBS UFF), Batch Listing (Reset / Import (Reject) / Import (Success) / Close), Upload → Pre-Check → Confirm, Cancel Receipt Action (4 module), Collection Verification (cột/criteria GIRO, nút Cancel, chặn Verify) | Đang hoàn thiện (Gunner tập trung tuần này) |
| **LKHS-326** | Jira của Stanley: Number Structure DocCode `316_ReceiptGroup` (Cash Management > Receipt Group No) | Phải deploy TRƯỚC LKHS-325 |
| (sub-task 271, chờ JiraID) | AR GIRO Status Report (spec mục 8) — ReportNo `CBGIRO01`, Cash Management > Cashiering Report | 25/11: chạy OK trên LKHS_Train (Gunner). File ở `work\LKHS-271\`: `Views\View_CB_GIROStatusReport.sql`, `Update Script\UpdateScript_CB_GIROStatusReport.sql`, `CB_GIROStatusReport.rdl` (v4, lịch sử `_versions\log.md`). Còn: đổi comment `LKHS-271 GIRO Report` → JiraID, test Failed/Cancel/Reset/nhiều batch, ghi docs ticket |

Master setup (Company Structure GIRO, Cash Book, debtor 4 module, dropdown SWIFT/Purpose) do Nurul giao ban đầu, sau Stanley làm — không thuộc phần của Gunner ("core module").

## 2. Quyết định đã chốt (KHÔNG đổi)
- LKHS chạy nhánh TFS riêng (Train `Dev\BRANCHES\NET4.0_SG`, Live `Rel\IFCA.NET 4.0_SG`) → GIRO là improvement trên nhánh LKHS, **không hậu tố `_LKHS`**, sửa thẳng standard của LKHS.
- Chỉ DBS (1 AR GIRO bank / company trước mắt); master lưu bảng **`CF_CompanyGiroBank`** (hỗ trợ nhiều bank/company).
- Stanley 12/10: Generate All theo filter của list (bỏ Processing Date); cột mới `CB_Receipt.IsGiroReceipt`.
- Stanley 02/11: duyệt bảng `CB_ReceiptGroup`, `CB_ReceiptGroupDetail` (+ReturnReason), `CB_ReceiptGroup_AuditLog` + `CB_Receipt.GroupNo`, `CB_Receipt.GIRORecordStatus` (kèm cột đề xuất thêm). File export **1 dòng / debtor**; DBS trả **1 file/batch chỉ gồm giao dịch fail**, còn lại = success (auto Verification). Batch ID ở phần cuối tên file trả về (tạm, Valerie confirm); case file rỗng chờ Valerie.
- Gom phiếu: **1 phiếu / Module + Debtor + Currency**, thu **đủ balance**, theo logic màn thu tiền chuẩn của từng module.
- Payment Date / Reference No nhập ở bước 6 **không bị bước batch ghi đè** (Reference No / Payment Date / Purpose ở popup batch chỉ đi vào file).
- D35 DDA Reference = `CF_Account.IdentityNo`; thiếu → **chặn tạo batch** (`AllowBlankIdentityNo = false`).
- GIRO Status: Generated / Exported / Success / Failed / Cancel (dùng "Success", không "Completed" cho phiếu). Batch: Exported / Cancel / Completed.
- Rental GIRO giữ ReceiptType **`MC_Fee`** (như Rental Collection > Receivable), không `MC_Payment` như doc.
- Cây Company **chưa lọc** AllowGiroProcess (làm sau nếu cần).
- Stanley 16/11: ARExportPath / ARImportPath = **folder local trên server**, map ổ đĩa trên PC user (user upload tay lên DBS portal). Không FTP, không API. Setup nhập **path server**, app pool cần quyền đọc/ghi.
- Cancel/Void phiếu Failed hoặc GIRO Cancel: **tái hiện logic void của từng module TRONG transaction GIRO** (`handler.CancelReceipt(tran, GIROCancelContext)`), không gọi màn hình thật (transaction riêng / entity không fetch / rule chặn ở màn hình). Chi tiết: `VOID_FUNCTIONS.md`.
- Phiếu GIRO ẩn ở list Collection 4 module: thêm cột `IsGiroReceipt` vào view list + lọc phẳng ở page `isnull(IsGiroReceipt,'N') <> 'Y'` (không subquery vì `Prc_splitpage`). Chi tiết: `PATCH_LKHS-320_HideGIRO.md`.
- Verify / Verify All không áp dụng cho phiếu GIRO — chỉ Verify qua Import.
- Forex: **Stanley đã xác nhận** realized forex gain/loss (theo logic OR Collection **LKHS-230**) áp cho GIRO cả 4 module, gộp vào LKHS-320. Phân tích: GL importer không phụ thuộc module → chỉ cần sửa allocation handler **Rental + Construction**; OR đã đúng; PS chưa có data ngoại tệ Live → hoãn (PS bill ngoại tệ đang bị chặn vì PS BL `AddCBAndBill` dùng số đã quy đổi).
  - Code 13/11: `GIROModuleHandlers.cs` có `GIROForexSetting.EnableForexRow` (mặc định false = hành vi cũ; true = Rental/Construction allocate theo rate bill + dòng forex, helper `InsertAllocationWithForex`); OR CancelReceipt trả balance = sum(AllocAmt) theo bill.
  - Câu hỏi còn mở với Stanley: GIRO bank ngoại tệ? rate lấy ngày Generate hay Payment Date? Lãi trả chậm không tính lại tới Payment Date (đang tạm giữ).

## 3. Việc còn mở (làm tiếp từ đây)
1. **Forex Rental / Construction**: bật/hoàn thiện `EnableForexRow` theo kết luận Stanley, test với bill ngoại tệ (đối chiếu LKHS-230 OR Collection).
2. **Test lại Cancel + Confirm-with-Failed** cho 3 module ngoài Rental (OR, Construction, PS) — Rental đã test kỹ. Kịch bản: `TEST_FULL_FLOW_LKHS-271.md`.
3. PS test cần company khác có bill PS (vd S43) + setup GIRO bank company đó (company 195 không có bill PS).
4. Câu hỏi business còn chờ: phạm vi report (mục 8 → Jira riêng), path/FTP production chi tiết, filter GIRO status trên cây company, case file reject rỗng, vị trí Batch ID trong tên file trả về.
6. **Danh sách thay đổi chờ làm gộp 1 lần (Gunner: tổng hợp rồi mới sửa)** — source local `E:\IFCA Software\LKHS_Train`:
   - (25/11, Stanley chốt) **DBS Batch ID (D07) + số trong tên file UFF = `CB_ReceiptGroup.CBReceiptGroupID`** (identity, chung mọi company, pad 5 số), không còn lấy `GroupNo` → `316_ReceiptGroup` được format tự do. Sửa `GIROBatchService.cs` (~160–214): validate/build file trước (BatchID tạm) → insert `CB_ReceiptGroup` → build lại D07 + `MakeFileName` theo ID → update `Filename`; vẫn 1 transaction, lỗi rollback. `GIROUffDbs.FormatBatchID` nhận ID (>99999 → chặn). Sửa comment `GIROUffDbs.cs:37`, message D07 `GIROUffDbs.cs:217`. **25/11 ĐÃ SỬA local LKHS_Train** (comment `LKHS-325 BatchID`), note áp TFS: `work\LKHS-271\GIROCode\CHANGES_LKHS-325_BatchID.md` — **Gunner test OK local 25/11** (batch tạo được với GroupNo có prefix, file `_000NN_` = ID), Gunner tự báo Stanley + commit TFS. TFS Dev SG: so `GIROBatchService.cs` + `GIROUffDbs.cs` ngày 2026-11-25, mức A → bản trước sửa (_ORIG) giống hệt TFS.
   - (27/11 consultant feedback T1, **CHỐT**) Tên file + **hiện đủ tên file trên màn hình** (không bị cắt: độ rộng cột Filename `Sys_ListDt` `CB.GIROBatchList` / popup). Chi tiết format ở dòng dưới. → **27/11 ĐÃ SỬA, test OK local, CS Dev SG 99795 (Rel SG chưa)** (`work\LKHS-271\CHANGES_LKHS-325_2026-11-27.md`)
   - (27/11 consultant T1, CHỐT) **Đổi nhãn "GIRO Batch Listing" → "GIRO Batch Reset / Import"** (CF_String của nút Collection Verification + tiêu đề trang `ARGIROBatchLst`; sửa script config 10/menu tương ứng). → **27/11 ĐÃ SỬA, test OK local, CS Dev SG 99795 (Rel SG chưa)** (`work\LKHS-271\CHANGES_LKHS-325_2026-11-27.md`)
   - (27/11 consultant T1, CHỜ Stanley) **Phiếu GIRO Rental không hiện ở RM > AR Trx > Receivable** (ảnh: search Receipt No `S36/CT/OR/26-1093` → rỗng; consultant muốn thấy phiếu ở màn thu tiền của module) — NGƯỢC quyết định đã chốt (ẩn phiếu GIRO ở list Collection 4 module, `PATCH_LKHS-320_HideGIRO.md`). Nếu hiện lại: cần chặn Edit/Delete/Void phiếu `IsGiroReceipt='Y'` ở màn module (đi qua GIRO Cancel), và áp cả 4 module?
   - (27/11 consultant T1, CHỐT) **Nút Cancel (Collection Verification) phải mờ trừ khi phiếu Generated chưa vào batch.** Ảnh T1: phiếu `S36/CT/OR/26-1093` đã ở batch 00002 (Exported, ref PLSAPR26) mà nút Cancel vẫn sáng khi tick. Server đã chặn (`CancelGeneratedReceipts`) nhưng UI chưa: `f_GIROCanCancel` chỉ chạy trong `OnBeforeMenu` (click dòng), không chạy khi tick checkbox / lúc load. Sửa: mặc định disable + đánh giá lại khi tick / tick-all (`ACReceiptVerify.aspx`, xem `PATCH_LKHS-325_ACReceiptVerify.md` mục 9). → **27/11 ĐÃ SỬA, test OK local, CS Dev SG 99795 (Rel SG chưa)** (`work\LKHS-271\CHANGES_LKHS-325_2026-11-27.md`)
   - (27/11, consultant hỏi, CHỐT ở dòng T1 trên) **Tên file UFF** đổi từ `UFF_COL_<OrgID>_<BatchID 5 số>_<yyyyMMddHHmmss>.csv` sang `<yyyyMMddHHmm>_<OrgID H03>_<Purpose D43>_<RefNo D34>_<BatchID D07>.csv` (đề xuất consultant, không có trong spec v01.01). Chỉ sửa `MakeFileName` (`GIROBatchService.cs` ~670) + chỗ gọi; Reference No phải lọc ký tự không hợp lệ trong tên file (`/ \ : * ? " < > |`). — **ĐÃ SỬA 27/11** (xem dòng T1)
   - (27/11, CHỐT) **GIRO Batch Listing: ô search Status (và Currency) dạng dropdown**. Lỗi gặp 27/11: consultant tự đổi `Sys_Filter` (`CB.GIROBatchList`: Currency `FltType` S→L2, RecordStatus `FltDisMode` 0→1) → `Invalid column name 'RecordStatusStringCode'` khi mở trang (framework đọc `<FltName>StringCode` từ `View_CB_ReceiptGroup_GIRO`). Cách làm thật: KHÔNG thêm cột view — dùng kiểu dropdown như GIRO Status Collection Verification (`Sys_BaseDt` L3 + `BdtSelNo` → `Sys_Select`, `Sys_Filter` L3/FltDisMode 1). Xem lại list GIRO khác (PreCheck `GIROStatus`, BatchDetail) có cần dropdown tương tự không. → **27/11 ĐÃ SỬA, test OK local, CS Dev SG 99795 (Rel SG chưa)** (`work\LKHS-271\CHANGES_LKHS-325_2026-11-27.md`)
   - (27/11, **consultant đồng ý — CHỐT**) **Collection Verification: bỏ Failed + Cancel khỏi dropdown GIRO Status** (chỉ còn All / Generated / Exported / Success) — 2 trạng thái này phiếu đã Voided nên list không bao giờ hiện. Tìm nguồn dropdown (Sys_Filter / danh sách giá trị) trước khi sửa. → **27/11 ĐÃ SỬA, test OK local, CS Dev SG 99795 (Rel SG chưa)** (`work\LKHS-271\CHANGES_LKHS-325_2026-11-27.md`)
5. Fix 19/11 (đã làm): popup lỗi không hiện khi message có CR/LF (`IOException 'The device is not ready.\r\n'`) — LKHS-325 `ARGIROBatchGenerate.aspx.cs` helper `JsMessage` (bỏ CR/LF, tách `<br>`, escape); LKHS-320 `ARGIROCollectionGenerate.aspx.cs` bỏ CR/LF ở cả 2 catch. Lỗi gốc "device is not ready" = path Export không tồn tại/không có quyền trên server.

## 3b. Q&A Stanley đã trả lời (25/11) — hành vi hiện tại, đừng tra code lại
- Generate GIRO Collection list rỗng (`where 1=2`): list lọc theo bank chọn ở cây **Bank Selection**; chưa chọn bank → 1=2. Test: company 195 (S36) chọn DBS1/003-922390-0 (NEW) = bank 588.
- Lỗi "GIRO Batch No ... not valid for DBS Batch ID (D07)": trước đây D07 = GroupNo phải 5 số → nay D07 = `CBReceiptGroupID` (đã sửa, mục 6).
- Lỗi "Bank SWIFT Code is empty": D21 bắt buộc SWIFT BIC ngân hàng debtor = GIRO Bank ở debtor profile, map Dropdown List > Bank SWIFT Code (SWIFT lưu `TitleCN`).
- Export folder không tồn tại / không quyền: KHÔNG tự tạo folder; popup lỗi (path + lỗi Windows), rollback toàn bộ (không batch, không file, phiếu giữ Generated). Path rỗng → chặn trước. (`GIROBatchService.cs` ~124, ~221–250)
- Ghi chú Stanley test 25/11 (LKHS_Test): mới Generate batch OR ở company 195 + 184; chưa test Import/Pre-Check/Confirm/Reset/Cancel và 3 module còn lại. Company 184 số phiếu OR `S01/AR/OR/-0008` thiếu năm (Number Structure OR Receipt của 184, không phải GIRO) — chưa báo Stanley.
- Trạng thái phiếu GIRO (chat 27/11): Generated = Active/Generated; Exported = Active/Exported; Reset = Active/Generated; Import success = Verified/Success; **Import reject = Voided/Failed (+ reason, void ngay lúc Import, allocation trả lại bill)**; GIRO Cancel = Voided/Cancel. Collection Verification không hiện phiếu Voided → Failed/Cancel chỉ xem ở AR GIRO Status report (hoặc batch detail).
- Ngày 26/11: chờ Stanley phản hồi thêm → gom thay đổi vào mục 6 rồi sửa 1 lần.

## 4. Source code ở đâu
- **Source local Claude Code đọc/sửa: `E:\IFCA Software\LKHS_Train`** (`App_Code\GIROCode\`, `CashFlow\ARGIRO*`). File GIRO ở đây = bản trong zip Gunner gửi = bản trên TFS (Gunner xác nhận 25/11) → không cần nhắc get latest cho các file GIRO.
- Bản mới nhất mọi file GIRO (Claude viết) + bản gốc standard đã tham chiếu nằm ở **claude.ai Project `claude/LKHS-271-src/`** và đã được Gunner deploy vào source LKHS (TFS nhánh LKHS) + gói `LKHS-271_TFS_LKHS-320_LKHS-325.zip`.
- Trong Claude Code: chạy `claude --add-dir <đường dẫn source web LKHS>` và đọc trực tiếp các file dưới đây (đó là nguồn sự thật, không dựa trí nhớ):
  - `App_Code/GIROCode/`: `GIROCollectionGenerator.cs`, `GIROModels.cs`, `GIROModuleHandlers.cs` (Rental/OR/Construction + CancelReceipt + forex), `GIROPropertySalesHandler.cs`, `GIROBatchService.cs`, `GIROUffDbs.cs` (UFF 68 field), `GIROReturnFileDbs.cs` (parse file trả về)
  - `CashFlow/`: `ARGIROCollection*.aspx(.cs)` (5 trang bước 6), `ARGIROBatchGenerate(Detail)`, `ARGIROBatchLst`, `ARGIROBatchImport`, `ARGIROBatchPreCheck` (bước 7), `ACReceiptVerify.aspx(.cs)` (standard, đã sửa tay theo `PATCH_LKHS-325_ACReceiptVerify.md`)
  - Standard đã sửa cho ẩn list: `PMReceivable/ARReceiptList.aspx.cs`, `McAccount/ARFeeList.aspx.cs`, `AccountReceivable/OtherReceiptList.aspx.cs`, `PSAccount/ARReceiptList.aspx.cs` + 4 view list.
  - SQL: xem `SQL_TFS_RUN_ORDER.txt` (19 object, tách 1 file/object).
- **Khuyến nghị Gunner**: copy gói zip mới nhất (`LKHS-271_TFS_LKHS-320_LKHS-325.zip`) vào `docs/lkhs-271/package/` để Claude Code có đúng bản giao gần nhất khi cần tạo lại package.

## 5. Quy tắc riêng của Jira này (Gunner)
- SQL IFCA viết tĩnh như view standard; **không dynamic SQL / dò cột runtime**. Không chắc cột → đưa query kiểm tra trước.
- **Không thêm cột/bảng DB** khi chưa bàn với Gunner (Sys_ config + CF_String cho UI thì được).
- Sửa nhỏ gộp vào package đang làm, **không gửi mini zip**; **hỏi trước khi gửi zip "final"**. Package nhóm theo Jira (LKHS-320/, LKHS-325/), README rõ file mới vs file sửa tay.
- File standard có sẵn: đưa **hướng dẫn sửa theo dòng mốc** (comment `LKHS-325 GIRO` / `LKHS-271 GIRO`), không gửi nguyên file thay thế. File mới thì gửi nguyên file.
- Config script Sys_/CF_String re-runnable (IF EXISTS DELETE → INSERT VALUES), sửa thẳng script chính khi cần chỉnh. Không script gán menu vào Menu Template.
- Tin nhắn cho Stanley: tiếng Anh **ngắn, chỉ hỏi**, bám đúng điểm Stanley vừa nêu, không nói "tôi sẽ làm gì".
- Gunner **chưa từng nói** cả 4 module phải theo LKHS-230 (LKHS-230 chỉ là forex OR Collection) — việc áp forex cho 4 module là do **Stanley xác nhận** sau đó.

## 6. File trong thư mục này
| File | Nội dung |
|---|---|
| `00-HANDOFF-LKHS-271.md` | File này |
| `TEST_FULL_FLOW_LKHS-271.md` | Nghiệp vụ GIRO (A1–A9) + kịch bản test full luồng 4 module + query kiểm tra |
| `SPEC_GIRO_Batch_v01.01.md` | Spec Stanley bước 7 (v01.01, 06/11) — bảng, màn hình, action |
| `PACKAGE_TFS_LKHS-320_325.md` | Cấu trúc package TFS, mapping script, change log sau 09/11, prerequisite |
| `SQL_TFS_RUN_ORDER.txt` | Thứ tự chạy 19 object SQL |
| `PACKAGE_README_LKHS-320.txt`, `PACKAGE_README_LKHS-325.txt` | README 2 gói |
| `PATCH_LKHS-320_HideGIRO.md` | Sửa ẩn phiếu GIRO ở 4 list module |
| `PATCH_LKHS-325_ACReceiptVerify.md` | Sửa tay Collection Verification (mục 1–9) |
| `VOID_FUNCTIONS.md` | Logic void/cancel receipt chuẩn từng module + cách GIRO tái hiện |
