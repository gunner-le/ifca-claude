-- Report in sai/không ra: kiểm Sys_Report trỏ đúng RDLC trước khi soi SP (không có cột ReportName).
SELECT ReportNo, ApplicationCode, ReportNameStringCode, ReportFileName, ReadTable
FROM Sys_Report
WHERE ReportFileName LIKE '%<Keyword>%' OR ReportNameStringCode LIKE '%<Keyword>%' OR ReportNo LIKE '%<Keyword>%';
SELECT * FROM Sys_ReportFilter WHERE ReportNo = '<ReportNo>';
