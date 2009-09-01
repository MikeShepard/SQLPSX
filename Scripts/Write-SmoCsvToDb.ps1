# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Load the Csv file into the specified database
### </Description>
### <Usage>
### ./Write-SmoCsvToDb.ps1 
### </Usage>
### </Script>
# ---------------------------------------------------------------------------


$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
. $scriptRoot\LibrarySmo.ps1

$CsvDir = "$scriptRoot\Data\"
$arcDir = "$scriptRoot\Data\Archive\"
$sqlserver = 'Z002\SQLEXPRESS'
$db = 'SQLPSX'

#######################
function Write-ScriptLog
{
    param($thread,$msg)
    $outfile = 'smocsvtodb.log'
    Add-Content -Path "$CsvDir$outfile" -Value "$((Get-Date).ToString(`"yyyy-MM-dd HH:mm`")) $thread $msg" 

}# Write-ScriptLog

#######################
function ImportCsv
{
    param($sqlserver, $db, $tblname, $csvfile)

    Set-SqlData $sqlserver $db "BULK INSERT $db..$tblname FROM '$csvfile' WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n')"
#    Write-host "Set-SqlData $sqlserver $db `"BULK INSERT $db..$tblname FROM '$csvfile' WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n')`""

}# ImportCsv

#######################
function processCsv
{
    param($csvFile,$tblname)

    Get-ChildItem "$CsvDir*" -Include *."$csvFile".* | where {$_.Length -gt 0} | foreach {Write-ScriptLog "ImportCsv" "$_"; ImportCsv "$sqlserver" "$db" "$tblname" "$_"}

}# processCsv

#######################
Write-ScriptLog "processCsv" "Login"
    processCsv "SqlLogin" "Login"
Write-ScriptLog "processCsv" "ServerPermission"
    processCsv "SqlServerPermission" "ServerPermission"
Write-ScriptLog "processCsv" "ServerRole"
    processCsv "SqlServerRole" "ServerRole"
Write-ScriptLog "processCsv" "SqlLinkedServerLogin"
    processCsv "SqlLinkedServerLogin" "SqlLinkedServerLogin"
Write-ScriptLog "processCsv" "SqlUser"
    processCsv "SqlUser" "SqlUser"
Write-ScriptLog "processCsv" "DatabasePermission"
    processCsv "SqlDatabasePermission" "DatabasePermission"
Write-ScriptLog "processCsv" "ObjectPermssion"
    processCsv "SqlObjectPermission" "ObjectPermission"
Write-ScriptLog "processCsv" "DatabaseRole"
    processCsv "SqlDatabaseRole" "DatabaseRole"

Write-ScriptLog "archiveCsv" "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))"
if (!(Test-Path "$arcDir$((Get-Date).ToString(`"yyyyMMdd`"))"))
{ new-item -path $arcDir -name $((Get-Date).ToString("yyyyMMdd")) -itemType 'directory' }
Move-Item "$CsvDir*.csv" "$arcDir$((Get-Date).ToString(`"yyyyMMdd`"))" 
Move-Item "$CsvDir*.err" "$arcDir$((Get-Date).ToString(`"yyyyMMdd`"))" 
Move-Item "$CsvDir*.log" "$arcDir$((Get-Date).ToString(`"yyyyMMdd`"))"
$cmd = "compact.exe /C /S:$arcDir$((Get-Date).ToString(`"yyyyMMdd`"))"
cmd /c $cmd
