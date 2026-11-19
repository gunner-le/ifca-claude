-- Trigger trên bảng (bài học PREVENT_DUP_INSERT trên AR_Trx: INSTEAD OF INSERT làm LLBLGen mất identity -> "Specified cast is not valid";
-- và danh sách cột cứng làm cột mới bị NULL).
SELECT t.name, t.is_disabled, t.is_instead_of_trigger, OBJECTPROPERTY(t.object_id,'ExecIsInsertTrigger') AS IsInsert,
       OBJECTPROPERTY(t.object_id,'ExecIsUpdateTrigger') AS IsUpdate, o.modify_date
FROM sys.triggers t JOIN sys.objects o ON o.object_id = t.object_id
WHERE t.parent_id = OBJECT_ID('<Table>')
ORDER BY t.name;
-- Xem nội dung:  EXEC sp_helptext '<TriggerName>';
