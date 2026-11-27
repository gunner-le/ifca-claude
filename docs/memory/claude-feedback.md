# Feedback / cách làm việc Gunner đã dạy (dùng chung Claude Code + claude.ai chat)

> Nguồn sự thật DUY NHẤT cho feedback của Gunner. Học được điều mới (Gunner sửa cách làm, hoặc xác nhận 1 cách làm đúng) → thêm mục vào đây (kèm ngày + ticket), commit + push. Không chỉ ghi vào memory riêng của máy.
> Format mỗi mục: **Rule** · *Vì sao* (ticket/ngày) · *Áp dụng*.

## 1. "Đóng ticket / close jira" = cập nhật docs
- **Rule:** Gunner nói "close jira" / "đóng ticket" = chạy luồng `/dong-ticket` (ticket-index, file ticket, jira-context, domain ref / learnings, note Jira Tech + Non-tech), đánh dấu đóng. KHÔNG nói "bạn tự đóng trên Jira", không bàn quyền truy cập Jira.
- *Vì sao:* LKHS-336 (2026-11-20) Gunner giải thích chỉ muốn ghi lại thông tin theo rule.

## 2. Backup `_ORIG` + version trong `work\`
- **Rule:** sửa file Gunner đưa vào `work\<JiraID>\` → copy `<tên>_ORIG.<ext>` trước (v0). Mỗi lần gen lại / ghi đè → copy bản hiện tại sang `work\<JiraID>\_versions\<tên>_v<N>.<ext>` + 1 dòng `_versions\log.md`. KHÔNG để backup trong thư mục source web (bị biên dịch → trùng class, hỏng site).
- *Vì sao:* PLBPG-62 (2026-11-20) Claude ghi đè RDL tải từ Report Server, `work\` không có git nên không quay lại được. 2026-11-23 Gunner chốt giữ `_ORIG` (copy ~0 token) + thêm version.
- *Áp dụng:* rule chi tiết ở CLAUDE.md mục "Sửa / tạo file".

## 3. Chỉ sửa đúng chỗ, không làm hỏng phần khác
- **Rule:** mọi chỉnh sửa (RDL, SP, aspx, script config) chỉ đổi đúng chỗ ticket cần — không reformat, không đổi thứ tự, không đụng textbox/dataset/biểu thức khác, giữ encoding + line ending. Sửa xong diff với `_ORIG`, cho Gunner thấy diff chỉ gồm phần JiraID.
- *Vì sao:* PLBPG-62 (2026-11-20): "sửa gì file report hay bất kỳ cái gì thì k dc làm hỏng hoặc thay đổi các phần khác"; biểu thức RDL nhiều dòng lỗi compile khi upload (BC30277).
- *Áp dụng:* validate (XML parse / cú pháp) trước khi giao; biểu thức RDL theo style sẵn có (giữ trên 1 dòng).

## 4. Mỗi ticket 1 phiên (desktop app)
- **Rule:** Gunner dùng Claude desktop (tab Code), mỗi ticket 1 session riêng (sidebar đặt tên theo Jira). Đổi ticket = bấm **New** (phiên mới) — KHÔNG bảo `/clear`. Chỉ gợi ý `/compact` khi 1 phiên ticket quá dài. Phiên cũ còn trong sidebar để mở lại đúng ticket.
- *Vì sao:* 2026-11-24 Gunner bối rối khi được bảo `/clear` (đã mở phiên mới mỗi ticket rồi).

## 5. Note Jira phải có changeset hoặc danh sách file
- **Rule:** mọi note fix (Tech VÀ Non-tech) phải truy vết được: có commit TFS → liệt kê changeset theo nhánh (Dev / Rel). KHÔNG commit (fix đã có trên TFS chỉ port sang server client, hoặc sửa riêng server) → ghi rõ "no new TFS commit", fix lấy từ đâu (nhánh + path TFS), file server đã sửa (full path, hàm/vị trí, dòng thêm, marker JiraID), và vì sao không copy cả file TFS nếu liên quan. File ticket có bảng `## Changeset TFS`, ghi dòng "không commit" khi không commit.
- *Vì sao:* đã nhắc trước đó, phải nhắc lại ở SWHARTANAH-358 (2026-11-24) — note "applied the fix" không có changeset/file thì consultant / deploy / revert sau không lần được.
- *Áp dụng:* khi soạn note (`/dong-ticket` hoặc bản "FIXED Train"): kiểm có changeset / file chưa; chưa biết changeset thì hỏi Gunner trước khi chốt.

