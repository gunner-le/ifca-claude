# IFCA — Cách làm việc đã thống nhất

> Bản gốc từ claude.ai Project. Trong Claude Code: "Project" = thư mục `docs/`; "gửi file cho user" = file đã nằm trong `docs/tickets/`.

Bối cảnh: hàng ngày xử lý nhiều ticket Jira cho nhiều client khác nhau (mỗi tiền tố Jira = 1 client), không có quyền truy cập trực tiếp code/DB — làm việc qua screenshot, code, kết quả SQL do user paste vào chat.

## Cấu trúc 3 file trong Project

- **`ticket-index.md`** — mục lục tất cả ticket (Ticket | Client | Module | Mô tả ngắn | Trạng thái | Ngày | File chi tiết). Đọc file này ĐẦU TIÊN khi cần tra "đã làm gì", trước khi đọc sâu file chi tiết.
- **`ifca-domain-reference.md`** — kiến thức nền tảng dùng chung mọi client/mọi ticket: cấu trúc bảng, ý nghĩa nghiệp vụ, pattern code hay lặp, quy ước đặt tên, cách trace audit log... Đọc trước khi bắt đầu 1 ticket thuộc module đã có ghi chú ở đây.
- **`working-notes.md`** (file này) — chỉ chứa quy tắc làm việc, không chứa kiến thức nghiệp vụ/kỹ thuật cụ thể.
- **`tickets/<TICKET>-<slug>.md`** — file chi tiết riêng từng ticket (root cause, code fix, kết quả test) — chỉ ticket/client đó dùng, không lặp sang ticket khác.

## Quy tắc 1: mỗi ticket Jira nên là 1 chat riêng

Không gộp nhiều ticket vào 1 chat dài xuyên ngày/xuyên client — dễ bị compact (mất chi tiết) và dễ lẫn code giữa các client khác nhau. Khi có ticket gấp chen ngang lúc đang làm ticket khác, mở **chat mới** cho ticket gấp thay vì tạm dừng trong cùng chat.

Vì mỗi chat là 1 phiên hoàn toàn mới (không tự nhớ nội dung chat khác), TOÀN BỘ kiến thức cần dùng lại về sau phải được ghi vào Project (2 file index/domain-reference ở trên) — không phụ thuộc vào việc nhớ lại từ lịch sử chat.

## Quy tắc 1b: khi nhận 1 ticket mới (đầu chat)

Thứ tự xử lý ngay khi user paste ticket ID + mô tả/screenshot Jira, KHÔNG cần user nhắc:

1. Nhìn tiền tố ticket để biết client, check `ticket-index.md` xem client/module này đã từng có ticket liên quan chưa.
2. Check `ifca-domain-reference.md` xem module liên quan đã có kiến thức nền chưa (bảng, business rule, bug pattern hay gặp) — áp dụng luôn nếu có, không hỏi lại user.
3. **Tóm tắt ngắn gọn lại hiểu của mình về ticket (lỗi gì / yêu cầu gì) để xác nhận đã hiểu đúng** — làm bước này TRƯỚC khi hỏi chi tiết thông tin cần thiết (code, SQL, screenshot...). Nếu hiểu sai, user sửa lại ngay từ đầu, đỡ hỏi lan man sai hướng.
4. Sau khi xác nhận hiểu đúng, mới hỏi cụ thể thông tin còn thiếu để bắt đầu điều tra.

## Quy tắc 2: phân biệt kiến thức riêng ticket vs kiến thức nền tảng dùng chung

Trong lúc điều tra, hễ phát hiện điều gì **KHÔNG riêng gì ticket/client đang làm** — ý nghĩa 1 bảng, hành vi 1 module, 1 pattern bug hay lặp lại, quy ước code/naming, bảng `sys_...` dùng chung... — ghi vào `ifca-domain-reference.md` (khi ticket có kết quả cuối — xem CLAUDE.md). Kiến thức đặc thù 1 client (customization riêng, dữ liệu cụ thể của ticket) thì chỉ ghi vào file chi tiết ticket đó.

## Quy tắc 3: mức độ áp dụng quy trình đầy đủ

Chỉ áp dụng toàn bộ quy trình dưới đây (viết file chi tiết, cập nhật index, gửi file, note Jira) cho ticket đủ "nặng" (đã điều tra/fix xong 1 vấn đề thực sự, hoặc phân tích rõ 1 yêu cầu nghiệp vụ). Câu hỏi nhỏ lẻ, tra cứu nhanh thì không cần.

