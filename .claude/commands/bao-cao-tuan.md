Báo cáo tuần cho Stanley/consultant: $ARGUMENTS (mặc định 7 ngày gần nhất)

Đọc `docs/ticket-index.md` (cột cập nhật), `docs/jira-context.md` PHẦN B (đang dở), `docs/lkhs-271/00-HANDOFF-LKHS-271.md`, và `git log --since="7 days ago"` của thư mục này nếu có.
**Bước 0 — dọn trạng thái trước:** liệt kê (tiếng Việt, gọn) các ticket trong index / PHẦN B còn "chờ… / đang dở / FIXED Train / Reopen" mà cột cập nhật cũ hơn 7 ngày: `Ticket — trạng thái đang ghi — ngày`. Hỏi Gunner cái nào đã xong (trả lời kiểu "LKHS-336, CMSD-60 xong, Rel 95011") → cập nhật theo rule "Đóng nhanh" trong CLAUDE.md, rồi mới viết báo cáo. Gunner bảo bỏ qua thì viết luôn.

Viết bằng **tiếng Anh ngắn gọn, không jargon**, nhóm theo client:
- **Done this week:** ticket — 1 dòng kết quả.
- **In progress:** ticket — trạng thái + bước tiếp.
- **Waiting on:** ticket — chờ ai (consultant / Stanley / user) chờ gì.
- **Questions for Stanley:** tối đa 3 câu, ngắn, chỉ hỏi.
- **Suggestions:** (nếu có) lỗi lặp lại đáng sửa tận gốc — lấy từ `docs/de-xuat-sua-tan-goc.md`.
Sau đó thêm 3-5 dòng tiếng Việt tóm tắt cho Gunner đọc nhanh. Không bịa ticket không có trong docs.
