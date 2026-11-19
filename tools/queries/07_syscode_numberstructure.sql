-- SysCode trả "" / "There is no row at position 0" khi sinh số chứng từ: thiếu Number Structure cho DocCode ở company đã resolve.
-- Chi tiết: docs/ifca-autocode-syscode-reference.md
SELECT TOP 50 * FROM View_CF_DocCode WHERE DocCodeNo = '<DocCodeNo>';   -- vd 316_ReceiptGroup, 017
SELECT c.CompanyID, a.Name AS CompanyName                                 -- CF_Company KHÔNG có CompanyName
FROM CF_Company c JOIN CF_Account a ON a.AccountID = c.AccountID
WHERE c.CompanyID = <CompanyID>;