## Quy tắc 4: các việc luôn làm khi kết thúc 1 ticket "nặng"

Chủ động làm (không đợi user yêu cầu lại), theo đúng thứ tự:

1. **Cập nhật `ticket-index.md`** — thêm/cập nhật dòng của ticket (trạng thái, ngày, đường dẫn file chi tiết).
2. **Viết/cập nhật file chi tiết** `tickets/<TICKET>-<slug>.md` — bối cảnh, root cause, fix, kết quả test.
3. **Trích xuất kiến thức nền tảng** (nếu có) sang `ifca-domain-reference.md` theo Quy tắc 2.
4. **Gửi file chi tiết cho user** — để user lưu về máy tính riêng, xem lại sau.
5. **Đưa kèm note root cause sẵn sàng paste vào Jira** — theo đúng 2 bản Tech/Non-tech ở Quy tắc 8 bên dưới — chủ động đưa, không cần đợi user hỏi lại.

Lưu ý trạng thái: nếu ticket mới đến bước "đã tìm root cause, chờ test" (chưa confirm), vẫn làm bước 1 và 3 (index + kiến thức nền tảng) ngay, nhưng file chi tiết đầy đủ (bước 2, 4, 5) có thể để đến khi có kết quả test — tránh viết đi viết lại nhiều lần cho cùng 1 ticket.

## Quy tắc 5: đa client, tránh lẫn

Nhiều client dùng chung 1 nền code IFCA nhưng customize khác nhau (xem quy ước đặt tên trong `ifca-domain-reference.md`). Khi áp dụng lại 1 finding cũ cho ticket mới, luôn kiểm tra đúng field Client trong index trước — không áp nhầm kết luận của client A sang client B.

## Quy tắc 6: patch dữ liệu — từng item riêng, luôn kèm giá trị cũ để revert

Bất kỳ câu SQL patch dữ liệu nào (UPDATE/DELETE trực tiếp lên DB) đều phải kèm khả năng revert lại giá trị cũ — không patch "một chiều" mà không lưu vết. Nguyên tắc chung: **patch từng item (từng row/khoá chính) bằng 1 câu UPDATE riêng, KHÔNG dùng 1 câu UPDATE với mệnh đề WHERE gộp điều kiện áp dụng cho nhiều row cùng lúc** — dù các row đó cùng chung 1 pattern lỗi. Lý do: patch riêng từng item cho phép review đúng từng bản ghi trước khi chạy, và revert đúng chính xác từng row nếu phát hiện sai sót, thay vì phải revert cả loạt.

- **Patch 1 row, vài cột**: comment giá trị cũ ngay cạnh giá trị mới trong câu UPDATE, và kèm câu UPDATE revert (comment sẵn, không chạy) ngay bên dưới. Ví dụ:
  ```sql
  UPDATE AR_Trx
  SET DocumentAmt = -776115.20, --0
      BalanceAmt = -776115.20   --0
  WHERE BillID = 10401

  -- Revert nếu cần:
  -- UPDATE AR_Trx SET DocumentAmt = 0, BalanceAmt = 0 WHERE BillID = 10401
  ```

- **Patch nhiều row cùng 1 pattern lỗi** (ví dụ hàng chục bill cùng bị sai 1 field): KHÔNG viết 1 câu `UPDATE ... WHERE <điều kiện lọc pattern>` chạy 1 lần cho tất cả. Thay vào đó, dùng 1 query SELECT để **sinh sẵn từng câu UPDATE riêng theo từng khoá chính**, mỗi câu kèm giá trị cũ trong comment cuối dòng để revert đúng từng row. Mẫu đã dùng ở FARLIMPG-169:
  ```sql
  SELECT
      'UPDATE AR_Trx SET TaxExemptRate = NULL WHERE BillID = ' + CAST(BillID AS varchar(20))
      + '; -- FARLIMPG-169 | ' + DocumentNo + ' | old TaxExemptRate = ' + CAST(TaxExemptRate AS varchar(50))
      AS PatchScript
  FROM AR_Trx
  WHERE ReceivableType = 'OD_Adjustment'
    AND TaxExempt = 'N'
    AND TaxExemptRate = 0
  ORDER BY BillID;
  ```
  Chạy query này để lấy danh sách câu UPDATE (mỗi dòng kết quả là 1 câu UPDATE hoàn chỉnh kèm comment giá trị cũ + JiraID), review lại rồi mới chạy từng câu — không chạy thẳng câu SELECT gốc dạng UPDATE...WHERE gộp.

