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
- Đồng nghiệp: xem mục "Môi trường & công cụ của Gunner".

## An toàn khi chạy lệnh (Claude Code)

- **Không tự chạy lệnh ghi dữ liệu (UPDATE/DELETE/INSERT/ALTER/CREATE/DROP/EXEC proc ghi) ở BẤT KỲ DB nào** — patch soạn ra, Gunner tự chạy trong SSMS.
- SELECT: chỉ trên DB **trên máy Gunner** (kể cả DB clone tên `_Live`), luôn hỏi trước; **không bao giờ kết nối server từ xa** (server client/công ty). Chi tiết: mục "SQL trên máy Gunner".
- Không `tf checkin`, không xoá file trong source. Sửa file chuẩn (standard) phải comment JiraID.
- Trước khi sửa 1 file, xác nhận đúng client/đúng thư mục source (tránh sửa nhầm bản client khác).

## Quy tắc hành vi khi trả lời

- **Luôn trả lời bằng tiếng Việt.** Nội dung gửi consultant/IFCA (note Jira, tin nhắn Stanley...) viết **tiếng Anh**, ngắn, không jargon. Gunner nghe/nói tiếng Anh yếu → tin nhắn cho Stanley: ngắn, chỉ hỏi, bám đúng ý Stanley vừa nêu; họp với Stanley thì chuẩn bị sẵn talking points tiếng Anh.
- **Nhận ticket mới:** không hỏi trắc nghiệm. Tóm tắt ngắn hiểu của mình về ticket → rồi hỏi bằng văn bản thường thông tin còn thiếu.
- **Trước khi trả lời ticket mới:** tra `docs/ticket-index.md`, `docs/jira-context.md`, `docs/ifca-domain-reference.md`, `docs/memory/*` và file ticket cũ cùng màn hình/bảng — **không đoán lại** những gì đã từng xác định (đã từng đoán sai `AP_Trx` cho màn AP Transaction, đúng là `AP_Journal`). Đối chiếu đúng cột Client trước khi áp finding cũ.
- **Không đoán khi chưa có dữ liệu thật.** Cần data thì đưa ngay câu SQL sẵn chạy (hoặc tự chạy SELECT nếu được phép), không chỉ liệt kê cần gì.
- Khi điều tra: **mỗi lượt chỉ 1 query / 1 yêu cầu** (bước kiểm tra quyết định nhất), Gunner không check song song nhiều thứ được.
- **So với TFS: luôn HỎI trước, Gunner xác nhận mới so** — xem mục "So với TFS — hỏi trước, so theo mức". Không tự đọc/so `SourceCode`, nhưng phải chủ động gợi ý (Gunner hay quên).
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
- **Changeset TFS:** Gunner gửi changeset ID của ticket nào → ghi NGAY (ngoại lệ quy tắc "chỉ ghi khi có kết quả cuối"), 1 Jira thường có changeset ở **2 nhánh Dev (Train) và Rel (Live)**, mỗi nhánh có thể nhiều changeset → nhóm theo nhánh, thêm ID mới vào cuối (không ghi đè ID cũ). Format thống nhất để grep được:
  - `docs/ticket-index.md`, cột Trạng thái: `CS Dev: 95010, 95022 · Rel: 95011` (LKHS ghi `Dev SG` / `Rel SG`; nhánh chưa commit ghi `Rel: chưa`).
  - `docs/tickets/<TICKET>-*.md`, mục `## Changeset TFS` (bảng): `| Nhánh | Changeset | Ngày | File/object | Ghi chú |` — 1 dòng / changeset, nhánh ghi đường dẫn đầy đủ (`Dev\BRANCHES\NET4.0_REL`, `Rel\IFCA.NET 4.0`, `..._SG`).
  - Ticket chưa có dòng index → ghi vào mục ticket trong `docs/jira-context.md` theo format dòng index. Dùng khi: revert (`tf rollback /changeset:<id>`), kiểm server đã có fix chưa, port fix sang nhánh khác (LKHS SG ↔ Malaysia).

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
| `docs/tickets/*.md` | File chi tiết từng ticket (13 ticket mở/phức tạp chép nguyên văn; ticket đã đóng khác: tóm tắt trong `jira-context.md`, bản gốc ở claude.ai Project) |
| `tools/sql-setup.md` | Cài sqlcmd, login chỉ đọc `claude_ro` |
| `.claude/commands/*.md` | Lệnh tắt — gõ `/huong-dan` để xem hết |
| `tools/queries/` | Thư viện query chẩn đoán (chỉ SELECT) |
| `docs/de-xuat-sua-tan-goc.md` | Lỗi lặp lại nên sửa tận gốc + draft gửi Stanley |
| `screens/` | Gunner lưu screenshot Jira vào đây |
| `ifca.bat` | Mở Claude Code: kiến thức + source client |

