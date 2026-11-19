Xuất danh sách thay đổi của ticket: $ARGUMENTS

Tìm trong các thư mục đang add mọi chỗ có comment mã Jira này (`// <JiraID>`, `-- <JiraID>`, `<%-- <JiraID> --%>`). Nếu thư mục là git repo thì đối chiếu thêm `git diff`. Với từng file:
- Đường dẫn file (tương đối trong thư mục client)
- Dòng mốc để tìm (dòng gốc có sẵn, duy nhất)
- Thao tác: thêm SAU / thêm TRƯỚC / THAY
- Đoạn code sạch để paste (giữ comment JiraID, KHÔNG có dấu +/- kiểu diff)
SP/View: chỉ các đoạn đổi (find → replace/insert). Object/file MỚI: ghi "file mới — copy nguyên file".
Cuối cùng: danh sách file cần áp lên server và TFS (nhánh Train `Dev\BRANCHES\NET4.0_REL` / Live `Rel\IFCA.NET 4.0`; LKHS dùng nhánh _SG). Không đề xuất copy đè cả file có sẵn.
