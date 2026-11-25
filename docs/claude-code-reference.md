# IFCA — Tra cứu cho Claude Code (tách từ CLAUDE.md 23/11/2026)

> CLAUDE.md giữ quy tắc hành vi (đọc mỗi phiên). File này là phần TRA CỨU — chỉ đọc mục cần (grep theo tiêu đề), không đọc hết.
> Mục: Tài liệu trong docs · Môi trường & công cụ · Client → thư mục source · TFS Standard · SQL trên máy Gunner (chi tiết) · Debug VS 2022 · Phiên không có source.

## Tài liệu trong `docs/`

| File | Nội dung |
|---|---|
| `docs/ticket-index.md` | Mục lục mọi ticket đã làm — grep ĐẦU TIÊN |
| `docs/lkhs-271/00-HANDOFF-LKHS-271.md` | **LKHS-271 GIRO (gồm LKHS-320 + LKHS-325 + LKHS-326) — Jira lớn ĐANG DỞ.** Đọc handoff + các file trong `docs/lkhs-271/` trước khi làm tiếp; giữ nguyên quyết định đã chốt |
| `docs/jira-context.md` | Context nghiệp vụ từng Jira (màn hình, bảng, root cause, quyết định, bài học). PHẦN B = ticket đang dở chỉ có trong chat cũ; PHẦN C = lịch sử 04–09/2026 |
| `docs/ifca-domain-reference.md` | Kiến thức nền dùng chung: bug pattern, module, Sys_ framework (cột thật), audit log |
| `docs/working-notes.md` | Quy tắc làm việc gốc (bản claude.ai) |
| `docs/ifca-cash-receipt-collection-reference.md` | Collection/Receipt 4 module AR, forex realized, Prc_splitpage, gotcha ASP.NET |
| `docs/ifca-autocode-syscode-reference.md` | SysCode / Number Structure |
| `docs/wcf-workflow-service-troubleshooting.md` | Lỗi WCF Workflow 404/405 |
| `docs/ENV-setup-checklist.md` | Dựng môi trường / server mới |
| `docs/memory/*.md` | Ghi nhớ tích luỹ: learnings (gotcha), architecture, framework reference, trạng thái ticket |
| `docs/memory/claude-feedback.md` | Feedback / cách làm việc Gunner đã dạy — dùng chung Claude Code + chat, đọc mỗi ticket |
| `docs/handoff-template.md` | Mẫu handoff chat → Claude Code (`/nhap-handoff`) |
| `docs/claude-chat-project-instructions.md` | Project instructions chuẩn cho Project "IFCA" trên claude.ai |
| `docs/tickets/*.md` | File chi tiết từng ticket (ticket đã đóng khác: tóm tắt trong `jira-context.md`, bản gốc ở claude.ai Project) |
| `docs/de-xuat-sua-tan-goc.md` | Lỗi lặp lại nên sửa tận gốc + draft gửi Stanley |
| `tools/sql-setup.md` | Cài sqlcmd, login chỉ đọc `claude_ro` |
| `tools/queries/` | Thư viện query chẩn đoán (chỉ SELECT) |
| `.claude/commands/*.md` | Lệnh tắt — gõ `/huong-dan` để xem hết |
| `screens/` | Gunner lưu screenshot Jira vào đây |
| `ifca.bat` | Mở Claude Code: kiến thức + source client |

## Môi trường & công cụ của Gunner
- Visual Studio 2022 (không dùng VS 2026 cho WebForms .NET 4.8); dnSpy/ILSpy khi DLL server khác TFS source.
- SQL Server production + Docker SQL Server 2025 để test (port 1434, volume `sqlvolume2025`), SSMS. .NET Framework 4.8 (Release 533509).
- Report SSRS/RDLC (Report Builder), letter Word mail-merge; QRCoder.dll phải đăng ký GAC + restart Report Server sau deploy. e-Invoice MyInvois/LHDN (IRBM).
- Jira: supportnet.ifcasoftware.com (account "IFCAVN RND Hoang Le Tien" = Gunner).
- Đồng nghiệp: Stanley (lead/kiến trúc, quyết policy, escalate), Julia (consultant/tester TIMATCH, FPARK, SWZECON, CMSD), Heah Pei Juin (LKHS, ASPENPG), Valerie (LKHS), Edward (HKB, SWZECON, SWIBRACO), WP Lim (JBTNPSB), Zac Ng (dev ASPENPG), anh Nguyễn Quốc Việt (lead VN, hỏi nghiệp vụ), James Dinh (dev, GRSUMMIT-176).

