# IFCA — Collection (phiếu thu) của 4 module AR + kiến thức framework (học từ LKHS-271)

> Kiến thức **dùng chung**, không riêng LKHS. Đọc khi gặp ticket về Collection / Receipt / Allocation / Void / forex realized / list grid ở Rental, Other Receivable, Construction (PM), Property Sales, hoặc Cash Management. Chi tiết riêng của dự án GIRO: `tickets/LKHS-271-ar-giro-collection-dbs.md`.
> Đây là bổ sung cho `ifca-domain-reference.md` (sẽ gộp vào file đó khi đóng LKHS-271).
> Lưu ý: tên file/trang/hàm dưới đây đã xác nhận trên source LKHS (nhánh SG). Client khác có thể có bản `_<CLIENT>` riêng — đối chiếu trước khi áp dụng.

## 1. Vòng đời phiếu thu (mọi module)

Collection (tạo `CB_Receipt` RecordStatus `Active` + `AR_Allocation` vào bill `AR_Trx`, trừ `AR_Trx.BalanceAmt`, trừ `CB_Receipt.AllocBalance`) → **Collection Verification** (`CashFlow/ACReceiptVerify.aspx`, menu `mcorp-15-07`, phiếu → `Verified`) → Bank-In (Collection Posting, `CB_Trx`) → GL Closing > Import Sub-Ledger (`GL_VoucherMain.VoucherCategory='Import'`).

- Bill status: Rental / PS `Active`; Other Receivable / PM `Approved`. Bill PS chưa xuất hoá đơn có `DocumentNo/Date/DueDate` NULL.
- `View_AC_Receipt` = nguồn của màn Collection Verification, gồm **4 nhánh UNION** (mỗi module 1 nhánh) → thêm cột phải thêm đủ 4 nhánh.
- `AR_Debtor.RefTable` cho biết module của debtor: `RT_RentalContract` = Rental, `CF_Company` = Other Receivable, `CF_Client` = Construction, `PS_Sale` = Property Sales.

## 2. Phiếu thu theo module

| | Rental | Other Receivable | Construction (PM) | Property Sales |
|---|---|---|---|---|
| ReceiptType | `MC_Fee` | `OD_Receipt` | `PM_Receipt` | `PS_Payment` |
| Doc code (SysCode) | 036 | 313 | 400 | 036 |
| Màn thu tiền (tạo) | `McAccount/ArFeeAdd2.aspx.cs` | `AccountReceivable/OtherReceiptEditSG.aspx.cs` (bản SG) | `PMReceivable/ArFeeAdd.aspx.cs` (class `PMReceiptBL` khai báo **trong code-behind** → không gọi được từ App_Code) | `PSAccount/PSReceiptAdd.aspx.cs` → BL `IFCA.Framework.PS.BL.Collection.Alloction.AddCBAndBill` |
| List Collection | `McAccount/ARFeeList.aspx` (view `View_MC_Receipt_List`, `ReceiptType='MC_Fee'`) | `AccountReceivable/OtherReceiptList.aspx` (view `View_CB_ReceiptOfOtherDebtor`) | `PMReceivable/ARReceiptList.aspx` (view `View_PM_Receipt`, LstNo `PM.ARReceiptLstNO`) | `PSAccount/ARReceiptList.aspx` (view `View_PS_cbReceiptList`; **class bên trong tên `PSAccount_ARDepositList`**) |
| Xoá/Void phiếu | `McAccount/ArReceiptDelete.aspx` → `ArCharge.CancellationCB_Receipt(id, voidDate, userID, remark)` (SQL trong MCCode) | `AccountReceivable/OtherReceiptDelete.aspx` (SQL: Voided, AllocBalance 0, bill += BaseAmt/ExchangeRate, contra `CB_Payment`, alloc Inactive) | Nút Delete trên `ARReceiptList` → `ARVoidTransaction.CancelReceipt` | `PSAccount/ArReceiptDelete.aspx.cs` (check `AccountSetting.GetAccountMinDate`, check refund, bill += BaseAmt) |
| Balance bill | trừ trực tiếp | trừ trực tiếp | **tính lại** = DocumentAmt − tổng AllocAmt của allocation Active (lỗi `PM.Common_DataSynch` khi vượt) | BL trừ (có chặn 0..abs(DocumentAmt)) |
| Ghi chú | `IsAdvancePayment`, `PaymentDescID`, `Supply` (dropdown); bill Interest → `MCInterest.PaidBill`; nút "Calculate" tính lại lãi trả chậm | `Supply` chỉ khi advance payment | `Supply='T'`; AllocDate = DocumentDate của bill | Lãi thả nổi `SaleInterest.ReCalc` / `PostFloatBill`; stakeholder bill → `AR_Allocation.RefTable='StakeholderTax'` |

- Bản `_SDPB` (`PSAccount/ARReceiptList_SDPB.aspx`, `View_PS_cbReceiptList_SDPB`) là customize của SDPB.
- `ARVoidTransaction` là class trong App_Code. Gặp lỗi compile `CS0117 'ARVoidTransaction' does not contain a definition for 'CancelReceipt'` → bản App_Code trên server cũ, lấy bản mới từ server/TFS về.

