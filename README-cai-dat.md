# Chuyển IFCA sang Claude Code — hướng dẫn

## Gói này có gì

```
CLAUDE.md                     ← quy tắc làm việc (Claude Code tự đọc mỗi phiên)
docs/
  ticket-index.md             ← mục lục ticket (bản 18/11)
  ifca-domain-reference.md    ← kiến thức nền dùng chung
  working-notes.md
  ifca-cash-receipt-collection-reference.md
  ifca-autocode-syscode-reference.md
  wcf-workflow-service-troubleshooting.md
  ENV-setup-checklist.md
  memory/                     ← những gì Claude đã ghi nhớ qua các chat
    learnings.md  architecture.md  framework-reference.md  ticket-status.md
  tickets/
    LKHS-271-ar-giro-collection-dbs.md
    (các file chi tiết ticket còn lại: gói bổ sung đợt 2)
```

## Cài đặt

1. Cài Claude Code (Windows: theo hướng dẫn tại https://docs.claude.com/en/docs/claude-code), đăng nhập cùng tài khoản Claude.
2. Tạo 1 thư mục "kiến thức IFCA" cố định, ví dụ `D:\IFCA-Claude\`, giải nén gói này vào đó.
3. Với mỗi client cần làm (vd source LKHS ở `D:\Source\LKHS`), có 2 cách:
   - **Cách đơn giản:** mở terminal tại `D:\IFCA-Claude` rồi chạy `claude --add-dir D:\Source\LKHS` → Claude đọc được cả docs lẫn source.
   - **Hoặc** copy `CLAUDE.md` vào gốc thư mục source, sửa bảng "Tài liệu" thành đường dẫn tuyệt đối `D:\IFCA-Claude\docs\...`.
4. Mỗi ticket mở 1 phiên Claude Code mới (giống quy tắc "1 ticket = 1 chat").

## Lưu ý

- **Không cho Claude Code chạy lệnh ghi lên DB Live.** `CLAUDE.md` đã ghi quy tắc này, nhưng anh vẫn nên đọc kỹ từng lệnh trước khi duyệt.
- Kiến thức mới: Claude Code sẽ tự cập nhật `docs/ticket-index.md` và `docs/tickets/*.md` khi ticket xong (theo quy tắc trong CLAUDE.md).
- claude.ai Project "IFCA" vẫn giữ nguyên. Anh có thể dùng song song, nhưng 2 bên **không tự đồng bộ**. Nên chọn `D:\IFCA-Claude\docs` làm bản chính từ nay.
- Source LKHS-271 (App_Code/GIROCode, CashFlow/ARGIRO*...) đang có trên source LKHS của anh nên không chép lại vào gói.

## Cách mở hằng ngày (nhanh nhất)
1. Giải nén thư mục `ifca-claude-code` vào chỗ cố định, ví dụ `E:\IFCA\ifca-claude-code`.
2. Double-click `ifca.bat` → hiện danh sách thư mục trong `E:\IFCA Software` → gõ số client → Claude Code mở với kiến thức + source client đó.
   - Hoặc gõ trong CMD: `ifca.bat LKHS_Train` hoặc `ifca.bat LKHS_Train LKHS` (Train + Live để so sánh).
   - Nếu source không nằm ở `E:\IFCA Software`, sửa dòng `set "ROOT=..."` đầu file.
3. Có thể tạo shortcut `ifca.bat` ra Desktop / ghim Taskbar.
4. Đổi ticket cùng client: `/clear`. Quay lại phiên cũ: `claude -r`. Cần thêm source khác giữa chừng: `/add-dir "E:\IFCA Software\<thư mục>"`.

