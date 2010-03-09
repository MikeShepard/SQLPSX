function Invoke-DBMaint
{
	<#
	.SYNOPSIS
	Implements full database maintenance.
	.DESCRIPTION
	Implements full database maintenance.
	.INPUTS
	Pipe ServerName
	.OUTPUTS
	None
	.EXAMPLE

	Invoke-DBMaint -server R2D2 -Databases "ALL" -Action "BKP_DB" -BackupOn c:\Temp -ReportOn c:\Temp
	
	Invoke-DBMaint -server R2D2 -Databases "SYSTEM" -Action "BKP_DB" -BackupOn c:\Temp -ReportOn c:\Temp
	
	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "BKP_DB" -BackupOn c:\Temp -ReportOn c:\Temp
	
	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "BKP_LOG" -BackupOn c:\Temp -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "IDX_ALL"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "IDX_REBUILD"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "IDX_REORG"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "STATS_FULL"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "STATS_SAMPLE"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "USER" -Action "CHECK_DB"  -ReportOn c:\Temp

	Invoke-DBMaint -server R2D2 -Databases "DELHIST" -Action "DEL_HIST"  -ReportOn c:\Temp -RemoveDataBackupsMSDB 10 -RemoveOldBackups 10

	get-content c:\temp\servers.txt | Invoke-DBMaint -Databases "USER" -Action "CHECK_DB"  -ReportOn c:\Temp

	.LINK
	http://sqlpsx.codeplex.com/
	#>
	
	
	param (
			[Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Server] $Server,
			
			[Parameter(position=1,Mandatory = $true )]
			[ValidateSet("ALL", "USER", "SYSTEM","DELHIST")]
			[string] 	$Databases ,
			
			[Parameter(position=2,Mandatory = $true )]
			[ValidateSet("BKP_DB","BKP_LOG","BKP_FILE","BKP_DIFF","IDX_ALL","IDX_REBUILD","IDX_REORG","STATS_SAMPLE","STATS_FULL","CHECK_DB","DEL_HIST")]
			[String]  	$Action ,

			[Parameter(position=3,Mandatory = $false )]
			[string] 	$UserName = "" ,
			
			[Parameter(position=4,Mandatory = $false )]
			[string] 	$Password = "" ,
			
		
			[Parameter(position=5,Mandatory = $false )] 
			[ValidateScript({Test-Path -path $_})]
			[String] 	$BackupOn = "c:\temp",
			
			[Parameter(position=6,Mandatory = $false )]
			[ValidateScript({Test-Path -path $_})]
			[String] 	$ReportOn = "",
			
			[Parameter(position=7,Mandatory = $false )]
			[ValidateRange(1,365)]
			[System.Int32] 	$RemoveOldBackups = 0,
			
			[Parameter(position=8,Mandatory = $false )]
			[ValidateRange(1,365)]
			[System.Int32]  $RemoveOldBackupsReports = 0,
			
			[Parameter(position=9,Mandatory = $false )]
			[ValidateRange(1,365)]
			[System.Int32]  $RemoveDataBackupsMSDB = 0
			
			
			)
			Begin
			{
			
				function Write-ScriptLog
				{
					param($msg,$date,$ReportOn)
					if ($ReportOn -ne "")
						{	Add-Content -Path (Join-Path $ReportOn "Invoke_DBMaint_$($ServerName)_$($date).log") -Value  $msg}
					Write-Output $msg	
				}
				
				function Invoke-DBMaintBackup 
				{
					param ($Action,$Databases,$ReportOn,$date,$dbs,$servername)
				
					[Microsoft.SqlServer.Management.Smo.BackupActionType] $actionbkp = "Database"
					
					$incremental = $false
				
					switch ($Action)
					{
						'BKP_DB'   {$extension = ".bak"}
						'BKP_FILE' {$extension = ".bak";  $actionbkp = "File" }
						'BKP_LOG'  {$extension = ".trn";  $actionbkp = "Log"  } 
						'BKP_DIFF' {$extension = "_Diff.bak" ;  $incremental = $true }
					}	
					
					Write-ScriptLog -msg $("Operation executed : BACKUP $($actionbkp) - Databases : $($databases) - Differential : $($incremental)") -date $($date) -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
	
						
					$dbs |	foreach { 
										try 
										{
											$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
											$DbName = $_.name
											if ($incremental)
												{ Invoke-SqlBackup -sqlserver $_.parent -dbname $_.name -action $actionbkp -incremental   -filepath (join-path $BackupOn "$($ServerName )$($_.name)$(get-date -format yyyyMMddhhmmss)$extension") -force }
											else
												{ Invoke-SqlBackup -sqlserver $_.parent -dbname $_.name -action $actionbkp  -filepath (join-path $BackupOn "$($ServerName )$($_.name)$(get-date -format yyyyMMddhhmmss)$extension") -force }
									
											
											$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
											Write-ScriptLog -msg $("Initial Time : $($initialtime) End Time : $($endtime) .Backup $($actionbkp) for server $($ServerName) Database $($DbName) to $($BackupOn) completed.") -date $($date) -reporton $($ReportOn)
											
										} catch {
											Write-ScriptLog -msg $("$(get-date -format yyyy/MM/dd) : Backup $($actionbkp) FAILED for server $($ServerName) Database $($DbName). Error details $($error[0])") -date $($date) -reporton $($ReportOn)
										}
										
									} 
				}
				
				function Invoke-DbMaintIndexes
				{
				
					param ($Action,$Databases,$ReportOn,$date,$dbs,$servername)
					
					Write-ScriptLog -msg $("Operation executed : Index $($action)  - Databases : $($databases)") -date $($date) -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
		
						
					$dbs |	Get-SqlTable | Get-SqlIndex |  foreach { 
										$index = $_
										Get-SqlIndexFragmentation $index | foreach { 
											try 
											{
												
												# If frag > 10 and < 30 and pages > 1000 , or choose reorg
												if (($_.AverageFragmentation -ge  10 -and $_.AverageFragmentation -le 30  -and $_.Pages -ge 1000) -or $action -eq "IDX_REORG")
													{ 
													
														$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
														Invoke-SqlIndexDefrag $index
														$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
														Write-ScriptLog -msg $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($index.Server) Database $($index.$DbName) Table $($index.table) Index $($index.name) Avg Fragmentation $($_.AverageFragmentation) | Reorganize Completed." ) -date $($date) -reporton $($ReportOn)
														
													}
												# if frag > 30 and pages > 1000 or chosse rebuild	
												elseif (($_.AverageFragmentation -gt 30 -and $_.Pages -ge 1000) -or $action -eq  "IDX_REBUILD")
													{
														
														$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
														Invoke-SqlIndexrebuild $index 
														$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
														Write-ScriptLog -msg $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) Database $($index.DbName) Table $($index.table) Index $($index.name) Avg Fragmentation $($_.AverageFragmentation)| Rebuild Completed.")  -date $($date) -reporton $($ReportOn)
														
													}
													
												
											} catch {
												Write-ScriptLog $("$(get-date -format yyyy/MM/dd) : Index Action FAILED for server $($ServerName) Database $($index.DbName) Table $($index.table) Index $($index.name) . Error details $($error[0])") -date $($date) -reporton $($ReportOn)												}
											

										}	
									} 
				}
				
				function invoke-dbmaintStats 
				{
				
					param ($Action,$Databases,$ReportOn,$date,$dbs,$servername)
				
					Write-ScriptLog -msg $("Operation executed : Update Statistics $($action)  - Databases : $($databases)") -date $($date) -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
	
						
					$dbs |	Get-SqlTable | Get-SqlStatistic | foreach { 
											$table = $_
											try 
											{
																						
												$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
												if ($Action -eq "STATS_FULL")
													{ Update-SqlStatistic -statistic $_ -scanType "FullSCAN" }
												Else
													{ Update-SqlStatistic -statistic $_ }
											
												$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
												Write-ScriptLog -msg $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) Database $($Table.DbName) Table $($Table.table)  | Statistics Updated.") -date $($date) -reporton $($ReportOn)
										
														
											} catch {
												Write-ScriptLog -msg $("$(get-date -format yyyy/MM/dd) : Statistics Update  FAILED for server $($ServerName) Database $($Table.DbName) Table $($Table.table)  . Error details $($error[0])")  -date $($date) -reporton $($ReportOn)
											}
											

										}	
									
				}
				
				function invoke-dbmaintcheckdb
				{
				
					param ($Action,$Databases,$ReportOn,$date,$dbs,$servername)
					
					Write-ScriptLog $("Operation executed : DBCC CHECKDB  - Databases : $($databases)") -date $($date)  -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
	
						
					$dbs |	foreach {
					
										$Database = $_
										
										try 
										{
					
											$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
											Invoke-SqlDatabaseCheck $Database
											$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
											Write-ScriptLog $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) Database $($Database.Name) | CHECKDB Completed." ) -date $($date) -reporton $($ReportOn)
											
										} catch {
											Write-ScriptLog $("$(get-date -format yyyy/MM/dd) : CHECKDB  FAILED for server $($ServerName) Database $($Database.Name) . Error details $($error[0])") -date $($date) -reporton $($ReportOn)

										}
						
									}
			
			
				}
				
				function invoke-dbmaintHKMSDB
				{
					param ($RemoveDataBackupsMSDB,$ReportOn,$server,$servername)
			
					Write-ScriptLog $("Operation executed : Housekeeping MSDB Days $($RemoveDataBackupsMSDB)") -date $($date)  -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
					
					$Dtfinal = (Get-Date) - (New-TimeSpan -Days $RemoveDataBackupsMSDB)
					
					try 
					{
						$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						$Server.DeleteBackupHistory($Dtfinal)
						$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						Write-ScriptLog $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) | Housekeeping MSDB Completed." ) -date $($date) -reporton $($ReportOn)


					} catch {
						Write-ScriptLog -msg $($Error[0]) -date $($date)  -reporton $($ReportOn)
					
					}
				}
				
				function invoke-dbmaintremoveoldbackups
				
				{
					param ($RemoveOldBackups,$date,$BackupOn,$ReportOn,$servername)
					
					Write-ScriptLog $("Operation executed : Removing Old Backups Days $($RemoveOldBackups)") -date $($date)  -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)

					try
					{
						#Only strings match $servername AND not match .log
						$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						Get-ChildItem $($BackupOn) | Where-Object {$_.name -match "(.*$servername.*)[^\.log]" -and (get-date).subtract($_.LastWriteTime).days -ge $RemoveOldBackups  } |  remove-item  -Force
						$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						Write-ScriptLog $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) | Removing Old Backups Completed." ) -date $($date) -reporton $($ReportOn)

				
					}catch {
						Write-ScriptLog  $("$(get-date -format yyyy/MM/dd) : Remove Old Backups  FAILED for server $($ServerName) . Error details $($error[0])") -date $($date) -reporton $($ReportOn)
						}
				}
				
				function invoke-dbmaintremoveoldbackupsreports
				
				{
				
					param ($RemoveOldBackupsReports,$date,$ReportOn,$servername)
					Write-ScriptLog $("Operation executed : Removing Old Reports Days $($RemoveOldBackupsReports)") -date $($date)  -reporton $($ReportOn)
					Write-ScriptLog -msg $("`n") -date $($date) -reporton $($ReportOn)
					
					try
					{
						$InitialTime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						#Only strings match $servername AND match .log
						Get-ChildItem $($ReportOn) | Where-Object { $_.name -match "(.*$servername.*)(\.log)" -and (get-date).subtract($_.LastWriteTime).days -ge $RemoveOldBackupsReports } | remove-item -force 
						$endtime = Get-Date -Format "yyyy/MM/dd hh:mm:ss"
						Write-ScriptLog $("Initial Time : $($initialtime) End Time : $($endtime) .Server $($ServerName) | Removing Old Eeports Completed." ) -date $($date) -reporton $($ReportOn)

					}catch {
						Write-ScriptLog $("$(get-date -format yyyy/MM/dd) : Remove Old Backups Reports  FAILED for server $($ServerName) . Error details $($error[0])") -date $($date) -reporton $($ReportOn)
					}
				}

				
			
			
			}
   
			process 
			{
			
			
			
				#Set Action Preference
				$ErrorActionPreference = "Continue"
				$date = get-date -format yyyyMMddhhmmss
				
				if ($Databases -eq "DELHIST" -or $Action -eq "DEL_HIST")
					{$Action = "DEL_HIST";$Databases = "DELHIST"}
				 
				try 
				{
				
					$ServerName = ((( $server -replace '\\','_') -replace '\[','') -replace '\]','')
					#Clean error
					$Error.Clear()
					
					#Try connect to the server
					if ($UserName -eq "" -and $Password -eq "")
						{$server = Get-SqlServer -sqlserver $server}
					else	
						{$server = Get-SqlServer  -sqlserver $server -username $UserName -password $Password}


					#Verify wich databases will be used	
					switch ($Databases)
					{
						'All' { $dbs = Get-SqlDatabase $server -force | Where-Object {$_.name  -notmatch "tempdb"}}
						'System' { $dbs = Get-SqlDatabase $server -force | where {$_.IsSystemObject -and $_.name  -notmatch "tempdb"} }
						'User' { $dbs = Get-SqlDatabase $server | Where-Object {$_.name -notmatch "tempdb"} }
					
					}
					
					
					# Only Backups
					
					if ($Action -match "^BKP_DB$|^BKP_LOG$|^BKP_FILE$|^BKP_DIFF$")
					{	invoke-dbmaintbackup $Action $Databases $ReportOn $date $dbs $servername }
					
					
					#Reindex or Rebuild. Use fragmentation >= 10 and <=30 Reorg and update stats. > 30 Rebuild. Only indexes with pagecount > 1000
								
					if ($Action -match "^IDX_ALL$|^IDX_REBUILD$|^IDX_REORG$")
					{ invoke-dbmaintindexes $Action $Databases $ReportOn $date $dbs $servername	}
					
					#Stats Sample or Full
					if ($Action -match "^STATS_SAMPLE|^STATS_FULL$")
					{	invoke-dbmaintStats	$Action $Databases $ReportOn $date $dbs $servername	}	
			
					#CheckDB
					if ($Action  -eq "CHECK_DB")
					{	invoke-dbmaintcheckdb	$Action $Databases $ReportOn $date $dbs $servername }	
			

					#Housekeeping MSDB
					if (($Action -eq "DEL_HIST" -and $RemoveDataBackupsMSDB -gt 0)  -or $RemoveDataBackupsMSDB -gt 0 )
					{ invoke-dbmaintHKMSDB $RemoveDataBackupsMSDB $ReportOn $server $servername } 	
					
						
					if ($RemoveOldBackups -gt 0)
					{ invoke-dbmaintremoveoldbackups $RemoveOldBackups $date $BackupOn $ReportOn $servername }
						
					
						
					if ($RemoveOldBackupsReports -gt 0 -and $ReportOn -ne "" )
					{ invoke-dbmaintremoveoldbackupsreports $RemoveOldBackupsReports $date $ReportOn $servername }
						
					
				} catch {
							Write-ScriptLog $("$(get-date -format yyyy/MM/dd) :Invoke-DBMaint  FAILED for server $($ServerName) . Error details $($error[0])") -date $($date) -reporton $($ReportOn)
				}
				
			}	
			
}
		



