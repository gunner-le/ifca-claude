Bắt đầu ticket mới: $ARGUMENTS

1. Tra `docs/ticket-index.md`, `docs/jira-context.md` (cả phần A/B/C), `docs/ifca-domain-reference.md`, `docs/memory/learnings.md` theo mã ticket, client, màn hình, bảng liên quan. Đối chiếu đúng client trước khi áp finding cũ.
2. Xác định thư mục source của client (bảng "Client → thư mục source" trong CLAUDE.md); nếu chưa được add thì nhắc Gunner `/add-dir`.
3. Trả lời bằng tiếng Việt: tóm tắt ngắn cách hiểu ticket (lỗi gì / yêu cầu gì, màn hình, bảng nghi ngờ), nêu ticket cũ liên quan nếu có.
4. Xin đúng MỘT thông tin quyết định nhất tiếp theo (1 query SQL sẵn chạy, hoặc đọc 1 file code cụ thể). Không đoán root cause khi chưa có dữ liệu.
