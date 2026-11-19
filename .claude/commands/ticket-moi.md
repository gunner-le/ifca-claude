Bắt đầu ticket mới: $ARGUMENTS

1. Tra `docs/ticket-index.md`, `docs/jira-context.md` (cả phần A/B/C), `docs/ifca-domain-reference.md`, `docs/memory/learnings.md` theo mã ticket, client, màn hình, bảng liên quan. Đối chiếu đúng client trước khi áp finding cũ.
2. Xác định thư mục source của client (bảng "Client → thư mục source" trong CLAUDE.md); nếu chưa được add thì nhắc Gunner `/add-dir`.
3. Trả lời bằng tiếng Việt: tóm tắt ngắn cách hiểu ticket (lỗi gì / yêu cầu gì, màn hình, bảng nghi ngờ), nêu ticket cũ liên quan nếu có.
4. Xin đúng MỘT thông tin quyết định nhất tiếp theo (1 query SQL sẵn chạy, hoặc đọc 1 file code cụ thể). Không đoán root cause khi chưa có dữ liệu.
5. Nếu bug nằm ở code/SP/view/report và file ticket chưa có dòng `TFS Live: ...`: thêm 1 câu cuối hỏi có so với TFS Live không, kèm tên file/object nghi ngờ và các mức (A) kiểm nhanh · (B) đoạn liên quan · (C) toàn file · bỏ qua — theo mục "So với TFS" trong CLAUDE.md. KHÔNG tự so trước khi Gunner trả lời.
