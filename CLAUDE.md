# IFCA — Hướng dẫn cho Claude Code

> File này Claude Code tự đọc mỗi phiên (giữ GỌN — chỉ quy tắc hành vi). Phần tra cứu (bảng client → thư mục source, cấu trúc TFS, SQL chi tiết, debug VS, phiên không source, danh sách docs, đồng nghiệp) ở **`docs/claude-code-reference.md`** — chỉ đọc đúng mục khi cần.

## Bối cảnh & vai trò
- Người dùng: **Gunner** (Jira "IFCAVN RND Hoang Le Tien", nick `letienhoang`), dev/support IFCA Software — ERP.NET (ASP.NET WebForms C# + LLBLGen + SQL Server + SSRS/RDLC + Word mail-merge), multi-tenant, client Malaysia/Singapore dùng chung 1 nền code, mỗi client customize riêng.
- **Tiền tố Jira key = mã client.** Pipeline: bug Live → consultant note Jira → Gunner clone DB/source đúng client → root cause → fix. Lỗi chung bản standard → Gunner tự commit TFS (2 nhánh Dev/Train, Rel/Live). Bug đã có fix trên TFS → lấy về áp cho client.
- 3 môi trường / client: Train, Live Testing (không bắt buộc), Live. Code/SQL Gunner đưa mặc định là của server/DB client đang xử lý (Live); chỉ khi Gunner nói "đây là TFS" mới là baseline chung.
- **Commit TFS do Gunner tự làm** — Claude không check-in.
- Đồng nghiệp chính: Stanley (lead, chốt nghiệp vụ & policy), Julia, Valerie, Heah Pei Juin (consultant) — đủ danh sách ở file tra cứu.

## An toàn khi chạy lệnh
- **Không tự chạy lệnh ghi dữ liệu (UPDATE/DELETE/INSERT/ALTER/CREATE/DROP/EXEC proc ghi) ở BẤT KỲ DB nào** — patch soạn ra, Gunner tự chạy trong SSMS.
- SQL: chỉ SELECT (và sp_helptext / OBJECT_DEFINITION / INFORMATION_SCHEMA), chỉ DB **trên máy Gunner** (localhost / `.` / Docker `localhost,1434`, kể cả DB clone tên `_Live`), luôn nói 1 câu query kiểm tra gì rồi hỏi trước; **không bao giờ kết nối server từ xa**. Không chép User/Password từ web.config. Luôn `TOP`/COUNT, chọn cột cần. Chi tiết (tìm DB qua web.config, ngày clone, lệnh sqlcmd): file tra cứu mục "SQL trên máy Gunner".
- Không `tf checkin`, không xoá file trong source. Thư mục `SourceCode` (TFS) chỉ đọc.
- Trước khi sửa 1 file, xác nhận đúng client/đúng thư mục source (tra bảng client → thư mục ở file tra cứu).

## Tiết kiệm token — chế độ "chat trước" (MẶC ĐỊNH)
- **Không tự đọc source code.** Gunner dán đoạn cần (hàm, khối SP, JS...) → phân tích trên đoạn đó. Thiếu thì nói rõ cần đoạn nào ("dán hàm `SaveARTrxMod` trong `PMCommonBL.cs`") hoặc hỏi "cho mình đọc file X không?" — Gunner đồng ý mới đọc.
- **Code fix đưa ngay trong chat** (dòng mốc + comment JiraID, theo quy tắc code). **Không sửa / tạo file** trừ khi Gunner bảo.
- Gunner bảo **"đọc file X"** → Grep tìm vị trí trước, chỉ Read đoạn liên quan (offset/limit, ~50–150 dòng), không đọc nguyên file dài (>300 dòng) trừ khi Gunner yêu cầu. **"dò call chain"** → nói trước sẽ đọc những file nào. **"sửa file" / "gen file"** → làm theo mục "Sửa / tạo file"; không in lại toàn bộ code vào chat (danh sách thay đổi để áp server: `/xuat-thay-doi`).
- **Tra docs bằng Grep** (mã Jira, client, màn hình, bảng, SP) trong `docs/`, chỉ đọc mấy dòng trúng — KHÔNG đọc nguyên `jira-context.md` / `ifca-domain-reference.md` / `ticket-index.md`.
- Vẫn tự làm không cần hỏi: Grep docs; ghi docs ticket theo quy tắc lưu tài liệu; tạo `_ORIG` / backup version trong `work\`.
- **Mỗi ticket 1 phiên** (desktop app): sang ticket khác → nhắc Gunner bấm **New** (phiên mới), KHÔNG bảo `/clear`; ticket dở thì `/tam-dung` trước; 1 phiên ticket quá dài → `/compact`. Việc nhẹ (patch data, query, sửa nhỏ) → gợi ý chọn model nhẹ hơn trong app.

## Quy tắc hành vi khi trả lời
- **Luôn trả lời bằng tiếng Việt.** Nội dung gửi consultant/IFCA (note Jira, tin nhắn Stanley...) viết **tiếng Anh**, ngắn, không jargon. Gunner nghe/nói tiếng Anh yếu → tin nhắn cho Stanley: ngắn, chỉ hỏi, bám đúng ý Stanley vừa nêu; họp với Stanley thì chuẩn bị sẵn talking points tiếng Anh.
- **Nhận ticket mới:** không hỏi trắc nghiệm. Tóm tắt ngắn hiểu của mình → hỏi bằng văn bản thường thông tin còn thiếu.
- **Trước khi trả lời ticket mới:** đọc `docs/memory/claude-feedback.md` (ngắn, bắt buộc); Grep `docs/ticket-index.md`, `docs/jira-context.md`, `docs/ifca-domain-reference.md`, `docs/memory/*`, `docs/tickets/` theo mã ticket / client / màn hình / bảng — **không đoán lại** những gì đã từng xác định (từng đoán sai `AP_Trx` cho màn AP Transaction, đúng là `AP_Journal`). Đối chiếu đúng client trước khi áp finding cũ. Ticket chỉ ghi "chỉ còn tiêu đề" → nói rõ không có chi tiết, hỏi Gunner.
- **LKHS-271 / 320 / 325 / 326 (GIRO) đang dở:** Gunner nhắc GIRO → đọc `docs/lkhs-271/00-HANDOFF-LKHS-271.md` trước, tiếp từ "Việc còn mở", không làm lại, không hỏi lại điều đã chốt.
- **Không đoán khi chưa có dữ liệu thật.** Cần data thì đưa ngay câu SQL sẵn chạy (hoặc tự chạy SELECT nếu được phép).
- Khi điều tra: **mỗi lượt chỉ 1 query / 1 yêu cầu** (bước kiểm tra quyết định nhất).
- **So với TFS: luôn HỎI trước, Gunner xác nhận mới so** — mục "So với TFS". Không tự đọc/so `SourceCode`, nhưng phải chủ động gợi ý (Gunner hay quên).
- Investigate root cause trước khi fix; bế tắc ở DB → decompile DLL (dnSpy/ILSpy, Gunner làm) hoặc hỏi Stanley, không suy đoán tiếp. Luôn xác nhận đúng call chain từ nút trên UI (tên hàm giống nhau là bẫy). Luôn check `Sys_Report.ReportFileName` trỏ đúng RDLC trước khi soi SP.
- Giải thích bối cảnh nghiệp vụ khi Gunner gặp module lạ.

## Kiểm tra nhanh khi nhận bug
1. **Lệch deploy?** Rất nhiều bug là server ≠ TFS (SWZECON-84, SWIBRACO-730/698, LKHS-322, FPARK-197, CMSD) → hỏi có so TFS Live không (không tự so).
2. **Lỗi đã biết?** Đối chiếu `docs/de-xuat-sua-tan-goc.md` (Tax Adj Journal không có GL, JS đọc cột grid ẩn, Bill Item Inactive, trigger PREVENT_DUP_INSERT, sale Return lọt letter). Gặp lại → xử lý xong nhắc Gunner mục đề xuất (thêm ticket vào danh sách khi `/dong-ticket`).
3. **Màn hình → bảng thật:** `tools/queries/03_screen_to_tables.sql`; xem định nghĩa view trước khi suy luận dữ liệu.

## Chưa có dữ liệu thật thì chưa kết luận
- Kết luận root cause phải dựa trên code thật + data thật (ưu tiên data CHƯA bị patch). Ghi rõ "đã xác nhận" vs "giả thuyết". DB clone cũ hơn sự kiện đang điều tra → nói rõ trước khi kết luận (NAIMCAP-953).
- Các lần sai trước đều do kết luận sớm: SWCHENGLING-67 (đổi `>` thành `>=` sai → revert ở 79), NAIMCAP-972 (sửa nhầm master view thay vì sub view), GRSUMMIT-204 (patch ngược dấu vì không xem view), JBTNPSB-25 (đào config quá lâu thay vì decompile).
- Trước khi đề xuất fix: nêu 1 cách kiểm chứng (query / bước test) và chờ Gunner xác nhận.

## Quy tắc code / SQL
- **SQL đưa cho Gunner chạy:** code block sẵn copy, đi từng bước cũng được. Ưu tiên query có sẵn trong `tools/queries/` (xem README: audit trace, màn hình→bảng, so config Sys_ 2 DB, tìm cột, trigger, SysCode, Sys_Report, độ mới DB clone) thay vì viết lại — đúng tên cột, đỡ token.
- **Mọi UPDATE/patch phải comment giá trị cũ** (`SET Amount = 3816.00 -- was 110053.44`). Patch đơn giản: 1 UPDATE / 1 record theo khoá, không bảng backup. Nhiều record cùng pattern: SELECT sinh từng câu UPDATE riêng kèm giá trị cũ + JiraID. Patch phức tạp: UpdateScript + RevertScript. WHERE ưu tiên business key khi không mơ hồ. Luôn SELECT kiểm tra trước khi patch. Có FK thì ưu tiên delete+reinsert. Sau patch CB nhắc `CBUpdateAccountBalance`.
- **Fix SP/SQL đi prod:** chỉ đưa đoạn thay đổi (find → replace / insert), mỗi chỗ comment JiraID (`-- SWIBRACO-587`), dòng cũ giữ dạng comment. Không đưa nguyên SP viết lại. Fix SQL/SP (nhất là performance): Gunner verify trong SSMS với data thật trước, rồi mới đụng C#.
- **Code C#/JS/ASPX:** không dùng ký hiệu diff `+`/`-`; code sạch, phần đổi bọc `// <JiraID> start` / `// <JiraID> end` (comment tiếng Anh nêu lý do). File chuẩn có sẵn → hướng dẫn sửa theo từng vị trí; file mới hoàn toàn → gửi nguyên file. Không dùng `++`/`--` trong snippet (hỏng khi copy) — dùng `+= 1`/`-= 1`.
- Nhiều file cho 1 deliverable → gom 1 zip (cấu trúc thư mục + README file mới vs file sửa tay).
- **Không hardcode record ID** (BillItemID IN (...)) — lọc theo thuộc tính đã kiểm chứng với data.
- **Không dynamic SQL (`EXEC(@sql)`) / dò cột lúc runtime** — SQL tĩnh; chưa chắc cột thì hỏi/chạy query kiểm tra.
- **Không thêm cột vào bảng nghiệp vụ** khi chưa được Gunner (và Stanley) đồng ý. Thêm config Sys_ + CF_String chỉ để hiển thị thì OK.
- **Script config (Sys_/CF_String/menu…) chạy lại được nhiều lần**: mỗi bảng `IF EXISTS (SELECT TOP 1 1 ...) BEGIN DELETE ... END` rồi `INSERT ... VALUES (N'...')`; không rollback; không ID cứng theo môi trường; sửa thẳng script chính. **Không script gắn menu vào Menu Template.** Cột thật bảng Sys_/CF_ ở `docs/ifca-domain-reference.md` — Grep trước khi viết, không đoán tên cột.
- SQL deliverable cho TFS: 1 file = 1 object (tên file = tên object), theo folder TFS (New Table / Table Change / Views / Update Script / Stored Procedures / Functions...), gom theo Jira.
- Audit DB luôn `IFCANetAudit_R2_8`. Collation `Chinese_PRC_CI_AS` ≠ tempdb → `COLLATE DATABASE_DEFAULT` khi join chuỗi với bảng tạm. Compat level thấp (100) không có STRING_AGG.
- Ưu tiên ổn định & đúng dữ liệu hơn tối đa hiệu năng.
- Policy customize: **LKHS và TH_LIVE sửa thẳng Standard** (không hậu tố). Client khác: clone view/SP/page với hậu tố `_<CLIENT>`.
- Source là ASP.NET **Web Site project** (VS 2022, biên dịch lúc chạy) — không đề xuất VS Code / `dotnet build` / `msbuild`. Debug: chỉ rõ breakpoint, Gunner F5 rồi dán giá trị (chi tiết ở file tra cứu).

## Sửa / tạo file (CHỈ khi Gunner bảo "sửa file" / "gen file")
Thư mục `E:\IFCA Software\<client>` và `SourceCode` là BẢN SAO, có thể cũ hơn server/TFS. Gunner KHÔNG copy đè cả file lên server/TFS — chỉ áp phần fix có note Jira.
1. Trước khi sửa file có sẵn: nhắc Gunner lấy bản mới nhất từ server/TFS về local nếu chưa chắc local đang mới.
2. Sửa đúng chỗ cần (Edit, không Write cả file); bọc `// <JiraID> start/end` (C#/JS), `<%-- <JiraID> --%>` (aspx), `-- <JiraID>` (SQL); dòng cũ comment lại, không xoá. Không reformat, không đổi chỗ khác (giữ CRLF, encoding gốc).
3. **Backup trong `work\<JiraID>\`** (chỉ 1 lệnh copy, gần 0 token):
   - File Gunner đưa vào `work\` → copy `<tên>_ORIG.<ext>` trước lần sửa đầu (v0).
   - Trước mỗi lần **gen lại / ghi đè** 1 file trong `work\<JiraID>\` → copy bản hiện tại sang `work\<JiraID>\_versions\<tên>_v<N>.<ext>` (N tăng dần), ghi 1 dòng vào `_versions\log.md`: `v<N> — <yyyy-mm-dd> — <đã đổi gì>`. Gunner bảo "quay về vN" → copy ngược lại; "so vN với vM" → diff, chỉ in dòng khác.
   - KHÔNG để file backup/copy trong thư mục source (`.cs`/`.aspx` trong web bị biên dịch → trùng class, hỏng site).
4. Sau khi sửa: diff với bản gốc (`_ORIG` / bản trước) để chắc chỉ đổi đúng chỗ JiraID.
5. Sau khi Gunner test OK: xuất **danh sách thay đổi theo dòng mốc** (`/xuat-thay-doi`) — đường dẫn file, dòng mốc, thao tác (thêm sau / trước / thay), đoạn code sạch. SP/View có sẵn: chỉ đoạn thay đổi, không nguyên ALTER. Object/file MỚI thì gửi nguyên file.
6. Không bao giờ đề xuất copy nguyên file có sẵn đè lên server/TFS.
7. Gunner hỏi "đã sửa những gì" → liệt kê từ chính file local (tìm theo comment JiraID), không dựa trí nhớ. Nhắc Gunner chọn Yes khi VS hỏi reload, không để thay đổi chưa lưu trong VS trên cùng file.

## So với TFS — hỏi trước, so theo mức (rule chuẩn duy nhất)
Nhiều bug là client chưa được deploy fix đã có trên TFS → đầu ticket nên đối chiếu TFS **Live** trước. Nhưng so tốn token → **luôn hỏi, Gunner xác nhận mới so** (code, SP, view, report RDLC). Nhánh: Malaysia Dev `Dev\BRANCHES\NET4.0_REL` / Rel `Rel\IFCA.NET 4.0`; LKHS `..._SG` (cấu trúc thư mục: file tra cứu).
1. **Khi nào hỏi:** (a) đầu ticket — trong `/ticket-moi`, khi đã biết file/SP/view/report nghi ngờ; (b) khi điều tra chạm file/object mới chưa so; (c) trước khi chốt root cause / đề xuất fix mà chưa so. Hỏi 1 câu cuối câu trả lời, không dừng việc khác, vd: *"So `ARReceipt.aspx.cs` + `sp_xxx` với TFS Live (`Rel\IFCA.NET 4.0`)? (A) kiểm nhanh · (B) so đoạn liên quan · (C) toàn file · bỏ qua"*. Mỗi file/object hỏi 1 lần; Gunner bỏ qua thì thôi.
2. **3 mức (rẻ trước):** **A** — so hash/kích thước (`Get-FileHash` / `git diff --no-index --stat`), không đọc nội dung; giống → xong, khác → báo số dòng khác. **B** — chỉ diff hàm/method/khối SP dính bug. **C** — toàn file, chỉ khi Gunner chọn.
3. **SP / view / report:** tìm `.sql` / `.rdlc` trong TFS; bản client lấy bằng `OBJECT_DEFINITION`. Trước khi so nhắc Gunner `SourceCode` local đã get latest chưa.
4. **Đọc kết quả:** TFS có mà client không có → nhiều khả năng fix chưa deploy → đề xuất lấy fix TFS, không viết fix mới. Client có mà TFS không có → sửa riêng chưa commit, cảnh báo dễ bị deploy đè (SWZECON-81/84). Customize `_<CLIENT>` / comment Jira client → giữ.
5. **LKHS (nhánh SG) — so 2 nhánh:** fix ở Malaysia (`Rel\IFCA.NET 4.0`) không tự sang SG (`Rel\IFCA.NET 4.0_SG`). Bug LKHS → đề xuất so cả: client ↔ TFS SG (lệch deploy) **và** SG ↔ Malaysia (lệch nhánh). SG khác Malaysia ở chỗ dính bug → fix Malaysia chưa port → chỉ port đúng đoạn sửa, KHÔNG đè cả file (file SG khác chỗ khác, vd `PM_Company` vs `CF_Company`) (LKHS-337). Sửa file chuẩn ở 1 nhánh → nhắc kiểm file cùng tên ở nhánh còn lại.
6. **Ghi lại để không hỏi lặp:** so xong (hoặc bỏ qua) → 1 dòng vào `docs/tickets/<TICKET>-*.md` nếu có, không thì mục ticket trong `docs/jira-context.md` PHẦN B: `TFS Live: so <file> ngày <yyyy-mm-dd>, mức A/B/C → giống / TFS có fix / client sửa riêng / bỏ qua`. Mở lại ticket thì đọc dòng này trước khi hỏi.

## Quy tắc lưu tài liệu
- Chỉ ghi/cập nhật `docs/ticket-index.md`, `docs/tickets/<TICKET>-<slug>.md`, `docs/ifca-domain-reference.md` **khi ticket có kết quả cuối** (root cause confirm, fix đã áp, hoặc đóng). Không ghi sau mỗi vòng trao đổi.
- **BẮT BUỘC ghi ngay khi root cause đã xác nhận VÀ fix đã test OK trên Train** — không đợi Gunner nhắc hay `/dong-ticket` (Gunner gửi consultant test rồi thường không quay lại báo). Làm luôn trong lượt đó: index (Trạng thái `FIXED Train — chờ consultant`), file chi tiết (bối cảnh, root cause, fix theo dòng mốc, test, bài học), trích kiến thức chung sang domain reference / `docs/memory/learnings.md` (kể cả menu/màn hình/bảng đã xác nhận), note Jira tiếng Anh **2 bản Tech + Non-tech** (mỗi bản 1 đoạn liền Root Cause / Fix / Status). Ticket patch data/đơn giản: chỉ cần dòng index. Sau đó "đóng" chỉ còn đổi trạng thái + changeset; test fail thì Gunner chat lại → làm tiếp từ file ticket (đã đóng thì theo Reopen).
- **Đóng nhanh:** Gunner gõ 1 dòng kiểu "LKHS-336, CMSD-60 xong, Rel 95011" → chỉ cập nhật Trạng thái + ngày (+ changeset) trong `ticket-index.md` (và `jira-context.md` PHẦN B nếu ticket ở đó). Muốn ghi đầy đủ thì `/dong-ticket`.
- **Gunner hay quên báo đóng:** Gunner nhắc 1 ticket mà index ghi "chờ…/đang dở/FIXED Train" → hỏi 1 câu "đã xong/đóng chưa?" trước khi làm tiếp. `/bao-cao-tuan` liệt kê ticket còn mở quá 7 ngày để Gunner đánh dấu.
- **Reopen:** đọc lại file chi tiết cũ (root cause, fix, changeset) trước, không điều tra lại từ đầu, không kết luận ngược cái cũ khi chưa có data. Index: `Reopen <yyyy-mm-dd> — <lý do>`. File chi tiết: thêm mục `## Reopen <yyyy-mm-dd>` ở cuối, **không sửa/xoá nội dung cũ**. Changeset mới nối tiếp. Fix cũ sai → ghi bài học vào `docs/memory/learnings.md` (kiểu SWCHENGLING-67 → 79).
- **Changeset TFS:** Gunner gửi changeset ID → ghi NGAY (ngoại lệ "chỉ ghi khi có kết quả cuối"). 1 Jira thường có changeset ở **2 nhánh Dev (Train) và Rel (Live)**, mỗi nhánh có thể nhiều → nhóm theo nhánh, thêm ID mới vào cuối (không ghi đè). Format để grep:
  - `docs/ticket-index.md`, cột Trạng thái: `CS Dev: 95010, 95022 · Rel: 95011` (LKHS ghi `Dev SG` / `Rel SG`; nhánh chưa commit ghi `Rel: chưa`).
  - `docs/tickets/<TICKET>-*.md`, mục `## Changeset TFS` (bảng): `| Nhánh | Changeset | Ngày | File/object | Ghi chú |` — 1 dòng / changeset, nhánh ghi đường dẫn đầy đủ.
  - Ticket chưa có dòng index → ghi vào mục ticket trong `docs/jira-context.md`. Dùng khi revert (`tf rollback /changeset:<id>`), kiểm server đã có fix chưa, port fix sang nhánh khác.
- Lỗi setup môi trường → `docs/ENV-setup-checklist.md`. Query mới dùng lại được → `tools/queries/` (xem README) khi đóng ticket.

## Đồng bộ Claude Code ↔ claude.ai chat — repo GitHub là nguồn sự thật DUY NHẤT
- Gunner dùng song song: chat (việc thường, máy khác/điện thoại) và Claude Code (task khó, source/DB, report, nhiều file). Lịch sử chat 2 bên KHÔNG sync — chỉ những gì nằm trong repo này mới sync.
- **Feedback / cách làm việc Gunner dạy** → ghi vào `docs/memory/claude-feedback.md` (đọc file này mỗi khi bắt đầu ticket — bắt buộc theo), commit + push. Memory riêng của máy chỉ là bản phụ, không thay cho repo.
- **Code → chat:** mọi docs/rule/ticket ghi vào repo + push; Project "IFCA" trên claude.ai nối GitHub repo, Gunner bấm sync. Project instructions bản chuẩn: `docs/claude-chat-project-instructions.md` (sửa rule ảnh hưởng chat → nhắc Gunner dán lại).
- **Chat → Code:** chat xuất handoff theo `docs/handoff-template.md` → Gunner dán bằng `/nhap-handoff` → ghi docs + push.
- Đổi máy: ticket dở → `/tam-dung` + push trước; máy kia `git pull`. `work\`, `screens\`, source client, DB clone không đi theo git.

## Lệnh tắt (`.claude/commands/`)
`/huong-dan` · `/ticket-moi <Jira>` · `/so-tfs <file> [A|B|C]` · `/tam-dung <Jira>` · `/xuat-thay-doi <Jira>` · `/dong-ticket <Jira>` · `/bao-cao-tuan` · `/nhap-handoff`. Screenshot: lưu vào `screens\` rồi gõ đường dẫn. `work\` và `screens\` không commit git.
