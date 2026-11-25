BEGIN TRANSACTION

BEGIN TRY


--Sys_ReportDefine
IF(EXISTS(SELECT TOP 1 * FROM Sys_ReportDefine (NOLOCK) WHERE ReportNo = '401_TIMATCH'))
BEGIN
 DELETE FROM Sys_ReportDefine WHERE ReportNo = '401_TIMATCH'
END

--Sys_ReportFilter
IF(EXISTS(SELECT TOP 1 * FROM Sys_ReportFilter (NOLOCK) WHERE ReportNo = '401_TIMATCH'))
BEGIN
 DELETE FROM Sys_ReportFilter WHERE ReportNo = '401_TIMATCH'
END

--Sys_Report
IF(EXISTS(SELECT TOP 1 * FROM Sys_Report (NOLOCK) WHERE ReportNo = '401_TIMATCH'))
BEGIN
 DELETE FROM Sys_Report WHERE ReportNo = '401_TIMATCH'
END


--Sys_Report
INSERT INTO Sys_Report([ReportNo],[ApplicationCode],[ReportNameStringCode],[Language],[CategoryStringCode],[ReportFileName],[ReadTable],[Order],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate])
VALUES(N'401_TIMATCH',N'Rental',N'Rpt_Mcorp_DebtorLedgerReport_TIMATCH',N'EN',N'Rpt_Rental_AccountReceivables',N'MC_DebtorInforTotalTwo_TIMATCH',N'View_Report_DebtorLedgerReport_TIMATCH',NULL,N'Y',N'Active','1',GETDATE(),'1',GETDATE());

--Sys_ReportDefine
INSERT INTO Sys_ReportDefine([ReportTemplateID],[ApplicationCode],[CategoryStringCode],[ReportNo],[ConditionDesc],[ConditionValue],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsSystem])
VALUES(61,N'Rental',N'Rpt_Rental_AccountReceivables',N'401_TIMATCH',NULL,NULL,205,N'Active','1',GETDATE(),'1',GETDATE(),N'Y');

INSERT INTO Sys_ReportDefine([ReportTemplateID],[ApplicationCode],[CategoryStringCode],[ReportNo],[ConditionDesc],[ConditionValue],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsSystem])
VALUES(79,N'Rental',N'Rpt_Rental_AccountReceivables',N'401_TIMATCH',NULL,NULL,71,N'Active','1',GETDATE(),'1',GETDATE(),N'Y');

INSERT INTO Sys_ReportDefine([ReportTemplateID],[ApplicationCode],[CategoryStringCode],[ReportNo],[ConditionDesc],[ConditionValue],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsSystem])
VALUES(80,N'Rental',N'Rpt_Rental_AccountReceivables',N'401_TIMATCH',NULL,NULL,137,N'Active','1',GETDATE(),'1',GETDATE(),N'Y');

--Sys_ReportFilter

INSERT INTO Sys_ReportFilter([ReportNo],[NameStringCode],[FldName],[FldType],[FldNeed],[FldRange],[IsSeparate],[ReportParam],[IsAsAtDate],[RelationFld],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[RefDataSource],[RefFields],[IsUnicode])
VALUES(N'401_TIMATCH',N'Sys.ReportFilter_401_TIMATCH_PropertyName',N'PropertyName',N'L',N'N',0,N'N',NULL,N'N',N'PropertyName',NULL,N'Active','1',GETDATE(),'1',GETDATE(),NULL,NULL,NULL);

INSERT INTO Sys_ReportFilter([ReportNo],[NameStringCode],[FldName],[FldType],[FldNeed],[FldRange],[IsSeparate],[ReportParam],[IsAsAtDate],[RelationFld],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[RefDataSource],[RefFields],[IsUnicode])
VALUES(N'401_TIMATCH',N'Sys.ReportFilter_401_TIMATCH_Name',N'DebtorName',N'S',N'N',0,N'N',NULL,N'N',NULL,NULL,N'Active','1',GETDATE(),'1',GETDATE(),NULL,NULL,NULL);

