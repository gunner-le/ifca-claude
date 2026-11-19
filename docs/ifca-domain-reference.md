# IFCA — Kiến thức nền tảng dùng chung (mọi client, mọi ticket)

File này chứa kiến thức **tổng quát**, không riêng ticket/client nào — đọc trước khi bắt đầu điều tra 1 ticket mới thuộc module đã có ghi chú dưới đây, để không phải giải thích lại từ đầu. Kiến thức riêng của 1 client/1 ticket cụ thể thì nằm ở file chi tiết ticket đó (xem `ticket-index.md`), không lặp lại ở đây.

## Quy ước đặt tên / kiến trúc chung

- **Tiền tố Jira key = mã client** (ví dụ `SWHARTANAH-xxx`, `TIMATCH-xxx`, `LKHS-xxx`, `HKB-xxx`, `FARLIMPG-xxx`, `SWZECON-xxx`, `SWIBRACO-xxx`, `SWCHENGLING-xxx`, `JESSELTON-xxx`) — mỗi client là 1 bản triển khai riêng, có thể có customization khác nhau trên cùng nền code IFCA chuẩn (TFS).
- **File/view/SP customize riêng cho 1 client thường có hậu tố `_<MÃ CLIENT>`** trong tên (ví dụ `CashFlow_ACPaymentBookEdit_TIMATCH.aspx.cs`, `View_PS_Sales_Status_Report_FARLIMPG_Final`, `View_CB_OtherPayment_SWIBRACO`). Khi thấy tên có hậu tố này, biết ngay đây là bản customize riêng, cần so sánh với bản TFS/standard (không hậu tố) nếu nghi ngờ bug do customization.
- Khi nghi ngờ 1 bug là do customize riêng cho client, cách xác minh nhanh nhất là **so sánh trực tiếp với bản TFS/standard cùng đối tượng** (view, SP, hàm) — nếu bản chuẩn cũng lỗi y hệt, đây là bug sản phẩm gốc (nên báo IFCA sửa ở nguồn), không phải lỗi riêng của client. Cũng có thể gặp chiều ngược lại: 1 client khác có thêm 1 customization hook (ví dụ 1 hàm override tham số) mà client đang điều tra không có — không vội kết luận đây là "thiếu fix", vì có thể client đang điều tra đã đạt hiệu quả tương đương bằng cách khác (ví dụ set tham số hệ thống toàn cục thay vì override có điều kiện) — xem LKHS-282.
- Một SP/dataset report có hardcode tên đối tượng hậu tố `_<CLIENT>` NGAY BÊN TRONG câu lệnh (không phải chỉ tên file bên ngoài) — ví dụ 1 dataset gọi `exec(...)` mà bên trong chuỗi SQL có nhắc `View_X_<CLIENT>` — chính là bằng chứng chắc chắn bản thân SP/report đó ĐÃ LÀ bản clone riêng cho client đó rồi (không phải SP dùng chung nhiều client), nên sửa trực tiếp SP đó không lo ảnh hưởng client khác.
- **Report/subreport có Data Source mà connection string là EXPRESSION build từ 1 Report Parameter (ví dụ tên `ServiceURL`, trỏ 1 web service theo môi trường)** — đây là điểm cấu hình rất dễ bị sai khi deploy/promote report giữa các môi trường (Train/Live Testing/Live), vì giá trị default của parameter đó phải set lại đúng riêng cho từng môi trường, không tự động theo instance đang chạy. Xem nhóm bug #13 bên dưới (SWZECON-75).

## Các nhóm bug hay lặp lại (nhận diện nhanh)

1. **"Cache/stale value thay vì đọc tươi tại đúng thời điểm quyết định"** — đã gặp ít nhất 2 lần ở 2 module khác nhau:
   - TIMATCH-396 (CM/Payment): biến `recordstatus` lấy từ query string URL lúc `OnInit`, không refresh theo DB, dẫn đến rẽ nhánh sai khi Save.
   - LKHS-303 (GL/Reversal JV): Digest được build lúc Load màn hình (theo mô tả JV gốc), không refresh lại theo input mới của user lúc Save.
   → Khi gặp bug dạng "hành vi phụ thuộc trạng thái nhưng ra sai kết quả", luôn kiểm tra: điều kiện rẽ nhánh có dựa vào giá trị đọc tươi từ DB tại đúng thời điểm xử lý không, hay đang dùng biến cache (URL param, ViewState, hidden field, biến gán 1 lần lúc Load)?

2. **"Cùng 1 enum/flag gộp nhiều bản chất nghiệp vụ khác nhau"** — đã gặp 2 lần:
   - TIMATCH-394: `PayableType` (MCPaymentRefund, MCReceiptRefund...) không phân biệt được "refund tiền cọc" vs "refund tiền công nợ" — phải cross-check với nội dung `Remark`.
   - FARLIMPG-126: `AR_BillItem.IsRebate = 'Y'` gộp cả "LOT - DISCOUNT ALLOWED" (chiết khấu giá lot) lẫn "Interest Rebate" (hoàn lãi) — phải lọc thêm theo `ItemName` chính xác.
   → Không giả định 1 enum/flag = 1 bản chất nghiệp vụ duy nhất. Khi cần lọc chính xác theo bản chất, kiểm chứng chéo với text mô tả (Remark/ItemName) trên toàn bộ data trước khi chốt điều kiện.

3. **"Hàm save dùng chung cho nhiều control trên 1 trang, có biến không được scope đúng theo RowState"** — SWHARTANAH-333: `SaveDataMethod` của 2 `SysListEditor` khác nhau trỏ chung 1 hàm `SaveData()`, hàm chạy 2 lần/lần Save; 1 biến gate (`IsReturn`) bị set ngoài điều kiện `RowState.Added` nên vẫn "dính" ở lần gọi thứ 2 dù không có gì mới. Khi gặp hành vi bị "nhân đôi" (số liệu cộng dồn 2 lần...), nghi ngờ đầu tiên: có control/hàm save nào bị gọi nhiều lần trong 1 request, và có biến nào trong hàm đó không được canh đúng theo `RowState` không.

4. **"Hardcode ID/tên control thay vì lấy động"** — LKHS-231: JS hardcode `document.getElementById("ctl00_search_SysCondition1_condition")`, sai vì naming container ASP.NET khác trang khác nhau. Luôn ưu tiên `<%=Control.ClientID%>` thay vì viết cứng chuỗi ID.

5. **"Giá trị raw trong bảng KHÔNG bằng giá trị hiển thị trên màn hình, do view có logic biến đổi (đảo dấu, ABS, nhân hệ số...)"** — GRSUMMIT-204: `View_AR_AdjustmentOfOtherDebtor` (view đọc, `Sys_Base.BseReadTable`) đảo dấu khi SELECT từ bảng ghi `AR_Trx` (`Sys_Base.BseWriteTable`): `-(T.DocumentAmt) AS DocumentAmt`, `-(t.BalanceAmt) AS BalanceAmt`, `(-(T.DocumentAmt) * T.ExchangeRate) AS BaseDocumentAmt`, còn `DocumentAmtBefTax` thì lấy `ABS()` (luôn dương bất kể dấu raw). Patch lần đầu theo giả định "raw = giá trị hiển thị" nên bị NGƯỢC DẤU — phải patch lại đúng dấu ngược lại mới ra đúng kết quả trên màn hình.
   → **Bất cứ khi nào `BseReadTable` (view) khác `BseWriteTable` (bảng ghi thật)**, TRƯỚC khi patch phải lấy definition của view (`sp_helptext '<ViewName>'` hoặc `SELECT OBJECT_DEFINITION(OBJECT_ID('<ViewName>'))`) để xác nhận công thức hiển thị (đảo dấu/ABS/nhân hệ số/join thêm điều kiện...) — không được giả định cột raw = giá trị hiển thị trên UI, dù tên cột giống hệt nhau.

6. **"Cột SQL thật sự là `float` nhưng entity model khai field là `Decimal?` — chỉ lộ lỗi khi giá trị = 0 (không phải NULL)"** — FARLIMPG-169: `AR_Trx.TaxExemptRate` (cột `float` ở SQL Server) khi có giá trị `0` (một `System.Double` thật, không phải NULL) làm 1 tiện ích generic clone entity qua reflection (`ClassUtil.EntityClone<T>` — copy `CurrentValue` field-by-field bằng `SetNewFieldValue`) bị entity model từ chối kiểu khi gán vào field đích khai `Nullable<Decimal>`, ném lỗi `The value X is of type Y while the field is of type Z`. Khi field đó là NULL thì không có gì để validate nên chạy qua bình thường — dễ khiến bug tưởng như "tùy record/tùy case nghiệp vụ" (ví dụ tưởng liên quan E-Invoice status) trong khi thực chất chỉ tùy giá trị field đó đúng bằng 0 hay NULL.
   → Khi gặp lỗi type-mismatch dạng "value X is of type Y while field is of type Z" ở bất kỳ nghiệp vụ nào có gọi entity clone/copy generic qua reflection: (a) chạy `SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '<bảng>'` để tìm cột nào là `float`/`real` thay vì `decimal`/`numeric`; (b) so sánh dữ liệu giữa 1 record lỗi và 1 record chạy OK, tìm đúng cột float nào khác nhau giữa "= 0" và "NULL" — đây mới là biến số quyết định, không phải khác biệt nghiệp vụ bề ngoài (loại giao dịch, status...).
   → **Bài học quan trọng về CHỌN NƠI FIX (rút ra sau khi thử fix tại màn hình tạo/sửa trước, thất bại, xem thêm mục `SysTabEdit1.SaveData` bên dưới):** đừng mặc định fix "từ gốc" (chỗ tạo ra data 0 thay vì NULL) là luôn đúng hướng — cần xét 2 điều trước: (1) **có set được NULL tại đó không** — nếu màn hình lưu qua `SysTabEdit1.SaveData` bằng `NameValueCollection`, RẤT CÓ THỂ không set NULL được (xem gotcha `SysTabEdit1.SaveData` bên dưới); (2) **giá trị "sai" đó có thực sự sai về nghiệp vụ không, hay chỉ là vấn đề kỹ thuật của riêng 1 hàm generic** — ví dụ `TaxExemptRate = 0` khi không tax-exempt hoàn toàn hợp lý về nghiệp vụ (0% exempt = không exempt, cùng kết quả tính toán), lỗi chỉ nằm ở chỗ `EntityClone` không chấp nhận BẤT KỲ giá trị non-null nào của field `float`/`Decimal?` (không riêng gì 0). Trong trường hợp này, **fix đúng và gọn nhất là tại chính điểm lộ lỗi** (trước dòng gọi `EntityClone`/`SetNewFieldValue`) — normalize field đó về NULL trong bộ nhớ ngay trước khi dùng, dùng `entity.Fields["<TênField>"].CurrentValue = null` (gán qua field API của entity, không qua `NameValueCollection`/SQL builder — tránh đúng giới hạn NULL đã gặp) — không cần sửa màn hình tạo, không cần patch SQL cho data cũ, vì bill nào bị chạm tới chức năng gây lỗi sẽ tự qua được đúng lúc đó.

7. **"Bug chỉ tái hiện trên 1 máy user cụ thể, không phải mọi user — nghi ngờ sớm cấu hình môi trường client (browser Security Zone / .NET Framework), không tiếp tục đào server-side nếu data/logic server đã xác nhận đúng"** — SWZECON-82: report ban đầu tưởng là lỗi logic sinh GL từ Cash Receipt/Other Receivable (dòng Bank line post sai Department). Điều tra qua data (`CB_Receipt`, `AR_Allocation`, `AR_Trx`, `GL_Voucher`) xác nhận toàn bộ dữ liệu/logic phía server nhất quán và đúng — nhưng bug **chỉ xảy ra trên máy của 1 user cụ thể**, những user khác thao tác y hệt không bị. Root cause thật sự: **Internet Options (IE/Edge IE-mode) > Security > Trusted Sites zone > Custom Level > mục ".NET Framework"** trên máy đó chưa bật đủ quyền (Loose XAML / XAML browser applications / XPS documents / "Permissions for components with manifests") — màn hình dùng 1 component .NET Framework-reliant chạy trong trình duyệt để set field liên quan lúc submit, bị chặn ngầm bởi zone permission và rơi về giá trị sai, không báo lỗi rõ ràng.
   → Khi 1 bug được report là "field X sai giá trị/hành vi lạ" nhưng KHÔNG tái hiện được cho user khác dùng cùng chức năng, cùng data tương tự → ưu tiên hỏi ngay "bug này chỉ xảy ra ở máy/user nào, hay mọi user đều gặp?" SỚM trong quá trình điều tra (trước khi đào sâu SQL/code), vì nếu câu trả lời là "chỉ 1 máy" thì hướng điều tra đúng chuyển sang cấu hình môi trường client (IE Security Zone, .NET Framework permission, trình duyệt/version, extension chặn) thay vì tiếp tục nghi ngờ logic server. Dữ liệu cũ đã lỡ post sai (trước khi user fix Trusted Sites zone) không tự sửa được — cần Manual Journal (JV) để điều chỉnh, không phải data patch trực tiếp vào bảng GL.

8. **"Dữ liệu derived/generated (schedule, summary...) KHÔNG tự regenerate khi đổi tham số hệ thống — dễ khiến 1 fix đúng bị tưởng lầm là chưa fix"** — LKHS-282 (RM/Bill Schedule): sau khi xác nhận `CF_Parameter` đã đổi đúng giá trị mới trong DB, nhiều lần test lại vẫn ra kết quả sai y hệt cũ — không phải vì fix sai, mà vì bảng dữ liệu derived (`MC_BillSchedule`) chỉ được INSERT bởi 1 hàm business logic cụ thể (`RtContractSum`) tại đúng thời điểm Save/Submit/Approve nguồn dữ liệu gốc (`RT_ContractCharges`), KHÔNG có cơ chế tự động re-run khi tham số điều khiển logic đó thay đổi. Thêm rắc rối: hợp đồng nguồn đã ở trạng thái **Approved** nên không cho Edit trực tiếp, khiến các lần "tạo record mới để test" không thực sự trigger lại hàm generate (record mới chưa qua Submit/Approve → detail schedule chưa sinh), nên vẫn hiển thị data cũ và bị hiểu lầm là "fix không có tác dụng".
   → Khi 1 bug liên quan tham số hệ thống điều khiển 1 quy trình sinh dữ liệu derived (schedule, ledger balance, summary...) đã sửa tham số xong mà kết quả **test lại vẫn y hệt cũ**, LUÔN kiểm tra trước tiên: (a) dữ liệu derived đang xem có phải sinh MỚI sau khi đổi tham số không, hay là data cũ còn sót lại (so `ModifyDate`/audit log insert timestamp của record derived với thời điểm đổi tham số); (b) hành động "test lại" có thực sự đi qua đúng code path sinh dữ liệu đó không (Save thôi có đủ, hay cần Submit + Approve mới thực sự trigger) — 1 record test tạo ra nhưng chưa hoàn tất workflow (chưa Approve) thường KHÔNG sinh ra dữ liệu derived, dễ nhầm là "đã test nhưng vẫn lỗi".
   → **Mẹo test trên hợp đồng RM đã Approved mà cần regenerate lại** (không có unit trống để tạo hợp đồng mới, Amortization Schedule/Contract Renewal không áp dụng được): bấm **Cancel** trên hợp đồng Approved → status chuyển về **New** (không phải huỷ hẳn/mất data) → lúc này **Edit** được bình thường → sửa/save lại tab **Schedule Billing** → **Submit** → **Approval** lại → hàm generate chạy lại đúng theo tham số hiện tại. Đã dùng thành công ở LKHS-282 để verify fix.
   → App cũng có thể cache tham số hệ thống (`SysParameter`/`CF_Parameter`) tĩnh trong RAM lúc app start — sau khi đổi tham số qua UI, nên recycle app pool/restart site trước khi test lại để loại trừ khả năng runtime vẫn đang dùng giá trị cache cũ dù DB đã đúng.

