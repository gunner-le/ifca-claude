-- Trace lịch sử thay đổi 1 bản ghi theo khoá chính (audit trigger IFCA)
-- Thay: <Table>, <KeyCol>, <KeyValue>. LIKE neo cuối '%=value' để không dính số khác (vd 712 vs 7120).
SELECT TOP 200 alt.AUDIT_LOG_TRANSACTION_ID, alt.AUDIT_ACTION_ID /*1=U 2=I 3=D*/, alt.APP_NAME, alt.HOST_NAME,
       alt.MODIFIED_BY, alt.MODIFIED_DATE, ald.PRIMARY_KEY_DATA, ald.COL_NAME,
       ald.OLD_VALUE_LONG, ald.NEW_VALUE_LONG
FROM [IFCANetAudit_R2_8].dbo.AUDIT_LOG_TRANSACTIONS alt
JOIN [IFCANetAudit_R2_8].dbo.AUDIT_LOG_DATA ald ON ald.AUDIT_LOG_TRANSACTION_ID = alt.AUDIT_LOG_TRANSACTION_ID
WHERE alt.TABLE_NAME = '<Table>'
  AND ald.PRIMARY_KEY_DATA LIKE '%[[]<KeyCol>]=<KeyValue>'
ORDER BY alt.MODIFIED_DATE, alt.AUDIT_LOG_TRANSACTION_ID;
-- Ghi chú: OLD/NEW_VALUE_LONG là ntext -> dùng LIKE, không dùng =. UPDATE chỉ log cột có trong SET.
-- APP_NAME = 'IFCA Software' là thao tác qua app; khác (SSMS...) là sửa tay.
