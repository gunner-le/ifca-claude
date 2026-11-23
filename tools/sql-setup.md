# Cho Claude Code chạy SELECT trên DB máy Gunner (sqlcmd)

## 1. Kiểm tra sqlcmd
CMD: `sqlcmd -?`  — nếu chưa có: cài "sqlcmd" (Microsoft) hoặc SQL Server Command Line Utilities.

## 2. Kết nối (điền vào `docs/claude-code-reference.md` mục "SQL trên máy Gunner")
- SQL Server cài trên máy (Windows auth): `sqlcmd -S localhost -E -d <DB> ...`
  (instance có tên: `-S localhost\<TênInstance>`)
- Docker SQL 2025 (port 1434): `sqlcmd -S localhost,1434 -U <login> -d <DB> ...`
  KHÔNG ghi mật khẩu vào file. Đặt biến môi trường 1 lần: `setx SQLCMDPASSWORD "<mật khẩu>"` rồi mở CMD mới — sqlcmd tự dùng.

## 3. (Khuyên dùng) login chỉ đọc
```sql
CREATE LOGIN claude_ro WITH PASSWORD = '<mật khẩu>';
-- lặp cho từng DB muốn cho đọc:
USE [<DB>]; CREATE USER claude_ro FOR LOGIN claude_ro; ALTER ROLE db_datareader ADD MEMBER claude_ro;
USE [IFCANetAudit_R2_8]; CREATE USER claude_ro FOR LOGIN claude_ro; ALTER ROLE db_datareader ADD MEMBER claude_ro;
```
Dùng `-U claude_ro` + SQLCMDPASSWORD. Như vậy kể cả lỡ bấm đồng ý nhầm một câu UPDATE thì SQL Server cũng chặn.
