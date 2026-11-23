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

## Chế độ "chat trước" (mặc định — tiết kiệm token)
Claude không tự đọc source, không tự sửa/tạo file; code fix đưa ngay trong chat. Muốn hơn thì nói:
- *(dán đoạn code)* — Claude phân tích trên đoạn đó (rẻ nhất)
- "đọc file X" / "đọc hàm Y trong file X" — Claude grep rồi chỉ đọc đoạn liên quan
- "dò call chain từ nút Z" — Claude nói trước sẽ đọc file nào
- "sửa file" / "gen file" / "làm file SQL" / "đóng gói zip" — Claude sửa/tạo file thật (backup `_ORIG` + `_versions\` trong `work\<JiraID>\`)
- "quay về v2 file X" / "so v1 với v2 file X" — lấy lại / so bản backup trong `work\<JiraID>\_versions\`
- Mỗi ticket 1 phiên: xong → `/tam-dung` (nếu dở) → `/clear`

## Câu nói thường dùng
- "làm tiếp <JiraID>" — tiếp ticket dở ở phiên mới
- "LKHS-325 đang làm tới đâu?" — GIRO đọc handoff
- "chạy query 04 so config LstNo X giữa DB A và B" — dùng thư viện `tools/queries/`
- "LKHS-336, CMSD-60 xong, Rel 95011" — đóng nhanh (chỉ cập nhật trạng thái + changeset)
- "LKHS-337: Dev 95010, Rel 95011" — ghi changeset
- "mở lại LKHS-337, Live lại sai …" — reopen (đọc file cũ, thêm mục Reopen)

## Mở Claude Code
`ifca.bat` → chọn số client (0 = không source: patch data / query server, file server copy vào `work\<JiraID>\`) · `ifca.bat LKHS_Train LKHS` (nhiều thư mục) · `claude -c` (phiên gần nhất)