## 3. Forex gain/loss **realized** khi thu bill ngoại tệ (SG, LKHS-230)

Bill ngoại tệ thu ở tỷ giá khác tỷ giá bill → 2 dòng `AR_Allocation` cho 1 bill:

| Dòng | AllocAmt | BaseAmt | ExchangeRate | CurrencyID |
|---|---|---|---|---|
| Chính | amt | round(amt × tỷ giá bill) | tỷ giá bill | currency bill |
| Chênh lệch | 0 | round(amt × tỷ giá thu) − BaseAmt chính | tỷ giá thu | currency bill |

Chỉ tạo dòng chênh lệch khi currency bill ≠ base currency (`CF_Currency.IsBaseCurrency='Y'`) và 2 tỷ giá khác nhau. Ví dụ 1,000 USD, bill 1.35, thu 1.30: 1,000/1,350/1.35 và 0/−50/1.30.

**GL đọc chung cho mọi ReceiptType (không cần sửa GL khi module khác áp cùng kiểu):**
- `View_GL_ReceiptItemsF`: join dòng chính (AllocAmt > 0) với dòng AllocAmt = 0 cùng receipt + bill, cộng BaseAmt → lúc Verify: Bank Nợ = BaseAmt theo tỷ giá thu, Debtor Có = tổng 2 dòng. Giả định tối đa 1 dòng chênh lệch / bill.
- `View_GL_ForexGainOrLoss` (phần AR): AllocAmt = 0, BaseAmt ≠ 0, phiếu Verified, `AR_Trx.ExchangeRate` ≠ `al.ExchangeRate`, alloc không Inactive/Void. Không lọc ReceiptType.
- `GLArAllocationRealizedImporterSG` (map ReceiptTypeID cho MC_Fee / OD_Receipt / PM_Receipt / PS_Payment); `GLForexGainOrLossImporterFactory`: `"ar_allocation"` → realized, `"cashiering"` → bank revaluation (unrealized, LKHS-290/292, khác hẳn). `GLReceiptImporterSG.CreateVoucherByItem` có nhánh forex đã comment. Các class `...SG` nằm trong Common Library nhánh SG (dùng cho mọi client SG).

**Khác biệt giữa các màn thu chuẩn (đừng giả định 4 module giống nhau):**
- OR (`OtherReceiptEditSG`): đúng kiểu trên.
- Rental (`ArFeeAdd2`): dòng chính theo **tỷ giá thu** (BaseAmt = amt × tỷ giá thu), dòng chênh lệch = amt × tỷ giá bill − amt × tỷ giá thu → quy ước ngược với LKHS-230.
- PM (`PMReceiptBL`): dòng chính theo tỷ giá bill, BaseAmt không làm tròn, **không có dòng chênh lệch**.
- PS (`AddCBAndBill`): truyền vào `payamt × tỷ giá bill` (tiền đã quy đổi) và BL dùng con số đó cho cả balance bill, AllocBalance phiếu lẫn AllocAmt; `AddBuild` ghi BaseAmt = allocamt × tỷ giá phiếu (quy đổi 2 lần). Với bill ngoại tệ thì sai ngay ở màn PS chuẩn; PS hiểu như hệ 1 currency (có chỗ hardcode `'RM' AS currency`).
- Rủi ro khi bill có 2 dòng allocation: SQL kiểu `UPDATE AR_Trx ... FROM AR_Allocation A ...` (OR Delete, Rental `CancellationCB_Receipt`) có thể lấy nhầm dòng AllocAmt 0 → trả balance sai. An toàn: cộng lại **tổng AllocAmt theo từng bill** (CROSS APPLY / GROUP BY).

## 4. Framework / gotcha (áp dụng mọi trang)

### 4.1 List grid `SysList2` + SP phân trang `Prc_splitpage`
- `SelectCommandText` của `SysList2` được gửi xuống `EXEC Prc_splitpage @sql=..., @idField=<BseIdField>, @where=N'<RowFilter/filter>', @order=...`.
- SP **đổi cả câu về chữ thường**, tìm ` order by `, ` where ` và ` from` **cuối cùng**, rồi đếm ngoặc phía sau mỗi vị trí; lệch ngoặc thì coi như không thấy (vị trí −1). Sau đó lấy từ ` from` tới hết câu để ghép `select @totalnum=count(1) <from><where>` và `select * into #tempdata <from><where>` (SP tự viết lại `select *`).
- Hệ quả: **không đặt subquery có `from`/`where` trong `SelectCommandText`** (vd `... and X not in (select .. from .. where ..)`) — SP cắt sai (`substring(@sql,-1,len)` mất 2 ký tự cuối) → lỗi "Unclosed quotation mark after the character string 'y'", "Incorrect syntax near 'y where 1=1'", "non-boolean type ... near 'companyid'". JOIN cũng không được (`select * into #tempdata` trùng tên cột).
- Cách đúng: điều kiện **phẳng** trên cột của view. Cần cột từ bảng khác → thêm cột vào view (không đổi số dòng nên màn khác không ảnh hưởng), hoặc tạo view mới cho riêng trang. Subquery bên trong view thì SP không nhìn thấy nên không sao.
- Trang GIRO `ARGIROCollectionSelect` có subquery trong `SelectCommandText` mà vẫn chạy — chưa xác minh vì sao (có thể khác cách gọi SP). Đừng lấy đó làm bằng chứng subquery an toàn cho mọi list.
- Muốn biết câu SQL thật: SSMS → XEvent Profiler → TSQL, lọc `batch_text contains '<tên view>'`.

