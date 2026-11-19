-- So config Sys_ giữa 2 DB trên cùng máy (pattern CMSD vs NAIM_PS_Live). LUÔN qualify [DB].dbo. cả 2 bên (thiếu là tự join chính nó).
-- Thay: <DB_A> (đang lỗi), <DB_B> (chuẩn), <LstNo>, <BseNo>, <MnuClass>.
-- 1) Cột grid
SELECT ISNULL(a.LdtLstOrder, b.LdtLstOrder) AS LstOrder, ISNULL(a.LdtFldName, b.LdtFldName) AS FldName,
       a.LdtFldDisplay AS A_Display, b.LdtFldDisplay AS B_Display, a.LdtFldEdit AS A_Edit, b.LdtFldEdit AS B_Edit,
       CASE WHEN a.LdtFldName IS NULL THEN 'thiếu ở A' WHEN b.LdtFldName IS NULL THEN 'thừa ở A' ELSE '' END AS Diff
FROM [<DB_A>].dbo.Sys_ListDt a
FULL JOIN [<DB_B>].dbo.Sys_ListDt b
  ON b.LdtLstNo = a.LdtLstNo AND b.LdtLstOrder = a.LdtLstOrder AND b.LdtFldName = a.LdtFldName
WHERE ISNULL(a.LdtLstNo, b.LdtLstNo) = '<LstNo>'
  AND (a.LdtFldName IS NULL OR b.LdtFldName IS NULL OR ISNULL(a.LdtFldDisplay,'') <> ISNULL(b.LdtFldDisplay,'') OR ISNULL(a.LdtFldEdit,'') <> ISNULL(b.LdtFldEdit,''))
ORDER BY 1, 2;
-- 2) Field của Base
SELECT ISNULL(a.BdtFldName, b.BdtFldName) AS FldName, a.BdtLstDefault AS A_Def, b.BdtLstDefault AS B_Def,
       a.BdtLstDisplay AS A_Disp, b.BdtLstDisplay AS B_Disp, a.BdtLstEdit AS A_Edit, b.BdtLstEdit AS B_Edit,
       CASE WHEN a.BdtFldName IS NULL THEN 'thiếu ở A' WHEN b.BdtFldName IS NULL THEN 'thừa ở A' ELSE 'khác' END AS Diff
FROM [<DB_A>].dbo.Sys_BaseDt a
FULL JOIN [<DB_B>].dbo.Sys_BaseDt b ON b.BdtBseNo = a.BdtBseNo AND b.BdtFldName = a.BdtFldName
WHERE ISNULL(a.BdtBseNo, b.BdtBseNo) = '<BseNo>'
  AND (a.BdtFldName IS NULL OR b.BdtFldName IS NULL OR ISNULL(a.BdtLstDefault,'') <> ISNULL(b.BdtLstDefault,'') OR ISNULL(a.BdtLstDisplay,'') <> ISNULL(b.BdtLstDisplay,''))
ORDER BY 1;
-- 3) Nút toolbar
SELECT ISNULL(a.ContextMnuNo, b.ContextMnuNo) AS ContextMnuNo, ISNULL(a.MnuNo, b.MnuNo) AS MnuNo,
       a.MnuScript AS A_Script, b.MnuScript AS B_Script, a.IsNeedPrivilege AS A_Priv, b.IsNeedPrivilege AS B_Priv,
       CASE WHEN a.ContextMnuNo IS NULL THEN 'thiếu ở A' WHEN b.ContextMnuNo IS NULL THEN 'thừa ở A' ELSE 'khác' END AS Diff
FROM [<DB_A>].dbo.Sys_ContextMenu a
FULL JOIN [<DB_B>].dbo.Sys_ContextMenu b ON b.MnuClass = a.MnuClass AND b.MnuNo = a.MnuNo AND b.ContextMnuNo = a.ContextMnuNo
WHERE ISNULL(a.MnuClass, b.MnuClass) = '<MnuClass>'
  AND (a.ContextMnuNo IS NULL OR b.ContextMnuNo IS NULL OR ISNULL(a.MnuScript,'') <> ISNULL(b.MnuScript,''))
ORDER BY 2, 1;
-- 4) Nút trùng trong 1 DB (pattern CMSD-24)
SELECT MnuClass, MnuNo, ContextMnuNo, COUNT(*) AS Cnt, MIN(ContextMenuID) AS MinID, MAX(ContextMenuID) AS MaxID
FROM [<DB_A>].dbo.Sys_ContextMenu WHERE MnuClass = '<MnuClass>'
GROUP BY MnuClass, MnuNo, ContextMnuNo HAVING COUNT(*) > 1;
