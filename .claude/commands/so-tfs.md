So file của client với TFS chuẩn: $ARGUMENTS
(ví dụ: `/so-tfs PSAccount/ARReceiptList.aspx.cs` hoặc `/so-tfs View_AC_Receipt`)

1. Xác định client đang làm và môi trường (thư mục `_Live`/`_LIVE` → so `SourceCode\Rel\IFCA.NET 4.0`; `_Train`/`_TRAIN` → `SourceCode\Dev\BRANCHES\NET4.0_REL`; LKHS → nhánh `_SG` tương ứng). Nếu thư mục TFS chưa được add, nhắc Gunner `/add-dir "E:\IFCA Software\SourceCode\..."`.
2. Tìm file tương ứng trong TFS (web: dưới `Source\PropertyNet\` hoặc `PropertyNet\`). Với SP/View/hàm SQL: tìm file .sql trong TFS; nếu chỉ có trên DB thì đề xuất query `sp_helptext` / OBJECT_DEFINITION (theo quy tắc SQL).
3. So sánh và phân loại từng khối khác nhau:
   - **Customize của client** (có hậu tố `_<CLIENT>`, comment Jira của client, logic riêng) → giữ.
   - **Client thiếu bản fix đã có trên TFS** (lệch deploy) → đây thường là root cause; nêu rõ đoạn TFS có mà client không có.
   - **Client có mà TFS không có** (sửa trên server chưa commit TFS) → cảnh báo nguy cơ bị deploy đè (bài học SWZECON-81/84).
4. Trả lời ngắn: bảng các khối khác nhau + phân loại + đề xuất. Không sửa file nào trong `SourceCode`.
