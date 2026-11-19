# CMSD-60 — PS Billing list: toolbar + chuột phải bị disable (lỗi JS thiếu cột e-Invoice)

## Ticket

Property Sales > Account Receivable > AR Transaction > Billing:
1. All functions disabled
2. Right click feature disabled

- Client: **CMSD** (clone từ NAIM, bản customize `_NAIMCAP`). Môi trường test: **CMSD_Train**. DB đối chiếu: **NAIM_PS_Live** (NAIM còn DB TC, không có list `_NAIMCAP`).
- Page: `ARChargeBillList_NAIMCAP.aspx` — `SysToolbar MenuNo="Sale-11-02" MenuClass="PS.BillList_NAIMCAP"`, `SysCondition` / `SysList2 LstNo="PS.BillNotPay_NAIMCAP"`.
- `Sys_Base` `PS.BillNotPay_NAIMCAP` → read/write `View_ps_BillNotPay`, `BseIdField = BillID`. `Sys_List` 1 dòng `LstOrder=1`, `LstDefault=Y`, tên "NOT EINV 10.01.2025" (giống hệt NAIM).

## Triệu chứng

JS `OnBeforeMenu()` (chạy khi chọn dòng) ném `Uncaught TypeError: Cannot read properties of null (reading 'get_value')` → dừng giữa chừng nên đoạn bật/tắt toolbar + context menu phía sau không chạy.

```js
RecordStatus = row.get_cellByColumnKey("RecordStatus".toLowerCase()).get_value();
taxcode      = row.get_cellByColumnKey("taxcode".toLowerCase()).get_value();
taxinvoice   = row.get_cellByColumnKey("taxinvoice".toLowerCase()).get_value();
einvoice     = row.get_cellByColumnKey("IsRequiredEInv".toLowerCase()).get_value();   // lỗi
eInvStatus   = row.get_cellByColumnKey("eInvStatus".toLowerCase()).get_value();       // lỗi
isEInvoice   = row.get_cellByColumnKey("iseinvoice") == null ? "N" : ...;             // có check null
```

`get_cellByColumnKey(key)` trả `null` khi grid không có cột key đó ở client.

## Điều tra

1. View `View_ps_BillNotPay` (CMSD) có đủ cột `TaxCode, TaxInvoice, IsRequiredEInv, eInvStatus, eInvStatusStringCode, IsEInvoice, eInvUniqueID, eInvVerifiedDate`.
2. Diff `Sys_ListDt` `PS.BillNotPay_NAIMCAP` NAIM_PS_Live ↔ CMSD_Train: CMSD là bộ cấu hình khác (có thêm Financier/Loan/UnitStatus/PrincipalAmt/TaxAmt/ProjectName), **thiếu 5 cột e-Invoice** NAIM có (`IsEInvoice, IsRequiredEInv, eInvStatusStringCode, eInvUniqueID, eInvVerifiedDate`). Không DB nào có `eInvStatus` trong `Sys_ListDt`.
3. Insert 5 dòng `Sys_ListDt` (LdtId 82046–82050) → grid **không** đổi. Liệt kê column key thực tế trên client:
   ```js
   // chạy trong Console, chọn đúng frame của trang (không phải "top"), đã chọn 1 dòng
   var r = gridManager2.GetSelectedRow(); var cols = r.get_grid().get_columns(); var keys = [];
   for (var i = 0; i < cols.get_length(); i++) keys.push(cols.get_column(i).get_key());
   console.log(keys.join(', '));
   ```
   Các key ẩn `billid, debtorid, saleid, taxid, taxinvoice` có mặt dù không nằm trong `Sys_ListDt` → đều là field `Sys_BaseDt` có `BdtLstDefault=1`, `BdtLstDisplay=0/NULL` (vì vậy dòng `taxinvoice` không lỗi).
4. `Sys_BaseDt` của base `PS.BillNotPay_NAIMCAP` bên CMSD **không có field e-Invoice nào**. Bên NAIM có đủ 6 (`eInvStatus` có sẵn `BdtLstDefault=1, BdtLstDisplay=0`; `IsEInvoice`/`IsRequiredEInv` `BdtLstDefault=1, BdtLstDisplay=1`). Insert 6 dòng `Sys_BaseDt` (BdtId 63432–63437, copy từ NAIM) → `einvstatus` xuất hiện ngay (cột ẩn), nhưng `isrequiredeinv`/`iseinvoice` vẫn chưa.
5. So thứ tự column key: NAIM theo đúng `LdtFldOrder` (layout default); CMSD thì không, và không có các cột mới thêm vào `Sys_ListDt` → CMSD đang render theo **layout cột lưu riêng của user** (lưu từ trước khi có field e-Invoice). Tick thêm cột "Required E-Invoice?" và "E-Invoice" trong layout → hết lỗi, toolbar + chuột phải hoạt động.

