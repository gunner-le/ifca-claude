-- Từ màn hình (TabNo trên URL / LstNo của grid) ra bảng đọc/ghi thật. Bài học GRSUMMIT-204: bảng đọc (view) có thể ĐẢO DẤU/ABS so với bảng ghi.
-- Form edit:
SELECT t.TabNo, b.BseNo, b.BseReadTable, b.BseWriteTable
FROM Sys_Tab t JOIN Sys_Base b ON b.BseNo = t.TabBseNo
WHERE t.TabNo = '<TabNo>';
-- Grid list:
SELECT l.LstNo, l.LstOrder, l.LstBseNo, b.BseReadTable, b.BseWriteTable, l.LstSort, l.LstFilter
FROM Sys_List l JOIN Sys_Base b ON b.BseNo = l.LstBseNo
WHERE l.LstNo = '<LstNo>';
-- Sau đó lấy định nghĩa view đọc:  EXEC sp_helptext '<BseReadTable>';
