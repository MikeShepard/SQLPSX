
# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Runs Write-SmoToCsvFile.ps1 with the specified number of threads.
### NOTE because a master powershell session is used to call the child
### sessions the minimum maxThread would be 2, increase by one for each
### additional thread. In my testing a single core machine with 1.5 GB of memory
### will consume 100% CPU and ~500 MB of memory.
### </Description>
### <Usage>
### ./Run-SmotToCsvFile.ps1 'MySqlServer'
### C:\usr\bin>C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.EXE -command "run-SmoToCsvFile.ps1 2>&1" >> C:\usr\bin\SQLPSX\SqlSec.err
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
. $scriptRoot\LibrarySmo.ps1
Set-Alias Test-SqlConn $scriptRoot\Test-SqlConn.ps1

$maxThread = 2
$ServerList = New-Object System.Collections.ArrayList
$SQLPSXServer = 'COUGARXA\SQLDEV2'
$SQLPSXDb = 'SQLPSX'
$SQLPSXDir = "C:\usr\bin\SQLPSX\"

#######################
function Get-SqlList
{
 Get-SqlData $SQLPSXServer $SQLPSXDb  "SELECT Server FROM dbo.SqlServer WHERE IsEnabled = 'true'" | foreach {$_.Server} | Test-SqlConn |
 foreach { $ServerList.Add("$_") > $null }

}# Get-SqlList

#######################
function LaunchThread
{
    param($sqlserver)

    $outfile = $sqlserver -replace '\\','_'

    $StartInfo = new-object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = "$pshome\powershell.exe"
    $StartInfo.Arguments = " -NoProfile -Command $scriptRoot\Write-SmoToCsvFile.ps1 $sqlserver 2>&1 >> $SQLPSXDir$outfile.err"
    $StartInfo.WorkingDirectory = "C:\Users\u00\bin"
    $StartInfo.LoadUserProfile = $true
    $StartInfo.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($StartInfo) > $null

}# LaunchThread

#######################
Get-SqlList

while ($ServerList.Count -gt 0)
{
    if ($(get-process | where {$_.ProcessName -eq 'Powershell' -and $_.Id -ne $PID} | measure-object).count -lt $maxThread)
    {   $server = $ServerList[0]
        #Launch Another Thread 
        LaunchThread $server
        #Set the Server as processed
        $ServerList.Remove("$server")
    }
    else
    {   #Sleep for 5 minutes
        [System.Threading.Thread]::Sleep(300000)
    }
}
