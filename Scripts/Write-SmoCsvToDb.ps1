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

$CsvDir = '\\Z002\C$\usr\bin\SQLPSX\'
$sqlserver = 'MyServer'
$db = 'SQLPSX'

#######################
function Write-ScriptLog
{
    param($thread,$msg)
    Write-Host "$((Get-Date).ToString(`"yyyy-MM-dd HH:mm`")) $thread $msg" 

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
    param($tblname)

    Get-ChildItem "$CsvDir*" -Include *."Sql$tblname".* | foreach {Write-ScriptLog "ImportCsv" "$_"; ImportCsv "$sqlserver" "$db" "$tblname" "$_"}

}# processCsv

#######################
Write-ScriptLog "processCsv" "Login"
    processCsv "Login"
Write-ScriptLog "processCsv" "ServerPermission"
    processCsv "ServerPermission"
Write-ScriptLog "processCsv" "ServerRole"
    processCsv "ServerRole"
Write-ScriptLog "processCsv" "SqlLinkedServerLogin"
    processCsv "SqlLinkedServerLogin"
Write-ScriptLog "processCsv" "SqlUser"
    processCsv "SqlUser"
Write-ScriptLog "processCsv" "DatabasePermission"
    processCsv "DatabasePermission"
Write-ScriptLog "processCsv" "ObjectPermssion"
    processCsv "ObjectPermission"
Write-ScriptLog "processCsv" "DatabaseRole"
    processCsv "DatabaseRole"

Write-ScriptLog "archiveCsv" "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))"
if (!(Test-Path "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))"))
{ new-item -path $CsvDir -name $((Get-Date).ToString("yyyyMMdd")) -itemType 'directory' }
Move-Item "$CsvDir*.csv" "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))" 
Move-Item "$CsvDir*.err" "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))" 
Move-Item "$CsvDir*.log" "$CsvDir$((Get-Date).ToString(`"yyyyMMdd`"))" 
