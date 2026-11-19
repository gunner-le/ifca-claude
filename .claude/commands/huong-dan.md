Hiển thị bảng hướng dẫn (KHÔNG làm gì khác, không đọc thêm file):

## Lệnh tắt IFCA
| Lệnh | Dùng khi | Ví dụ |
|---|---|---|
| `/huong-dan` | Quên lệnh | |
| `/ticket-moi <JiraID> <nội dung>` | Bắt đầu ticket | `/ticket-moi SWZECON-105 AP > Report ...` |
| `/so-tfs <file/object> [A\|B\|C]` | So client với TFS Live (A kiểm nhanh · B đoạn liên quan · C toàn file) | `/so-tfs App_Code/PM/PMCommonBL.cs B` |
| `/tam-dung <JiraID>` | Gác ticket dở, ghi trạng thái | `/tam-dung LKHS-335` |
| `/xuat-thay-doi <JiraID>` | Lấy danh sách chỗ sửa (dòng mốc) để áp server/TFS | `/xuat-thay-doi LKHS-333` |
| `/dong-ticket <JiraID>` | Ticket xong: cập nhật docs + note Jira Tech/Non-tech | `/dong-ticket FPARK-216` |
| `/bao-cao-tuan` | Tóm tắt tuần (EN) để họp Stanley | |

## Lệnh có sẵn của Claude Code
| Lệnh | Tác dụng |
|---|---|
| `/clear` | Xoá hội thoại, bắt đầu ticket mới (docs vẫn còn) |
| `/compact` | Tóm gọn hội thoại dài (tiết kiệm token) |
| `/resume` | Mở lại phiên cũ (chọn theo câu đầu có mã Jira) |
| `/add-dir "<đường dẫn>"` | Thêm thư mục source (vd `E:\IFCA Software\SourceCode\Rel\IFCA.NET 4.0`) |
| `/exit` | Thoát (đổi client: thoát → chạy lại `ifca.bat`) |
| `Esc` | Dừng ngay việc đang làm |

## Câu nói thường dùng
- "làm tiếp <JiraID>" — tiếp ticket dở ở phiên mới
- "LKHS-325 đang làm tới đâu?" — GIRO đọc handoff
- "chạy query 04 so config LstNo X giữa DB A và B" — dùng thư viện `tools/queries/`

## Mở Claude Code
`ifca.bat` → chọn số client (0 = không source: patch data / query server, file server copy vào `work\<JiraID>\`) · `ifca.bat LKHS_Train LKHS` (nhiều thư mục) · `claude -c` (phiên gần nhất)
