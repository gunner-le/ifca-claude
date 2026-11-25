# CMSD-71 — Rental AR Billing Submit: "Not exists worlflow" dù đã setup workflow

- **Client:** CMSD (clone NAIM_PS, code giữ tên `_NAIMCAP`)
- **Màn hình:** Rental Management > A/c Receivable > AR Transaction > Billing > Submit — `McAccount/ARChargeBillList_NAIMCAP.aspx(.cs)`, WebMethod `Submit`
- **Môi trường gặp:** Train (server mới 10.10.10.41), company RCM (RIVERVALE, CompanyID 6)
- **Trạng thái:** FIXED (debug local với DB Train: Submit OK 2026-11-24, CHƯA test Approve) — chờ test Approve + áp server Train + consultant test. Không commit TFS (TFS Rel/Dev CMSD đã có fix).

## Triệu chứng
Workflow Management > Rental Management > AR Billing Approval đã setup template cho RCM (bước Billing Approval). Submit bill → alert `Error: Not exists worlflow, please try re-check.` (chính tả gốc trong code: "worlflow").

## Root cause (đã xác nhận code + data)
1. **Hàm `Submit` hardcode entity PS** `IFCA.PS.WF.WF_SaleArBillingService` (OA_WorkflowEntity 270, ApplicationCode Sale) thay vì Rental `IFCA.MC.WF.WF_McArBillingService` (271). Template RCM trên 270 = TempID 77882, 0 flow → `isexists = 0` → lỗi. Template consultant setup ở cây Rental = 77887 (entity 271, 1 flow) không được đọc.
2. Đổi entity xong → `Create workflow instance failed` (ArgumentException trong `IFCA.Framework.WorkflowEngine.WorkflowEngine.StartWorkflow`): `WorkflowHelper.MakeWorkflow(EntiInterface)` = `Activator.CreateInstance(type)` trong try/catch trả null → **client thiếu class `IFCA.MC.WF.WF_McArBillingService`** (không có trong App_Code lẫn Bin). Runtime vẫn được tạo trước đó (RuntID 10, TempID 77912 = bản copy template, RunState `Equipped`, SubmitUserID NULL, không có FlowLog).
3. **Lệch deploy:** TFS `Rel\IFCA.NET 4.0\Customization\CMSD` (và NAIMCAP, Dev CMSD) đã có cả 2 phần (ngày 2026-04-02); CMSD server chưa được deploy.

## Fix (lấy từ TFS, không viết mới)
| File | Thao tác |
|---|---|
| `McAccount/ARChargeBillList_NAIMCAP.aspx.cs` (~dòng 153 và ~172, hàm `Submit`) | `GetOAWorkflowEntity(...)` và `OA_WF_WorkflowPublic.SubmitWorkflow(...)`: đổi chuỗi `"IFCA.PS.WF.WF_SaleArBillingService"` → `"IFCA.MC.WF.WF_McArBillingService"` (cả file chỉ khác TFS đúng 2 dòng này) |
| `App_Code/MCCode/clsWF_McArBillingService.cs` | **File MỚI** — copy nguyên từ TFS `...\Customization\CMSD\3.0 Customization\PropertyNet\App_Code\MCCode\` (154 dòng; class `WF_McArBillingService` + `WF_McArBillingServiceEntity`; chỉ phụ thuộc view `View_ps_BillNotPay`) |

Không cần consultant setup lại workflow (template 77887 cây Rental đúng).

## Test
- Local (VS, DB Train): Submit bill khác 111 → Success (2026-11-24). **Approve chưa test.**
- Local debug cần bật endpoint HTTP của `WorkFlowWCFForSL/WorkFlowService.svc` (binding `WorkFlowServicesBinding` + basicHttp/mex) — chỉ local, không đưa lên server.
- Còn: áp lên server Train, consultant test Submit + Approve.

## Còn mở / lưu ý
- Runtime treo RuntID 10 (bill 111, Equipped) trên DB local Train — kiểm tra nếu Submit lại bill 111 lỗi.
- `McAccount/ARBillADD_NAIMCAP.aspx.cs` (trang duyệt của entity 271) khác TFS 50 dòng; `ARChargeBillList_NAIMCAP.aspx` khác 943 dòng — chưa so nội dung (Approve chưa test — rủi ro nằm ở đây).
- Client thiếu ~25 file so với TFS Rel CMSD (`ArCharge_NAIMCAP.cs`, `RentalCommon_NAIMCAP.cs`, `ArBillEnterSubmit_NAIMCAP`, `ArMassBillingPost_NAIMCAP`, `ArRefundAdd/Receive_NAIMCAP`, các page `_CMSD`…) → deploy CMSD chưa đủ, nên báo Stanley.
- TAIBAH (company 5) có 12 template trùng trên entity 270 (77879, 77885…77898) — dọn khi có Jira.

## TFS
TFS Live: so `McAccount/ARChargeBillList_NAIMCAP.aspx.cs` ngày 2026-11-24, mức B (hàm Submit) → TFS có fix. File class mới có sẵn ở TFS. Không có changeset mới (không commit).

## Bài học
- Màn Rental (McAccount) customize NAIM dùng entity workflow riêng `WF_McArBillingService` (271); entity 270 là PS. "Not exists worlflow" = template của entity mà code tra không có flow, không phải chưa setup.
- `Create workflow instance failed` = engine không tạo được class workflow (`MakeWorkflow` nuốt exception) → kiểm class `EntiInterface` có trong App_Code/Bin.
- Grep câu lỗi: đọc đúng chính tả ("worlflow"), Git Bash `grep -r` trên thư mục site có thể crash (exit 134/2) → dùng PowerShell / Grep tool.

## Note Jira
**Tech:** Root Cause: The Rental AR Billing list (`McAccount/ARChargeBillList_NAIMCAP.aspx.cs`, `Submit`) on the CMSD server used the Property Sales workflow entity `IFCA.PS.WF.WF_SaleArBillingService`, so it looked for the RIVERVALE template under Property Sales (empty, no steps) instead of the one set up under Rental Management; the Rental workflow class `IFCA.MC.WF.WF_McArBillingService` (`App_Code/MCCode/clsWF_McArBillingService.cs`) was also missing on the server. Both are already in TFS (`Rel\IFCA.NET 4.0\Customization\CMSD`) but were not deployed. Fix: changed the entity in `ARChargeBillList_NAIMCAP.aspx.cs` (2 lines, same as TFS) and added the new file `App_Code/MCCode/clsWF_McArBillingService.cs` from TFS; no new TFS changeset. Status: Submit tested OK on local with Train data; Approve still to be tested; pending deploy to Train server and consultant testing.

**Non-tech:** Root Cause: The Billing screen under Rental Management was checking the Property Sales workflow instead of the Rental Management workflow, and one program file for the Rental workflow was missing on the server. Fix: updated the screen and added the missing file from the standard source; the existing workflow setup does not need to change. Status: Submit tested OK, Approve still being tested; please re-test Submit and Approve on Train after deployment.