## Môi trường & công cụ của Gunner
- Visual Studio 2022 (không dùng VS 2026 cho WebForms .NET 4.8); dnSpy/ILSpy khi DLL server khác TFS source.
- SQL Server production + Docker SQL Server 2025 để test (port 1434, volume `sqlvolume2025`), SSMS. .NET Framework 4.8 (Release 533509).
- Report SSRS/RDLC (Report Builder), letter Word mail-merge; QRCoder.dll phải đăng ký GAC + restart Report Server sau deploy. e-Invoice MyInvois/LHDN (IRBM).
- Đồng nghiệp: Stanley (lead/kiến trúc, quyết policy, escalate), Julia (consultant/tester TIMATCH, FPARK, SWZECON, CMSD), Heah Pei Juin (LKHS, ASPENPG), Valerie (LKHS), Edward (HKB, SWZECON, SWIBRACO), WP Lim (JBTNPSB), Zac Ng (dev ASPENPG), anh Nguyễn Quốc Việt (lead VN, hỏi nghiệp vụ), James Dinh (dev, GRSUMMIT-176).
- Collation DB IFCA `Chinese_PRC_CI_AS` ≠ tempdb → thêm `COLLATE DATABASE_DEFAULT` cho join chuỗi với bảng tạm.
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
| **TFS Standard** | SourceCode | source lấy từ TFS = baseline chuẩn, chia thư mục con theo môi trường (Train/Live) — chọn đúng nhánh khi so sánh; chỉ so khi Gunner xác nhận (mục "So với TFS") |
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

## So với TFS — hỏi trước, so theo mức (rule chuẩn duy nhất)
Nhiều bug là client chưa được deploy fix đã có trên TFS → đầu ticket nên đối chiếu TFS **Live** trước. Nhưng so tốn token → **luôn hỏi, Gunner xác nhận mới so** (kể cả code, SP, view, report RDLC).
1. **Khi nào hỏi:** (a) đầu ticket — trong `/ticket-moi`, sau phần tóm tắt, khi đã biết file/SP/view/report nghi ngờ; (b) khi điều tra chạm thêm file/object mới chưa so; (c) trước khi chốt root cause / đề xuất fix mà chưa so. Hỏi 1 câu cuối câu trả lời, không dừng việc điều tra khác, vd: *"So `ARReceipt.aspx.cs` + `sp_xxx` với TFS Live (`Rel\IFCA.NET 4.0`)? (A) kiểm nhanh · (B) so đoạn liên quan · (C) toàn file · bỏ qua"*. Mỗi file/object hỏi 1 lần; Gunner bỏ qua thì thôi.
2. **3 mức (rẻ trước):**
   - **A — kiểm nhanh (~0 token):** so hash/kích thước bằng lệnh (`Get-FileHash` / `git diff --no-index --stat`), không đọc nội dung. Giống → xong; khác → chỉ báo số dòng khác.
   - **B — đoạn liên quan:** chỉ diff hàm/method/khối SP dính tới bug.
   - **C — toàn file:** chỉ khi Gunner chọn.
3. **SP / view / report:** tìm `.sql` / `.rdlc` trong TFS; bản client lấy bằng `OBJECT_DEFINITION` (Gunner chạy, hoặc tự SELECT nếu DB trên máy Gunner). Trước khi so nhắc Gunner `SourceCode` local đã get latest chưa (bản cũ → kết luận "chưa fix" sai).
4. **Đọc kết quả:** TFS có mà client không có → nhiều khả năng fix chưa deploy → đề xuất lấy fix TFS, không viết fix mới. Client có mà TFS không có → sửa riêng chưa commit, cảnh báo dễ bị deploy đè (SWZECON-81/84). Customize `_<CLIENT>` / comment Jira client → giữ.
4b. **LKHS (nhánh SG) — so 2 nhánh:** fix ở nhánh Malaysia (`Rel\IFCA.NET 4.0`) không tự sang SG (`Rel\IFCA.NET 4.0_SG`). Bug LKHS → khi hỏi, đề xuất so cả 2: client LKHS ↔ TFS SG (lệch deploy) **và** SG ↔ Malaysia (chuẩn chung — lệch nhánh). SG khác Malaysia ở chỗ dính bug → nhiều khả năng fix Malaysia chưa port → chỉ port đúng đoạn sửa, KHÔNG đè cả file Malaysia (file SG khác ở chỗ khác, vd `PM_Company` vs `CF_Company`) (LKHS-337: RDL `PM_DebtorAgingSumByTrxDate` Owing trừ Unallocated). Ngược lại: sửa file chuẩn ở 1 nhánh → nhắc Gunner kiểm file cùng tên ở nhánh còn lại.
5. **Ghi lại để không hỏi lặp:** so xong (hoặc Gunner bảo bỏ qua) → ghi 1 dòng vào `docs/tickets/<TICKET>-*.md` nếu có, không thì mục ticket trong `docs/jira-context.md` PHẦN B (ngoại lệ của quy tắc "chỉ ghi docs khi có kết quả cuối"): `TFS Live: so <file> ngày <yyyy-mm-dd>, mức A/B/C → giống / TFS có fix / client sửa riêng / bỏ qua`. Mở lại ticket thì đọc dòng này trước khi hỏi.

