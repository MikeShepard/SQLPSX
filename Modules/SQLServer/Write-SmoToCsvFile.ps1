
# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Generates an a csv file for all SQL Server security settings
### </Description>
### <Usage>
### ./Write-SmotToCsvFile.ps1 'MySqlServer'
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

param ($sqlserver)

#$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
#. $scriptRoot\LibrarySmo.ps1
#Set-Alias Test-SqlConn $scriptRoot\Test-SqlConn.ps1

import-module sqlserver

$scriptRoot = "C:\SQLPSX"

$DBExclude = @{}
$dir = "$scriptRoot\Data\"
$outfile = $sqlserver -replace '\\','_'

#######################
function PrepareCsv
{
    param($file)
    (Get-Content $file) | where {$_.readcount -gt 1} | foreach {$_ -replace "`"`"","'"} | foreach {$_ -replace "`""} |
                                                       foreach {$_ -replace "'","`""} | foreach {$_ -replace "False,","0,"} |
                                                       foreach {$_ -replace "True,","1,"} | Set-Content $file 
}# PrepareCsv

#######################
function Write-ScriptLog
{
    param($thread,$msg)
    Add-Content -Path "$dir$outfile.log" -Value "$((Get-Date).ToString(`"yyyy-MM-dd HH:mm`")) $thread $msg"

}# Write-ScriptLog

#######################
function Get-DBExclude
{
    if (test-path $scriptRoot\DBExclude.txt)
    {
        Get-Content $scriptRoot\DBExclude.txt |
        foreach { $server = $_.split(",")[0]; $dbname = $_.split(",")[1];
           if (!($DBExclude.Contains($server)))
           { $DBExclude[$server] = @($dbname) }
           else
           { $DBExclude[$server] += @($dbname) };
        }
    }

}# Get-DBExclude

#######################
function IsDBExcluded
{
    param($server, $dbname)

    if (!($DBExclude))
    { return $false }
    elseif ($DBExclude[$server] -contains $dbname)
    { return $true }
    else
    { return $false }

}# IsDBExcluded
#######################

function processSqlList
{
    param ($sqlserver)

    Write-ScriptLog "Write-SmoToCsvFile" "Started:$sqlserver"
    $server = Get-SqlServer $sqlserver
    $dbs = $(Get-SqlDatabase $server)
    Write-ScriptLog "Get-SqlLogin" "Started:$sqlserver"
        Get-SqlLogin $server | Select LoginType, Xmlmembers, Server, Name, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.SqlLogin.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.SqlLogin.csv"
        PrepareCsv "$dir$outfile.SqlLogin.csv"
    Write-ScriptLog "Get-SqlServerPermission" "Started:$sqlserver"
        Get-SqlServerPermission $server | Select PermissionState, Xmlmembers, Server, Grantee, PermissionType, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.SqlServerPermission.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.SqlServerPermission.csv"
        PrepareCsv "$dir$outfile.SqlServerPermission.csv"
    Write-ScriptLog "Get-SqlServerRole" "Started:$sqlserver"
        Get-SqlServerRole $server | Select Xmlmembers, Server, Name, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.SqlServerRole.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.SqlServerRole.csv"
        PrepareCsv "$dir$outfile.SqlServerRole.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.SqlLinkedServerLogin.csv"
        Get-SqlLinkedServerLogin $server | Select Server, timestamp, LinkedServer, DataSource, Impersonate, Name, RemoteUser | Export-Csv -NoTypeInformation "$dir$outfile.SqlLinkedServerLogin.csv"
        PrepareCsv "$dir$outfile.SqlLinkedServerLogin.csv"
#    Although piping will "work" for example instead of the syntax below use $dbs | Get-SqlUser, it is extremely slow
#    This is because unlike other shells, Powershell processes everthing left of the pipe before passing to the next pipe. Most of time this is OK,
#    except when dealing with large result sets such as this. Here we do not want Powershells' pipe behavior. It would be nice if this was a option
#    which could be passed to the pipe 
    foreach ($db in $dbs | where {$(IsDBExcluded $_.parent.name $_.name) -eq $false}) 
    {
    Write-ScriptLog "Get-SqlUser" "Started:$sqlserver.$($db.name)"
        Get-SqlUser $db | Select LoginType, Xmlmembers, objects, Server, dbname, Login, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.$($db.name).SqlUser.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.$($db.name).SqlUser.csv"
        PrepareCsv "$dir$outfile.$($db.name).SqlUser.csv"
    Write-ScriptLog "Get-SqlDatabaseRole" "Started:$sqlserver.$($db.name)"
        Get-SqlDatabaseRole $db | Select IsFixedRole, Xmlmembers, Server, dbname, Name, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.$($db.name).SqlDatabaseRole.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.$($db.name).SqlDatabaseRole.csv"
        PrepareCsv "$dir$outfile.$($db.name).SqlDatabaseRole.csv"
    Write-ScriptLog "Get-SqlDatabasePermission" "Started:$sqlserver.$($db.name)"
        Get-SqlDatabasePermission $db | Select PermissionState, Xmlmembers, Server, dbname, Grantee, PermissionType, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.$($db.name).SqlDatabasePermission.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.$($db.name).SqlDatabasePermission.csv"
        PrepareCsv "$dir$outfile.$($db.name).SqlDatabasePermission.csv"
    Write-ScriptLog "Get-SqlObjectPermission" "Started:$sqlserver.$($db.name)"
        Get-SqlObjectPermission $db | Select ObjectClass, ColumnName, PermissionState, Xmlmembers, Server, dbname, Grantee, PermissionType, ObjectSchema, ObjectName, timestamp | Export-Csv -NoTypeInformation "$dir$outfile.$($db.name).SqlObjectPermission.csv"
    Write-ScriptLog "PrepareCsv" "Started:$dir$outfile.$($db.name).SqlObjectPermission.csv"
        PrepareCsv "$dir$outfile.$($db.name).SqlObjectPermission.csv"
    }
    Write-ScriptLog "Write-SmoToCsvFile" "Finished:$sqlserver"
}

#######################
# Main                #
#######################
Get-DBExclude
processSqLList $sqlserver