### 4.2 Sys_ config
- `Sys_Base.BseWriteTable` **không được NULL** cho resource dùng bởi grid (`GridBuilderHelper.GetGridInfo` gọi `GetString`) → lỗi "Data is Null". Grid chỉ đọc thì vẫn điền 1 bảng (vd `CB_Receipt`).
- Dropdown làm criteria trên list: `Sys_BaseDt.BdtFldType='L3'`, `BdtFilter='2'`, `BdtRelationName` = tên field, `BdtSelNo` → `Sys_Select` (`SelSql` trả `text, value`; `SelFldReturn` `"value,valueDesc"`; `SelFldUpdate` `"value,value"`); `Sys_Filter` `FltType='L3'`, `FltDisMode=1`.
- Tìm resource nào đọc 1 view: `SELECT BseNo, BseReadTable, BseWriteTable FROM Sys_Base WHERE BseReadTable LIKE '%<view>%'` + `sys.sql_modules.definition LIKE` + `Sys_Select.SelSql LIKE` + `findstr /s /i /m` trên source. Trước khi sửa WHERE của view chuẩn, luôn kiểm tra view đó có là `BseReadTable` của form View/Edit không (`ApproveView` sẽ không mở được record bị lọc).
- `Sys_Menu`: URL ở cột `MnuProgram` (không có `MnuUrl`).

### 4.3 Number Structure
- `new SysCode("<DocCodeNo>", ...)` cần dòng `CF_DocCode` (`ApplicationID, DocCodeNo, DocCodeName, TableName, PrimaryKey, CodeField...`) + Number Structure cho company. Thiếu → "There is no row at position 0". Cột là **`DocCodeNo`** (không phải `DocCode`).
- Chi tiết SysCode: `ifca-autocode-syscode-reference.md`.

### 4.4 ASP.NET / IIS
- **App_Code**: sửa 1 file `.cs` trong App_Code → IIS compile lại toàn site → lỗi tiềm ẩn ở trang/App_Code khác (vd class cũ thiếu hàm) lộ ra lúc đó, dễ tưởng do thay đổi mới gây ra.
- Công tắc bật/tắt tính năng không thêm cột DB: `public static readonly bool X = false;` trong App_Code (dùng `static readonly` thay `const` để không bị warning "unreachable code"); đổi giá trị trên server, App_Code tự compile lại.
- `PageMethods` (JS) chỉ gọi được `static [WebMethod]` của **chính trang đó**.
- Popup mở lại hiện trang cũ (cache) → thêm tham số `t=<timestamp>` vào URL.
- Popup thông báo `Message` (`msg.GetHtml()` → `var MessageCollection = {Tip:"..."}`) đặt text vào **chuỗi JS**: text có `\r\n` (vd `ex.Message` của IOException "The device is not ready.\r\n", SqlException nhiều lỗi) làm JS lỗi cú pháp → popup không hiện, trang chỉ reload. Luôn bỏ `\r`/`\n` (thay `<br>`), nhân đôi `\` của path, rồi `Message.FormatMessage` từng dòng trước khi đưa vào `msg.Msg`.
- **Ổ map (Z:\) chỉ tồn tại trong phiên đăng nhập Windows của người map** → IIS / app pool không thấy. Đường dẫn file cấu hình cho web phải là đường dẫn trên server hoặc **UNC** (`\\server\share\...`), và app pool account cần quyền đọc/ghi (ApplicationPoolIdentity truy cập share qua mạng bằng tài khoản máy `DOMAIN\<WEBSERVER>$`).
- Tên file `.aspx.cs` có thể khác tên class bên trong (vd `PSAccount/ARReceiptList.aspx.cs` chứa `PSAccount_ARDepositList`) — luôn hỏi đúng đường dẫn file, không suy từ tên class.
- Code-behind gọi được BL trong DLL từ App_Code; class khai báo trong code-behind trang thì không.

### 4.5 SQL
- `sp_helptext` ngắt dòng ở 255 ký tự → copy định nghĩa view dài có thể bị gãy giữa từ; ghép lại trước khi ALTER (hoặc dùng `OBJECT_DEFINITION`).
- `NOT IN (select PK ...)` an toàn khi cột là khoá chính (không NULL).
- View dùng `SELECT v.*` từ view khác: thêm cột ở view gốc phải `sp_refreshview` view bọc ngoài.
