USE [msdb]
GO

/****** Object:  Job [SQLPSX]    Script Date: 07/10/2010 17:18:28 ******/
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLPSX')
EXEC msdb.dbo.sp_delete_job @job_id=N'3f2c4f7d-20a2-4e63-a6cb-206d4b019abc', @delete_unused_schedule=1
GO

USE [msdb]
GO

/****** Object:  Job [SQLPSX]    Script Date: 07/10/2010 17:18:28 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [dbaudit]    Script Date: 07/10/2010 17:18:28 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'dbaudit' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'dbaudit'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLPSX', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Runs Powershell scripts to create security settings csv files and load them into a database for reporting', 
		@category_name=N'dbaudit', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [PurgeHistory]    Script Date: 07/10/2010 17:18:28 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'PurgeHistory', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXECUTE dbo.usp_del_DatabasePermission
EXECUTE dbo.usp_del_DatabaseRole
EXECUTE dbo.usp_del_LinkedServerLogin
EXECUTE dbo.usp_del_Login
EXECUTE dbo.usp_del_ObjectPermission
EXECUTE dbo.usp_del_ServerPermission
EXECUTE dbo.usp_del_ServerRole
EXECUTE dbo.usp_del_SqlUser', 
		@database_name=N'SQLPSX', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run-SmoToCsvFile]    Script Date: 07/10/2010 17:18:28 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run-SmoToCsvFile', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.EXE -command "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules\SQLServer\run-SmoToCsvFile.ps1 2>&1"', 
		@output_file_name=N'C:\SQLPSX\Data\SQLPSX.err', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [WAIT]    Script Date: 07/10/2010 17:18:28 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'WAIT', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'WAITFOR DELAY ''00:05''', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Write-SmoCsvToDb]    Script Date: 07/10/2010 17:18:28 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Write-SmoCsvToDb', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.EXE -command "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules\SQLServer\Write-SmoCsvToDb.ps1 2>&1"', 
		@output_file_name=N'C:\SQLPSX\Data\SQLPSX.err', 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Weekly', 
		@enabled=0, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20080710, 
		@active_end_date=99991231, 
		@active_start_time=150000, 
		@active_end_time=235959, 
		@schedule_uid=N'8ec1b0f5-c6b1-44c1-8308-c01f7bed505b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