9. **"Field đã set `Sys_TabDt.TdtFldEdit = 1` (cho editable qua config) nhưng vẫn bị khoá — do code-behind override lại `ReadOnly`/`Enabled` NGAY SAU khi control được tạo"** — LKHS-203 (RM/AR Bill Adjustment): `ArAdjustmentEdit.aspx.cs`, hàm `SysTabEdit1_CustomControlsCreated` (event của `SysTabEdit`, chạy mỗi khi control tree được build — cả lúc load lẫn có thể ở postback) set cứng, KHÔNG điều kiện:
   ```csharp
   WebCurrencyEdit documentAmt = (WebCurrencyEdit)SysTabEdit1.FindControl("DocumentAmt");
   if (documentAmt != null)
   {
       documentAmt.Enabled = true;
       documentAmt.ReadOnly = true;   // luôn readonly, không check điều kiện gì
       documentAmt.BackColor = System.Drawing.Color.Gainsboro;
       ...
   }
   ```
   Field `DocumentAmt` (hiển thị "Amount" trên UI) vì vậy KHÔNG THỂ editable được dù `Sys_TabDt.TdtFldEdit` của field này có set `= 1` cho đúng Tab/TCSNO — vì code này chạy SAU giai đoạn framework áp dụng config, và override lại vô điều kiện.
   → Khi 1 field vẫn KHÔNG edit được dù đã set đúng `Sys_TabDt.TdtFldEdit = 1` (đã kiểm tra DB đúng), đừng dừng lại ở việc sửa config — luôn tìm tiếp trong code-behind các event `CustomControlsCreated`/`OnInit`/`OnPreRender` của `SysTabEdit`/`SysTabEdit2` xem field đó có bị code `FindControl("<TênField>")` rồi set cứng `ReadOnly`/`Enabled`/`Visible` hay không. Code-behind luôn có quyền ghi đè và thường chạy sau bước áp dụng config, nên 1 field có thể "trông như bị khoá bởi config" nhưng thực chất bị khoá cứng bằng code, sửa config sẽ không có tác dụng gì.

