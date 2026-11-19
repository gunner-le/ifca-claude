# WorkFlow WCF Service (`WorkFlowWCFForSL/WorkFlowService.svc`) — lỗi yellow screen & cách xử lý

Áp dụng mọi client. Triệu chứng chung: mở **Account Payable > Customized Setup > Workflow Management** (hoặc màn hình khác dùng workflow) ra yellow screen ngay lúc load.
Stack trace: `WFEntityManage.OnLoad` → `CWorkflowTemplate.GetWorkflowRunState` → `WorkflowTemplateBLL.GetWorkflowRunState` → `svcWorkflow.WorkFlowServiceClient.GetWorkflowRunState`.
App gọi service bằng **POST (SOAP)**. Mở `.svc` bằng trình duyệt là **GET** (trang help/metadata) → ra "You have created a service" KHÔNG chứng minh endpoint SOAP nhận được POST.

## Phân biệt theo mã lỗi

| Lỗi | Nguyên nhân | Fix | Đã gặp |
|---|---|---|---|
| **404** `EndpointNotFoundException: There was no endpoint listening at http://...` | `web.config` site chỉ còn endpoint **HTTPS** (`WorkFlowServicesBindingHttps`, `security mode="Transport"`, `mexHttpsBinding`); binding `WorkFlowServicesBinding` + endpoint HTTP bị comment. Client build address theo scheme của request → user vào bằng http → gọi http → không có endpoint. Vào bằng https thì chạy. Kiểm tra: `.svc?wsdl` → `<soap:address location="https://...">` chỉ có https. | Bỏ comment binding `WorkFlowServicesBinding` VÀ 2 endpoint http (`basicHttpBinding` + `mexHttpBinding`), giữ nguyên cặp https (khác scheme nên không trùng `address=""`). Phải sửa cả 2 chỗ, thiếu binding là site lỗi khi khởi động. Sửa xong **recycle App Pool bằng tay** cho chắc (có lần sửa xong chưa ăn, recycle mới chạy). Lưu ý: nếu site KHÔNG có binding https trên IIS thì không được để endpoint https (service chết toàn bộ — lỗi "Could not find a base address that matches scheme https"). | SWIBRACO-697 (Ibraco_Live, 2026-09-25); PLB_UAT_V54 (2026-10-20) |
| **405** `ProtocolException: The remote server returned an unexpected response: (405) Method Not Allowed` | **Server mới chưa cài WCF HTTP Activation** → IIS không có handler `.svc` (`svc-Integrated-4.0`), `.svc` bị xử lý như file tĩnh → POST bị 405. Sửa `web.config` không có tác dụng. | PowerShell (Admin): `Get-WindowsFeature *WCF*` → `Install-WindowsFeature NET-WCF-HTTP-Activation45` (hoặc Server Manager > Features > .NET Framework 4.x Features > WCF Services > HTTP Activation), rồi `iisreset`/recycle. Kiểm tra IIS > Handler Mappings có `svc-Integrated-4.0`. | PMT_TRAIN (einvoice.tambunindah.com, Palmington, 2026-11-16) — confirm chạy được sau khi cài feature |

Khả năng khác cho 405 (chưa gặp thực tế): site ép redirect http→https (URL Rewrite/proxy), POST bị redirect thành GET → WCF trả 405. Kiểm tra IIS log thấy `POST ... 301/302` rồi `GET ... 405`.

## Checklist khi deploy client lên server mới
1. Cài **WCF HTTP Activation** (.NET 4.x) trước.
2. Đối chiếu `<service name="WorkFlowService.WorkFlowService">` trong `web.config` với binding thật của site trên IIS (có https hay không).
3. Test bằng màn hình Workflow Management (không chỉ mở `.svc` bằng browser).
