# Mẫu handoff (claude.ai chat → Claude Code)

> Dùng khi làm ticket bên claude.ai chat. Chat KHÔNG ghi được vào repo → cuối ticket (hoặc khi học được điều mới) chat xuất bản handoff theo đúng mẫu dưới; Gunner dán vào Claude Code bằng `/nhap-handoff` → Claude Code ghi vào docs + push → bên chat bấm sync GitHub để nhận lại.
> Nhiều ticket: gộp nhiều khối `# <JiraID>` trong 1 lần dán. Không chép code dài — chỉ đoạn sửa chính (dòng mốc + đoạn mới). Giữ nguyên SQL quan trọng.

```text
# <JiraID> — <tiêu đề ngắn>
Trạng thái: <đang dở | FIXED Train — chờ consultant | đã áp Live | đóng | Reopen>  · Ngày: <yyyy-mm-dd>
Client / môi trường: <client, Train/Live>
Màn hình / menu: <menu > ... , file .aspx>
Bảng / view / SP / RDLC / DLL: <tên thật>

## Đã XÁC NHẬN (có data/code chứng minh)
- ...
## GIẢ THUYẾT chưa chốt
- ...
## Root cause (nếu đã chốt)
...
## Fix (file + dòng mốc + đoạn đổi chính, marker JiraID) — đã áp Train/Live chưa
- ...
## Changeset TFS
Dev: <id, id | chưa | không commit>  · Rel: <id | chưa | không commit>
## Query quan trọng (giữ nguyên SQL)
...
## ID / chứng từ test
...
## Bước tiếp theo
...
## Note Jira (nếu đã viết) — [Tech] / [Non-tech]
...
## Bài học / rule mới (feedback Gunner, gotcha, kiến thức dùng chung)
- <rule> — vì sao (ticket, ngày)
```

Mục không có thì ghi "—", không bỏ tiêu đề.
