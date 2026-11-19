-- So filter của các report cùng họ (vd Aging by Doc Date vs by Trx Date dùng chung 1 SP mà 1 bản sai).
-- Bài học LKHS-336: SP aging parse As At bằng chuỗi '<Fld><=' trong @QueryCriteria.
--   Ô As At phải FldRange=2 (sinh Fld<='..'); FldRange=0 trên Date sinh Fld='..'; FldRange=3 = khoảng From-To.
--   Ô ngày không dùng làm As At nên Inactive (như EN291 inactivate DocumentDate).
-- Đối chiếu thêm dòng CRITERIA đỏ cuối report = chuỗi @QueryCriteria SP nhận thật.
SELECT r.ReportNo, r.ReportFileName, r.ReadTable,
       f.ReportFilterID, f.FldName, f.FldType, f.FldNeed, f.FldRange, f.IsAsAtDate, f.RecordStatus, f.[Order]
FROM Sys_Report r
INNER JOIN Sys_ReportFilter f ON f.ReportNo = r.ReportNo
WHERE r.ReportFileName LIKE '<ReportFileName prefix>%'   -- vd 'PM_DebtorAgingDetail%'
ORDER BY r.ReportNo, f.FldType, f.FldName;
