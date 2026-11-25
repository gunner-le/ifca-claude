# CMSD-74 — AR Refund Requisition: 404 rồi Save lỗi `PurposeID` NULL

- **Client:** CMSD (clone NAIM_PS, code giữ tên `_NAIMCAP`)
- **Màn hình:** Rental Management > A/c Receivable > AR Transaction > Collection > **Refund Requisition** → popup `McAccount/ArRefundReceive_NAIMCAP.aspx(.cs)` (`SysTabEdit1` TabNo `AR.Journal`, `SysTabEdit2` TabNo `MC.RefundInfo`, Save = `DataSave` → `SysTabEdit1.SaveData` insert `AP_Journal` + `AR_Allocation`)
- **Môi trường gặp:** Train (server 10.10.10.41), company RCM (RIVERVALE)
- **Trạng thái:** Purpose: FIXED Train (2026-11-24). PayableType trùng ID: test OK local (DB lấy từ server) 2026-11-25 — chờ chạy server Train + consultant. 2 script config cần chạy lên Live (kiểm form Live trước).

## Triệu chứng
1. Bấm Refund Requisition → HTTP 404 `/train/McAccount/ArRefundReceive_NAIMCAP.aspx` — server thiếu file. Gunner copy file lên (TFS Dev/Rel changeset **99690** "Add customization page NAIMCAP: ArRefundReceive_NAIMCAP") → hết 404.
2. Save → lỗi. Debug local (DB `CMSD_Train`): `SqlException: Cannot insert the value NULL into column 'PurposeID', table 'CMSD_Train.dbo.AP_Journal'`.
3. Trên server từng thấy `HttpException: Multiple controls with the same ID 'PayableType'` tại `SysTabEdit1_CustomControlsCreated` dòng 72 (`FindControl("RequestUserID")`). **Không tái hiện** ở local; sau khi chạy script fix, server Train Save OK → không điều tra tiếp, **chưa xác nhận nguyên nhân** (config `AR.Journal` chỉ có 1 field sinh ID `PayableType`: `PayableTypeStringCode`, type `LC`, relation `PayableType`; section không trùng).

## Root cause (đã xác nhận code + data)
- Code: `DataSave` **không gán `PurposeID`** — dòng `collection.Add("PurposeID", Constants.GetPopupLstElementID("Expense"))` đã bị comment từ SWIBRACO-9 / IOI-8918 ở cả bản chuẩn `Source\PropertyNet\McAccount\ArRefundReceive.aspx.cs` (comment: *"PurposeID should be set to enabled"*, *"Set TdtFldEdit to 1 instead"*) lẫn bản NAIMCAP/CMSD. Thiết kế chuẩn: Purpose lấy từ **field trên form**.
- `AP_Journal.PurposeID` NOT NULL, không default, không trigger set (3 trigger `tr_*_AUDIT_AP_Journal` chỉ audit) — ở cả CMSD và NAIM_TC_Live.
- `Sys_BaseDt` base `AR.Journal` có field `PurposeStringCode` (type `L`, list `Purpose`, relation `PurposeID`, `BdtTabDisplay=1`) ở cả 2 DB, nhưng **`Sys_TabDt` form `AR.Journal` của CMSD thiếu dòng `PurposeStringCode`** (NAIM_TC có: TdtId 44250, order 12, `TdtFldEdit=1`). → form CMSD không có ô Purpose → `SaveData` không ghi `PurposeID` → insert fail.
- Bằng chứng: NAIM_TC_Live có 605 refund (`MC*Refund`, 2023-09 → 2026-08) đều có PurposeID (vd 973 `Project`); CMSD chưa từng có refund nào.

## Fix (config, không sửa code)
Script chạy lại được: `work\CMSD-74\CMSD-74_Sys_TabDt_AR.Journal_Purpose.sql` — `IF EXISTS … DELETE` rồi `INSERT Sys_TabDt` (`AR.Journal` / `AR.Journal` / `AR.Journal` / `PurposeStringCode` / `用途` / `AR.Journal_PurposeStringCode` ×2 / `TdtFldEdit='1'` / order 12). `CF_String` `AR.Journal_PurposeStringCode` (Field + Help, EN "Purpose") đã có sẵn. Order 12 trống (form có 1–9, 11).

Sau khi chạy: restart app (local F5 lại / server recycle) vì config `Sys_` bị cache.

## Test
- Local (VS, DB CMSD_Train): sau F5 lại, form có dropdown Purpose sau Payee Name; chọn Purpose + Document Amount → Save OK (2026-11-24).
- Server Train: chạy script → Save OK (2026-11-24).
- Còn: consultant test; chạy script lên Live.

