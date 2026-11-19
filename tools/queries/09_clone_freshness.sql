-- DB clone trên máy mới tới đâu (so với ngày giao dịch đang điều tra). Chạy trong đúng DB clone.
SELECT MAX(CreateDate) AS LastAR_Trx FROM AR_Trx;
SELECT MAX(CreateDate) AS LastCB_Receipt FROM CB_Receipt;
-- Lần restore gần nhất vào DB này + thời điểm backup gốc:
SELECT TOP 1 rh.destination_database_name, rh.restore_date, bs.backup_finish_date, bs.server_name AS BackupFromServer, bs.database_name AS BackupFromDb
FROM msdb.dbo.restorehistory rh
JOIN msdb.dbo.backupset bs ON bs.backup_set_id = rh.backup_set_id
WHERE rh.destination_database_name = DB_NAME()
ORDER BY rh.restore_date DESC;
