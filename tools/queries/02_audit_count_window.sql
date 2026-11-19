-- Đếm số lần đổi theo bảng/khoá/cột trong khung giờ hẹp (lộ pattern nhân đôi, batch...)
-- Thay: <Table1>, <Table2>, <start>, <end>, <Col1>, <Col2>. KHÔNG lọc theo dải AUDIT_LOG_TRANSACTION_ID.
SELECT alt.TABLE_NAME, ald.PRIMARY_KEY_DATA, ald.COL_NAME, COUNT(*) AS ChangeCount,
       MIN(alt.MODIFIED_DATE) AS FirstChange, MAX(alt.MODIFIED_DATE) AS LastChange,
       MIN(alt.APP_NAME) AS AppName, MIN(alt.MODIFIED_BY) AS ModifiedBy
FROM [IFCANetAudit_R2_8].dbo.AUDIT_LOG_TRANSACTIONS alt
JOIN [IFCANetAudit_R2_8].dbo.AUDIT_LOG_DATA ald ON ald.AUDIT_LOG_TRANSACTION_ID = alt.AUDIT_LOG_TRANSACTION_ID
WHERE alt.TABLE_NAME IN ('<Table1>', '<Table2>')
  AND alt.MODIFIED_DATE BETWEEN '<start>' AND '<end>'
  AND ald.COL_NAME IN ('<Col1>', '<Col2>')
GROUP BY alt.TABLE_NAME, ald.PRIMARY_KEY_DATA, ald.COL_NAME
ORDER BY alt.TABLE_NAME, ald.PRIMARY_KEY_DATA;
