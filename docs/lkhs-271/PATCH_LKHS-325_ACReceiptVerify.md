# LKHS-325: sửa tay màn Collection Verification (`CashFlow/ACReceiptVerify.aspx` + `.aspx.cs`, file STANDARD)
Đã áp dụng trên source LKHS — đọc code thật trong source (tìm comment `LKHS-325 GIRO`). Bản đầy đủ có code: claude.ai Project `claude/LKHS-271-src/PATCH_LKHS-325_ACReceiptVerify.md`.
Chỉ THÊM code, không xoá/đổi dòng cũ; tìm theo dòng mốc.

| # | File | Dòng mốc | Thêm gì |
|---|---|---|---|
| 1 | .aspx.cs `ReceiptVerify` | sau `string selectReceiptIDs = str[1];` | chặn phiếu GIRO: STUFF/FOR XML lấy DocNo `IsGiroReceipt='Y'` trong ID chọn → trả `CB.GIRO_VerifyBlocked` + danh sách |
| 2 | .aspx.cs `VerifyAll(string filter)` | sau `string strMessage = ""; string strSql = string.Empty;` | `filter = "(" + filter + ") and CBReceiptID not in (select CBReceiptID from CB_Receipt where IsGiroReceipt = 'Y')"` (filter dùng cho cả check Cash Account và 2 UPDATE) |
| 3 | .aspx `OnBeforeMenu` | TRƯỚC `else if(pc[i] =="ItemProfile"||pc[i]=="VerifyAll")` | nhánh `GIROBatchGenerate` luôn sáng (không cần chọn dòng) |
| 4 | .aspx | TRƯỚC `function f_VerifyAll()` | `f_GIROBatchGenerate()` (cần CompanyID từ cây, mở `../CashFlow/ARGIROBatchGenerate.aspx?CompanyID=`, 950x650) + `f_GIROAfterBatch()` (reload list theo CompanyID + payMethod, không message) |
| 5 | .aspx `OnBeforeMenu` | sửa nhánh mục 3 | `GIROBatchGenerate||GIROBatchListing` |
| 6 | .aspx | trước `f_GIROAfterBatch` | `f_GIROBatchListing()` mở `../CashFlow/ARGIROBatchLst.aspx?CompanyID=` 1100x600 |
| 7 | .aspx.cs | TRƯỚC `[WebMethod(true)] public static string VerifyAll` | WebMethod `GIROCancelReceipt(receiptIDs)` → `new GIROBatchService().CancelGeneratedReceipts(receiptIDs, CurrentUserId)`, catch `GIROException` trả message |
| 8 | .aspx | TRƯỚC `function f_VerifyAll()` | `f_GIROCancel()` (confirm `CB.GIROCancel_Confirm`) → `f_DoGIROCancel` (PageMethods) → `f_GIROCancelDone` (`refresh(result)`) |
| 9 | .aspx `OnBeforeMenu` + hàm | TRƯỚC nhánh ItemProfile/VerifyAll | nhánh `GIROCancel` sáng khi `f_GIROCanCancel(selectRowId)`: mọi dòng tick đều `isgiroreceipt='Y'`, `groupno` rỗng, `girorecordstatus='Generated'` (đọc cột grid → cần view `View_AC_Receipt` + config 13) |

Ghi chú: nút do script config tạo (08 Generate, 10 Listing, 11 Cancel `ContextMnuNo=GIROCancel`), `IsNeedPrivilege='N'`; nếu không hiện kiểm tra quyền menu `mcorp-15-07`. Cần chọn company trên cây trước. `OnBeforeMenu` chỉ chạy khi click dòng (AfterRowActivate), không khi chỉ tick — hành vi sẵn có, giữ nguyên. Server vẫn kiểm tra lại khi Cancel.