## Client → thư mục source (máy Gunner: `E:\IFCA Software\<thư mục>`)
Mở bằng `ifca.bat` (menu chọn client) hoặc `ifca.bat <thư mục> [<thư mục 2>...]`. Trong phiên thêm thư mục: `/add-dir "E:\IFCA Software\<thư mục>"`.
Hậu tố `_Live`/`_LIVE` = source lấy từ server Live của client; `_Train`/`_TRAIN` = bản Train. Không hậu tố = bản làm việc chính (hỏi Gunner nếu cần biết là Train hay Live). Tên có dấu cách luôn để trong ngoặc kép.
Code/SQL Gunner paste mặc định là của Live client đang xử lý — thư mục `_Live` là nơi đối chiếu.

| Jira prefix | Thư mục source | Ghi chú |
|---|---|---|
| ASPENPG | Aspen_Live | Aspen Vision City (CompanyID 12, prefix AVC/) |
| BDBPG | "BDB LIVE" | BDB Land |
| CMSD | CMSD, CMSD_Train | clone NAIM_PS, tên NAIMCAP trong code |
| FARLIMPG | FARLIMPG_LIVE | FGMB |
| FPARK | FPARK | Financial Park Labuan |
| GRSUMMIT | GRSUMMIT_Live, GRSUMMIT_Train | |
| IDEAL | IDEAL_LIVE | |
| JBCG | JBCG_Live | |
| JBTNPSB | JBTN_LIVE, JBTN_Train | client Standard, không customize |
| JESSELTON | JESSELTON_LIVE | |
| LKHS | LKHS, LKHS_Train | nhánh TFS riêng `NET4.0_SG` / `IFCA.NET 4.0_SG`, sửa thẳng standard; GIRO (LKHS-271/320/325) |
| NAIMCAP | Naim_PS_Live | Property Sales (Tenancy là app/DB riêng Naim_TC) |
| PKENPS | PKENPS_LIVE | |
| PLBPG | PLB_LIVE | |
| PALMINGTONPG | PMT_TRAIN | |
| SBHSKG | SBHSKG_LIVE | |
| STARKPG | STARKPG | |
| SUMMERPG | SUMMER_LIVE, SUMMER_TRAIN | |
| SUNGGUH | SUNGGUH | |
| SWCHENGLING | SWCHENGLING | DB SWCHENLING_LIVE (compat level 100) |
| SWHARTANAH | SWHARTANAH_LIVE | GRSUMMIT page AP Invoice gần như clone của Hartanah |
| SWIBRACO | SWIBRACO_LIVE | |
| SWSRIDATAI | SWSRIDATAI_Live | |
| SWZECON | SWZECON_Live | |
| TH_LIVE | TH_LIVE | sửa thẳng Standard như LKHS |
| TIMATCH | TIMATCH_LIVE | |
| **TFS Standard** | SourceCode | source lấy từ TFS = baseline chuẩn, chia thư mục con theo môi trường (Train/Live) — chọn đúng nhánh khi so sánh; chỉ so khi Gunner xác nhận (CLAUDE.md mục "So với TFS") |
| HKB, HARIANPG, client mới | chưa có — cập nhật khi làm ticket | |

## TFS Standard — cấu trúc `E:\IFCA Software\SourceCode` (mirror TFS `$/Property/`)
**Nhánh dùng thật (Gunner xác nhận 19/11):**
| Client | Train / Dev | Live |
|---|---|---|
| Mọi client Malaysia (standard) | `Dev\BRANCHES\NET4.0_REL` | `Rel\IFCA.NET 4.0` |
| **LKHS** (Singapore) | `Dev\BRANCHES\NET4.0_SG` | `Rel\IFCA.NET 4.0_SG` |
Các nhánh khác (`NET4.0`, `NET4.0_VN`, `NET3.5_VN`, `IFCA.NET 4.0_VN`, `IFCA.NET 3.0`) không dùng — đừng so với chúng.