## Sửa file có sẵn (code / SQL) — KHÔNG để Gunner phải copy đè cả file
Thư mục `E:\IFCA Software\<client>` và `SourceCode` là BẢN SAO trên máy Gunner, có thể cũ hơn server/TFS. Gunner KHÔNG copy đè cả file lên server/TFS (sợ mất phần sửa của người khác) — chỉ áp phần fix có note Jira.
1. Trước khi sửa 1 file có sẵn: nhắc Gunner lấy bản mới nhất của file đó từ server (Live/Train) hoặc TFS về local, nếu chưa chắc local đang mới.
2. Khi sửa file local: chỉ thêm/sửa đúng chỗ cần; bọc bằng `// <JiraID> start` / `// <JiraID> end` (C#/JS), `<%-- <JiraID> --%>` (aspx), `-- <JiraID>` (SQL); dòng cũ comment lại, không xoá. Không reformat, không đổi chỗ khác trong file (giữ CRLF, encoding gốc).
3. Sau khi Gunner test OK: xuất **danh sách thay đổi theo dòng mốc** cho từng file — đường dẫn file, dòng mốc để tìm, thao tác (thêm sau / thêm trước / thay), đoạn code sạch để paste (không dấu +/- diff). Gunner tự áp lên server và TFS.
4. SP / View có sẵn: chỉ đưa các đoạn thay đổi (find → replace / insert, có comment Jira, giữ dòng cũ dạng comment); không đưa nguyên ALTER để chạy đè. Object mới hoàn toàn thì gửi nguyên file.
5. Không bao giờ đề xuất copy nguyên file có sẵn đè lên server/TFS. File MỚI do ticket tạo ra thì được gửi/copy nguyên file.
6. Khi Gunner hỏi "đã sửa những gì", liệt kê lại từ chính file local (tìm theo comment JiraID), không dựa trí nhớ.

## SQL trên máy Gunner (sqlcmd) — chỉ SELECT, luôn hỏi trước
Hướng dẫn cài/đăng nhập: `tools/sql-setup.md`. Kết nối (Gunner điền):
| Client | DB | Lệnh kết nối | Ngày clone/restore |
|---|---|---|---|
| (vd LKHS) | LKHS_Train | `sqlcmd -S <server> -E -d <DB>` hoặc `-S localhost,1434 -U claude_ro -d <DB>` | (vd 2026-11-09) |
| (chung) | IFCANetAudit_R2_8 | (như trên) | |
- Ngày clone: khi điền bảng, chạy `tools/queries/09_clone_freshness.sql` để lấy. Nếu chứng từ/sự kiện đang điều tra MỚI HƠN ngày clone, hoặc Live có thể đã đổi data sau ngày clone (allocation, post bill...) → nói rõ với Gunner trước khi kết luận theo data local (bài học NAIMCAP-953).
Quy tắc:
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

## Lệnh tắt (slash command) — trong `.claude/commands/`
`/huong-dan` (tra cứu mọi lệnh) · `/ticket-moi <Jira>` · `/so-tfs <file> [A|B|C]` · `/tam-dung <Jira>` · `/xuat-thay-doi <Jira>` · `/dong-ticket <Jira>` · `/bao-cao-tuan`
Thư mục `SourceCode` (TFS chuẩn) bị cấm sửa trong `.claude/settings.json` — chỉ đọc, chỉ so khi Gunner xác nhận.
Screenshot: lưu vào `screens\` rồi gõ đường dẫn.

## Kiểm tra nhanh khi nhận bug (trước khi đào sâu)
1. **Lệch deploy?** Rất nhiều bug là server ≠ TFS (SWZECON-84, SWIBRACO-730/698, LKHS-322, FPARK-197, CMSD). → hỏi Gunner có so TFS Live không, theo mục "So với TFS" (không tự so).
2. **Lỗi đã biết?** Đối chiếu `docs/de-xuat-sua-tan-goc.md`: Tax Adj Journal không có GL, JS đọc cột grid ẩn, Bill Item Inactive, trigger PREVENT_DUP_INSERT, sale Return lọt letter.
3. **Màn hình → bảng thật:** `tools/queries/03_screen_to_tables.sql`; xem định nghĩa view đọc trước khi suy luận dữ liệu.
4. Gặp nhóm lỗi trong `de-xuat-sua-tan-goc.md` lần nữa → xử lý ticket, rồi nhắc Gunner mục đề xuất (thêm ticket vào danh sách đó khi `/dong-ticket`).

## Chưa có dữ liệu thật thì chưa kết luận
- Mọi kết luận root cause phải dựa trên code thật + data thật (ưu tiên data CHƯA bị patch). Ghi rõ đâu là "đã xác nhận", đâu là "giả thuyết".
- Các lần sai trước đây đều do kết luận sớm: SWCHENGLING-67 (đổi `>` thành `>=` sai → revert ở 79), NAIMCAP-972 (sửa nhầm master view thay vì sub view), GRSUMMIT-204 (patch ngược dấu vì không xem view), JBTNPSB-25 (đào config quá lâu thay vì decompile).
- Đọc được nhiều file không có nghĩa là đúng: trước khi đề xuất fix, nêu 1 cách kiểm chứng (query / bước test) và chờ Gunner xác nhận.

## Thư viện query: `tools/queries/` (xem README trong đó)
Dùng file có sẵn thay vì viết lại (đúng tên cột, đỡ token): audit trace, đếm audit theo khung giờ, màn hình→bảng, so config Sys_ 2 DB, tìm cột trong object, trigger trên bảng, SysCode, Sys_Report, độ mới DB clone. Query mới dùng lại được → thêm vào đây khi đóng ticket.

## Debug: Gunner dùng Visual Studio 2022 (File > Open Web Site), KHÔNG dùng VS Code
- Source là ASP.NET **Web Site project** (biên dịch lúc chạy, không có .csproj/.sln build bằng lệnh). Đừng đề xuất VS Code, `dotnet build`, `msbuild` cho web.
- VS và Claude Code phải trỏ CÙNG thư mục `E:\IFCA Software\<client>`. Nếu kết quả debug không khớp với file vừa sửa → hỏi Gunner VS đang mở thư mục nào.
- Sau khi sửa 1 file: nhắc Gunner chọn Yes khi VS hỏi reload, và không để thay đổi chưa lưu trong VS trên cùng file (VS lưu sẽ đè mất phần Claude vừa sửa).
- Sửa `App_Code` → cả site biên dịch lại; 1 file lỗi có thể làm hỏng cả thư mục trang (CMSD-40). Giữ cú pháp sạch, đủ `using`, `#region/#endregion` cân bằng.
- Claude không gắn được debugger. Khi cần debug: chỉ rõ breakpoint (file + dòng mốc + biến/biểu thức cần xem trong Watch/Immediate), Gunner F5 rồi dán giá trị/stack trace. DLL không có source/PDB → dnSpy/ILSpy (Gunner làm), Claude phân tích code decompile được dán vào.

## Phiên KHÔNG có source (ifca.bat chọn 0) — patch data / làm trực tiếp trên server
- Dùng cho: ticket patch data, ticket chỉ cần query, hoặc client chưa clone source về máy.
- Không tìm source trên máy. Cần code → nhờ Gunner copy đúng file (aspx.cs, SP, view...) từ server vào `work\<JiraID>\` rồi đọc ở đó; hoặc Gunner dán vào. Coi đó là bản LIVE của client (theo quy tắc mặc định).
- SQL: đưa câu SELECT để Gunner tự chạy trên server (SSMS) — KHÔNG kết nối server từ xa. Kết quả Gunner dán vào. Ưu tiên query có sẵn trong `tools/queries/`.
- Patch: theo quy tắc patch (1 UPDATE / record, comment giá trị cũ, SELECT kiểm tra trước, sau CB patch nhắc `CBUpdateAccountBalance`...). Gunner tự chạy.
- Fix code: đưa hướng dẫn sửa theo dòng mốc (như bên chat), vì không có file local để sửa. Nếu Gunner đã copy file vào `work\<JiraID>\` thì có thể sửa bản đó để Gunner xem, nhưng vẫn phải xuất danh sách thay đổi theo dòng mốc để áp lên server/TFS.
- `work\` và `screens\` không commit git (`.gitignore`) — có thể chứa dữ liệu client.

