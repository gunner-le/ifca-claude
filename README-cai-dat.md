# IFCA trên Claude Code — hướng dẫn cài đặt & dùng hằng ngày

## Gói này có gì
```
ifca.bat                 ← mở Claude Code (menu chọn client trong E:\IFCA Software)
CLAUDE.md                ← quy tắc làm việc, Claude Code tự đọc mỗi phiên
.claude\settings.json    ← quyền: lệnh chỉ đọc chạy sẵn, cấm sửa SourceCode (TFS chuẩn)
.claude\commands\        ← lệnh tắt /ticket-moi /tam-dung /xuat-thay-doi /dong-ticket
docs\                    ← toàn bộ kiến thức IFCA
  ticket-index.md        ← mục lục ticket
  jira-context.md        ← context nghiệp vụ ~139 ticket (A: có file chi tiết, B: đang dở, C: lịch sử 04–09/2026)
  lkhs-271\              ← handoff GIRO LKHS-271/320/325 (Jira lớn đang dở)
  tickets\               ← file chi tiết ticket
  memory\                ← gotcha, kiến trúc, trạng thái ticket
  ifca-domain-reference.md, ENV-setup-checklist.md, ...
tools\sql-setup.md       ← cài sqlcmd + login chỉ đọc
screens\                 ← để screenshot Jira
```

## Cài đặt (1 lần)
1. Giải nén vào chỗ cố định, vd `E:\IFCA\ifca-claude-code` (giữ thư mục ẩn `.claude`).
2. Claude Code: nên cài bản CLI `irm https://claude.ai/install.ps1 | iex` (PowerShell) → `C:\Users\<you>\.local\bin\claude.exe`. Chưa cài thì `ifca.bat` tự dùng bản trong extension VS Code.
3. Lần đầu chạy: chọn theme → đăng nhập tài khoản Claude → Trust thư mục.
4. (Khuyên dùng) `git init` + commit trong thư mục này và trong thư mục source client — xem mục Git dưới.
5. (Tuỳ chọn) SQL: làm theo `tools\sql-setup.md`.

## Dùng hằng ngày
| Việc | Cách |
|---|---|
| Mở | double-click `ifca.bat` → gõ số client (hoặc `ifca.bat LKHS_Train`, `ifca.bat LKHS_Train LKHS`) |
| Ticket mới cùng client | `/clear` → `/ticket-moi <JiraID> <nội dung Jira>` |
| Ticket khác client | `/exit` → `ifca.bat` → chọn client |
| Thêm source khác giữa chừng | `/add-dir "E:\IFCA Software\<thư mục>"` (vd `SourceCode\Rel\IFCA.NET 4.0` để so TFS) |
| Gác ticket dở | `/tam-dung <JiraID>` |
| Quay lại phiên cũ | mở đúng client → `/resume` → chọn (câu đầu có mã Jira) |
| Tiếp ticket dở ở phiên mới | "làm tiếp <JiraID>" |
| Lấy phần sửa để áp lên server/TFS | `/xuat-thay-doi <JiraID>` |
| Đóng ticket | `/dong-ticket <JiraID>` → `git commit` |
| So client với TFS | `/so-tfs <file hoặc object>` |
| Báo cáo tuần (EN) | `/bao-cao-tuan` |
| **Quên lệnh** | **`/huong-dan`** |
| Dừng ngay | `Esc` · Gọn hội thoại dài: `/compact` |

## Lưu ý an toàn
- Claude Code chỉ sửa BẢN SAO trên máy. Không copy đè cả file lên server/TFS — dùng `/xuat-thay-doi` và áp từng chỗ.
- Đọc kỹ bảng xác nhận trước khi bấm Yes; không bật chế độ bỏ qua xác nhận.
- SQL: chỉ SELECT, chỉ DB trên máy bạn, luôn hỏi trước. Patch bạn tự chạy trong SSMS.
- Kiến thức mới chỉ ghi vào `docs\` trên máy — claude.ai Project không tự đồng bộ. Từ nay `docs\` là bản chính.

## Git (khuyên dùng)
- Thư mục kiến thức: `git init` → `git add -A` → `git commit -m "init"`; sau mỗi ticket `git add -A && git commit -m "<JiraID>"`.
- Source client (`E:\IFCA Software\<client>`): `git init` + `.gitignore` (bin/, obj/, *.dll, *.pdb) → commit "baseline". Trước ticket lấy bản mới nhất file từ server/TFS → commit. Sau khi sửa: `git diff` xem đúng dòng đã đổi; hỏng thì `git checkout -- <file>`.