10. **"Patch cục bộ chỉ vá đúng phần hiển thị (1 cột lấy riêng qua subquery từ view/nguồn khác) mà không đồng bộ với WHERE filter build động — filter vẫn áp trên nguồn cũ, âm thầm loại đúng những dòng cần sửa"** — SWIBRACO-686 (CM/Other Payment, Print Listing): dataset header report `CB_OtherPaymentHeader` có dạng
    ```sql
    PayTo=(select top 1 PayTo from View_CB_OtherPayment_SWIBRACO where CBPaymentID = a.CBPaymentID),
    * from View_CB_OtherPayment a where ... AND a.CompanyID=... + @QueryCriteria
    ```
    Cột `PayTo` **hiển thị** được vá riêng qua subquery lấy từ view customize `View_CB_OtherPayment_SWIBRACO` (đúng), nhưng `@QueryCriteria` (điều kiện search do user nhập, build động — ví dụ `PayTo LIKE '%msig%'`) vẫn áp thẳng lên `a.PayTo` của **view standard** `View_CB_OtherPayment` (chưa được vá, rỗng cho 1 số payment). Kết quả: report bỏ sót đúng những dòng mà cột bị vá (PayTo) chỉ đúng ở view mới, vì điều kiện lọc chưa bao giờ được trỏ sang view mới đó. Xác nhận bằng data thật: 4/10 payment có `PayTo` rỗng ở view standard nhưng đúng "MSIG INSURANCE (MALAYSIA) BHD" ở view `_SWIBRACO`.

    Đã xem definition cả 2 view — lý do lệch: `View_CB_OtherPayment` lấy thẳng `A.PayTo` (cột free-text raw của `CB_Payment`, không xử lý gì thêm); `View_CB_OtherPayment_SWIBRACO` tính `PayTo` bằng `CASE WHEN A.CreditorID IS NOT NULL THEN (SELECT Name FROM view_ap_creditor WHERE RecordStatus='Active' AND a.CreditorID=CreditorID) ELSE A.PayTo END` — tức ưu tiên lấy tên từ **Creditor Master** qua `CB_Payment.CreditorID` nếu payment có link Creditor, chỉ fallback `PayTo` raw khi không có CreditorID. Trong case này, cả 10/10 payment đều có `CreditorID` hợp lệ (link đúng creditor "MSIG INSURANCE (MALAYSIA) BHD"), nhưng cột `PayTo` raw chỉ được điền tay cho 6/10 — 4 dòng còn lại tuy có CreditorID nhưng `PayTo` raw để trống. Xem thêm ghi chú `CB_Payment.PayTo`/`CreditorID` ở mục Module CM/Payment bên dưới.

    Fix: đổi hẳn `FROM` của dataset sang view đã vá (`View_CB_OtherPayment_SWIBRACO`), bỏ subquery vá riêng (dư thừa, gây trùng tên cột) — miễn là view mới là superset cột so với view cũ (kiểm tra bằng cách so `*` của cả 2 view trước khi đổi).
    → **Khi 1 report/dataset có dynamic WHERE build từ search criteria của user (`@QueryCriteria`, `SysCondition`...), VÀ có 1 cột nào đó được "vá" riêng qua subquery từ view/nguồn khác** (thường là dấu hiệu: tên cột xuất hiện 2 lần trong SELECT, 1 lần từ subquery/join thêm, 1 lần từ `*`/nguồn chính) → luôn nghi ngờ ngay: điều kiện lọc động có đang filter trên đúng cột ĐÃ VÁ đó không, hay vẫn filter trên bản cũ/chưa vá. Đây không phải lỗi JS build criteria (khác với nhóm bug #4/`SysCondition`) mà là lỗi kiến trúc SQL — 2 nguồn dữ liệu khác nhau cho cùng 1 tên cột trong cùng 1 câu query, chỉ 1 trong 2 nguồn nhận được điều kiện lọc.

11. **"`.Contains()` trên 1 chuỗi nối bằng dấu phẩy để kiểm tra 1 giá trị có nằm trong danh sách cố định hay không — lỗi vì so khớp theo SUBSTRING chứ không theo TOKEN chính xác"** — SWIBRACO-681 (GL, report "SST Payable and Tracking" — dropdown filter "Module" trống, không có value nào để chọn): `ReportFilter2.aspx.cs`, hàm `BuildCell()` (dòng ~634):
    ```csharp
    if (sAppCode.Equals("gl") && "year,startmonth,endmonth,month,moduletype".Contains(row["FldName"].ToString().ToLower()))
        cell.Controls.Add(InputGLSelect(row, start, Value, row["FldName"].ToString().ToLower()));
    ```
    Code muốn kiểm tra `FldName` có phải 1 trong 5 tên field GL year/month cố định hay không, nhưng dùng `string.Contains()` ngay trên chuỗi gốc thay vì split ra mảng rồi so khớp từng phần tử. Vì `"moduletype"` (1 phần tử hợp lệ trong danh sách) CHỨA sẵn substring `"module"`, field tên `Module` (report SST Payable, khác hẳn `ModuleType`) bị nhận nhầm là match → bị route sang `InputGLSelect()` (hàm chuyên build dropdown năm/tháng/phòng ban kế toán GL) thay vì hàm đúng `InputSelect()` (hàm đọc `RefDataSource` để build dropdown List generic — xem mục `InputSelect()` bên dưới). `InputGLSelect()` chỉ có nhánh xử lý CHÍNH XÁC `bindFldName.Equals("moduletype")` (không có nhánh nào cho `"module"`), nên khi nhận `bindFldName="module"` không khớp nhánh if/else if nào, hàm chỉ add đúng 1 dòng mặc định "Please Select" ở đầu hàm rồi return — dropdown trống hẳn, không có lỗi/exception nào để lộ ra dấu vết.
    → Đã xác nhận bằng cách loại trừ tuần tự (không phải suy đoán): test trực tiếp `dbo.GetString2` không phân biệt hoa/thường (loại giả thuyết lowercase phá case), đọc source `Common.pf_CustomizationChangeValue`/`CustomizationChangeValue2` xác nhận no-op với case này (loại giả thuyết hook customization), chạy thử trực tiếp câu SQL cuối cùng của `RefDataSource` ra đúng 5 dòng module hợp lệ (loại giả thuyết lỗi ở tầng SQL/data) — chỉ còn lại khả năng field bị route sai TRƯỚC KHI vào `InputSelect()`, dẫn tới việc đọc lại `BuildCell()` và phát hiện đúng điểm này.
    → Khi gặp lại pattern `"a,b,c,d".Contains(x)` hoặc `.IndexOf()` tương tự để kiểm tra 1 giá trị có nằm trong 1 danh sách cố định hay không (đặc biệt trong các nhánh dispatch theo `FldName`/`fldName` ở các report/screen khác dùng chung `ReportFilter2.aspx.cs` hay các file tương tự), LUÔN nghi ngờ: giá trị đang test có phải substring của 1 phần tử KHÁC dài hơn trong chính danh sách đó không (ví dụ tên field ngắn trùng tiền tố/hậu tố tên field dài hơn, như `module`⊂`moduletype`, hay tương tự `year`⊂`fiscalyear`). Đây là lỗi rất âm thầm — không throw exception, không lỗi rõ ràng, chỉ lặng lẽ route sai logic, chỉ phát hiện được bằng cách đọc kỹ code dispatch, không đoán được nếu chỉ nhìn triệu chứng "dropdown trống". Cách viết đúng: `"<chuỗi>".Split(',').Contains(x)` hoặc `Array.IndexOf("<chuỗi>".Split(','), x) >= 0` (so khớp CHÍNH XÁC từng token).

12. **"Query chậm do COMPILE (lập plan) chứ không phải do EXECUTION — view quá lớn + filter literal từ UI → mỗi lần đổi giá trị lọc là compile lại"** — SWCHENGLING-76 (PS/Letter Printing, Progress Billing Statement): view Master `View_PSLetter3233_Master_SWCHENGLING` có 401 cột, ~60 join (trong đó ~12 view con, mỗi view con lại chứa nhiều bảng), 8 derived table tính tiền trên toàn bộ `AR_Trx`, ~25 subquery. Chạy thật chỉ ~1,6s, nhưng **compile mất ~66–72s**. App (`PrintService.GetMainDataTable`) gửi filter dạng literal (`UnitNo = '033'`), nên in unit khác = câu SQL khác = compile lại → user thấy "lần nào in cũng chậm ~1 phút".
    → **Đặc điểm nhận diện:** chạy lại ĐÚNG câu đó lần 2 trong SSMS thì nhanh (plan có trong cache), đổi giá trị lọc thì chậm lại. Compile tăng **siêu tuyến tính** theo tổng kích thước query: chọn từng nhóm 30 cột riêng thì 1–2s, nhưng 401 cột cùng lúc thì ~54s — nên sửa lặt vặt 1 khối (bỏ window function, gộp subquery, bỏ join trùng, ép thứ tự join bằng join hint) KHÔNG giảm được compile. Filter theo khoá chính bảng gốc (`SaleID`) compile nhanh hơn nhiều so với filter theo cột ở cuối chuỗi LEFT JOIN (`CompanyNo`, `UnitNo`).
    → **Cách đo đúng (rất dễ đo sai, đã mất nhiều vòng vì đo sai):**
      - Tắt **Include Actual Execution Plan (Ctrl+M)** và bật **Query Options > Results > Discard results after execution** — SSMS dựng plan khổng lồ / hiển thị grid hàng trăm cột có thể tốn hàng chục giây, làm tưởng nhầm SQL chậm.
      - `SET STATISTICS TIME ON` + `DATEDIFF` trong **cùng batch** KHÔNG đo được compile của câu đó (batch được compile TRƯỚC khi dòng đầu tiên chạy). Muốn đo gồm compile: tách batch bằng `GO`, lưu thời điểm vào bảng tạm global (`##t`) trước/sau.
      - Kiểm tra plan có được cache/dùng lại: `sys.dm_exec_cached_plans` (`usecounts`) / `sys.dm_exec_query_stats` (`plan_generation_num`, `creation_time`). Query DMV phải chạy ở batch RIÊNG, không chung batch với câu cần kiểm tra (nếu không, điều kiện `NOT LIKE '%dm_exec%'` sẽ loại mất chính dòng cần tìm).
      - Muốn biết phần nào của view gây compile lâu: script chia cột view theo nhóm (lấy từ `sys.columns`), chạy `SELECT <nhóm cột> INTO #x FROM <view> WHERE ... OPTION (RECOMPILE)` từng nhóm riêng và cộng dồn, đo thời gian — nếu nhóm nào riêng cũng nhanh mà cộng dồn tăng vọt → do tổng kích thước, không phải 1 cột.
    → **Fix đã chứng minh hiệu quả (compile 66s → 2s, số liệu khớp 100%):** thay vì đọc view, gọi **SP chứa nội dung view** nhận danh sách khoá (`@SaleIDs`): (1) tính trước vào bảng tạm (`#temp`) CHỈ cho các key đang in — các khối tổng tiền, các subquery trỏ view lớn, và **từng view con** (`SELECT * INTO #X FROM <view con> WHERE <key> IN (...)`); (2) câu SELECT cuối chỉ join bảng thường + bảng tạm (không còn view con), thêm `OPTION (KEEPFIXED PLAN)` để không compile lại khi số dòng thay đổi. Mỗi câu nhỏ compile nhanh, câu cuối cũng nhỏ. Phía C#: vẫn dùng filter UI nguyên bản nhưng chỉ `select distinct <key> from <view> where <filter>` (1 cột → compile nhanh), rồi truyền danh sách key vào SP.
    → **Các hướng KHÔNG hiệu quả với trường hợp này:** plan guide TEMPLATE / `PARAMETERIZATION FORCED` (phụ thuộc text câu SQL của app, khó bắt đúng); SP chỉ bọc lại view (`SELECT * FROM view WHERE SaleID ...`) — vẫn chậm với dữ liệu thật (37–45s cho 9 Sale); chạy từng Sale 1 lần trong loop (plan cho 1 Sale không hợp với Sale có nhiều giao dịch). Bảng tạm `#temp` KHÔNG làm giảm compile nếu câu cuối vẫn là `SELECT * FROM <view lớn>` — phải bỏ hẳn view lớn khỏi câu cuối.
    → **Rủi ro bảo trì:** SP là bản sao logic view → sửa view (thêm cột/đổi công thức) PHẢI sửa SP, nếu không merge field mới (Edit Template vẫn đọc cột từ view qua `SELECT TOP 0 *`) sẽ trống/lỗi khi in. Nên thêm comment cảnh báo ở đầu view.
    → Lưu ý môi trường: nhiều DB IFCA chạy `compatibility_level = 100` (legacy cardinality estimator, không có scalar UDF inlining, không có `STRING_SPLIT`) — tách chuỗi danh sách ID trong SP dùng XML (`CAST('<i>' + REPLACE(@ids, ',', '</i><i>') + '</i>' AS XML).nodes('/i')`). Không đổi compatibility level của DB khách để "chữa" 1 query (ảnh hưởng toàn hệ thống).

13. **"Report/subreport lấy data qua Web Service (Data Source Type=XML), connection string build động từ 1 Report Parameter riêng theo môi trường (vd `ServiceURL`) — default value bị set nhầm sang môi trường khác khi deploy, fail ÂM THẦM không báo lỗi"** — SWZECON-75 (CM/Payment, Print "PV without Cheque"): bảng double-entry (Code/Description/DR/CR) trên bản in được sinh bởi 1 subreport (`CB_PVWithoutCheque_Sub1_SWZECON`) gọi WebMethod `GetPreviewJournalData2` (`GLSubLedgerJournalPreview.GetPreviewJounals(SubLedgerCategory.CB_Payment, ...)`) qua Data Source Type=XML. Report Parameter `ServiceURL` (dùng làm expression cho connection string của Data Source đó) trên Report Server của **Live** lại có default value trỏ sang URL của **Train** — subreport gọi sai endpoint, không lấy được data, nhưng KHÔNG có lỗi hiển thị nào cả (khác hẳn lỗi "Error: Subreport could not be shown." — đó là 1 vấn đề khác, do Data Source Credentials="prompt", chỉ gặp khi debug ở máy local/dev), chỉ đơn giản bảng ra rỗng — rất dễ khiến nghi ngờ sai hướng (code/SQL/mapping RDLC) trong khi toàn bộ các tầng đó vẫn đúng.
    → **Kỹ thuật quyết định để loại trừ nhanh code/data/logic khỏi diện nghi vấn**: gọi TRỰC TIẾP WebMethod đứng sau subreport (qua trang test tự sinh `<service>.asmx?op=<MethodName>` của ASMX — chỉ hoạt động khi gọi từ chính máy host service, tức server đó) với đúng tham số thật, bypass hẳn subreport/report engine. Nếu trả về đúng data như mong đợi → chắc chắn vấn đề nằm ở tầng report/subreport CONFIGURATION (Data Source, Parameters, Credentials), không phải code C#/SQL — lúc đó mới đáng để đi vào Report Server (Report Manager) kiểm tra **Parameters** của report đó, đặc biệt các parameter dùng để build connection string động theo môi trường.
    → Khi gặp lại pattern "subreport/report lấy data qua 1 URL/endpoint không cố định (build từ Report Parameter)" và bảng/report đó BLANK không lỗi trên 1 môi trường cụ thể trong khi tính năng tương đương (ví dụ nút xem trước trên UI, gọi thẳng cùng 1 hàm business logic) vẫn đúng → luôn kiểm tra default value của các Report Parameter đó trên đúng Report Server của môi trường đang lỗi, đối chiếu xem có đang trỏ nhầm sang môi trường khác (Train/Live Testing/Live) hay không — đây là lỗi cấu hình deploy rất dễ xảy ra khi promote report giữa các môi trường mà quên update lại default value, và không giới hạn ở CM/Payment hay SWZECON — bất kỳ report/subreport nào dùng chung pattern Data Source Type=XML gọi Web Service + Report Parameter theo môi trường đều có nguy cơ này.

14. **"1 record master 'không hiện' trong danh sách/cây chọn trong khi các record cùng loại ở company khác vẫn hiện — so sánh với NHIỀU record OK cùng loại, không chỉ 1"** — JESSELTON-272 (CM/Payment Verification, cây Bank Selection): account Cash `PC-ADMIN_JP` không hiện dưới node "Cash". So với 1 record OK duy nhất thì ra nhiều khác biệt (`ReconciliationMode='M'` vs `'Munual'`, `OverdraftLimit` NULL vs 0, các cột NULL vs '' — dấu hiệu record insert bằng script migration), dễ chốt nhầm. Thử sửa `ReconciliationMode` thì không có tác dụng. Khi đối chiếu TOÀN BỘ record cùng loại, có 1 record migration khác (PALI) giống y record lỗi ở các cột đó mà vẫn hiện, nên loại được. Khác biệt thật duy nhất: record lỗi có `AccountID` (FK sang `CF_Account`), mọi record Cash khác đều NULL.
    → Quy trình: (a) query toàn bộ record cùng loại (cùng `AccountTypeID`/type) trên mọi company; (b) chọn cột nào record lỗi khác TẤT CẢ record OK, không phải khác 1 record; (c) kiểm tra nhanh trên UI ở company có record "giống record lỗi ở cột đang nghi" để loại giả thuyết, không cần đụng DB; (d) test patch 1 cột trên Train trước khi kết luận.

15. **"1 view report có nhiều block UNION ALL lấy cùng 1 bảng (vd `RecordStatus='Voided'`) nhưng mỗi block viết điều kiện lọc KHÁC NHAU — 1 block lọc đúng, 1 block thiếu/sai điều kiện hoàn toàn"** — FPARK-166 (AR/Reporting, Debtor Ledger Report): view `View_Report_DebtorLedgerReport_FPARK` có 2 block cùng xử lý document Voided nhưng theo 2 cách khác nhau: block 1 (`View_RT_Ar_Trx`) cho `RecordStatus IN ('Active','Voided')` hiện **vô điều kiện** (không hề có logic giới hạn nào) — bug rộng, 280 debtor/470 dòng/RM 674,025.98; block 3 (`AR_Trx` trực tiếp, document reversal) có 1 derived table `VoidInfo` cho Voided hiện có điều kiện ("double-void": chỉ khi invoice gốc bị reverse CŨNG Voided) — bug hẹp hơn nhưng vẫn sai, 494 dòng/287 debtor. Hai bug độc lập, cộng hưởng trên cùng 1 tập chứng từ (đã quan sát: phần "Debit thiếu" ở block 3 hoá ra là phần "Debit thừa vô điều kiện" ở block 1 của ĐÚNG những invoice đó).
    → Khi 1 view nhiều-block UNION ALL có từ 2 block trở lên cùng đọc 1 bảng nguồn (hoặc cùng khái niệm `RecordStatus`), ĐỪNG giả định các block xử lý nhất quán với nhau — phải đọc riêng từng block, so sánh điều kiện lọc Voided/InActive/trạng thái của từng block, vì rất có thể 1 block được viết cẩn thận (có exception logic) còn 1 block khác đơn giản là quên lọc hoàn toàn.
    → Kỹ thuật xác nhận AN TOÀN khi bỏ 1 exception logic dạng "double-void" (cho phép 1 trạng thái bất thường hiện có điều kiện): join trực tiếp 2 vế (bản ghi reversal ↔ bản ghi gốc) qua đúng audit cặp `RefTable/RefRecordID`, xác nhận TOÀN BỘ cặp đều đối xứng tuyệt đối (amount ngược dấu nhau, net = 0) trước khi kết luận bỏ hẳn điều kiện không ảnh hưởng số dư thực — chỉ loại bỏ noise hiển thị.
    → Query debug hiệu quả: query kiểm tra đích danh DocumentNo cụ thể trong view (nên IN 1 danh sách rõ ràng đã biết) đáng tin hơn 1 query tổng quát kiểu "join lại view với bảng gốc theo DocumentNo" — query tổng quát dễ bắt nhầm case hợp lệ khác (ví dụ 1 invoice có nhiều dòng line item, chỉ 1-2 dòng bị void riêng lẻ còn dòng khác vẫn Active — hoàn toàn bình thường, không phải bug).

## Module: Rental Management (RM) / AR / Bill Adjustment

- File chính: `ArAdjustmentEdit.aspx` / `ArAdjustmentEdit.aspx.cs` (class `McAccount_ArAdjustmentEdit`), `TabNo = 'MC.AdjustmentEdit'`. Grid chi tiết "Adjustment Detail" render bằng `SysListEditor2` (`SysList1`, `LstNo = 'MC.AdjustmentListEdit'`), nạp allocation liên quan từ `View_MC_Bill` join `AR_Allocation` (`AdjustmentID = BillID` hiện tại).
- Field "Amount" trên UI = control/DB column **`DocumentAmt`** (bảng `AR_Trx`, giống tên cột dùng ở module AR khác) — không nhầm với field "Adjustment Amount" (khác, nằm trong grid Adjustment Detail, cột `adjustmentamt`).
- `Sys_TabDt` cho tab `MC.AdjustmentEdit` có ít nhất 2 `TDTTCSNO` (tab-class/section) khác nhau cho CÙNG 1 field: `AdjustmentEdit` và `ArAdjustmentAdd` — `TDTFLDEDIT` có thể khác nhau giữa 2 section này (ví dụ `CreditTerm`/`ItemName`/`ReferenceNo` = 1 ở section `AdjustmentEdit` nhưng = 0 ở `ArAdjustmentAdd`). Luôn xác định rõ TCSNO nào thực sự áp dụng cho tình huống đang xét trước khi kết luận field đã/chưa editable — chỉ check 1 TCSNO có thể ra kết luận sai.
- `DocumentAmt` (Amount) bị hardcode readonly vô điều kiện trong code-behind, bất kể config `Sys_TabDt` — xem nhóm bug #9 ở trên.
- Field "Adjustment Type" (dropdown Debit/Credit Adjustment trên UI) — chưa xác định được tên cột DB/control ID thật (không xuất hiện trong `ArAdjustmentEdit.aspx`/`.aspx.cs`, nên nhiều khả năng do `SysTabEdit1` tự render theo config `Sys_TabDt`/`Sys_Select` giống các field chuẩn khác) — sẽ bổ sung khi có kết quả tra cứu.

## Module: Cash Management (CM) / Payment

- Bảng chính: `CB_Payment` — cột số chứng từ là **`DocNo`** (không phải `DocumentNo` — dễ nhầm, các module khác có thể dùng `DocumentNo`).
- **Verify Payment** (PaymentService.Verify): sinh `GL_VoucherMain` (RecordStatus='Accounted') + `CB_Trx` (đánh dấu `IsVerified='Y'`, `RefTable`/`RefRecordID` trỏ về `CB_Payment`).
- **Cancel Payment**: KHÔNG xóa bản gốc — sinh ra 1 bản ghi `CB_Payment` reversal thứ 2 (cùng `DocNo`, giá trị âm), link qua `CB_Trx.TrxType='CancelPayment'` (`RefRecordID` = ID payment gốc). Vì vậy 1 `DocNo` trả về 2 dòng KHÔNG mặc định là lỗi duplicate — phải check `CB_Trx.TrxType` để phân biệt "reversal hợp lệ" với "trùng lặp ngoài ý muốn" trước khi kết luận.
- Sau khi patch dữ liệu `CB_Payment`/`CB_Trx`, luôn chạy recalculate lại số dư tài khoản ngân hàng:
  ```sql
  EXEC CBUpdateAccountBalance @BankAccountID = <id>, @UserID = 1
  ```
  Lưu ý: proc này có thể chạy chậm với dữ liệu lớn — ưu tiên chạy giờ thấp điểm, test ở Train trước nếu có thể.
- Rủi ro đã biết (chưa xử lý, chỉ ghi nhận): sau Cancel Payment, `GL_VoucherMain` gốc có thể không tự động bị đảo bút toán tương ứng — cần hỏi riêng nếu gặp lệch GL vs Cash sau 1 lần Cancel.
- **GL detail của 1 Cash Receipt/Payment nằm ở bảng `GL_Voucher`** (không phải `GL_VoucherMain` — bảng đó CHỈ là header/tổng, tìm bằng `VoucherMainID`). `GL_Voucher` chứa từng dòng Debit/Credit thật (`AccountCodeID`, `DeptID`, `BaseDebitAmt`/`BaseCreditAmt`...), `RefTable`/`RefRecordID` trỏ về chứng từ nguồn (ví dụ `CB_Receipt`). Khi 1 voucher có `VoucherCategory = 'Import'`, đây là voucher sinh từ batch **GL Closing > Import Sub-Ledger** (không phải real-time lúc Verify).
- **Other Payment**: view chính `View_CB_OtherPayment` (`CB_Payment`, `PaymentType='CBOtherPayment'`). Report Print Listing (`CB_OtherPaymentHeader`) dataset header là dynamic SQL `exec(...)` với `@QueryCriteria` build từ search screen — xem nhóm bug #10 (SWIBRACO-686) nếu gặp lại kiểu "list đúng nhưng print thiếu record khi filter theo field nào đó" ở report Other Payment (hoặc report Print Listing khác có cấu trúc dataset tương tự) của client khác.
- **`CB_Payment.PayTo` là free-text, có thể trống ngay cả khi payment đã link 1 Creditor thật qua `CB_Payment.CreditorID`** (FK sang AP Creditor master, resolve tên qua `view_ap_creditor.Name` — WHERE `RecordStatus='Active'`). 2 cột `CB_Payment.IsCreditor`/`CreditorName` là cặp cột KHÁC, có vẻ legacy/không đồng bộ với `CreditorID` — đã gặp ở SWIBRACO-686: payment có `CreditorID` hợp lệ nhưng `IsCreditor`/`CreditorName` đều NULL, dễ gây nhầm khi chỉ check 2 cột này rồi kết luận "không liên quan Creditor". Khi cần biết tên Payee "chuẩn" của 1 Other Payment (ví dụ để lọc/report), ưu tiên coalesce theo `CreditorID` trước (nếu có), chỉ fallback về `PayTo` raw khi không có `CreditorID` — không dùng thẳng `PayTo`/`IsCreditor`/`CreditorName` mà không kiểm tra `CreditorID`.
- **Print "PV (without Cheque)" — bảng double-entry (Code/Description/DR/CR)**: KHÔNG đọc trực tiếp `GL_Voucher` — sinh động qua subreport (ví dụ `CB_PVWithoutCheque_Sub1_SWZECON`) gọi Web Service (`GetPreviewJournalData2` trong `BusinessJournalReportsWebService.asmx`, wrap quanh `GLSubLedgerJournalPreview.GetPreviewJounals(SubLedgerCategory.CB_Payment, key, userID, lang)`). Data Source của subreport là Type=XML, connection string build từ Report Parameter riêng theo môi trường (ví dụ `ServiceURL`) — xem nhóm bug #13 (SWZECON-75) nếu bảng này ra trống mà nút "Journal" trên UI vẫn đúng: nghi ngờ đầu tiên là default value của parameter đó bị trỏ nhầm môi trường trên Report Server, không phải lỗi code/SQL.
- **Bank account master `CF_BankAccount`** (JESSELTON-272): cột chính `BankAccountID`, `CompanyID`, `BankCode` (mã hiển thị, vd `MBB-FD_JP`), `AccountNo`, `AccountTypeID`, `AccountID`, `CurrencyID`, `ReconciliationMode` (app ghi `'Munual'` — đúng chính tả sai như vậy; record migration có thể là `'M'`), `OverdraftLimit`, `RecordStatus` (`Activated`).
  - `AccountTypeID` → `CF_PopupLstElement` (PopupLstID 627, PopType `ACType`): **2249 = `BankAccount`, 2250 = `CashAccount`**.
  - `AccountID` → **`CF_Account.AccountID`** (FK `FK_CF_BankAccount_CF_Account`): với BankAccount trỏ tới bản ghi **ngân hàng** trong `CF_Account` (vd "MALAYAN BANKING BERHAD"); với CashAccount bình thường **NULL**.
  - **Cây Bank Selection** (panel trái màn hình Payment Verification, có thể cả các màn CM khác): node hiển thị `BankCode/AccountNo/<tên ngân hàng từ CF_Account>`, tách 2 nhánh "Bank" và "Cash". Nhánh "Cash" chỉ liệt kê CashAccount có `AccountID IS NULL` (suy ra từ data + test, chưa đọc code). CashAccount bị gắn `AccountID` sẽ biến mất khỏi CẢ 2 nhánh → không verify được PV của account đó. Màn nhập Payment chọn account qua dropdown nên vẫn tạo được PV, lỗi chỉ lộ ở bước Verify. Fix: `UPDATE CF_BankAccount SET AccountID = NULL WHERE BankAccountID = <id>` (không cần `CBUpdateAccountBalance`).
  - Query kiểm tra lệch loại ↔ liên kết toàn hệ thống:
    ```sql
    SELECT ba.BankAccountID, ba.CompanyID, ba.BankCode, e.ElementCode AS AccountType, ba.AccountID
    FROM CF_BankAccount ba
    JOIN CF_PopupLstElement e ON e.PopupLstElementID = ba.AccountTypeID
    WHERE (e.ElementCode = 'CashAccount' AND ba.AccountID IS NOT NULL)
       OR (e.ElementCode = 'BankAccount' AND ba.AccountID IS NULL)
    ```

## Recalculate sau khi patch dữ liệu (theo module — mỗi module 1 SP riêng, không dùng lẫn)

Sau khi patch dữ liệu trực tiếp vào DB, hầu hết module đều có 1 stored procedure "recalculate" riêng để đồng bộ lại số dư/số liệu tổng hợp — **phải xác định đúng SP của đúng module đang patch**, không suy ra module này áp dụng được cho module khác.

| Module | Recalculate SP | Tham số | Khi nào dùng |
|---|---|---|---|
| CM / Bank (Cash Management) | `CBUpdateAccountBalance` | `@BankAccountID`, `@UserID` | Sau khi patch `CB_Payment`/`CB_Trx` — chạy cho đúng 1 `BankAccountID` liên quan. Nếu vấn đề không rõ ảnh hưởng account nào (ví dụ "bank balance not tally với Cashiering Enquire vs Cash Ledger report" mà không chỉ rõ account), có thể cần chạy loop cho TOÀN BỘ bank account (xem mẫu bên dưới) thay vì chỉ 1 account. |
| Project Accounting (PM) — Construction Management > Project Accounting | `Prc_PM_RecalculateProjectBalance` | `@ProjectIDs`, `@CompanyIDs` | Sau khi patch `PM_LedgerMain` (ví dụ `DocumentDate`, `TransactionDate` của Project External Journal) — chạy theo đúng `ProjectID`/`CompanyID` liên quan. |

Bổ sung thêm khi gặp module khác có recalculate proc riêng.

**Mẫu loop CB recalculate cho TOÀN BỘ bank account** (dùng khi vấn đề ảnh hưởng nhiều/không rõ account, ví dụ ticket "Run CB recalculation" do bank balance not tally với Cashiering Enquire vs Cash Ledger report):

```sql
DECLARE @BankAccountID INT;
DECLARE Cur CURSOR STATIC FOR
select BankAccountID from CF_BankAccount

OPEN Cur;
FETCH NEXT FROM Cur INTO @BankAccountID;

WHILE @@FETCH_STATUS = 0
BEGIN
EXEC CBUpdateAccountBalance @BankAccountID, 1
   FETCH NEXT FROM Cur INTO @BankAccountID;
END;

CLOSE Cur;
DEALLOCATE Cur;
```

**Mẫu patch + recalculate cho Project Accounting (PM)** (ví dụ patch doc date/trx date cho `PM_LedgerMain`):

```sql
UPDATE PM_LedgerMain
SET DocumentDate = '<new date>',   -- was <old date>
    TransactionDate = '<new date>' -- was <old date>
WHERE LedgerMainID = <id>

EXEC Prc_PM_RecalculateProjectBalance @ProjectIDs = '<ProjectID>', @CompanyIDs = '<CompanyID>'
```

## Module: GL / Journal Processing

- File chính: `GLVoucher.aspx.cs`, class `GLVoucher_GLVoucher`. Chức năng "Reversal Posted JV" = `action == "eliminations"` (hàm `LoadEliminationsData`, `SaveVouchers`).
- **Quy tắc kế toán đúng cho JV đảo ngược (reversal/elimination): phải HOÁN ĐỔI cột Debit↔Credit**, không phải đổi dấu tại chỗ (số âm trong cột Debit/Credit là bất thường, sai chuẩn kế toán, gây lệch khi báo cáo khác tổng hợp theo giá trị tuyệt đối).
- **Đã xác nhận: lỗi "đổi dấu tại chỗ" này tồn tại ở CẢ bản TFS/standard**, không riêng khách hàng nào — nếu gặp lại ở client khác, đây là bug sản phẩm gốc, nên báo IFCA sửa nguồn.
- Còn 1 chỗ TƯƠNG TỰ nhưng CHƯA fix (ngoài phạm vi các ticket đã làm): `SaveCashFlows()` / `LoadCashFlowXml()` cũng đổi dấu tại chỗ cho Cash Flow amount — nếu có ticket liên quan Cash Flow trên JV reversal, đây là nơi cần xem trước.
- Digest (mô tả) dòng chi tiết JV reversal: nếu build tại thời điểm Load (theo mô tả JV gốc) mà không refresh lại lúc Save theo input hiện tại của user → sai (xem nhóm bug #1 ở trên).
- Bug "field post sai giá trị nhưng chỉ 1 user gặp" trên màn hình Verify Journal/Post GL: xem nhóm bug #7 ở trên (SWZECON-82) — nghi ngờ cấu hình IE Security Zone/.NET Framework của máy đó trước khi đào sâu SP/code.

## Module: PO / GRN (Purchase Order / Goods Received Note)

- `PO_PurchaseItem.BalanceQty`: số lượng CỦA DÒNG PO còn có thể nhận hàng (giảm khi tạo GRN, tăng khi Return hàng).
- `PO_GRNItem.BalanceQty` / `VerifiedBalanceQty`: khác với trên — là số lượng CỦA DÒNG GRN còn có thể TRẢ LẠI (return), set = Quantity lúc GRN được tạo, giảm dần khi return.
- Popup chọn PO khi tạo GRN mới lọc theo view `View_PO_PurchaseOrder_PurchaseItem_Select`, điều kiện cốt lõi: `a1.BalanceQty > 0` (đọc trực tiếp từ `PO_PurchaseItem.BalanceQty`) — bất kỳ bug nào làm `BalanceQty` bị tính sai (thừa/thiếu) đều ảnh hưởng trực tiếp đến việc PO item có bị chọn lại nhầm hay không.
- `CF_XRef`: bảng cross-reference DÙNG CHUNG toàn hệ thống (không riêng PO/GRN) để link 2 bản ghi bất kỳ — cột `FromRefTable/FromRefRecordID` → `ToRefTable/ToRefRecordID`. Dùng để trace quan hệ giữa GRN item gốc và GRN item return tương ứng.
- File xử lý Goods Return: `PurchaseOrder_GoodsReturnEdit.aspx.cs` (khác với `PurchaseOrder_POGRNEdit.aspx.cs` — file GRN nhận hàng thông thường). 2 file này DÙNG CHUNG khái niệm balance nhưng xử lý riêng, đừng nhầm lẫn khi tra code.
- Xem thêm cách trace audit log chi tiết ở mục riêng bên dưới — đã dùng thành công để tìm root cause SWHARTANAH-333.

## Module: AR / Billing / Tax

- Công thức tính thuế chuẩn (dùng chung mọi nơi tính tax trong AR/AP):
  - **Inclusive** (giá đã gồm thuế): `TaxAmount = (Amount × Rate) / (1 + Rate)`
  - **Exclusive** (giá chưa gồm thuế): `TaxAmount = Amount × Rate`
  (Rate = TaxRate/100)
- `PMCommonBL` là BL class dùng chung cho nhiều màn hình billing. Lưu ý: TFS có thể có NHIỀU hàm tên gần giống nhau cho cùng mục đích (ví dụ `SaveARTrxMod` và `SaveARTrxMod2`) — khi so sánh bản client với TFS, phải xác nhận ĐÚNG hàm nào đang thực sự được gọi (qua trang gọi vào, không chỉ đoán theo tên), tránh so nhầm hàm.
- `AR_BillItem.IsRebate = 'Y'`: KHÔNG đại diện cho 1 loại rebate duy nhất — gộp cả "LOT - DISCOUNT ALLOWED" (chiết khấu giá) và "Interest Rebate" (hoàn lãi) và có thể còn loại khác. Khi cần tính đúng 1 loại rebate cụ thể, phải lọc thêm theo `ItemName` chính xác, không chỉ dựa vào `IsRebate`.
- **`AR_Trx`** là bảng transaction dùng chung cho NHIỀU loại nghiệp vụ AR khác nhau (không chỉ billing thông thường), phân biệt qua cột `ReceivableType` — ví dụ `OD_Adjustment` = Other Debtor Adjustment (màn "Other Receivable", tab `AR.AdjustmentOfOtherDebtor`, write table xác nhận qua `Sys_Base.BseWriteTable`). Các cột amount chính: `DocumentAmt`, `BalanceAmt`, `DocumentAmtBefTax`, `TaxAmt`, `ChargeAmt` — quan hệ đúng: `DocumentAmt = DocumentAmtBefTax + TaxAmt`. "Base Document Amount" hiển thị trên UI không có cột riêng, tính từ `DocumentAmt × ExchangeRate`.
- **Kiểu dữ liệu cột `AR_Trx`**: hầu hết cột amount (`DocumentAmt`, `BalanceAmt`, `TaxAmt`, `ChargeAmt`, `DocumentAmtBefTax`, `TaxExemptAmt`, `OriginalDocAmt`...) đều là `decimal(22,10)`. Ngoại lệ — CHỈ 3 cột sau là `float`: **`ExchangeRate`, `TaxRate`, `TaxExemptRate`**. Xem nhóm bug #6 ở trên (FARLIMPG-169): field `TaxExemptRate` gây lỗi type-mismatch khi = 0 (không NULL) do entity model khai `Decimal?` trong khi cột vật lý là `float`.
- **Đã gặp 1 lần (GRSUMMIT-204)**: bản ghi `OD_Adjustment` có `DocumentAmt`/`BalanceAmt` (raw trong `AR_Trx`) = 0 trong khi đúng ra phải có giá trị. **Quan trọng: `DocumentAmt`/`BalanceAmt` hiển thị trên UI = ĐẢO DẤU của giá trị raw** (xem view `View_AR_AdjustmentOfOtherDebtor` ở mục Sys_ Framework bên trên) — khi patch lại giá trị đúng, phải patch NGƯỢC DẤU với giá trị mong muốn hiển thị trên màn hình, không patch thẳng giá trị hiển thị vào cột raw. `DocumentAmtBefTax` thì view lấy `ABS()` nên dấu raw của cột này không ảnh hưởng hiển thị — kết luận trước đó cho rằng "`DocumentAmtBefTax` đã đúng sẵn, chỉ cần đồng bộ sang `DocumentAmt`" là SAI, vì không tính đến việc view đảo dấu.
- **Auto Reversal / Void cho AR Adjustment** (`ARVoidTransaction.VoidAdjBill`): sinh 1 bản ghi `AR_Trx` mới (đảo dấu `DocumentAmt`/`TaxAmt`/`DocumentAmtBefTax`) link qua `RefTable`/`RefRecordID` về bill gốc, đồng thời set `BalanceAmt = 0` ở cả 2 bên và inactive các `AR_Allocation` liên quan. Có tích hợp riêng cho E-Invoice (đánh dấu `IOI-9835`) để lấy đúng `DocumentDate` theo `VoidDate` cho bản ghi reversal (`clsEInvoiceHelper.GetReversalDocumentDate()`). Trước dòng `ClassUtil.EntityClone<ARTrxEntity>(adjTrx)` bên trong hàm này là điểm đúng nhất để chặn lỗi type-mismatch dạng nhóm bug #6 (normalize field lỗi về NULL qua `entity.Fields["..."].CurrentValue = null` ngay tại đây, KHÔNG cần sửa màn hình tạo/sửa hay patch SQL — xem FARLIMPG-169).
- **Màn hình tạo/sửa Other Receivable Adjustment**: `AccountReceivable_OtherAdjustmentEdit.aspx.cs` (khác với `AccountReceivable_OtherAdjustmentDelete.aspx.cs` — file riêng cho Void/Auto Reversal, xem `ARVoidTransaction.VoidAdjBill` ở trên). `Save_Click` của file Edit build 1 `NameValueCollection` rồi gọi `SysTabEdit1.SaveData(tranction, NameValue)` để ghi `AR_Trx` — bất kỳ field nào bị `NameValue.Add(...)` vô điều kiện (không check flag liên quan) đều có nguy cơ ghi đè sai giá trị mặc định thay vì để NULL (xem nhóm bug #6, FARLIMPG-169). **Lưu ý: field ghi qua đường này KHÔNG THỂ set về NULL được** (xem gotcha `SysTabEdit1.SaveData` ở mục Framework bên dưới) — nếu cần NULL, không sửa được ở đây, phải xử lý tại điểm dùng dữ liệu (ví dụ `VoidAdjBill` như trên).
- **Debtor Ledger Report (custom, clone theo client, ví dụ `View_Report_DebtorLedgerReport_FPARK`/`_TIMATCH`)**: view dạng nhiều block UNION ALL, mỗi block lấy 1 loại chứng từ (billing thường, contra receipt, reversal/CM, refund...). Xem nhóm bug #15 ở trên (FPARK-166) — khi debug report dạng này, luôn đọc riêng từng block, không giả định các block xử lý `RecordStatus` nhất quán với nhau.

## Module: Property Sales / Reporting

- Report/view thường có bản clone riêng theo client (hậu tố `_<CLIENT>`, ví dụ `View_PS_Sales_Status_Report_FARLIMPG_Final`) — khi sửa, chỉ sửa đúng bản của client đang yêu cầu, không đụng bản chuẩn/clone của client khác.
- `AR_Trx` liên kết `AR_BillItem` (BillItemID) và `PS_Unit`/Lot (UnitID) — dùng để tổng hợp số liệu theo từng lot/unit trong các report Property Sales.

## Module: Property Sales / Letter Printing — `PrintService.cs` (web service in Letter)

Màn hình Property Sales > Letter Printing (và Standard Letter / Edit Template) dùng chung 1 web service `PrintService.cs` cho MỌI loại Letter (Progress Billing, Payment Reminder, Official Receipt, MOT, VP...) và nhiều module khác (MC/Rental bill, HR letter...). Đã đọc code thật ở SWCHENGLING-76.

- **Entry point**: các WebMethod `GetLetterSettingByLetterID` / `GetLetterSettingByLetterID1/2/3` → đều gọi `GetLetterDataByLetterID(isMergeDoc, letterID, wherePhrase, subWherePhrase, mainSql, subSql, conditionID, userID, out error)`.
- **`wherePhrase` / `subWherePhrase`** = điều kiện lọc user chọn trên UI (field + toán tử + giá trị, kết hợp And/Or), được **mã hoá AES** từ client, giải mã bằng `UtilityHelper.DecryptAES(...)` rồi ghép thẳng vào SQL dạng **literal** (không parameter) — hệ quả hiệu năng xem nhóm bug #12.
- **Cấu hình Letter** đọc từ `view_cf_lettersetting` (`where letterID = ...`): các cột quan trọng `MainBseReadTable` (view Master), `SubBseReadTable`, `SubBseNoSortClause`, `Language`, `ConfigDataType` (`Procedure` hay view/table), `ProcedureConfig`, `IsCustomiseLetter`, `IsCustomiseMainTable`. Ngoài ra `GetLetterSetting(letterID)` → `CFLetterTypeViaLetterTypeID` (`LstNo`, `RelationField`) → `GetSysListSetting(lstNo)` (`LstFilter`, `LstSort`).
- **Dispatch theo `LetterTypeID`**: `switch (letterSetting.LetterTypeID)` có RẤT NHIỀU `case` hardcode riêng (3, 24, 32/33, 35, 44, 53, 113/114, 863, 923-939, 954/955...) tự build `mainSql` riêng. Letter không nằm trong case nào đi vào nhánh **`default`**. Trước switch có `Common.pf_CustomizationChangeValue(..., "SetOldLetterTypeID", ...)` có thể đổi LetterTypeID (IOI-1882).
- **Nhánh `default`** (đường đi của đa số Letter customize theo client, ví dụ `View_PSLetter3233_Master_SWCHENGLING`), thứ tự:
  1. `Common.pf_CustomizationChangeLetter(...)` (NAIMCAP-153) — nếu trả khác null thì return luôn.
  2. `Common.pf_CustomizationPrintProgressBilling(..., "ProgressBilling", "GetChangeProgressBilling")` (NAIMCAP-72) — tương tự.
  3. Nếu `IsCustomiseLetter='Y'` và `IsCustomiseMainTable='Y'` → main table lấy qua `Common.pf_LoadCustomization(..., "clsPrintService", "GetLetterDataByLetterID_MainTable", "GetLetterPrintServiceMaintable", ...)` (hook customize theo client, MYTE-644/IJM-87).
  4. Nếu `ConfigDataType = Procedure` → `GetMainDataProcedure(bseNo, ProcedureConfig, wherePhrase)`: `ProcedureConfig` dạng `"<ProcName>@<param1>,<param2>"`, giá trị tham số lấy bằng cách **split `wherePhrase` theo dấu phẩy** → chỉ dùng được khi UI truyền danh sách giá trị, **KHÔNG dùng được với điều kiện SQL tự do** của màn hình Letter Printing thông thường.
  5. Còn lại → **`GetMainDataTable(tableName, lstFilter, lstSort, wherePhrase)`**: build `SELECT * FROM <view>` + `\r\n where <lstFilter> and <wherePhrase>`, `CommandTimeout = 360000`, **sort thực hiện trên DataTable** (`DefaultView.Sort = lstSort`, không ORDER BY trong SQL — comment gốc: tránh timeout), set `strMainSQL = "select distinct [relationField] from (<sql>) a"` để phần Sub dùng.
  6. Sau đó `FormatString`, `pf_LoadCustomization(..., "PrintBy", ..., "ChangeValueTable")` (NAIMCAP-468), đổi DBNull → ""/0, `FilterCompanyByUser(...)`.
- **Sub table**: nếu `!isMergeDoc` và có `SubBseReadTable` → `_MainSql = "select <relationField> from <MainBseReadTable> where <wherePhrase>"` → `GetSubDataTable(SubBseReadTable, subWherePhrase, _MainSql, ...)` (Sub view lọc theo `relationField IN (<_MainSql>)` — đây là lý do câu Sub luôn nhúng lại view Master trong `IN (...)`). Nếu `isMergeDoc` → `GetSubTable(LetterTypeID)` trả nhiều sub table, mỗi dòng có `BseNo` (tra `sys_Base.bsereadtable`), `relationField`, `SubTableID`, `ProcedureConfig`, `IsCustomiseSubTable` (hook STG-74). `GetSubDataTable` có `switch (tableName.ToLower())` xử lý riêng vài view (`view_psletter21_sub`, `view_psletter2_sub`...).
- **Edit Template** (Standard Letter) lấy danh sách merge field bằng `SELECT TOP 0 * FROM <MainBseReadTable>` — chỉ lấy cấu trúc cột nên không chậm dù view lớn. Vì vậy **view Master vẫn phải giữ đủ cột** kể cả khi lúc in đã chuyển sang lấy dữ liệu từ SP.
- **Pattern tối ưu 1 Letter chậm mà không ảnh hưởng Letter khác** (dùng ở SWCHENGLING-76): trong `GetMainDataTable`, thêm nhánh `if (string.Equals(tableName, "<View cụ thể>", StringComparison.OrdinalIgnoreCase))` ngay sau `DataTable dt = null;` → `select distinct <key> from <view> <filter>` (giữ nguyên filter UI) → gọi SP nhận danh sách key → sort theo `lstSort`, set `strMainSQL` như code gốc → `return dt`. Các Letter khác đi đường cũ.
- Liên quan: view `View_PS_LetterUnit` là view dùng CHUNG cho nhiều Letter PS (lọc `PS_Sale.RecordStatus IN ('Book','sale','sign')`) — xem ASPENPG-684 khi Letter không in ra record của Sale đã `Return`.

## Framework / component dùng chung (áp dụng mọi module, mọi client)

- **`SysListEditor` / `SysListEditor2`**: control grid CRUD dùng chung toàn hệ thống. 1 trang có thể có NHIỀU `SysListEditor` khác nhau, mỗi cái có `SaveDataMethod` riêng — nếu 2 control cùng trỏ vào 1 hàm save, hàm đó sẽ chạy nhiều lần/1 lần bấm Save trang. Bất kỳ biến nào trong hàm save không được canh đúng theo `row.RowState` đều có nguy cơ bị "dính" sai ở lần gọi thừa.
- **`SysCondition` / `SysListPrint` / `f_GetConditionFilter`**: framework JS dùng chung cho nhiều màn hình list/report để build điều kiện lọc trước khi in/search. Lỗi hay gặp: (a) hardcode ID DOM thay vì dùng `<%=Control.ClientID%>`; (b) vòng lặp quét `<select>` không loại trừ các dropdown ẩn không có `name` (thường do control lịch/calendar popup để lại trong DOM sau khi user đã từng mở). **Lưu ý phân biệt**: đây là lỗi build criteria ở tầng JS/client — khác với nhóm bug #10 (SWIBRACO-686), là lỗi ở tầng dataset SQL (criteria build đúng, nhưng áp lên sai view/nguồn dữ liệu). Khi debug 1 report "in thiếu/sai record", nên trace SQL Profiler xem `@QueryCriteria` thực nhận được là gì TRƯỚC, để biết lỗi nằm ở JS (criteria sai ngay từ đầu) hay ở dataset SQL phía sau (criteria đúng nhưng áp sai chỗ).
- **Audit log** (mọi bảng nghiệp vụ chính): xem chi tiết đầy đủ ở mục dưới — dùng chung cho MỌI client vì đây là cơ chế trigger-based chuẩn của IFCA. **Tên database audit giống nhau ở mọi client: `IFCANetAudit_R2_8`** (không cần hỏi lại/đoán theo tên client mỗi lần).
- **`ClassUtil.EntityClone<T>`**: tiện ích generic clone entity dùng chung (thư viện Utility, không phải App_Code) — copy `CurrentValue` từng field qua reflection (match theo tên property ↔ tên field), dùng `SetNewFieldValue` để set vào entity mới. KHÔNG có ép kiểu thủ công bên trong — nếu throw lỗi type-mismatch, nguyên nhân luôn nằm ở chỗ 1 field nào đó của entity NGUỒN đã tự mang sai kiểu runtime (ví dụ cột vật lý `float` nhưng model khai `Decimal?`, xem nhóm bug #6) chứ không phải lỗi của bản thân hàm clone này.
- **`SysTabEdit1.SaveData(DbTransaction transaction, NameValueCollection extendData, List<string> excludeData)`** — hàm save dùng chung của control `SysTabEdit`/`SysTabEdit2`, build câu Insert/Update thủ công (không qua LLBLGen) qua 2 nhánh xử lý field HOÀN TOÀN riêng biệt:
  1. **Nhánh `extendData`** (field code-behind tự thêm bằng tay qua `NameValue.Add(key, value)`, dùng khi field không thuộc danh sách chuẩn của tab): với MỌI key khớp tên cột ghi được, giá trị LUÔN bị bọc qua `SqlExpression.String(extendData[text])` — **hàm này không có bất kỳ xử lý NULL nào**, kể cả truyền `""` hay `null` (C#) cũng đều build ra 1 string literal, và SQL Server tự động convert chuỗi rỗng `''` sang `0` khi gán cho cột kiểu numeric/float (khác hẳn với chuỗi không hợp lệ khác sẽ báo lỗi convert). **Kết luận quan trọng: field ghi qua đường `NameValueCollection` này KHÔNG THỂ set NULL được, dù thử cách nào** (đã test cả `""` và `null`, đều ra `0`) — đây là giới hạn cứng của framework, không phải lỗi dùng sai giá trị.
  2. **Nhánh `tabDetails`** (field chuẩn khai báo trong `Sys_TabDt`, đọc trực tiếp từ Control trên trang qua `GetValueByControl`): nhánh này CÓ xử lý NULL đúng chuẩn (`if (!string.IsNullOrEmpty(valueByControl)) {...} else { val = SqlExpression.Null(); }`) — nhưng chỉ áp dụng cho field có `Sys_TabDt.TdtFldEdit = '1'` cho đúng Tab đang dùng; field có `TdtFldEdit = 0` (hoặc không có row trong `Sys_TabDt` cho Tab đó) bị `continue` bỏ qua hoàn toàn trong vòng lặp này, dù field đó VẪN xuất hiện ở `Sys_TabDt` cho TAB KHÁC (mỗi Tab có row `Sys_TabDt` riêng cho cùng tên field, `TdtFldEdit` có thể khác nhau giữa các Tab).
  → **Cách xác định 1 field save qua đúng nhánh nào** (không đoán): `SELECT * FROM Sys_TabDt WHERE TdtFldName = '<TênField>' AND TdtTabNo = '<TabNo của đúng màn hình>'` — nếu không có row hoặc `TdtFldEdit != '1'`, field đó chỉ có thể ghi qua `extendData` (code-behind tự `NameValue.Add`), và do đó **không set NULL được qua đường save này** — nếu cần NULL, phải xử lý ở nơi khác (ví dụ tại điểm dùng dữ liệu, xem FARLIMPG-169/`VoidAdjBill`), không cố tìm cách "vá" tại `Save_Click`.
- **`Sys_TabDt.TdtFldEdit` chỉ quyết định phần "field có được `SaveData` xử lý qua nhánh control-bound hay không" và (ở 1 số control) trạng thái ReadOnly mặc định lúc render — nó KHÔNG đảm bảo field thực sự editable trên UI**, vì code-behind (`CustomControlsCreated`/`OnInit`/`OnPreRender`) luôn có thể `FindControl` rồi override `ReadOnly`/`Enabled`/`Visible` lại sau đó — xem nhóm bug #9 (LKHS-203). Khi 1 field vẫn khoá dù config đã đúng, luôn kiểm tra tiếp code-behind, không dừng lại ở việc sửa `Sys_TabDt`.
- **`DataAccessHelper`** (data access dùng chung): `ExecuteDataTable(string sql)`, `ExecuteDataset(string sql | SqlCommand/DbCommand)`, `ExecuteScalar`, `ExecuteDataSet2(procName, params object[])` (gọi SP theo thứ tự tham số), `CreateConnection()`, `CurrentInstance` (Enterprise Library Database). Gọi SP có tham số đặt tên: tạo `SqlCommand` với `CommandType.StoredProcedure` + `Parameters.Add(...)` rồi `DataAccessHelper.ExecuteDataset(cmd)` (đã dùng ở SWCHENGLING-76). Lưu ý: kết nối ADO.NET mặc định `ARITHABORT OFF` còn SSMS `ON` → SQL Server cache 2 plan riêng cho app và SSMS; lần gọi đầu từ app vẫn phải compile riêng dù SSMS đã chạy trước.
- **Report/subreport dùng Data Source Type=XML gọi Web Service, với 1 Report Parameter riêng làm connection string theo môi trường** (ví dụ `ServiceURL`): khi troubleshoot 1 report/subreport dạng này bị trống/sai data mà không có lỗi hiển thị rõ ràng, kỹ thuật hiệu quả nhất là gọi TRỰC TIẾP WebMethod đứng sau (qua trang test `.asmx?op=<MethodName>` tự sinh, chạy từ chính server host) để cô lập ngay: nếu ra đúng data → vấn đề chắc chắn ở cấu hình Report Server (Parameters/Data Source), không phải code/SQL — xem nhóm bug #13 (SWZECON-75).

## Bảng framework/hệ thống dùng chung (không phải bảng nghiệp vụ riêng module nào)

### Sys_ Framework — metadata-driven UI engine

Gần như MỌI module (Cost, Sale, MCorp, Rental, AP, AR...) được dựng động từ các bảng `Sys_` này — không hardcode UI riêng từng màn hình. **Khi gặp bug về hiển thị/hành vi UI** (field không hiện, không sửa được, sai required, sai dropdown...), cần nghĩ tới khả năng đây là **lỗi config trong các bảng Sys_ này**, không phải lỗi code C#/JS.

| Bảng | Vai trò |
|---|---|
| `Sys_Application` | Danh mục module hệ thống (Cost, Sale, MCorp, Rental, AP, AR...), mỗi record 1 module, link qua `ApplicationCode` |
| `Sys_Base` | Định nghĩa Basic Resource — nguồn dữ liệu (read table/view, write table, primary key), nền tảng cho cả grid list và form edit |
| `Sys_BaseDt` | Chi tiết field của Basic Resource — kiểu hiển thị, width, required (`BdtLstNeed`), editable (`BdtLstEdit`), visible (`BdtLstDisplay`), dropdown list... **Bảng quan trọng nhất để config UI** |
| `Sys_Tab` | Định nghĩa Edit Resource — form chỉnh sửa (`SysTabEdit`), link `Sys_Base` qua `TabBseNo` |
| `Sys_TabClass` | Các tab/section trong form edit (ví dụ "Contract Information", "Contract Signing Information") |
| `Sys_TabDt` | Field hiển thị trong từng tab của form edit |
| `Sys_TabCard` | Container chứa các tab (`SysContainerTab`), config button menu cho từng tab |
| `Sys_List` | Định nghĩa List Resource — grid list (`SysListEditor`): sort, filter, view |
| `Sys_ListDt` | Field hiển thị trong grid list — width, edit, visible |
| `Sys_Select` | Config popup chọn dữ liệu (`DataSelect.aspx`) — SQL query, return fields, update fields |
| `Sys_Menu` | Cấu trúc menu hệ thống, URL page, parent menu |
| `Sys_MenuDefine` | Menu mapping/hint |
| `Sys_MenuTemplate` | Template menu theo module/AppCode |
| `Sys_ContextMenuClass` | Nhóm button (Save, Edit, Delete...) |
| `Sys_ContextMenu` | Chi tiết từng button — script JS, permission, icon |
| `Sys_Filter` | Field dùng để filter/search trong list |
| `CF_String` | Bảng dịch đa ngôn ngữ (EN, CN, MY, TH...) — mọi label/text trỏ về qua `StringCode` |

Liên kết chính:
```
Sys_Application (AppCode)
    → Sys_Base (BseNo) → Sys_BaseDt (BdtBseNo, BdtFldName)
    → Sys_Tab (TabNo) → Sys_TabClass → Sys_TabDt
    → Sys_TabCard → Sys_ContextMenu
    → Sys_List (LstNo) → Sys_ListDt
    → Sys_Select (SelNo) ← BdtSelNo
    → CF_String (StringCode) ← tất cả StringCode fields
```

`PrivilegeHelper.GetSysTabEditRevokeFieldNames` dùng `Sys_Tab`/`TabNo` để quyết định field nào bị khoá theo phân quyền user.

**Kỹ thuật tra bảng ghi dữ liệu thực sự đằng sau 1 tab/màn hình khi chưa biết tên bảng** (áp dụng mọi client, mọi module — đã dùng lần đầu ở GRSUMMIT-204): lấy `TabNo` từ URL màn hình (tham số `TabNo=` trên `ApproveView.aspx`/`Edit.aspx`...), rồi join `Sys_Tab` → `Sys_Base` để lấy đúng bảng đọc/ghi, không cần đoán theo kinh nghiệm:

```sql
SELECT b.BseNo, b.BseName, b.BseReadTable, b.BseWriteTable
FROM Sys_Tab t
JOIN Sys_Base b ON b.BseNo = t.TabBseNo
WHERE t.TabNo = '<TabNo>'
```

### Cấu trúc cột THẬT của các bảng Sys_ / CF_ và quy ước script config (xác nhận ở LKHS-271 — KHÔNG hỏi lại)

**Quy ước viết script config (Gunner yêu cầu, áp dụng mọi ticket IFCA):**
- Script phải **chạy lại được nhiều lần** để commit TFS rồi deploy Train/Live Testing/Live: mỗi bảng 1 khối `IF EXISTS (SELECT TOP 1 1 ... WITH (NOLOCK) WHERE <khoá>) BEGIN DELETE ... END` rồi `INSERT` lại. **Không cần file rollback riêng.**
- **Không dùng ID cứng theo môi trường** (PopupLstID, MnuId, identity...). Cần giá trị không biết trước (IntegrityCheck, StringType...) thì `INSERT ... SELECT` từ dòng mẫu có sẵn theo **mã** (vd copy menu từ `MnuNo` mẫu).
- Tách riêng script dữ liệu test (chỉ local, không commit).
- Sau khi chạy config: **restart site / recycle App Pool** — `Sys_Menu` và `CF_String` bị cache lúc app start, chuỗi mới hiện "`<code lowercase> - Please Translate`" cho đến khi restart.
- Đồng nghiệp có tool "SQL Clone Tool" (Clone by Key: Base / Tab / List / Filter / Report / Context Menu / String) sinh script đúng style trên — dùng để clone config từ màn hình mẫu. Tool KHÔNG có phần Menu.

**`Sys_Base`**: `BseId`(identity), `BseClass`, `BseNo`, `BseName`, `BseNameStringCode` (`Sys_Base_Name_<BseNo>`), `BseReadTable` (view đọc), `BseWriteTable`, `BseDesc`, `BseDescStringCode` (`Sys_Base_Desc_<BseNo>`), **`BseIdField`** (khoá — chính là giá trị `gridManager2.GetSelectedRowIds()` trả về), `BseQryType`, `BseMenu`, `BseDefine`.

**`Sys_BaseDt`** (khai báo MỌI cột của view nguồn): `BdtBseNo, BdtFldName, BdtFldDesc, BdtFldDescEN, BdtFldDescStringCode, BdtFldHelpStringCode, BdtFldMaxLen, BdtFldType, BdtFldWidth, BdtFldAlign, BdtFldVAlign, BdtLstDefault, BdtLstNeed, BdtLstEdit, BdtLstDisplay, BdtPrnDefault, BdtFldOrder, BdtFldList, BdtTabDisplay, BdtTabSave, BdtFormula, BdtFilter, BdtTabChg, BdtTabDefault, BdtTabSelect, BdtPrivilege, BdtFldKind, BdtTabWidth, BdtRelationName, BdtTabColSpan, BdtFldBEmpty, BdtFldUEmpty, BdtFldRange, BdtSelNo, BdtWriteTable, BdtWriteField, BdtDecimalPlace, BdtIsCurrentDate, BdtIsNegativeAllow`.
- `BdtFldType`: `I` int, `S` string, `FM` tiền (kèm `BdtDecimalPlace` 2/8), `D` date, `L2`/`L3` dropdown dịch qua StringCode (`BdtRelationName` = cột giá trị thật, vd `Currency`→`CurrencyID`; `BdtSelNo` = danh sách), `LC` dropdown danh sách cố định (`BdtFldList`='YesOrNo'), `Selecter`.
- `BdtLstDisplay` 1/0 (cột ID để 0). `BdtFilter`: NULL = không search được, 0/1 = search text/khoảng, 2 = dropdown (quan sát từ `AC.Payable`).
- Quy ước StringCode field: `<BseNo>_<FldName>`.

**`Sys_List`**: `LstId, LstNo, LstOrder, LstName, LstNameStringCode, LstTitle, LstTitleStringCode, LstBseNo, LstSort, LstFilter, LstFilterDesc, LstStat, LstDefault, LstUseId, LstRange, LstFront, LstPage`. Mỗi list tối thiểu 2 dòng: `LstOrder = -1` (mẫu hệ thống, LstDefault N) và `1` (layout mặc định, **LstDefault Y**). StringCode: `Sys_List_Name_<LstNo>_<LstOrder>`, `Sys_List_Title_<LstNo>_<LstOrder>`.

**`Sys_ListDt`** (cột lưới, theo từng LstOrder): `LdtId, LdtLstNo, LdtLstOrder, LdtFldName, LdtFldDesc, LdtFldDescEN, LdtFldDescStringCode, LdtFldHelpStringCode, LdtFldMaxLen, LdtFldWidth, LdtFldAlign, LdtFldVAlign, LdtFldType, LdtFldEdit, LdtFldOrder, LdtFldDisplay, LdtStatMode, LdtFixHeaderStringCode, LdtFixHeaderSeq`. Tiêu đề cột trên lưới lấy `LdtFldDesc`; màn hình List Layout Configuration lấy qua CF_String.

**`Sys_Filter`** (Ô SEARCH phía trên lưới — thiếu bảng này thì không có ô search): `FltId, FltBseNo, FltLstNo, FltTitle, FltType, FltPrecision, FltDisMode, FltRange, FltBFromTable, FltBDisText, FltBDisValue, FltBDefaultMode, FltBIncNullText, FltBIncNullvalue, FltEFromTable, FltEDisText, FltEDisValue, FltEDefaultMode, FltEIncNullText, FltEIncNullvalue, FltOrder, FltNewline, FltName, FLtListData`. Mẫu đã dùng: chuỗi `FltType='S', FltDisMode=0, FltRange=0`; ngày `FltType='D', FltRange=1` (từ–đến); `FltEIncNullText=1`, `FltNewline=0`, `FltName` = tên field.

**`Sys_ContextMenuClass`** (BẮT BUỘC đăng ký MnuClass của nút): `MnuClass, DescriptionStringCode` (`MnuClass_<MnuClass>`).
**`Sys_ContextMenu`** (nút toolbar): `ContextMenuID`(identity), `ContextMnuNo, MnuClass, MnuNo, MnuStringCode` (`<MnuNo>_<MnuClass>_<ContextMnuNo>`), **`MnuScript`** (hàm JS, vd `f_PaymentAuto()`), `InitStatus, CausesValidation, IsInDropDown, IsNeedPrivilege` ('Y' = cần cấp quyền), `ImageName, ParentID, SeqNo`. Trang list đọc danh sách nút: `select ContextMnuNo from Sys_ContextMenu where MnuNo=.. and MnuClass=.. order by SeqNo`.

**`Sys_Menu`**: `MnuId, MnuSystem` (vd `Cashiering`), `MnuType, MnuOrder, MnuNo, MnuName, MnuNameEN, MnuBaseNameStringCode, MnuNameStringCode, MnuProgram` (**URL trang**, quy ước `/CashFlow/<Page>.aspx?MnuNo=<MnuNo>` — KHÔNG có cột MnuUrl), `MnuPic, MnuParentNo` (nhóm cha), `MnuFunNo, MnuMduNo, MnuDesc, MnuEdition, MnuClass, MnuClsOrder, IsVisible, IntegrityCheck, RecordStatus, IsLeaf, IsHideMenu`.
- **Tên menu trong cây Menu Template lấy theo `MnuBaseNameStringCode`** (quy ước `<MnuNo>_Base`) — copy nguyên từ menu mẫu sẽ hiện trùng tên menu mẫu.
- `IntegrityCheck` (chuỗi mã hoá): copy nguyên từ menu mẫu cùng nhóm vẫn hoạt động (đã test LKHS-271).
- **Menu mới chỉ hiện sau khi gắn vào Menu Template**: System Setup > Menu Template Definition (`/System/SysMenuTemplateAM.aspx`) → chuyển menu từ cây trái sang "Selected Menu" → Save, cho từng template user dùng (System Menu, Standard Menu (LKHS)...). Header template ở `Sys_MenuTemplate`: `TemplateID, TemplateNo` (vd `IFCATemp0001`), `TemplateDesc` (vd "System Menu"), `IsDefault, ApplicationCode, CreateUserID, CreateDate, ModifyUserID, ModifyDate, RecordStatus` (bảng chi tiết menu ↔ template: chưa ghi nhận). **Quy ước: KHÔNG script phần gắn menu vào template** — để user/consultant tự gắn trên màn Menu Template Definition ở từng môi trường (đúng hơn vì template khác nhau theo client); script config chỉ tạo `Sys_Menu` + CF_String, và ghi chú bước gắn template trong hướng dẫn deploy.
- Nhóm menu Cash Management: `Cash-01` Cashiering Setting, `Cash-03` Receipt (`mcorp-15-07` Collection Verification `/CashFlow/ACReceiptVerify.aspx`, `mcorp-15-08` `ACReceiptBook.aspx`, `mcorp-15-16` Other Receipt), `Cash-06` Payment (`mcorp-15-09` Generate Payment `/CashFlow/ACPayment.aspx`, `mcorp-15-10` `ACPaymentBook.aspx`, `Cash-06-06` Payment Listing Screen), `Cash-15` Cash Book/Report.

**`Sys_Tab`** (form edit — `SysTabEdit TabNo`): `TabNo` nvarchar(30), **`TabName` nvarchar(20) — rất ngắn, dễ lỗi "String or binary data would be truncated"**, `TabBseNo` nvarchar(40), `TabNameStringCode` (`Sys_Tab_Name_<TabNo>`, CF_String `Common`/`Sys_Tab`).
**`Sys_TabClass`** (section trong form): `TcsTabNo, TcsNo` (vd `AC00073`), `TcsName` nvarchar(60), `TcsNameEN` varchar(50), `TcsNameStringCode` (`TabClass_<TabNo>_<TcsNo>`, CF_String `Field`/`Sys_TabClass`), `TcsClass`, **`TcsListNum`** (số field trên 1 hàng).
**`Sys_TabDt`** (field của form): `TdtBseNo, TdtTabNo, TdtTcsNo, TdtFldName` nvarchar(30), `TdtFldDesc, TdtFldDescStringCode, TdtFldHelpStringCode, TdtFldEdit` ('1' = sửa được, NULL = chỉ đọc), `TdtFldOrder, TdtListType, TdtIsHidden, TdtIsNewLine, TdtIsMergeNextField`. Field phải có trong `Sys_BaseDt` của `TabBseNo`. **Field chỉ hiện trên form khi `Sys_BaseDt.BdtTabDisplay = '1'`** — để NULL thì form ra trống (chỉ có tiêu đề), dù `Sys_TabDt` đủ (LKHS-271). Form xem chỉ đọc dùng chung: `../Common/ApproveView.aspx?TabNo=<TabNo>&isView=Y&CurId=<id>` — chỉ cần config Sys_Tab/TabClass/TabDt, không cần code trang.
- Field dropdown trên form: `Sys_BaseDt.BdtFldType='L'`, `BdtFldList` = tên danh sách CF_PopupLst (vd `PayMethod`), `BdtRelationName` = cột giá trị → **ID control trên trang = `BdtRelationName`** (code-behind `SysTabEdit1.FindControl("PayMethod") as DropDownList`, có thể `Items.Clear()` rồi nạp lại trong `SysTabEdit1.CustomControlsCreated`). Field `S` có relation (vd `ACNo` → `BankAccountID`) sinh thêm hidden field theo relation. Ngày = `WebDateChooser`. Gán giá trị: `SysTabEditUtil.SetSysTabEditValueByName(SysTabEdit1, name, value)`.
**`Sys_TabCard`** (khung tab chứa iframe/lưới con — `SysContainer TcdTabNo` + `SysContainerTab TcdCardNo`): `TcdId`(identity), `TcdTabNo, TcdCardNo` nvarchar(30), `TcdStringCode` (tiêu đề khung, CF_String `Field`/NULL), `TcdScript, TcdOrder`, **`MnuClass, MnuNo`** = nhóm nút hiện trên khung (vd Import/Remove).
- Độ dài: `Sys_ContextMenu.ContextMnuNo/MnuClass/MnuNo` nvarchar(30), `MnuStringCode` varchar(100), `ImageName` nvarchar(50); `Sys_List.LstNo` nvarchar(40), `LstTitle` nvarchar(50); `Sys_ListDt.LdtFldName` nvarchar(30). Tool SQL Clone Tool clone được Tab (kèm Base/BaseDt/TabDt/TabClass) nhưng KHÔNG có Sys_TabCard.
- **Pattern popup "Generate" (học từ `ACGeneratePayment`)**: toolbar nút Save = `ContextMnuNo 'Save'`, `MnuScript ' if(!f_SaveData()) return '` (`SubmitHelper.js` gọi `f_CheckSave()` của trang rồi postback), code-behind gắn `SysToolBar.FindContextButton("Save").Click`; Close = `f_Close()` → `top.close()`. Khung chi tiết: nút Import `f_Select()`, Remove `f_Cancel()`.
- **Gotcha cửa sổ con**: `sysf_opensubonewin` gọi TỪ BÊN TRONG 1 popup không mở cửa sổ riêng (trang con nằm trong cửa sổ popup) → `top.close()` ở trang con đóng luôn popup cha. Popup cấp 2 (vd Import trong popup Generate) dùng `window.open(...)` + `window.opener.<hàm>()` + `window.close()` (LKHS-271).

**`CF_String`**: `StringType, RefTable, StringCode, StringCN, StringEN, StringSP, StringJP, StringKR, StringTH, StringMY, StringFR, StringGM, StringENGB, StringCNT, IsSystem, RecordStatus, CreateUserID, CreateDate, ModifyUserID, ModifyDate, IsTranslated2EN, Dummy, DummyDate`. Loại theo dữ liệu thật:
| Dùng cho | StringType / RefTable |
|---|---|
| Nhãn field (`<BseNo>_<Fld>`) | 2 dòng: `Field` + `Help`, RefTable `Sys_BaseDt` |
| Sys_Base name/desc | `Control` / `Sys_Base` |
| Sys_List name/title | `Control` / `Sys_List` |
| Nút (ví dụ `mcorp-15-09_AC.Payable_PaymentAuto`) | `Common` / `Sys_ContextMenu` (riêng `..._View` mẫu là `Control` / `Sys_Menu`) |
| Đầu danh sách dropdown (`CF_PopupLst`) | `Control` / `CF_PopupLst` |
| Thông báo dùng trong code (`Strings.GetString`) | `Common` / NULL |

**Dropdown chung `CF_PopupLst` / `CF_PopupLstElement`** (màn Cash Mgmt > Customized Setup > Dropdown List, `SysPopupSet.aspx`): `CF_PopupLst(ApplicationID, DescriptionCN/EN, DescStringCode, Type, ParentPopupLstID, IsSystem, IsMultipleLevel, DisplayOrder, RecordStatus...)` + gắn module qua `CF_XRef('CF_PopupLst', PopupLstID, 'Sys_Application', AppID)`. Phần tử nằm ở `CF_PopupLstElement` (đọc qua `View_PopupLst`), mượn các cột `Rank` (S/N), `ElementCode`, `Title`, `TitleCN`... để chứa dữ liệu riêng. Ví dụ LKHS-271: Type `SWIFTCode` (ElementCode = Bank Code, Title = Bank Name, **TitleCN = SWIFT BIC**), Type `DBSPurposeCode` (ElementCode = Purpose Code, Title = Description); Type `PayMethod` = phương thức thanh toán.

**Pattern màn hình "Generate" (list + popup tạo chứng từ hàng loạt) — học từ Generate Payment:**
- Trang khung `ACPayment.aspx` (master `Master2row_1row.master`): iframe `CostCompanyTree.aspx?SelNode=<MnuNo>&mType=m` gọi ngược `f_ShowList("com", id, name)`; iframe `BankTree.aspx?...&companyID=` gọi ngược `f_ClickAccount(type, bankAccountID, currencyID, currency, accountID)`; iframe3 = trang lưới với query string `companyID/currencyID/bankAccountID`.
- Trang lưới `ACPaymentLst.aspx` (master `MasterBarCondList.master`): `SysToolbar` (LstNo/MenuClass/MenuNo), `SysCondition LstNo`, `SysList2 UseCheckBox="true" LstNo`; code-behind set `SysList1.SelectCommandText` (nguồn = function/view), `Common.pf_LoadCustomization(this, "", "Init")`. JS: `gridManager2.GetSelectedRowIds()` → mở popup `sysf_opensubonewin(url, w, h, "yes")`; popup lưu xong gọi `opener.f_ReLoad()` → `gridManager2.Refresh()`.
- Popup `ACGeneratePayment.aspx` (master `MasterBarListFooter.master`): `SysTabEdit` header + iframe detail `ACGeneratePaymentDetail.aspx` (`SysList2`) dựa trên **bảng tạm theo GUID** (`CB_PaymentTempDetail.PaymentGuid`); Import (`ACPayableInvoiceSelect.aspx`) / Remove (`&cancelIDs=`) / Edit dòng (`ACGeneratePaymentDetailEdit.aspx`) chỉ thao tác bảng tạm. Chống sửa đồng thời bằng DateMark = MAX(ModifyDate) chứng từ nguồn.
- Save: gom nhóm theo đối tượng → mỗi nhóm 1 chứng từ; số chứng từ hàng loạt `new SysCodeCollection(Constants.PaymentDocNo, DocAnchorType.Company, companyID, n)` → `.Submit(tran)` / `.Cancel(tran)`; header insert bằng `Constants.SaveDataFromTabInsert(tran, TabNo, SysTabEdit1, collection, "<Table>", Constants.Active, userid) + "; select @@IDENTITY"`; allocation insert raw SQL với `?` thay bằng ID; check vượt số tiền chứng từ; commit; xoá bảng tạm.

### Report framework — Sys_Report / Sys_ReportDefine / Sys_ReportFilter

Bộ 3 bảng này định nghĩa 1 report **kiểu có màn hình filter riêng trước khi Preview** ("Conditions Configuration", ví dụ SST Payable and Tracking, Debtor Control Summary...) — KHÁC với bộ `Sys_Base`/`Sys_Tab` ở trên (dùng cho form edit/list thông thường).

| Bảng | Vai trò |
|---|---|
| `Sys_Report` | Định nghĩa 1 report. Cột chính: `ReportNo` (PK, khoá nối sang 2 bảng dưới), `ApplicationCode` (module, AR/GL/CM...), `ReportNameStringCode` (tên hiển thị, trỏ `CF_String`), `Language`, `CategoryStringCode` (nhóm report, ví dụ `RPT_Type_ARODReport`), `ReportFileName` (tên file report/RDLC thật), `ReadTable` (view/bảng nguồn dữ liệu chính report đọc, ví dụ `VIEW_AR_DebtorControlSummary_SWZECON`), `Order`, `IsSystem`, `RecordStatus`. |
| `Sys_ReportDefine` | Gắn report vào đúng vị trí/nhóm trong cây "Report Navigator" (danh sách report bên trái màn hình Reporting). Cột chính: `ReportTemplateID` (trỏ 1 node nhóm/template report cố định trong cây — ý nghĩa từng ID cụ thể CHƯA xác nhận đầy đủ), `ApplicationCode`, `CategoryStringCode`, `ReportNo` (FK → `Sys_Report`), `ConditionDesc`/`ConditionValue` (thường NULL — CHƯA xác nhận khi nào có giá trị), `Order` (thứ tự hiển thị trong nhóm), `IsSystem`. |
| `Sys_ReportFilter` | Định nghĩa TỪNG FIELD filter hiển thị trên màn hình "Conditions Configuration" trước khi Preview — mỗi dòng = 1 field filter của 1 report (`ReportNo` FK). Xem chi tiết cột bên dưới — đây là bảng trọng tâm để debug các bug dạng "field filter X không lọc được/dropdown rỗng". |

**Cột của `Sys_ReportFilter`** — đã đối chiếu 2 bộ dữ liệu thật: script tạo report `AR_CUS_DCS01_SWZECON` (`TransactionDate`/`DebtorName`/`AccountNo`/`DebtorType`) và data thật của report `SSTPayable` (`TransactionDate`/`TaxCode`/`DayPaidForDue`/`DayUnPaid`/`Module`/`AllocDocumentNo`/`DocumentNo`) — nên các mục dưới đây đã **xác nhận qua 2 nguồn**, không còn là suy đoán từ 1 ví dụ:

- `NameStringCode` — trỏ `CF_String` lấy label hiển thị field, quy ước đặt tên `Sys.ReportFilter_<ReportNo>_<FldName>`.
- `FldName` — tên field/tham số filter, khớp tên tham số report dùng để build WHERE.
- `FldType` — kiểu control render: `D` = Date, `S` = String (text tự do, có thể range 2 ô nếu `FldRange=3`, ví dụ `AllocDocumentNo`/`DocumentNo`), `SW` = String kèm Wildcard (ô nhập kèm tìm gần đúng, ví dụ `AccountNo`), `L` = List/dropdown (ví dụ `DebtorType`, `TaxCode`, `Module`), `I` = Integer/số nguyên (ví dụ `DayPaidForDue`, `DayUnPaid`).
- `FldNeed` — `Y`/`N`, field bắt buộc nhập hay không.
- `FldRange` — **đã xác nhận**: `3` = field hiển thị dạng khoảng giá trị (2 ô input, From-To) — áp dụng cho `TransactionDate` (Date) và cả `AllocDocumentNo`/`DocumentNo` (String); `0` = field nhập 1 giá trị (áp dụng cho List, Integer, và 1 số String khác như `DebtorName`).
- `IsSeparate` — quan sát thực tế: hầu hết field để `N` (kể cả field List như `TaxCode`/`Module`, khác hẳn giả thuyết ban đầu là "List luôn = Y" — giả thuyết đó SAI, đã sửa lại); nhưng 2 field Integer (`DayPaidForDue`, `DayUnPaid`) lại có `IsSeparate = 'I'`, trùng ký tự với chính `FldType` của chúng — nghi ngờ đây có thể là lỗi gõ/copy nhầm giá trị `FldType` sang cột này lúc tạo report, KHÔNG chắc là 1 giá trị có chủ đích. Ý nghĩa thật của cột này vẫn CHƯA xác nhận chắc chắn, cần thêm ví dụ.
- `ReportParam` — **đã xác nhận 1 trường hợp rõ ràng**: với field Integer (`DayPaidForDue`, `DayUnPaid`), `ReportParam` = CHÍNH TÊN FIELD đó — khác mọi field khác (Date/String/List) đều để `NULL`. Nghi ngờ: đánh dấu field này được truyền THẲNG làm tham số report/SP theo đúng tên (khác cơ chế build dynamic WHERE criteria dùng cho field String/Date/List) — cần thêm ví dụ loại field khác có set `ReportParam` để xác nhận chắc chắn hơn.
- `IsAsAtDate` — thực ra là `Y`/`N` (không phải chỉ set cho Date như suy đoán ban đầu) — trong data `SSTPayable`, kể cả `TransactionDate` cũng để `N`. Ý nghĩa cột này CHƯA xác nhận rõ, cần ví dụ có set `Y` thật để đối chiếu.
- `RelationFld` — **đã sửa giả thuyết ban đầu (không chỉ dành riêng cho List)**: thấy set cho field List (`TaxCode`→`TaxCode`, `Module`→`Module`) LẪN 1 field String (`AllocDocumentNo`→`AllocDocumentNo`, trùng tên field) — nhưng field String khác cùng loại (`DocumentNo`) lại để `NULL`. Ý nghĩa chính xác của việc field String có/không set `RelationFld` CHƯA xác nhận (có thể chỉ là dữ liệu tự do lúc tạo report, không ảnh hưởng hành vi runtime).
- `RefDataSource` — **xác nhận rõ với field List có `FldType = 'L'`**: khi field List có `RefDataSource` là 1 câu SELECT thật, dropdown được populate ĐỘNG từ query này lúc render màn hình filter. Ví dụ thật từ `SSTPayable`:
  - `TaxCode`: `SELECT DISTINCT TaxCode, TaxCode FROM View_CF_Tax WHERE RecordStatus <> 'Inactive'`
  - `Module`: `SELECT Module, Module FROM (SELECT dbo.GetString2('AppPMName','EN') AS Module UNION SELECT dbo.GetString2('AppSalesName','EN') UNION SELECT dbo.GetString2('AppRentalName','EN') UNION SELECT dbo.GetString2('AppMCorpName','EN') UNION SELECT dbo.GetString2('AppAccountReceivableName','EN')) R`
  → Dropdown Module trên report `SSTPayable` CHỈ có đúng 5 lựa chọn CỐ ĐỊNH (hardcode ngay trong `RefDataSource`, không đọc từ `Sys_Application`): tên hiển thị (tiếng Anh) của PM (Project Management), Sales, Rental, MCorp, Account Receivable — KHÔNG có GL, KHÔNG có CM/Cash, KHÔNG có AP thông thường trong danh sách. Đây là điểm mấu chốt cho SWIBRACO-681, xem ghi chú riêng bên dưới.
- `RefFields` — chưa gặp ví dụ nào có giá trị khác NULL kể cả ở 2 nguồn dữ liệu đã xem, ý nghĩa CHƯA xác nhận.
- `IsUnicode` — luôn `N` trong MỌI ví dụ đã thấy (String lẫn List lẫn Integer lẫn Date, cả 2 nguồn) — CHƯA gặp giá trị `Y` để so sánh, có thể chỉ dùng khi field cần build `N'...'` cho ký tự Unicode (tiếng Trung/Nhật...).
- `Order` — thứ tự hiển thị field trên màn hình filter (NULL ở 1 số dòng `SSTPayable` — có vẻ không bắt buộc phải set).

**Ghi chú riêng cho SWIBRACO-681 (SST Payable and Tracking — "cannot filter by Module") — ĐÃ XÁC ĐỊNH ROOT CAUSE BẰNG CODE THẬT (xem đầy đủ ở nhóm bug #11 phía trên).**

Triệu chứng: dropdown Module TRỐNG, không có value nào để chọn. `Sys_Report.ReadTable` (`View_GL_SST_Payable`) chỉ là 1 view "giả" dùng để dựng khung filter, không phải nguồn data thật.

**Root cause cuối cùng**: `ReportFilter2.aspx.cs`, hàm `BuildCell()` dòng ~634, dùng `"year,startmonth,endmonth,month,moduletype".Contains(row["FldName"].ToString().ToLower())` để nhận diện field GL year/month — nhưng vì `"moduletype"` CHỨA substring `"module"`, field `Module` bị nhận nhầm và route sang `InputGLSelect()` (hàm build dropdown năm/tháng GL) thay vì hàm đúng `InputSelect()` (hàm đọc `RefDataSource`, xem chi tiết bên dưới). `InputGLSelect()` không có nhánh nào khớp CHÍNH XÁC `"module"` (chỉ có `"moduletype"`) nên dropdown chỉ còn 1 dòng mặc định "Please Select" — chi tiết đầy đủ + fix đề xuất xem nhóm bug #11.

**3 giả thuyết ĐÃ LOẠI TRỪ trong quá trình điều tra (giữ lại để tránh lặp lại hướng sai nếu gặp bug tương tự)**:
1. `.ToLower()` trong `InputSelect()` làm hỏng `dbo.GetString2('AppPMName','EN')` → SAI, đã test trực tiếp: `SELECT dbo.GetString2('AppPMName','EN')` và `SELECT dbo.GetString2('apppmname','EN')` ra CÙNG kết quả ("Construction Management") — `GetString2` không phân biệt hoa/thường trên `StringCode` (áp dụng chung mọi report/client, ghi nhận luôn ở đây).
2. Hook `Common.pf_CustomizationChangeValue("CustomizationChangeValue2", ...)` (gọi trong nhánh `catch` của `InputSelect()`) làm hỏng `sql` → SAI, đọc source thật của `CustomizationChangeValue2` xác nhận nó chỉ có 1 `case` (`"SYSAUTOCODEARRANGE_SQL"`, dùng cho customization khác hẳn) — với input của Module thì rơi `default`, trả nguyên `sql` không đổi (no-op).
3. Câu SQL cuối cùng do `InputSelect()` build ra (từ `RefDataSource`) tự nó lỗi/rỗng ở tầng DB → SAI, đã chạy thử trực tiếp, ra đúng 5 dòng module hợp lệ: Construction Management, Other Receivable, Property Sales, Rental Management, Residential Management.

→ Sau khi loại hết 3 khả năng trên (đều liên quan tới `InputSelect()`), việc đọc lại `BuildCell()` (nơi GỌI `InputSelect()`) mới lộ ra field `Module` thực chất CHƯA BAO GIỜ đi vào `InputSelect()` — bị chặn ngay từ bước dispatch. Đây là bài học điều tra: khi 1 hàm xử lý (được cho là) chịu trách nhiệm chính hoá ra vẫn "sạch" ở mọi bước dù đã trace kỹ, nên lùi lại 1 tầng kiểm tra xem hàm đó có THỰC SỰ được gọi cho đúng field/case đang xét hay không, trước khi đào sâu hơn vào bên trong hàm đó.

**Hướng tra cứu chung khi gặp bug "field filter X trên report không hoạt động đúng"** (áp dụng cho các report cùng kiểu sau này):
```sql
-- 1. Tìm ReportNo từ tên report hiển thị
SELECT r.*
FROM Sys_Report r
LEFT JOIN CF_String s ON s.StringCode = r.ReportNameStringCode
WHERE s.StringEN LIKE '%<tên report>%' OR r.ReportFileName LIKE '%<từ khoá>%'

-- 2. Xem toàn bộ field filter của report đó, tập trung field đang lỗi
SELECT * FROM Sys_ReportFilter WHERE ReportNo = '<ReportNo>' ORDER BY [Order]
```
Trọng tâm khi debug dropdown (`FldType = 'L'`): xem `RefDataSource` có query hợp lệ không, và nếu có, chạy thử ngay câu query đó để xem thực tế trả về option nào — so với danh sách module/giá trị nghiệp vụ cần lọc để biết có bị thiếu option không, TRƯỚC khi kết luận là lỗi tầng dataset/SP.

### ReportFilter2.aspx.cs — cơ chế render màn hình "Conditions Configuration" và populate dropdown List

Class `ReportPrint_ReportFilter2` (file `ReportFilter2.aspx.cs`) là trang generic render TOÀN BỘ màn hình filter ("Conditions Configuration") cho MỌI report định nghĩa qua `Sys_Report`/`Sys_ReportFilter` (khi `issystem='Y'`) — dùng chung cho tất cả module/client, không phải file riêng cho SST Payable hay SWIBRACO.

- **`Page_Load`**: đọc `sWhere` — 1 điều kiện filter đã lưu trước đó của user cho report này (`Sys_ReportRefCompany.ConditionValue`, theo `ReportNo` + `CompanyID` + `CreateUserID`) — dùng để PREFILL lại các ô filter khi user quay lại report đã chạy trước đó. Rồi gọi `BuildHtmlTable()`.
- **`BuildHtmlTable()`**: query `View_Sys_ReportFilter` theo đúng `reportno` (view này build từ bảng `Sys_ReportFilter`, xem mục ngay phía trên), lặp qua từng dòng field filter theo đúng `[Order]`, gọi `BuildCell()` để sinh control tương ứng theo `FldType`.
- **`BuildCell()`**: dispatch theo `FldType` — `S`→text box (`InputText`), `D`/`DT`→date picker (`InputDate`), `I`→numeric (`InputNumeric`, có 1 đoạn hardcode riêng: report `SSTPayable` set default `DayPaidForDue=60`/`DayUnPaid=365` khi field trống — khớp đúng giá trị mặc định thấy trên UI), `SW`→text kèm nút chọn popup (rất nhiều nhánh hardcode theo `sAppCode`/`FldName`/`reportno` cụ thể — muốn thay đổi hành vi 1 field `SW` của 1 report cụ thể, tìm đúng nhánh khớp `sAppCode`+`FldName`(+`reportno`) trước khi sửa nhánh generic cuối), `L`→dropdown (`InputSelect`, xem chi tiết bên dưới; cũng có rất nhiều nhánh hardcode theo report/field cụ thể trước khi rơi vào nhánh generic).
- **QUAN TRỌNG: file này KHÔNG build chuỗi `QueryCriteria`/WHERE cuối cùng gửi cho report engine khi bấm Preview** — nó chỉ lo RENDER form và ĐỌC LẠI điều kiện đã lưu trước đó để prefill. Việc build điều kiện lọc mới khi bấm Preview nằm ở JS phía client (không nằm trong file `.aspx.cs`, có thể ở `.aspx` markup hoặc JS include riêng) — muốn xem cần lấy file markup, không phải code-behind.

**`InputSelect()` — cách dropdown List (`FldType='L'`) không dùng `RelationFld` mà dùng `RefDataSource`** (đã đọc đầy đủ code thật, dòng 1955-2020 của `ReportFilter2.aspx.cs`):

1. Parse `RefDataSource` bằng cách **lowercase TOÀN BỘ chuỗi rồi split tại từ `"from"`** để tách phần "SELECT col1[,col2]" (`arr1[0]`) và phần "FROM ..." còn lại (`arr1[1]`) — cách parse này rất naive (chỉ dựa vào tách chuỗi, không phải SQL parser thật), giả định `RefDataSource` luôn có dạng đơn giản `SELECT <col>[, <col2>] FROM <nguồn>` và chỉ có ĐÚNG 1 chữ "from" trong toàn chuỗi.
2. Có 2 nhánh code GẦN NHƯ TRÙNG NHAU: 1 nhánh hardcode riêng cho `fldName == "PropertyType"`, 1 nhánh generic (`else`) dùng cho MỌI field List khác (bao gồm `TaxCode` và `Module`) — build sql ban đầu `"Select <col1> as col, <col2> as valueClnum from <arr1[1]>"`.
3. **Bước probe kiểm tra `CompanyID` — đây chính là điểm rẽ nhánh quyết định field List có ra dropdown hay không**, xử lý khác nhau tuỳ `arr1[1]` (phần sau "from", đã lowercase) **có sẵn chữ "where" hay không**:
   - **Có "where" sẵn** (ví dụ `TaxCode`: `... from view_cf_tax where recordstatus <> 'inactive'`): probe bằng `select 1 from <arr1[1]> and CompanyID=<CompId>` (nối thêm `and CompanyID=...` ngay sau điều kiện where có sẵn) — nếu nguồn có cột `CompanyID` (đúng với hầu hết master view), probe thành công, `sql` cuối = câu gốc + `and CompanyID=... order by <col1>`.
   - **KHÔNG có "where"** (ví dụ `Module`: nguồn là derived table từ `UNION SELECT dbo.GetString2(...)`, không có mệnh đề where lẫn cột `CompanyID`): probe bằng `select TOP 1 1 from <arr1[1]> where CompanyID=<CompId>` — nguồn không có cột `CompanyID` nên probe **chắc chắn ném lỗi** `Invalid column name 'CompanyID'`.
4. Khi probe ở bước 3 ném lỗi (rơi vào `catch`) — **CHỈ nhánh generic (`else`, không phải nhánh `PropertyType`) có thêm 1 bước nữa**: build `sql` fallback KHÔNG có điều kiện `CompanyID` (`"Select ... from <arr1[1]> order by <col1>"`), rồi gọi tiếp `Common.pf_CustomizationChangeValue(arr2, sql, "CustomizationChangeValue2", arr1[1].ToString().Trim(), 0)` (dòng 2014, comment `//PKNS-131`). **`TaxCode` không bao giờ rơi vào `catch`** (RefDataSource có sẵn where + view có CompanyID) nên không đụng hook này; **`Module` LUÔN rơi vào `catch`** (derived table UNION, không CompanyID) nên luôn đi qua hook.
   → **ĐÃ LOẠI TRỪ: hook `pf_CustomizationChangeValue`/`CustomizationChangeValue2` KHÔNG phải nguyên nhân** — Gunner đã cung cấp source thật của `CustomizationChangeValue2` (2 overload). Cơ chế: `pf_CustomizationChangeValue` dispatch theo tên hàm (`"CustomizationChangeValue2"`) rồi gọi overload khớp tham số còn lại — ở đây khớp overload `(object objToCustomize, object objGet, object objToChange, int curID)`, mapping: `objToCustomize=arr2`, `objGet=sql` (chính là sql fallback), `objToChange=arr1[1].ToString().Trim()` (toàn bộ text derived table), `curID=0`. Hàm chỉ có 1 `switch (objToChange.ToString().ToUpper())` với đúng 1 case cụ thể (`"SYSAUTOCODEARRANGE_SQL"`, dùng cho customization khác hẳn — auto-code arrange); text derived table của `Module` không khớp case nào → rơi `default` → `returnvl = objGet.ToString()` = **trả nguyên `sql` KHÔNG ĐỔI GÌ**. Tức hook này với case Module là **no-op hoàn toàn**, không hề làm rỗng hay hỏng `sql`. (Overload còn lại `(IFCA.Web.UI.Page, object, object, string)` có case `"VIEW_CF_DOCCODE"` — dùng cho 1 customization khác nữa, cũng không liên quan Module.)
   → Vậy `sql` cuối cùng thực sự được dùng để `ExecuteDataset` cho field `Module` chắc chắn là:
   ```sql
   Select module as col, module as valueClnum from  (select dbo.getstring2('apppmname','en') as module union select dbo.getstring2('appsalesname','en') union select dbo.getstring2('apprentalname','en') union select dbo.getstring2('appmcorpname','en') union select dbo.getstring2('appaccountreceivablename','en')) r order by module
   ```
   Về cú pháp câu này hợp lệ — đã Gunner chạy thử trực tiếp trên DB, ra ĐÚNG 5 dòng module hợp lệ (Construction Management, Other Receivable, Property Sales, Rental Management, Residential Management), KHÔNG lỗi gì. Tức toàn bộ chuỗi logic `InputSelect()` mô tả ở mục này (bước 1-4) **hoàn toàn không phải nguyên nhân của SWIBRACO-681** — root cause thật nằm ở 1 tầng CAO HƠN, TRƯỚC KHI field `Module` kịp vào hàm `InputSelect()` này: xem nhóm bug #11 ở đầu file (hàm `BuildCell()` route sai field `Module` sang `InputGLSelect()` do lỗi `.Contains()` substring). Vẫn giữ lại toàn bộ phân tích cơ chế `InputSelect()` ở mục này vì đây là kiến thức đúng, dùng được cho các field List khác thực sự đi qua hàm này.
5. **Giả thuyết `.ToLower()` làm hỏng `dbo.GetString2` ĐÃ BỊ LOẠI TRỪ** (test thật trên DB client SWIBRACO): `SELECT dbo.GetString2('AppPMName','EN')` và `SELECT dbo.GetString2('apppmname','EN')` cho ra **cùng 1 kết quả** ("Construction Management") — `GetString2` không phân biệt hoa/thường trên `StringCode`. **Kết luận này áp dụng chung cho MỌI report/client** — không cần nghi ngờ hướng case-sensitivity nữa khi gặp field List khác có `RefDataSource` gọi `GetString2`/hàm tương tự.
6. Nếu `FldNeed != 'Y'`, LUÔN thêm sẵn 1 option đầu tiên "Please Select" (`value=""`) trước khi loop bind các dòng data thật (dòng ~2082) — nên 1 dropdown "trống" trên UI vẫn luôn hiện được đúng 1 dòng "Please Select", dễ khiến người dùng tưởng field có hoạt động nhưng thực chất không có option thật nào phía sau. **Lưu ý: đây cũng chính xác là những gì user thấy với field `Module` của SWIBRACO-681 — nhưng vì lý do khác hẳn (field chưa từng vào tới `InputSelect()`), không phải vì lý do này.**

**Quy tắc chẩn đoán chung rút ra từ SWIBRACO-681, áp dụng cho MỌI field List (`FldType='L'`) của MỌI report**: nếu 1 dropdown List bị rỗng trong khi field List khác CÙNG report vẫn có value bình thường, **kiểm tra TRƯỚC TIÊN xem field đó có thực sự đi vào `InputSelect()` hay bị 1 trong các nhánh hardcode ở đầu `BuildCell()`'s case `"L"` "cướp" mất** (đặc biệt nhánh GL year/month ở dòng ~634, xem nhóm bug #11) — chỉ khi đã chắc chắn field đi đúng vào `InputSelect()` mới cần soi tiếp `RefDataSource`/probe `CompanyID`/hook customization như mô tả ở các bước 1-6 trên. Thứ tự điều tra đúng nên đi từ NGOÀI VÀO TRONG (nơi gọi hàm trước, bên trong hàm sau), không nên giả định ngay hàm "đúng chức năng" (`InputSelect`) chắc chắn được gọi.

### Các bảng framework khác (ngoài nhóm Sys_ UI engine)

- **`SysCode`** (class dùng chung, không hẳn là 1 bảng đơn) — sinh số chứng từ tự động theo `DocAnchorType` (Company...) — dùng ở mọi màn hình có số chứng từ auto-gen (GRN No, JV No, Payment No...). Chi tiết: `ifca-autocode-syscode-reference.md`.
- **`CF_XRef`** — bảng cross-reference dùng chung, link 2 bản ghi bất kỳ qua `FromRefTable/FromRefRecordID` → `ToRefTable/ToRefRecordID`. Đã dùng để trace quan hệ GRN gốc ↔ GRN return ở SWHARTANAH-333.
- **`CF_Document`** — bảng lưu file đính kèm dùng chung (`RefTable/RefRecordID/DocumentPath/DocumentName...`), dùng cho mọi màn hình có tính năng đính kèm file.
- **`CF_PopupLstElement`** — bảng danh mục/lookup dùng chung cho dropdown (`PopupLstElementID`, `ElementCode`) — đã dùng ở TIMATCH-394 để lookup `BillTypeID` → `ElementCode='Adjustment'`, và ở JESSELTON-272 để lookup `CF_BankAccount.AccountTypeID` (2249 `BankAccount` / 2250 `CashAccount`, PopType `ACType`).
- **`CF_Account`** — master "đối tác" dùng chung (khách hàng, nhà cung cấp, ngân hàng...; cột `AccountID`, `AccountNo`, `Name`, `IsCompany`, `TIN`, `IsEInvoice`...). `CF_BankAccount.AccountID` trỏ vào đây để lấy tên ngân hàng. Không xoá/sửa bản ghi `CF_Account` khi chỉ cần bỏ liên kết từ 1 bảng khác (có thể đang được tham chiếu ở nơi khác) — xem JESSELTON-272.
- **`CF_Company`** — company master (qua view `View_CF_Company`). KHÔNG có cột `CompanyName` — tên ở `CF_Account` (`CF_Company.AccountID` → `CF_Account.Name`).
- **`view_cf_lettersetting`** — cấu hình từng Letter (theo `LetterID`): view Master/Sub, `ConfigDataType`, `ProcedureConfig`, cờ customize — xem mục `PrintService.cs` ở trên.

Bổ sung thêm khi gặp bảng framework mới ở các ticket sau.

---

## Trace audit log — schema, gotcha, quy trình

Áp dụng khi cần điều tra "ai/cái gì đã đổi giá trị này, lúc nào" mà không có log ứng dụng — dùng bảng audit trigger-based của IFCA. **Database audit dùng chung 1 tên GIỐNG NHAU ở MỌI client: `IFCANetAudit_R2_8`** (đã xác nhận, không phải khác nhau theo client như từng nghĩ ban đầu — không cần hỏi lại tên DB mỗi ticket).

### Schema

Mọi bảng nghiệp vụ chính đều có 3 trigger `tr_i_AUDIT_<Table>`, `tr_u_AUDIT_<Table>`, `tr_d_AUDIT_<Table>` ghi vào 2 bảng:

- **`AUDIT_LOG_TRANSACTIONS`** — 1 dòng / 1 câu lệnh DML. Cột: `AUDIT_LOG_TRANSACTION_ID` (PK, **số ít** "TRANSACTION" — dễ gõ nhầm thành `AUDIT_LOG_TRANSACTIONS_ID`, sẽ báo lỗi `Invalid column name`), `DATABASE`, `TABLE_NAME`, `TABLE_SCHEMA`, `AUDIT_ACTION_ID` (1=Update, 2=Insert, 3=Delete), `HOST_NAME`, `APP_NAME`, `MODIFIED_BY`, `MODIFIED_DATE`, `AFFECTED_ROWS`, `SYSOBJ_ID`.
- **`AUDIT_LOG_DATA`** — 1 dòng / 1 cột bị đổi hoặc được insert. Cột: `AUDIT_LOG_DATA_ID`, `AUDIT_LOG_TRANSACTION_ID` (FK join sang bảng trên), `PRIMARY_KEY_DATA` (dạng text `[ColName]=value`, ví dụ `[POItemID]=71294`), `COL_NAME`, `OLD_VALUE_LONG`/`NEW_VALUE_LONG` (kiểu `ntext`), `NEW_VALUE_BLOB`, `NEW_VALUE`, `OLD_VALUE`, `PRIMARY_KEY`, `DATA_TYPE`, `KEY1..KEY4`, `NEW_VALUE_VARBINARY`, `OLD_VALUE_VARBINARY`.

Nếu nghi ngờ tên cột (có thể khác nhau giữa các bản/client), chạy trước:
```sql
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME IN ('AUDIT_LOG_TRANSACTIONS', 'AUDIT_LOG_DATA')
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
```

### Các lỗi/gotcha hay gặp

- **`ntext`/`varchar` không so sánh được bằng `=`** — `OLD_VALUE_LONG`, `NEW_VALUE_LONG`, `PRIMARY_KEY_DATA` là `ntext`. Dùng `LIKE '%value%'`, không dùng `=` (sẽ báo `Msg 402: data types ntext and varchar are incompatible in the equal to operator`).
- **UPDATE trigger chỉ log đúng cột thực sự nằm trong mệnh đề `SET` của câu lệnh đó** — nếu 1 UPDATE chỉ đổi `BalanceQty`, sẽ KHÔNG có dòng audit nào cho `POItemID` dù đó là cột khoá đang lọc theo. Vì vậy lọc `WHERE COL_NAME = 'X'` có thể bỏ sót các UPDATE chỉ đổi cột khác của cùng dòng — nên trace theo `PRIMARY_KEY_DATA` (khoá chính) trước, không nên chỉ lọc theo tên cột nghiệp vụ đang nghi ngờ.
- **`AUDIT_LOG_TRANSACTION_ID` là ID toàn hệ thống** (mọi bảng, mọi user, mọi module) — KHÔNG lọc theo dải ID (`BETWEEN x AND y`) để tìm "các thay đổi cùng lúc", vì sẽ dính luôn hoạt động của người khác không liên quan (dễ ra hàng trăm dòng dư thừa). Luôn lọc theo `TABLE_NAME` cụ thể + khung `MODIFIED_DATE` hẹp thay vì theo ID.
- **`APP_NAME` + `HOST_NAME`** là cách nhanh nhất để phân biệt thao tác qua ứng dụng thật (`APP_NAME = 'IFCA Software'`) với thao tác SQL trực tiếp (SSMS/ODBC login riêng, ví dụ user kiểu `ifca.reporting`) — rất quan trọng để kết luận 1 bất thường là bug code hay do người dùng chỉnh tay ngoài luồng.

### Quy trình trace hiệu quả (đã dùng thành công ở SWHARTANAH-333)

1. Xác định khoá chính của bản ghi nghiệp vụ đang nghi vấn (ví dụ `POItemID`), lấy lịch sử đổi giá trị đầy đủ theo thời gian:
   ```sql
   SELECT alt.AUDIT_LOG_TRANSACTION_ID, alt.TABLE_NAME, alt.APP_NAME, alt.HOST_NAME,
          alt.MODIFIED_BY, alt.MODIFIED_DATE, ald.PRIMARY_KEY_DATA, ald.COL_NAME,
          ald.OLD_VALUE_LONG, ald.NEW_VALUE_LONG
   FROM [IFCANetAudit_R2_8].dbo.AUDIT_LOG_TRANSACTIONS alt
   JOIN [IFCANetAudit_R2_8].dbo.AUDIT_LOG_DATA ald
     ON ald.AUDIT_LOG_TRANSACTION_ID = alt.AUDIT_LOG_TRANSACTION_ID
   WHERE alt.TABLE_NAME = '<TableName>'
     AND ald.PRIMARY_KEY_DATA LIKE '%<KeyValue>%'
   ORDER BY alt.MODIFIED_DATE;
   ```
2. Khi thấy 1 thời điểm bất thường (giá trị đổi không khớp với bất kỳ chứng từ nghiệp vụ nào), khoanh đúng khung giờ đó (vài giây) và mở rộng sang **các bảng liên quan** (không giới hạn 1 khoá chính) để xem toàn cảnh hành động:
   ```sql
   SELECT alt.TABLE_NAME, alt.MODIFIED_DATE, ald.PRIMARY_KEY_DATA, ald.COL_NAME,
          ald.OLD_VALUE_LONG, ald.NEW_VALUE_LONG
   FROM [IFCANetAudit_R2_8].dbo.AUDIT_LOG_TRANSACTIONS alt
   JOIN [IFCANetAudit_R2_8].dbo.AUDIT_LOG_DATA ald
     ON ald.AUDIT_LOG_TRANSACTION_ID = alt.AUDIT_LOG_TRANSACTION_ID
   WHERE alt.TABLE_NAME IN ('<Table1>', '<Table2>')
     AND alt.MODIFIED_DATE BETWEEN '<start>' AND '<end>'
   ORDER BY alt.AUDIT_LOG_TRANSACTION_ID;
   ```
3. Nếu kết quả quá nhiều dòng để đọc trực tiếp, **group lại thành bảng đếm** thay vì dump từng dòng — cách này lộ ngay pattern (ví dụ: 1 bảng chỉ đổi đúng 1 lần nhưng bảng liên quan bị đổi 2 lần cho MỌI bản ghi trong cùng lô, tức lỗi nhân đôi ở tầng batch, không phải ngẫu nhiên/1 dòng lẻ):
   ```sql
   SELECT alt.TABLE_NAME, ald.PRIMARY_KEY_DATA, ald.COL_NAME, COUNT(*) AS ChangeCount,
          MIN(alt.MODIFIED_DATE) AS FirstChange, MAX(alt.MODIFIED_DATE) AS LastChange
   FROM [IFCANetAudit_R2_8].dbo.AUDIT_LOG_TRANSACTIONS alt
   JOIN [IFCANetAudit_R2_8].dbo.AUDIT_LOG_DATA ald
     ON ald.AUDIT_LOG_TRANSACTION_ID = alt.AUDIT_LOG_TRANSACTION_ID
   WHERE alt.TABLE_NAME IN ('<Table1>', '<Table2>')
     AND alt.MODIFIED_DATE BETWEEN '<start>' AND '<end>'
     AND ald.COL_NAME IN ('<Col1>', '<Col2>')
   GROUP BY alt.TABLE_NAME, ald.PRIMARY_KEY_DATA, ald.COL_NAME
   ORDER BY alt.TABLE_NAME, ald.PRIMARY_KEY_DATA;
   ```
4. So sánh `APP_NAME`/`HOST_NAME`/`MODIFIED_BY` giữa "sự kiện nguồn" (ví dụ dòng GRN item bị đổi) và "sự kiện bị ảnh hưởng" (ví dụ PO bị cộng dư): nếu cùng app/cùng user nhưng số lần xảy ra khác nhau (1 vs 2) → đây là dấu hiệu rất mạnh của lỗi code tự nhân đôi xử lý (double-processing), không phải do người dùng thao tác 2 lần — vì sự kiện nguồn (phản ánh đúng số lần user bấm) chỉ có 1, còn hệ quả lại có 2.
