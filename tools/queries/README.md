# Thư viện query chẩn đoán IFCA (chỉ SELECT)
Claude Code: dùng file ở đây thay vì viết lại từ đầu — thay placeholder `<...>`, giữ nguyên tên cột. Chạy theo quy tắc mục "SQL trên máy Gunner" trong CLAUDE.md (hỏi trước, chỉ DB trên máy).
| File | Dùng khi |
|---|---|
| 01_audit_trace_by_key.sql | Ai/khi nào đổi giá trị 1 bản ghi |
| 02_audit_count_window.sql | Nghi xử lý bị nhân đôi / batch — đếm số lần đổi trong khung giờ |
| 03_screen_to_tables.sql | Màn hình (TabNo/LstNo) → bảng đọc/ghi thật → định nghĩa view |
| 04_sys_config_diff_2db.sql | Màn hình lỗi ở client này nhưng chạy ở client khác (lệch Sys_ config, nút trùng) |
| 05_find_column_usage.sql | Object nào dùng 1 cột; cột thật của bảng |
| 06_triggers_on_table.sql | Save lỗi lạ / cột bị NULL dù code gửi giá trị |
| 07_syscode_numberstructure.sql | Số chứng từ rỗng / "no row at position 0" |
| 08_report_file_check.sql | Report sai/không ra — kiểm RDLC + filter |
| 09_clone_freshness.sql | DB clone trên máy mới tới ngày nào |
Thêm query dùng lại được vào đây khi đóng ticket (1 file / 1 mục đích, có comment bài học).
