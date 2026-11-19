-- View/SP/function/trigger nào dùng 1 cột/từ khoá (vd IsConsolSelfBilled, TaxExemptRate). Chạy trên từng DB cần so (Train vs Live clone).
SELECT TOP 100 o.type_desc, o.name, o.modify_date
FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
WHERE m.definition LIKE '%<Keyword>%'
ORDER BY o.type_desc, o.name;
-- Cột thật của bảng/view:
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '<Table>' ORDER BY ORDINAL_POSITION;