## 6. Report SSRS: dataset view hay SP — tự quyết, không hỏi
- **Rule:** RDL IFCA: dataset query view (vd `CB_DocumentStatusReport`: `exec('select ... from View_X a where a.CompanyID='+@CompanyID+' and '+@QueryCriteria)`) hoặc EXEC SP (`@CompanyID int, @QueryCriteria varchar(4000)`, vd LKHS-274). Data đơn giản → view; phức tạp/cần logic → SP. Tự chọn, nói lựa chọn 1 dòng, làm tiếp.
- Report MỚI (Sys_Report / Sys_ReportDefine / Sys_ReportFilter / CF_String UpdateScript): dùng template `tools/templates/UpdateScript_report_config_sample_TIMATCH.sql` + mục "Khai báo report MỚI" trong `docs/ifca-domain-reference.md`; chỉ hỏi cái thật sự thay đổi (node/menu nào).
- RDL mới dựa trên report mẫu cùng node Report Navigator (shared DS `PropertyNetMaster`, params CompanyID/Language/AsAtDate/DateFormatString/CompanyName/QueryCriteria, dataset Header từ `view_cf_company` + `getstring2(ReportFileName)`).
- *Vì sao:* LKHS-271 GIRO report (2026-11-25) Gunner khó chịu vì bị hỏi "view hay SP?" và hỏi lại cách khai báo report đã giải thích nhiều lần.

## 7. Tìm chuỗi lỗi trong source: kiểm kỹ trước khi kết luận "không có"
- **Rule:** zoom screenshot đọc đúng chính tả (message IFCA hay sai chính tả, vd "worlflow"); grep đoạn ngắn đặc trưng + biến thể (`wor.?l?flow`, `-i -F`, không chỉ `-P`); kiểm exit code (2 = lỗi, kết quả không tin được — `grep -P` có thể dừng ở file binary/UTF-8 lỗi). Grep `.cs/.aspx/.js` trước bằng `-F`, DLL riêng. Không kết luận "không có trong source local / lệch deploy" chỉ từ 1 lần grep trượt.
- *Vì sao:* CMSD-71 (2026-11-24) đọc nhầm "worlflow" thành "worflow", `grep -P` exit 2 → kết luận sai, bắt Gunner query + restore DB thừa; chuỗi nằm sẵn trong `ARChargeBillList_NAIMCAP.aspx.cs`.

## 8. Tin nhắn soạn cho Gunner gửi: dùng "I", không "we"
- **Rule:** tin nhắn / note tiếng Anh gửi Stanley, consultant, Jira nói với tư cách Gunner, ngôi thứ nhất số ít: "I", "I can adjust", không "we" / "our". Mô tả hệ thống trung tính ("the system ...") vẫn OK.
- *Vì sao:* LKHS-271 trả lời Stanley (2026-11-25) dùng "We check... We can adjust" → Gunner sửa.

## 9. Lỗi trên màn hình do mình viết: so DB với script config trong package TRƯỚC khi đoán
- **Rule:** màn hình/config Claude đã giao (có script `Sys_`/CF_String trong package) mà lỗi sau khi consultant chỉnh → (1) Grep docs theo đúng phần bị lỗi (ô search = `Sys_Filter`, cột lưới = `Sys_ListDt`, field = `Sys_BaseDt`), (2) 1 query lấy config bảng đó trên DB đem so với script config gốc → ra ngay dòng bị đổi. Không dò lần lượt từng bảng, không bắt Gunner chạy nhiều query.
- *Vì sao:* LKHS-271 GIRO Batch Listing (2026-11-27) lỗi `Invalid column name 'RecordStatusStringCode'` khi consultant đổi ô search Status sang dropdown. Claude Code dò `Sys_BaseDt` → `Sys_ListDt` → INFORMATION_SCHEMA → trace (4 lượt), trong khi docs đã ghi `Sys_Filter` = search; Claude chat so với `10_Config_CB_GIROBatchList.sql` thấy ngay `Sys_Filter` khác 2 dòng (Currency `FltType` S→L2, RecordStatus `FltDisMode` 0→1).
- *Áp dụng:* ô search dropdown (`FltType` L2/L3 hoặc `FltDisMode`=1) → framework đọc cột `<FltName>StringCode` từ BseReadTable; view không có cột đó → lỗi khi mở trang.
