USE [Admin]
GO

/****** Object:  StoredProcedure [dbo].[DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]    Script Date: 11/23/2023 8:07:25 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--EXEC DBAUtil.dbo.DBA_SQLErrorLog_Alert
CREATE PROC [dbo].[DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]
AS

SET NOCOUNT ON


Declare @emailTo VARCHAR(100) = 'henokteka89@gmail.com', @EmailandPagerTo  VARCHAR(100) = 'kabdahlak123@gmail.com'
--Declare @emailTo VARCHAR(100) = 'henokteka89@gmail.com', @EmailandPagerTo  VARCHAR(100) = 'henokteka89@gmail.com'
Declare @start smalldatetime, @end smalldatetime
SET	@end	= getdate()
SET	@start	= dateadd(mi,(-1) * 5, @end)

IF OBJECT_ID('tempdb..#SQLErrorLog') IS NOT NULL DROP TABLE #SQLErrorLog;

-- Command will create the temporary table in tempdb to store the current error log
CREATE TABLE [dbo].[#SQLErrorLog]
([LogDate] DATETIME NULL, [ProcessInfo] VARCHAR(20) NULL, [Text] VARCHAR(MAX) NULL ) ;

-- Command will insert the errorlog data into temporary table
INSERT INTO #SQLErrorLog ([LogDate], [ProcessInfo], [Text])
EXEC xp_readerrorlog 0, 1, N'I/O requests taking longer than 15 seconds to complete',null, @start, @end 
--EXEC xp_readerrorlog 6, 1, N'I/O requests taking longer than 15 seconds to complete',null, null, null 
--SELECT * FROM #SQLErrorLog
DECLARE @EnvType char(2) = 'NP'
IF SUBSTRING(CONVERT(varchar(100),SERVERPROPERTY('machinename')),10,2) IN ('PD', 'TR','AU','UT','LT','FT','EU') 
--Select SUBSTRING(CONVERT(varchar(100),SERVERPROPERTY('machinename')),10,2) 
SET @EnvType = 'PD'

Declare @Pagesubject nvarchar(1000)
Declare @Emailsubject nvarchar(1000)
Declare @tableHTMLEmail nvarchar(max)  = ''
Declare @env_code  CHAR(3)
IF @@SERVERNAME LIKE 'ES%'
BEGIN
SET @env_code= SUBSTRING(CONVERT(varchar(100),SERVERPROPERTY('machinename')),10,3)
END
ELSE 
BEGIN 
SET @env_code='PD1'
END 
Set @Pagesubject =   'SQLQC Alert (Critical) '+@env_code+' - I/O requests taking longer than 15 seconds to complete' + ' '  + @@servername
Set @Emailsubject =  'SQLQC Alert (Warning) '+@env_code+' - I/O requests taking longer than 15 seconds to complete' + ' '  + @@servername

Set @tableHTMLEmail = N'<table border="1">' +
		N'<FONT SIZE="2" FACE="Calibri">' +            
		N'<tr><th align="center">LogDate</th>' +
		N'<th align="center">ProcessInfo</th>' +
		N'<th align="center">ErrorMessage</th>' +
		N'</tr>' +
				ISNULL(CAST ( ( 
							select td = '',
							FORMAT(LogDate, N'yyyy-MM-dd HH:mm:ss'),'',
							td = ProcessInfo,'',
							td = [Text],''
								From #SQLErrorLog
						 
						FOR XML PATH('tr'), TYPE 
				) AS NVARCHAR(MAX) ),'') +
		N'</FONT>' +
		N'</table>' 


IF EXISTS (Select 1 from #SQLErrorLog )  and @EnvType = 'PD'
BEGIN
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'EmailProfile',
                                @body = @tableHTMLEmail,
								@body_format = 'HTML',
                                @recipients   = @EmailandPagerTo,
                                @subject      = @Pagesubject ;

	--EXEC xp_logevent 50001, @Pagesubject, 'Error'; 
END

IF EXISTS (Select 1 from #SQLErrorLog ) and @EnvType = 'PD'
BEGIN
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'EmailProfile',
                                @body = @tableHTMLEmail,
								@body_format = 'HTML',
                                @recipients   = @emailTo,
                                @subject      = @Emailsubject ;

--EXEC xp_logevent 50001, @Pagesubject, 'Warning'; 
END
GO


---Job
USE [msdb]
GO

/****** Object:  Job [DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]    Script Date: 11/23/2023 8:10:46 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 11/23/2023 8:10:46 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]    Script Date: 11/23/2023 8:10:46 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dbo].[DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]', 
		@database_name=N'DBAUtil', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DBA_SQLErrorLog_IO_requeststakinglongerthan15seconds]', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210609, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'6e80884f-c5c7-4280-a187-aad227dbf793'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