## Còn mở / lưu ý
- Purpose **không required** — user bỏ trống vẫn lỗi SQL NULL (thông báo khó hiểu). Hỏi Stanley/consultant có cần required hoặc default (NAIM hay dùng `Project`).
- Alert "No amount for refund" khi Save = `f_save()` chặn Document Amount ≤ 0 — không phải bug.
- Lỗi `PayableType` trùng ID: xem mục "Update 2026-11-25" (đã tìm ra).

## Update 2026-11-25 — lỗi `Multiple controls with the same ID 'PayableType'`
- Server mở popup (vd receipt CurId=17, bấm Add) lỗi tại `SysTabEdit1_CustomControlsCreated` dòng 72 (`FindControl`). Stack: `SysTabEdit.CreateChildControls` → `CustomControlsCreated` → `FindControl` → `FillNamedControlsTable`.
- Loại dần: data view `View_MC_APJournal` (0 dòng cho 17/24), user, receipt, file (hash `Bin\IFCA.Framework.*.dll`, trang, master giống server), recycle app pool + reset memcache, web.config (chỉ khác DB `DEV-IFCADB`, SSRS, `IRBM_API_URL`, WCF). Local không lỗi vì **DB clone cũ**; lấy lại DB từ server → tái hiện.
- **Root cause (đã xác nhận):** form `AR.Journal` trên DB server đã được tạo lại (TdtId 47290–47304, thêm `DebtorAcct`, `DebtorName`, `PayableType`, `RefRecordID`; `PayTo` 11→10) — chưa rõ ai/cách nào (Customize Form Layout UI hay script). Có 2 field cùng sinh control ID `PayableType`: `PayableTypeStringCode` (LC, relation `PayableType`, TdtId 47293) và `PayableType` (S, TdtId 47302, order 13).
- **Fix:** `work\CMSD-74\CMSD-74_Sys_TabDt_AR.Journal_remove_PayableType.sql` — DELETE `Sys_TabDt` `AR.Journal`/`PayableType` (giá trị cũ ghi trong comment + câu revert). Test local (DB từ server) OK 2026-11-25. Còn: chạy server Train + recycle; hỏi consultant ai sửa layout.
- `DebtorName` và `PurposeStringCode` cùng order 12 — chạy được, chỉnh nếu thứ tự hiển thị lạ.
- Bài học: nghi config nhưng local không tái hiện → **lấy lại DB mới nhất từ server trước**, rồi mới so file/web.config. Lần này mất nhiều vòng so DLL/web.config vì dựa vào DB clone cũ. Query config nên dump **toàn bộ field của TabNo**, không lọc theo tên (field trùng ID có thể tên khác hẳn: `PayableType` vs relation của `PayableTypeStringCode`).

## Changeset TFS
| Nhánh | Changeset | Ngày | File/object | Ghi chú |
|---|---|---|---|---|
| Dev / Rel `Customization\CMSD\3.0 Customization\PropertyNet\McAccount` | 99690 | trước 2026-11-24 | `ArRefundReceive_NAIMCAP.aspx(.cs)` | Thêm page (fix 404) — có sẵn, Gunner copy lên server |

Script config CMSD-74: chưa commit TFS.

## TFS
TFS Live: so `ArRefundReceive_NAIMCAP.aspx(.cs)` (CMSD ↔ NAIMCAP ↔ standard `ArRefundReceive.aspx.cs`) ngày 2026-11-24, mức A+B → `.aspx` giống hệt; `.aspx.cs` CMSD vs NAIMCAP chỉ khác `using ...CMSD/NAIMCAP.AutoCode`; bản server = TFS CMSD. Purpose bỏ khỏi code từ SWIBRACO-9/IOI-8918 ở mọi bản.

## Bài học
- Save fail `Cannot insert NULL into <col>` trên trang `SysTabEdit`: code không gán thì cột phải đến từ field trên form → so `Sys_TabDt` (theo **relation** `BdtRelationName`, không chỉ `TdtFldName`) với client đang chạy được. Field dropdown thường tên `<X>StringCode`, relation `<X>ID`.
- Đã đọc comment SWIBRACO-9/IOI-8918 trong bản chuẩn là thấy hướng ngay — nên đọc bản chuẩn trước khi lần config.
- Query tìm field theo `TabNo LIKE '%Refund%'` bỏ sót: TabNo thật lấy từ thẻ `<IFCAUI:SysTabEdit TabNo=...>` trong aspx (trang Refund dùng `AR.Journal`).
- Config `Sys_` cache trong app: chạy script xong phải restart app mới thấy.