- `Rel\IFCA.NET 4.0\` gồm: `Source` (PropertyNet web, vd `Source\PropertyNet\App_Code\PM\PMCommonBL.cs` = "TFS Live" ở SWZECON-84), `Customization` (DLL customize theo client), `Customized Version`, `Common Library` (DLL framework/BL dùng chung, vd FA), `SmartClient`, `E-Invoice Client Deployment`, `Tools`.
- `Rel\IFCA.NET 4.0_SG\` cấu trúc khác: `PropertyNet`, `Reports`, `Data Definition`, `Common Library`.
- Package nâng version (PLBPG-79): `_Package (Edge)/Versioning/Version XX` trên TFS.
- Nhánh để so: client Train → `Dev\BRANCHES\NET4.0_REL`, client Live → `Rel\IFCA.NET 4.0` (LKHS dùng 2 nhánh _SG). Bug có ở bản chuẩn → bug sản phẩm, Gunner tự commit TFS vào đúng nhánh Train/Live.
- Mở kèm khi cần so: `ifca.bat SWZECON_Live "SourceCode\Rel\IFCA.NET 4.0"` hoặc trong phiên `/add-dir "E:\IFCA Software\SourceCode\Rel\IFCA.NET 4.0"`.
- TFS DB script chia folder New Table / Table Change / Views / Update Script / Stored Procedures / Functions — 1 file = 1 object.

## SQL trên máy Gunner (sqlcmd) — chi tiết
Quy tắc cốt lõi (chỉ SELECT, chỉ server máy Gunner, hỏi trước) nằm trong CLAUDE.md. Hướng dẫn cài/đăng nhập: `tools/sql-setup.md`. Kết nối (Gunner điền):
| Client | DB | Lệnh kết nối | Ngày clone/restore |
|---|---|---|---|
| (vd LKHS) | LKHS_Train | `sqlcmd -S <server> -E -d <DB>` hoặc `-S localhost,1434 -U claude_ro -d <DB>` | (vd 2026-11-09) |
| (chung) | IFCANetAudit_R2_8 | (như trên) | |
- Ngày clone: khi điền bảng, chạy `tools/queries/09_clone_freshness.sql` để lấy. Nếu chứng từ/sự kiện đang điều tra MỚI HƠN ngày clone, hoặc Live có thể đã đổi data sau ngày clone (allocation, post bill...) → nói rõ với Gunner trước khi kết luận theo data local (bài học NAIMCAP-953).
- CHỈ chạy SELECT (và sp_helptext / OBJECT_DEFINITION / INFORMATION_SCHEMA). KHÔNG BAO GIỜ chạy UPDATE/INSERT/DELETE/ALTER/CREATE/DROP/EXEC SP ghi dữ liệu — patch đưa cho Gunner tự chạy trong SSMS.
- Ranh giới là SERVER, không phải tên DB:
  - ĐƯỢC đọc: mọi DB trên MÁY GUNNER — `-S localhost`, `.`, `(local)`, `127.0.0.1`, `localhost\<instance>`, Docker `localhost,1434` — kể cả DB clone về mang tên `_Live` (vd `LKHS_Live`, `SWZECON_Live`).
  - KHÔNG BAO GIỜ kết nối: bất kỳ server nào khác (server client, server công ty, IP/hostname từ xa, VPN), dù DB tên Train hay Live. Nếu Gunner nhờ chạy trên server từ xa → đưa query để Gunner tự chạy.
- Tìm DB của client: đọc `<connectionStrings>` (và appSettings liên quan DB) trong `web.config` của thư mục client đang add (`E:\IFCA Software\<client>\web.config` hoặc thư mục web con). Chỉ lấy **Data Source** và **Initial Catalog/Database**.
  - Data Source là máy Gunner (localhost / . / (local) / 127.0.0.1 / tên máy Gunner / `localhost,1434`) → được dùng, ghi vào bảng kết nối ở trên.
  - Data Source là server khác (IP, hostname server client/công ty) → KHÔNG dùng, báo Gunner "web.config này trỏ server từ xa" và hỏi DB clone trên máy tên gì.
  - KHÔNG chép User ID / Password từ web.config vào docs, câu trả lời hay lệnh. Chạy sqlcmd bằng Windows auth `-E` hoặc login `claude_ro` (mật khẩu qua biến môi trường SQLCMDPASSWORD), không dùng tài khoản sa trong web.config.
- Trước mỗi lần chạy: nói 1 câu query để kiểm tra gì. sqlcmd KHÔNG nằm trong danh sách allow → Gunner luôn được hỏi.
- Tiết kiệm token: chỉ chọn cột cần, luôn có `TOP` (mặc định 50) hoặc GROUP BY/COUNT trước khi lấy chi tiết; không `SELECT *` trên bảng rộng (AR_Trx, CB_Receipt...) trừ khi lọc 1-2 dòng. Định dạng gọn: `sqlcmd ... -W -s "|" -Q "SET NOCOUNT ON; <query>"`.
- Tên DB audit luôn `IFCANetAudit_R2_8`. Compat level thấp (vd 100) không có STRING_AGG.

## Debug: Gunner dùng Visual Studio 2022 (File > Open Web Site), KHÔNG dùng VS Code
- Source là ASP.NET **Web Site project** (biên dịch lúc chạy, không có .csproj/.sln build bằng lệnh). Đừng đề xuất VS Code, `dotnet build`, `msbuild` cho web.
- VS và Claude Code phải trỏ CÙNG thư mục `E:\IFCA Software\<client>`. Nếu kết quả debug không khớp với file vừa sửa → hỏi Gunner VS đang mở thư mục nào.
- Sau khi sửa 1 file: nhắc Gunner chọn Yes khi VS hỏi reload, và không để thay đổi chưa lưu trong VS trên cùng file (VS lưu sẽ đè mất phần Claude vừa sửa).
- Sửa `App_Code` → cả site biên dịch lại; 1 file lỗi có thể làm hỏng cả thư mục trang (CMSD-40). Giữ cú pháp sạch, đủ `using`, `#region/#endregion` cân bằng. Không để file backup/copy `.cs`/`.aspx` trong thư mục source (bị biên dịch → trùng class).
- Claude không gắn được debugger. Khi cần debug: chỉ rõ breakpoint (file + dòng mốc + biến/biểu thức cần xem trong Watch/Immediate), Gunner F5 rồi dán giá trị/stack trace. DLL không có source/PDB → dnSpy/ILSpy (Gunner làm), Claude phân tích code decompile được dán vào.

