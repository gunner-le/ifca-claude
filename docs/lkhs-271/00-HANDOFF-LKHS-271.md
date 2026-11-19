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
| (sau) | AR GIRO Status Report (spec mục 8) | Jira riêng, chưa làm |

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
5. Fix 19/11 (đã làm): popup lỗi không hiện khi message có CR/LF (`IOException 'The device is not ready.\r\n'`) — LKHS-325 `ARGIROBatchGenerate.aspx.cs` helper `JsMessage` (bỏ CR/LF, tách `<br>`, escape); LKHS-320 `ARGIROCollectionGenerate.aspx.cs` bỏ CR/LF ở cả 2 catch. Lỗi gốc "device is not ready" = path Export không tồn tại/không có quyền trên server.

## 4. Source code ở đâu
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
