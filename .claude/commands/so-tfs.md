So file của client với TFS chuẩn: $ARGUMENTS
(ví dụ: `/so-tfs PSAccount/ARReceiptList.aspx.cs`, `/so-tfs View_AC_Receipt B`, `/so-tfs ARReceipt.aspx.cs C`)
Mức so (chữ cuối trong tham số): **A** kiểm nhanh (mặc định) · **B** đoạn liên quan · **C** toàn file. Rule đầy đủ: mục "So với TFS" trong CLAUDE.md.

1. Xác định client đang làm và môi trường (thư mục `_Live`/`_LIVE` → so `SourceCode\Rel\IFCA.NET 4.0`; `_Train`/`_TRAIN` → `SourceCode\Dev\BRANCHES\NET4.0_REL`; LKHS → nhánh `_SG` tương ứng). Mặc định ưu tiên TFS **Live**. Nếu thư mục TFS chưa được add, nhắc Gunner `/add-dir "E:\IFCA Software\SourceCode\..."`. Nhắc 1 câu: `SourceCode` local đã get latest chưa.
   - **LKHS:** so thêm file cùng tên ở nhánh Malaysia (`Rel\IFCA.NET 4.0`, report ở `Source\Reports`) — SG lệch Malaysia ở chỗ dính bug = fix Malaysia chưa port sang SG (LKHS-337). Chỉ port đoạn sửa, không đè cả file.
2. Tìm file tương ứng trong TFS (web: dưới `Source\PropertyNet\` hoặc `PropertyNet\`). SP/View/hàm SQL/report: tìm file `.sql` / `.rdlc` trong TFS; bản client lấy bằng `OBJECT_DEFINITION` (Gunner chạy, hoặc tự SELECT nếu DB trên máy Gunner — theo quy tắc SQL).
3. So theo mức:
   - **A:** `Get-FileHash` 2 file (hoặc `git diff --no-index --stat`) — KHÔNG đọc nội dung. Giống → báo "giống TFS", xong. Khác → báo số dòng khác, hỏi có lên B không.
   - **B:** chỉ diff hàm/method/khối SP liên quan tới bug (`git diff --no-index` rồi lọc đúng đoạn), không đọc cả file.
   - **C:** diff toàn file.
4. Phân loại từng khối khác nhau:
   - **Customize của client** (hậu tố `_<CLIENT>`, comment Jira của client, logic riêng) → giữ.
   - **Client thiếu bản fix đã có trên TFS** (lệch deploy) → thường là root cause; nêu rõ đoạn TFS có mà client không có, đề xuất lấy fix TFS thay vì viết fix mới.
   - **SG thiếu fix mà Malaysia có** (chỉ LKHS — lệch nhánh) → port đoạn sửa sang SG (Live + Train), Gunner commit cả 2 nhánh SG.
   - **Client có mà TFS không có** (sửa trên server chưa commit TFS) → cảnh báo nguy cơ bị deploy đè (bài học SWZECON-81/84).
5. Trả lời ngắn: bảng các khối khác nhau + phân loại + đề xuất. Không sửa file nào trong `SourceCode`.
6. Ghi 1 dòng vào `docs/tickets/<TICKET>-*.md` nếu có, không thì mục ticket trong `docs/jira-context.md` PHẦN B: `TFS Live: so <file> ngày <yyyy-mm-dd>, mức A/B/C → giống / TFS có fix / client sửa riêng`.