## Phiên KHÔNG có source (ifca.bat chọn 0) — patch data / làm trực tiếp trên server
- Dùng cho: ticket patch data, ticket chỉ cần query, hoặc client chưa clone source về máy.
- Không tìm source trên máy. Cần code → nhờ Gunner copy đúng file (aspx.cs, SP, view...) từ server vào `work\<JiraID>\` rồi đọc ở đó; hoặc Gunner dán vào. Coi đó là bản LIVE của client (theo quy tắc mặc định).
- SQL: đưa câu SELECT để Gunner tự chạy trên server (SSMS) — KHÔNG kết nối server từ xa. Kết quả Gunner dán vào. Ưu tiên query có sẵn trong `tools/queries/`.
- Patch: theo quy tắc patch (1 UPDATE / record, comment giá trị cũ, SELECT kiểm tra trước, sau CB patch nhắc `CBUpdateAccountBalance`...). Gunner tự chạy.
- Fix code: đưa hướng dẫn sửa theo dòng mốc (như bên chat), vì không có file local để sửa. Nếu Gunner đã copy file vào `work\<JiraID>\` thì có thể sửa bản đó (khi Gunner bảo), nhưng vẫn phải xuất danh sách thay đổi theo dòng mốc để áp lên server/TFS.
- `work\` và `screens\` không commit git (`.gitignore`) — có thể chứa dữ liệu client.