INSERT INTO Sys_ReportFilter([ReportNo],[NameStringCode],[FldName],[FldType],[FldNeed],[FldRange],[IsSeparate],[ReportParam],[IsAsAtDate],[RelationFld],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[RefDataSource],[RefFields],[IsUnicode])
VALUES(N'401_TIMATCH',N'Sys.ReportFilter_401_TIMATCH_DebtorAcct',N'DebtorAcct',N'L',N'N',0,N'N',NULL,N'N',N'DebtorAcct',NULL,N'Active','1',GETDATE(),'1',GETDATE(),NULL,NULL,NULL);

INSERT INTO Sys_ReportFilter([ReportNo],[NameStringCode],[FldName],[FldType],[FldNeed],[FldRange],[IsSeparate],[ReportParam],[IsAsAtDate],[RelationFld],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[RefDataSource],[RefFields],[IsUnicode])
VALUES(N'401_TIMATCH',N'Sys.ReportFilter_401_TIMATCH_TransactionDate',N'TransactionDate',N'D',N'N',3,N'N',NULL,N'N',NULL,NULL,N'Active','1',GETDATE(),'1',GETDATE(),NULL,NULL,NULL);

INSERT INTO Sys_ReportFilter([ReportNo],[NameStringCode],[FldName],[FldType],[FldNeed],[FldRange],[IsSeparate],[ReportParam],[IsAsAtDate],[RelationFld],[Order],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[RefDataSource],[RefFields],[IsUnicode])
VALUES(N'401_TIMATCH',N'Sys.ReportFilter_401_TIMATCH_DocumentDate',N'DocumentDate',N'D',N'N',3,N'Y',N'StartDate,EndDate',N'Y',NULL,NULL,N'Active','1',GETDATE(),'1',GETDATE(),NULL,NULL,NULL);



--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Rpt_Mcorp_DebtorLedgerReport_TIMATCH'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Rpt_Mcorp_DebtorLedgerReport_TIMATCH'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Rpt_Mcorp_DebtorLedgerReport_TIMATCH',N'客户帐务分析',N'Debtor Ledger Report - TIMATCH',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),NULL,N'N',GETDATE());

--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_DebtorAcct'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_DebtorAcct'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Sys.ReportFilter_401_TIMATCH_DebtorAcct',N'Debtor A/c',N'Debtor A/c',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),N'N',N'N',GETDATE());

--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_DocumentDate'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_DocumentDate'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Sys.ReportFilter_401_TIMATCH_DocumentDate',N'By Document Date',N'By Document Date',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),N'N',N'N',GETDATE());

--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_Name'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_Name'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Sys.ReportFilter_401_TIMATCH_Name',N'Debtor',N'Debtor',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),N'N',N'N',GETDATE());

--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_PropertyName'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_PropertyName'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Sys.ReportFilter_401_TIMATCH_PropertyName',N'Project',N'Project',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),N'N',N'N',GETDATE());

--CF_String
IF(EXISTS(SELECT TOP 1 * FROM CF_String (NOLOCK) WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_TransactionDate'))
BEGIN
DELETE FROM CF_String WHERE StringCode = 'Sys.ReportFilter_401_TIMATCH_TransactionDate'
END
INSERT INTO CF_String([StringType],[RefTable],[StringCode],[StringCN],[StringEN],[StringSP],[StringJP],[StringKR],[StringTH],[StringMY],[StringFR],[StringGM],[StringENGB],[StringCNT],[IsSystem],[RecordStatus],[CreateUserID],[CreateDate],[ModifyUserID],[ModifyDate],[IsTranslated2EN],[Dummy],[DummyDate])
VALUES(N'Common',NULL,N'Sys.ReportFilter_401_TIMATCH_TransactionDate',N'Transaction Date',N'Transaction Date',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'N',N'Active','1',GETDATE(),'1',GETDATE(),N'N',N'N',GETDATE());

COMMIT TRANSACTION
PRINT 'SUCCESS: MC_DASBP_FPARK inserted successfully'

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION
    PRINT 'ERROR: ' + ERROR_MESSAGE()
END CATCH