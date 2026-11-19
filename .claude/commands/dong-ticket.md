Đóng ticket: $ARGUMENTS (chỉ làm khi Gunner xác nhận đã test OK / có kết quả cuối)

1. `docs/ticket-index.md`: thêm/cập nhật dòng (client, module/màn hình, mô tả ngắn + root cause + fix, trạng thái, ngày, file chi tiết).
2. `docs/tickets/<TICKET>-<slug>.md`: bối cảnh, root cause, fix (diff trước/sau theo dòng mốc), kết quả test, rủi ro còn lại, bài học.
3. `docs/jira-context.md`: chuyển ticket từ PHẦN B (nếu có) sang mục đã đóng của client, bản tóm tắt nghiệp vụ.
4. `docs/ifca-domain-reference.md` / `docs/memory/learnings.md`: chỉ thêm nếu có kiến thức dùng chung MỚI (menu/màn hình → bảng, gotcha).
5. Nếu ticket thuộc nhóm lỗi lặp lại → thêm vào `docs/de-xuat-sua-tan-goc.md`. Query chẩn đoán dùng lại được → lưu vào `tools/queries/`.
6. Đưa 2 bản note Jira tiếng Anh, ngắn: **[Tech]** và **[Non-tech]**, mỗi bản Root Cause / Fix / Status.
7. Changeset TFS: nếu ticket có sửa code/SP/view/report chuẩn mà chưa có `CS <id>` trong index/file chi tiết → hỏi Gunner changeset ID của CẢ 2 nhánh Dev và Rel (có thể nhiều ID mỗi nhánh) để ghi theo format trong CLAUDE.md; thiếu nhánh nào thì ghi `chưa` cho nhánh đó. Gunner chưa commit TFS → ghi "chưa commit TFS" ở trạng thái.
Báo lại file nào đã cập nhật. Nhắc Gunner `git commit` thư mục ifca-claude-code.
