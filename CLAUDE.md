# IFCA — Hướng dẫn cho Claude Code

> File này Claude Code tự đọc mỗi phiên. Chuyển từ claude.ai Project "IFCA" (19/11/2026).
> Kiến thức chi tiết nằm trong `docs/` — đọc khi cần, không cần đọc hết mỗi phiên.

## Bối cảnh dự án & vai trò

- Người dùng: **Gunner** (Jira account "IFCAVN RND Hoang Le Tien", nick `letienhoang`), dev/support engineer cho **IFCA Software** — ERP.NET (ASP.NET WebForms C# + LLBLGen + SQL Server + SSRS/RDLC + Word mail-merge), multi-tenant, nhiều client Malaysia/Singapore dùng chung 1 nền code, mỗi client có customize riêng.
- **Tiền tố Jira key = mã client** (SWHARTANAH, TIMATCH, LKHS, HKB, FARLIMPG, SWZECON, SWIBRACO, FPARK, CMSD, JESSELTON, PALMINGTONPG...). Jira: supportnet.ifcasoftware.com.
- **Pipeline bug:** bug ở Live → consultant note Jira → assign Gunner → clone DB/source đúng client để điều tra → root cause → fix. Lỗi chung bản standard → Gunner tự commit TFS (2 nhánh Train/Live). Bug đã có fix trên TFS → lấy về áp cho client.
- **3 môi trường / client:** Train (test), Live Testing (clone Live, không bắt buộc), Live (production).
- Mặc định code/SQL Gunner đưa là của server/DB client đang xử lý. Chỉ khi Gunner nói "đây là TFS" mới hiểu là baseline chung.
- **Commit TFS do Gunner tự làm** — Claude không check-in, chỉ sửa file / đưa đúng đoạn fix.
- Đồng nghiệp: Stanley (lead/architect, chốt nghiệp vụ & policy), Julia (consultant/QA TIMATCH, FPARK, SWZECON, CMSD), Valerie (LKHS), Heah Pei Juin (LKHS, ASPENPG), WP Lim (JBTNPSB), Edward, Zac Ng (ASPENPG), Nguyen Quoc Viet (lead/consultant VN, hỏi nghiệp vụ).

## An toàn khi chạy lệnh (Claude Code)

- **KHÔNG BAO GIỜ chạy UPDATE/DELETE/INSERT/ALTER/EXEC proc ghi dữ liệu trên DB Live.** Chỉ chạy SELECT trên DB local/Train/clone khi Gunner cho phép. Script patch: soạn ra file, Gunner tự chạy.
- Không `tf checkin`, không xoá file trong source. Sửa file chuẩn (standard) phải comment JiraID.
- Trước khi sửa 1 file, xác nhận đúng client/đúng thư mục source (tránh sửa nhầm bản client khác).

## Quy tắc hành vi khi trả lời

- **Luôn trả lời bằng tiếng Việt.** Nội dung gửi consultant/IFCA (note Jira, tin nhắn Stanley...) viết **tiếng Anh**, ngắn, không jargon. Tin nhắn cho Stanley: ngắn, chỉ hỏi, bám đúng ý Stanley vừa nêu.
- Gunner nói tiếng Anh/nghe yếu: khi họp với Stanley thì chuẩn bị sẵn talking points tiếng Anh.
- **Nhận ticket mới:** không hỏi trắc nghiệm. Tóm tắt ngắn hiểu của mình về ticket → rồi hỏi bằng văn bản thường thông tin còn thiếu.
- **Trước khi trả lời ticket mới:** tra `docs/ticket-index.md`, `docs/jira-context.md`, `docs/ifca-domain-reference.md`, `docs/memory/*` và file ticket cũ cùng màn hình/bảng — **không đoán lại** những gì đã từng xác định (đã từng đoán sai `AP_Trx` cho màn AP Transaction, đúng là `AP_Journal`). Đối chiếu đúng cột Client trước khi áp finding cũ.
- **Không đoán khi chưa có dữ liệu thật.** Cần data thì đưa ngay câu SQL sẵn chạy (hoặc tự chạy SELECT nếu được phép), không chỉ liệt kê cần gì.
- Khi điều tra: **mỗi lượt chỉ 1 query / 1 yêu cầu** (bước kiểm tra quyết định nhất), Gunner không check song song nhiều thứ được.
- Investigate root cause trước khi fix; bế tắc ở DB → decompile DLL (dnSpy/ILSpy) hoặc hỏi Stanley, không suy đoán tiếp. Luôn xác nhận đúng call chain từ nút trên UI (tên hàm giống nhau là bẫy). Luôn check `Sys_Report.ReportFileName` trỏ đúng RDLC trước khi soi SP.
- Giải thích bối cảnh nghiệp vụ khi Gunner gặp module lạ.

## Quy tắc code / SQL

- **SQL đưa cho Gunner chạy:** code block sẵn copy. Không cần gộp 1 script lớn, đi từng bước cũng được.
- **Mọi UPDATE/patch phải comment giá trị cũ** cạnh giá trị mới (`SET Amount = 3816.00 -- was 110053.44`). Patch đơn giản: 1 UPDATE / 1 record theo khoá, không tạo bảng backup. Nhiều record cùng pattern: SELECT sinh từng câu UPDATE riêng kèm giá trị cũ + JiraID. Patch phức tạp: UpdateScript + RevertScript. WHERE ưu tiên business key khi không mơ hồ. Luôn SELECT kiểm tra trạng thái trước khi patch. Có FK thì ưu tiên delete+reinsert.
- **Fix SP/SQL đi prod:** chỉ đưa đoạn thay đổi (find → replace / insert), mỗi chỗ comment JiraID (`-- SWIBRACO-587`), dòng cũ giữ lại dạng comment. Không đưa nguyên SP viết lại.
- Fix SQL/SP (nhất là performance): Gunner verify chạy đúng & nhanh trong SSMS với data thật trước, rồi mới đụng C#.
- **Code C#/JS/ASPX:** không dùng ký hiệu diff `+`/`-`. Code sạch, phần đổi bọc `// <JiraID> start` / `// <JiraID> end` (comment tiếng Anh nêu lý do). File chuẩn có sẵn → hướng dẫn sửa theo từng vị trí (Gunner tự commit TFS); file mới hoàn toàn → gửi nguyên file. Trong Claude Code: được sửa trực tiếp file nhưng vẫn phải bọc comment JiraID.
- Nhiều file cho 1 deliverable → gom 1 zip (cấu trúc thư mục + README file mới vs file sửa tay).
- **Không hardcode record ID** (BillItemID IN (...)) trong SP/SQL fix — lọc theo thuộc tính (ItemCode/ItemName/flag/type) đã kiểm chứng với data.
- **Không dynamic SQL (`EXEC(@sql)`) / dò cột lúc runtime** — viết SQL tĩnh như view chuẩn; chưa chắc cột thì hỏi/chạy query kiểm tra trước.
- **Không thêm cột vào bảng nghiệp vụ** khi chưa bàn và được Gunner (và Stanley) đồng ý. Thêm config Sys_ + CF_String chỉ để hiển thị thì OK.
- **Script config (Sys_/CF_String/menu…) chạy lại được nhiều lần**: mỗi bảng `IF EXISTS (SELECT TOP 1 1 ...) BEGIN DELETE ... END` rồi `INSERT ... VALUES (N'...')`; không cần rollback; không ID cứng theo môi trường. Sửa thì sửa thẳng script chính, không sinh script "update" riêng. **Không script gắn menu vào Menu Template** (user tự gắn theo môi trường).
- Cột thật của bảng Sys_/CF_ đã ghi trong `docs/ifca-domain-reference.md` — đọc trước khi viết script config, không đoán tên cột.
- SQL deliverable cho TFS: 1 file = 1 object (tên file = tên object), theo folder TFS (New Table / Table Change / Views / Update Script / Stored Procedures / Functions...), gom theo Jira.
- Audit DB luôn là `IFCANetAudit_R2_8` (mọi client) — viết thẳng tên, không placeholder.
- Policy customize: **LKHS và TH_LIVE sửa thẳng Standard** (không clone hậu tố). Client khác: clone view/SP/page với hậu tố `_<CLIENT>`.

## Quy tắc lưu tài liệu (thay cho Project docs)

- Chỉ ghi/cập nhật `docs/ticket-index.md`, file chi tiết `docs/tickets/<TICKET>-<slug>.md` và `docs/ifca-domain-reference.md` **khi ticket có kết quả cuối** (root cause confirm, fix đã áp, hoặc đóng). Không ghi sau mỗi vòng trao đổi.
- Khi ticket "nặng" xong: (1) cập nhật index; (2) viết file chi tiết (bối cảnh, root cause, fix, test); (3) trích kiến thức dùng chung sang domain reference (kể cả menu/màn hình/bảng đã xác nhận); (4) đưa note Jira tiếng Anh **2 bản Tech + Non-tech**, mỗi bản 1 đoạn liền (Root Cause / Fix / Status) — chỉ viết khi root cause/fix đã test đúng.
- Lỗi setup môi trường ghi vào `docs/ENV-setup-checklist.md`.

## Môi trường

- VS 2022 (.NET Framework 4.8 WebForms), dnSpy/ILSpy, SSMS, SQL Server (Docker SQL 2025 local port 1434), TFS, Report Builder.
- Collation DB IFCA `Chinese_PRC_CI_AS` ≠ tempdb → thêm `COLLATE DATABASE_DEFAULT` cho join chuỗi với bảng tạm.

## Tài liệu trong `docs/`

| File | Nội dung |
|---|---|
| `docs/ticket-index.md` | Mục lục mọi ticket đã làm — đọc ĐẦU TIÊN |
| `docs/lkhs-271/00-HANDOFF-LKHS-271.md` | **LKHS-271 GIRO (gồm LKHS-320 + LKHS-325 + LKHS-326) — Jira lớn ĐANG DỞ.** Đọc handoff + các file trong `docs/lkhs-271/` trước khi làm tiếp; giữ nguyên quyết định đã chốt |
| `docs/jira-context.md` | Context nghiệp vụ từng Jira (màn hình, bảng, root cause, quyết định, bài học) — đọc khi gặp ticket cùng client/màn hình |
| `docs/ifca-domain-reference.md` | Kiến thức nền dùng chung: bug pattern, module, Sys_ framework (cột thật), audit log |
| `docs/working-notes.md` | Quy tắc làm việc gốc (bản claude.ai) |
| `docs/ifca-cash-receipt-collection-reference.md` | Collection/Receipt 4 module AR, forex realized, Prc_splitpage, gotcha ASP.NET |
| `docs/ifca-autocode-syscode-reference.md` | SysCode / Number Structure |
| `docs/wcf-workflow-service-troubleshooting.md` | Lỗi WCF Workflow 404/405 |
| `docs/ENV-setup-checklist.md` | Dựng môi trường / server mới |
| `docs/memory/*.md` | Ghi nhớ tích luỹ: learnings (gotcha), architecture, framework reference, trạng thái ticket |
| `docs/tickets/*.md` | File chi tiết từng ticket |

## Môi trường & công cụ của Gunner
- Visual Studio 2022 (không dùng VS 2026 cho WebForms .NET 4.8); dnSpy/ILSpy khi DLL server khác TFS source.
- SQL Server production + Docker SQL Server 2025 để test (port 1434, volume `sqlvolume2025`), SSMS. .NET Framework 4.8 (Release 533509).
- Report SSRS/RDLC (Report Builder), letter Word mail-merge; QRCoder.dll phải đăng ký GAC + restart Report Server sau deploy. e-Invoice MyInvois/LHDN (IRBM).
- Jira: supportnet.ifcasoftware.com (account "IFCAVN RND Hoang Le Tien" = Gunner). TFS DB script chia folder New Table / Table Change / Views / Update Script / Stored Procedures / Functions — 1 file = 1 object.
- Đồng nghiệp: Stanley (lead/kiến trúc, quyết policy, escalate), Julia (consultant/tester TIMATCH, FPARK, SWZECON, CMSD), Heah Pei Juin (LKHS, ASPENPG), Valerie (LKHS), Edward (HKB, SWZECON, SWIBRACO), WP Lim (JBTNPSB), Zac Ng (dev ASPENPG), anh Nguyễn Quốc Việt (lead VN, hỏi nghiệp vụ), James Dinh (dev, GRSUMMIT-176).
- Gunner nghe/nói tiếng Anh yếu: tin nhắn/talking point cho Stanley phải ngắn, chỉ hỏi, bám đúng điểm Stanley vừa nêu.
- Ưu tiên ổn định & đúng dữ liệu hơn tối đa hiệu năng; tối ưu SP chọn cách an toàn.
- Code snippet: không dùng `++`/`--` (hỏng ký tự khi copy) — dùng `+= 1`/`-= 1`.
- `docs/jira-context.md` PHẦN B = ticket đang dở chỉ có trong chat cũ; PHẦN C = lịch sử 04–09/2026 (TIMATCH, FPARK, SWZECON, JBTNPSB, NAIMCAP, ASPENPG...) — đọc khi Gunner nhắc ticket không có trong index. Ticket chỉ ghi "chỉ còn tiêu đề" thì nói rõ không có chi tiết và hỏi Gunner.
- **LKHS-271 / 320 / 325 đang làm dở**: khi Gunner nhắc GIRO, đọc `docs/lkhs-271/00-HANDOFF-LKHS-271.md` trước, rồi đọc code thật trong source LKHS (`--add-dir`). Tiếp tục từ mục "Việc còn mở", không làm lại, không hỏi lại điều đã chốt.

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
| **TFS Standard** | SourceCode | source lấy từ TFS = baseline chuẩn, chia thư mục con theo môi trường (Train/Live) — chọn đúng nhánh khi so sánh; nghi bug do customize thì so với đây |
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
- So bản client với chuẩn: client Train → `Dev\BRANCHES\NET4.0_REL`, client Live → `Rel\IFCA.NET 4.0` (LKHS dùng 2 nhánh _SG). Bug có ở bản chuẩn → bug sản phẩm, Gunner tự commit TFS vào đúng nhánh Train/Live.
- Mở kèm khi cần so: `ifca.bat SWZECON_Live "SourceCode\Rel\IFCA.NET 4.0"` hoặc trong phiên `/add-dir "E:\IFCA Software\SourceCode\Rel\IFCA.NET 4.0"`.
