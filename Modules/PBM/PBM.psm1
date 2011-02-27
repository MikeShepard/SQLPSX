#if ($shellid -ne 'Microsoft.SqlServer.Management.PowerShell.sqlps' -or (!(get-command -name Invoke-PolicyEvaluation)))
#{ throw 'PBM must be run within sqlps mini-shell or SQL Server cmdlets must be loaded' }
# Note: This module is meant to run within sqlps or within a PowerShell host with sqlps cmdlets loaded.
# Sqlps does not support import-module or any post V1 cmdlets including write-eventlog.
# In sqlps the module must be dot sourced...
# . C:\scripts\pbm.psm1
# Dot sourcing a module is not recommanded.
# This module is loosely based on epmframework http://epmframework.codeplex.com but cleaned up to be more PowerShell like
# and remove multi-table/complex XML parsing

$Script:EvaluationMode = "Check"
$Script:PolicyServer = "Z003\R2"
$Script:PolicyDatabase = "MDW"
$Script:CMS = "Z003\SQLEXPRESS"
$Script:WriteEventLog = $false
$Script:LogName = "Application"
$Script:LogSource = "PBMScript"
$Script:EntryType = "Error"
$Script:EventId = 34052

#######################
function Get-PolicyStore
{
    $conn = new-object Microsoft.SQlServer.Management.Sdk.Sfc.SqlStoreConnection("server=$Script:PolicyServer;Trusted_Connection=true")
    $policyStore = new-object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)
    Write-Output $policyStore

} #Get-PolicyStore

#######################
function Get-TargetServer
{
 [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$ConfigurationGroup)

$query = @"
SELECT s.server_name AS server_name
FROM msdb.dbo.sysmanagement_shared_registered_servers_internal s
INNER JOIN msdb.dbo.sysmanagement_shared_server_groups cg
        ON s.server_group_id = cg.server_group_id 
WHERE cg.name = '$ConfigurationGroup'
"@
    Invoke-SqlCmd -ServerInstance $Script:CMS -Query $query | Select-object -ExpandProperty server_name

} #Get-TargetServer

#######################
function Write-PolicyEvalError
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=1, Mandatory=$true)] [string]$PolicyName,
    [Parameter(Position=2, Mandatory=$true)] [string]$Exception,
    [Parameter(Position=3, Mandatory=$true)] [string]$PolicyEvalErrorDate)


    $query = "INSERT INTO PolicyEvalError (ServerInstance, PolicyName, Exception) VALUES('{0}','{1}','{2}', '{3}')"  -f $ServerInstance,$PolicyName,$Exception, $PolicyEvalErrorDate
    Invoke-Sqlcmd -ServerInstance $Script:PolicyServer -Database $Script:PolicyDatabase -Query $query -ErrorAction Stop

} # Write-PolicyEvalError

#######################
function Write-PolicyEval
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$ConfigurationGroup,
    [Parameter(Position=1, Mandatory=$true)] [string]$PolicyCategoryFilter,
    [Parameter(Position=2, Mandatory=$true)] [string]$PolicyEvalMode,
    [Parameter(Position=3, Mandatory=$true)] [string]$PolicyName,
    [Parameter(Position=4, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=5, Mandatory=$true)] [string]$TargetQueryExpression,
    [Parameter(Position=6, Mandatory=$true)] [bool]$Result,
    [Parameter(Position=7, Mandatory=$true)] [string]$PolicyEvalDate,
    [Parameter(Position=8, Mandatory=$false)] [string]$Exception)


$query = @"
INSERT INTO PolicyEval (ConfigurationGroup, PolicyCategoryFilter, PolicyEvalMode, PolicyName, ServerInstance, TargetQueryExpression, Result, Exception,PolicyEvalDate)
VALUES ('$ConfigurationGroup', '$PolicyCategoryFilter', '$PolicyEvalMode', '$PolicyName', '$ServerInstance', '$TargetQueryExpression', $([byte]$Result),'$Exception','$PolicyEvalDate')
"@

    Invoke-Sqlcmd -ServerInstance $Script:PolicyServer -Database $Script:PolicyDatabase -Query $query -ErrorAction Stop

} # Write-PolicyEval

#######################
function Import-PolicyEvaluation
{

   [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$ConfigurationGroup,
    [Parameter(Position=1, Mandatory=$true)] [string]$PolicyCategoryFilter)

    $PolicyStore = Get-PolicyStore
    $date = (get-date -Format u) -replace 'Z'

    if ($Script:WriteEventLog)
    {
        $eventlog = Get-EventLog -List | Where-Object { $_.Log -eq $Script:LogName }
        $eventlog.Source = $Script:LogSource
    }

    foreach ($Policy in $PolicyStore.Policies | where-object {$_.PolicyCategory -eq $PolicyCategoryFilter})
    {
        foreach ($TargetServer in Get-TargetServer $ConfigurationGroup)
        {
            try {
                Invoke-PolicyEvaluation -Policy $Policy -TargetServerName $TargetServer -AdHocPolicyEvaluationMode $Script:EvaluationMode | `
                Select-object -ExpandProperty ConnectionEvaluationHistories | Select-Object -ExpandProperty EvaluationDetails |  `
                foreach-object { Write-PolicyEval $ConfigurationGroup $PolicyCategoryFilter $Script:EvaluationMode $Policy.Name $TargetServer `
                                                  $_.TargetQueryExpression $_.Result $date $($_.Exception -replace "'")
                            if ($Script:WriteEventLog -and $_.Result -eq $false)
                            {
                                $message= "{0} on {1} {2} failed." -f $Policy.PolicyName,$TargetServer,$_.TargetQueryExpression
                                $eventlog.WriteEntry($Message,$Script:EntryType,$Script:EventId)
                            }
                }
            }
            catch {	  
                $Exception = "{0}, {1}" -f  $_.Exception.GetType().FullName,$( $_.Exception.Message -replace "'" )
                Write-PolicyEvalError $TargetServer $Policy.Name $Exception $date
            }
        }
    }

} #Import-PolicyEvaluation