## Root cause

Gói clone NAIM → CMSD đưa sang **page/JS bản có e-Invoice** (`ARChargeBillList_NAIMCAP.aspx` đọc `IsRequiredEInv`, `eInvStatus`...) nhưng **cấu hình `Sys_` của list `PS.BillNotPay_NAIMCAP` vẫn là bản trước e-Invoice**: `Sys_BaseDt` thiếu 6 field e-Invoice và `Sys_ListDt` thiếu 5 cột. Grid không render các cột này → JS `get_cellByColumnKey(...).get_value()` lỗi null → `OnBeforeMenu()` dừng → toàn bộ nút toolbar và context menu không được bật. Ngoài ra layout cột cá nhân user đã lưu không tự có cột mới nên phải tick thêm.

## Fix (config, không sửa code) — đã chạy trên CMSD_Train

1. `Sys_BaseDt`: 6 field copy từ NAIM_PS_Live (`IsEInvoice, IsRequiredEInv, eInvStatus, eInvStatusStringCode, eInvUniqueID, eInvVerifiedDate`), giữ nguyên giá trị NAIM. Script sinh từ NAIM bằng query generator (`IF NOT EXISTS ... INSERT`, re-run được).
2. `Sys_ListDt`: 5 cột copy từ NAIM, `LdtFldOrder` 29–33 (nối cuối, không đổi layout CMSD).
3. Kiểm tra trước khi chạy: view có đủ cột, `CF_String` đủ StringCode, `Sys_Select 'Common.IRBMStatus'` tồn tại.
4. Recycle app pool; user đã lưu layout riêng → mở List View tick "Required E-Invoice?" + "E-Invoice".
5. (Nếu đã chạy) dòng `Sys_ListDt` `eInvStatus` ẩn thêm thử nghiệm — NAIM không có, có thể xoá; `eInvStatus` đã được load nhờ `Sys_BaseDt.BdtLstDefault=1`.

## Kết quả

Gunner test OK trên CMSD_Train (2026-11-17): chọn dòng không còn lỗi JS, toolbar + chuột phải hoạt động.

## Còn lại

- Deploy CMSD Live: chạy cùng script `Sys_BaseDt` + `Sys_ListDt`, recycle app pool; user nào đã lưu layout riêng màn Billing cần tick 2 cột (hoặc reset layout) — chưa xác định bảng lưu layout cá nhân để reset bằng SQL.
- Đề xuất (chưa làm): JS `OnBeforeMenu()` check null trước `.get_value()` như dòng `iseinvoice`, để toolbar không chết khi layout thiếu cột.
- Nên rà các list `_NAIMCAP` khác trên CMSD có page đã có e-Invoice mà `Sys_BaseDt` còn bản cũ (cùng dạng CMSD-18, CMSD-40).

## Jira note (English)

**Root Cause:** The Billing list page (`ARChargeBillList_NAIMCAP.aspx`) deployed to CMSD is the e-Invoice version: when a row is selected, its script reads the e-Invoice columns (Required E-Invoice, E-Invoice Status, E-Invoice) from the grid to decide which toolbar/right-click functions to enable. However, the list configuration for CMSD (`PS.BillNotPay_NAIMCAP`, Sys_BaseDt/Sys_ListDt) was still the pre-e-Invoice version and did not contain these fields, so the grid did not load them. The script failed with a JavaScript error and stopped before enabling the toolbar buttons and context menu, so all functions and right-click appeared disabled.

**Fix:** Added the missing e-Invoice fields (IsEInvoice, IsRequiredEInv, eInvStatus, eInvStatusStringCode, eInvUniqueID, eInvVerifiedDate) to the list configuration, aligned with NAIM. Users who have a saved personal column layout for this screen need to add the "Required E-Invoice?" and "E-Invoice" columns (List View) once. No code change.

**Status:** Fixed and tested on CMSD Train. Pending deployment to CMSD Live.
