Bắt đầu ticket mới: $ARGUMENTS

Chế độ "chat trước" (CLAUDE.md): KHÔNG tự đọc source, KHÔNG đọc nguyên file docs.
1. **Grep** (không Read cả file) trong `docs/ticket-index.md`, `docs/jira-context.md` (cả phần A/B/C), `docs/tickets/`, `docs/ifca-domain-reference.md`, `docs/memory/` theo mã ticket, client, màn hình, bảng/SP liên quan; chỉ đọc vài dòng quanh chỗ trúng. Đối chiếu đúng client trước khi áp finding cũ. Ticket đã có trong index → theo rule "quên báo đóng" / Reopen.
2. Xác định thư mục source của client (grep bảng "Client → thư mục source" trong `docs/claude-code-reference.md`); nếu chưa được add thì nhắc Gunner `/add-dir`.
3. Trả lời bằng tiếng Việt: tóm tắt ngắn cách hiểu ticket (lỗi gì / yêu cầu gì, màn hình, bảng nghi ngờ), nêu ticket cũ liên quan nếu có.
4. Xin đúng MỘT thông tin quyết định nhất tiếp theo: 1 query SQL sẵn chạy, HOẶC nhờ Gunner dán đúng 1 đoạn code (nêu file + hàm/khối cần). Chỉ đọc file khi Gunner bảo. Không đoán root cause khi chưa có dữ liệu.
5. Nếu bug nằm ở code/SP/view/report và file ticket chưa có dòng `TFS Live: ...`: thêm 1 câu cuối hỏi có so với TFS Live không, kèm tên file/object nghi ngờ và các mức (A) kiểm nhanh · (B) đoạn liên quan · (C) toàn file · bỏ qua — theo mục "So với TFS" trong CLAUDE.md. KHÔNG tự so trước khi Gunner trả lời.