- **Patch phức tạp** (nhiều bảng liên quan): backup dữ liệu ra bảng tạm trước khi patch (`SELECT * INTO <TableName>_Backup_<Ticket> FROM <TableName> WHERE ...`), và chuẩn bị sẵn câu revert khôi phục từng row từ bảng backup đó.

Áp dụng cho MỌI loại patch (không chỉ riêng 1 module) — luôn đưa kèm phương án revert trong câu trả lời khi đề xuất patch, không đợi user nhắc.

## Quy tắc 7: comment JiraID tại mọi vị trí sửa code

Bất kỳ đoạn code fix nào đề xuất (kể cả 1 dòng) đều phải kèm comment ngay tại vị trí sửa, nêu rõ: JiraID + lý do sửa ngắn gọn (bằng tiếng Anh, vì đây là nội dung trong source code dùng chung, không phải trả lời cho user). Mục đích: sau này đọc lại code dễ trace được lịch sử sửa đổi gắn với ticket nào, không cần tra lại chat cũ. Ví dụ:
```csharp
// FARLIMPG-169: only write TaxExemptRate when TaxExempt = 'Y' — previously written
// unconditionally, causing a cast exception during Auto Reversal.
NameValue.Add("TaxExemptRate", hidTaxExempt.Value == "Y" ? ... : "");
```
Khi đưa code fix cho user, luôn viết code thuần (không dùng ký hiệu diff `+`/`-`) để user copy-paste trực tiếp được — chỉ cần chỉ rõ trong lời giải thích đoạn nào là mới/đổi so với code gốc.

## Quy tắc 8: note root cause luôn có 2 bản — Tech và Non-tech

Khi soạn note root cause (để paste Jira hoặc gửi cho ai đó), luôn chuẩn bị sẵn 2 bản riêng biệt, không gộp chung, không đợi user hỏi lại:

1. **Bản Tech**: mô tả chi tiết kỹ thuật như cũ — tên hàm/class/file, bảng/cột DB, exception message... dùng cho dev/technical consultant đọc để hiểu và fix được.
2. **Bản Non-tech**: mô tả bằng ngôn ngữ nghiệp vụ, **KHÔNG dùng tên hàm/class/file/biến trong code** — thay vào đó nêu rõ: tên màn hình/chức năng đúng như hiển thị trên UI mà user thao tác (ví dụ "Other Receivable > AR Adjustment", nút "Auto Reversal"), thao tác nào gây ra lỗi, điều kiện nghiệp vụ nào dẫn đến lỗi (ví dụ "khi Tax Exempt = No") — để người không đọc code (khách hàng, quản lý, consultant non-technical) vẫn hiểu được vấn đề nằm ở đâu và nhận diện được case tương tự.

Cả 2 bản đều viết bằng tiếng Anh (theo quy ước ở mục "Ngôn ngữ" bên dưới), trừ khi user yêu cầu khác. **Cả 2 bản đều viết liền thành 1 đoạn văn (paragraph), KHÔNG xuống dòng ngắt ý** — để dễ copy-paste thẳng vào 1 field của Jira mà không bị vỡ định dạng.

## Ngôn ngữ

- **Làm việc trực tiếp với user: luôn tiếng Việt.**
- **Mặc định tiếng Anh cho MỌI nội dung hướng tới consultant/người bên IFCA** (đều là người nước ngoài) — không cần user nhắc mỗi lần: note Jira chính thức, tin nhắn/câu hỏi soạn để user gửi hộ hoặc chat trực tiếp cho consultant, bất kỳ nội dung nào có đối tượng đọc là consultant/IFCA thay vì user.
- Cách phân biệt: nội dung TRẢ LỜI CHO USER → tiếng Việt. Nội dung SOẠN ĐỂ GỬI CHO NGƯỜI KHÁC (consultant/IFCA) → tiếng Anh, kể cả khi user yêu cầu bằng tiếng Việt (ví dụ "hỏi hộ tôi consultant xem..." → soạn câu hỏi bằng tiếng Anh, còn phần tôi giải thích/dẫn dắt cho user thì vẫn tiếng Việt).
