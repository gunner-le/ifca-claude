# Đề xuất sửa tận gốc các lỗi lặp lại (để trao đổi với Stanley)

> Mỗi mục: lỗi lặp lại ở nhiều ticket → hiện đang patch từng lần → đề xuất sửa 1 lần ở bản standard (TFS). Khi gặp ticket mới thuộc 1 nhóm dưới đây: xử lý ticket như thường, và nhắc Gunner mục này.

## 1. Tax Adjustment Journal "Posted" nhưng không có dòng GL
- Ticket: LKHS-196, 270, 311, 317, 319, 335 (≥6 lần). `GL_VoucherMain` 'Accounted' nhưng 0 dòng `GL_Voucher`; PM_LedgerMain có thể kẹt 'New'.
- Đang làm: patch header → user re-approve → re-post.
- Đề xuất: điều tra `TaxAdjustmentJournalVoucher.Approve()` / `PostProjectLedger()` — nghi exception bị nuốt giữa transaction (header commit, detail không). Thêm log + bọc 1 transaction.

## 2. JS đọc cột grid không có trên layout → nút toolbar mờ / script dừng
- Ticket: HARIANPG-45, 46, FPARK-214, CMSD-60, (CMSD-61?), FPARK Auto Reversal (TaxInvoice).
- Đang làm: bật cột trong List Layout / thêm config Sys_.
- Đề xuất: helper JS an toàn null trong framework (`gridManager2.GetValueByName` / `get_cellByColumnKey(...)` trả null thì dùng giá trị mặc định), hoặc server trả trạng thái nút thay vì đọc từ cột grid.

## 3. Bill Item bắt buộc bị Inactive → yellow page "no row at position 0"
- Ticket: SUMMERPG-20 (Compensate), JBTNPSB-19, SWCHENGLING-74.
- Đề xuất: kiểm `Rows.Count == 0` → thông báo rõ "Bill Item 'X' is inactive, please activate in Bill Item setup".

## 4. Lệch bản deploy (server ≠ TFS)
- Ticket: SWZECON-81→84 (fix chưa commit bị deploy đè), SWIBRACO-730 (DLL Live cũ), SWIBRACO-698 (deploy thiếu DB/DLL), LKHS-322 (DLL FA cũ), FPARK-197 (code cũ), CMSD (config lệch NAIM).
- Đề xuất quy trình: fix xong commit TFS trong ngày; mỗi lần deploy ghi changeset + danh sách file; định kỳ so DLL/ngày file server với TFS cho client lớn.
- Biến thể "lệch nhánh": fix ở nhánh Malaysia (`IFCA.NET 4.0`) không được port sang nhánh SG (`IFCA.NET 4.0_SG`) — LKHS-337 (RDL `PM_DebtorAgingSumByTrxDate` Owing trừ Unallocated). Đề xuất: khi sửa report/SP chuẩn ở 1 nhánh, ghi chú/kiểm file cùng tên ở nhánh còn lại.

## 5. Trigger `PREVENT_DUP_INSERT` trên AR_Trx
- Ticket: PALMINGTONPG-4, SUMMERPG-24 (nghi), cột mới bị NULL (IsRefundNote).
- Đề xuất: bỏ hẳn trigger ở bản standard hoặc viết lại (không INSTEAD OF, không danh sách cột cứng).

## 6. Sale đã Return/Cancel lọt vào letter/report
- Ticket: SWCHENGLING-66/72, NAIMCAP-972, ASPENPG-654, ASPENPG-671/684 (ngược lại: cần in sale Return).
- Đề xuất: thống nhất 1 điều kiện chuẩn trong view letter dùng chung, có tham số cho trường hợp cần in sale Return.

## 7. `alert('{0}')` không escape message lỗi → report trắng trang
- Ticket: PLBPG-62 (FileServer 503), SWHARTANAH-358 (tên employee có `'` → SQL lỗi trong FileServer).
- `Common/RdlCommControl.ascx.cs` catch khối Report History (và các `alert('" + ex.Message + "')`) nhét message thô vào JS → dấu `'`/xuống dòng làm vỡ script, user chỉ thấy trang trắng dù report đã render.
- Đề xuất: dùng `HttpUtility.JavaScriptStringEncode(ex.Message)` ở mọi chỗ `RegisterStartupScript` + `alert`; FileServer `GetFolderIdByPath` dùng parameter thay vì ghép chuỗi. (Nhánh Dev đã bỏ khối upload Report History — có thể chỉ cần deploy bản mới.)

---
## Draft gửi Stanley (EN, ngắn — Gunner chỉnh trước khi gửi)
Hi Stanley, while fixing recent tickets I noticed a few issues keep coming back across clients. Could we consider fixing them once in the standard version?
1. Tax Adjustment Journal posted without GL lines — happened 6 times at LKHS; we patch data each time. May I spend some time to find the root cause in the Approve/Post code?
2. Toolbar buttons disabled because a grid column is hidden in the list layout (HARIANPG, FPARK, CMSD). Could we make the JS null-safe in the standard page/framework?
3. Pages crash when a required Bill Item is inactive (Compensate etc.). Could we show a clear message instead?
Which of these would you like me to look at first?
