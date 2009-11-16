# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the SMO.Agent Classes
### </Description>
### <Usage>
### . ./LibraryAgent.ps1
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

#######################
function Get-AgentJobServer
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver $Username $Password }
        'Server' { $server = $sqlserver }
        default { throw 'Get-AgentJobServer:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-AgentJobServer $($server.Name)"
    Write-Output $server.JobServer

} #Get-AgentJobServer

#######################
function Get-AgentAlertCategory
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentAlertCategory:Param `$jobserver must be a String or JobServer object.' }
    }
    
    Write-Verbose "Get-AgentAlertCategory $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.AlertCategories.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.AlertCategories[$name] 
      }
    }
    else
    { $jobsrv.AlertCategories }


} #Get-AgentAlertCategory

#######################
function Get-AgentAlert
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentAlert:Param `$jobserver must be a String or JobServer object.' }
    }
    
    Write-Verbose "Get-AgentAlert $($jobsrv.Name)"

    if ($name)
    { if (!$jobsrv.Alerts.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.Alerts[$name] 
      }
    }
    else
    { $jobsrv.Alerts }


} #Get-AgentAlert

#######################
function Get-AgentJob
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentJob:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentJob $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.Jobs.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.Jobs[$name] 
      }
    }
    else
    { $jobsrv.Jobs }

} #Get-AgentJob

#######################
function Get-AgentJobSchedule
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Agent.Job]$job,
    [Parameter(Position=1, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$name="*"
    )

    process
    {
        foreach ($jobSchedule in $job.JobSchedules)
        {
            if ($jobSchedule.name -like "*$name*" -or $name.Contains($jobSchedule.name))
            {
            #Return JobSchedule Object
            $jobSchedule 
            }
        }

    }

} #Get-AgentJobSchedule

#######################
function Get-AgentJobStep
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Agent.Job]$job,
    [Parameter(Position=1, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$name="*"
    )

    process
    {
        foreach ($JobStep in $job.JobSteps)
        {
            if ($JobStep.name -like "*$name*" -or $name.Contains($jobStep.name))
            {
            #Return JobStep Object
            $JobStep 
            }
        }

    }

} #Get-AgentJobStep

#######################
function Get-AgentOperator
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentOperator:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentOperator $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.Operators.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.Operators[$name] 
      }
    }
    else
    { $jobsrv.Operators }

} #Get-AgentOperator

#######################
function Get-AgentOperatorCategory
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentOperatorCategory:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentOperatorCategory $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.OperatorCategories.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.OperatorCategories[$name] 
      }
    }
    else
    { $jobsrv.OperatorCategories }

} #Get-AgentOperatorCategory

#######################
function Get-AgentProxyAccount
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentProxyAccount:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentProxyAccount $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.ProxyAccounts.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.ProxyAccounts[$name] 
      }
    }
    else
    { $jobsrv.ProxyAccounts }

} #Get-AgentProxyAccount

#######################
function Get-AgentSchedule
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentJobSchedule:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentJobSchedule $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.SharedSchedules.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.SharedSchedules[$name] 
      }
    }
    else
    { $jobsrv.SharedSchedules }

} #Get-AgentSchedule

#######################
function Get-AgentTargetServerGroup
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentTargetServerGroup:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentTargetServerGroup $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.TargetServerGroups.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.TargetServerGroups[$name] 
      }
    }
    else
    { $jobsrv.TargetServerGroups }

} #Get-AgentTargetServerGroup

#######################
function Get-AgentTargetServer
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$name 
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentTargetServer:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentTargetServer $($jobsrv.Name) $name"

    if ($name)
    { if (!$jobsrv.TargetServers.Contains("$name")) {throw 'Check $name Name.'}
      else { 
        $jobsrv.TargetServers[$name] 
      }
    }
    else
    { $jobsrv.TargetServers }

} #Get-AgentTargetServer

#######################
function Set-AgentJobHistoryFilter
{
    param(
    [Parameter(Position=0, Mandatory=$false)] [string]$name,
    [Parameter(Position=1, Mandatory=$false)] [datetime]$endDate,
    [Parameter(Position=2, Mandatory=$false)] [datetime]$startDate,
    [Parameter(Position=3, Mandatory=$false)] [string]$outCome
    )

    $jobHistoryFilter = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter
    if ($name) { $jobHistoryFilter.JobName = $name }
    if ($endDate) { $jobHistoryFilter.EndRunDate = [datetime]$endDate }
    if ($startDate) { $jobHistoryFilter.StartRunDate = [datetime]$startDate }
    #outComeTypes: Cancelled,Failed, InProgress, Retry, Succeeded, Unknown
    if ($outcome) { $jobHistoryFilter.OutComeTypes = $outCome }

    Write-Output $jobHistoryFilter
}
#######################
function Get-AgentJobHistory
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $jobserver,
    [Parameter(Position=1, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter]$jobHistoryFilter
    )

    switch ($jobserver.GetType().Name)
    {
        'String' { $jobsrv = Get-AgentJobServer $jobserver }
        'JobServer' { $jobsrv = $jobserver }
        default { throw 'Get-AgentJobHistory:Param `$jobserver must be a String or JobServer object.' }
    }

    Write-Verbose "Get-AgentJobHistory $($jobsrv.Name)"

    if ($jobHistoryFilter)
    { if ($jobHistoryFilter.GetType().Name -ne "JobHistoryFilter") {throw 'JobHistoryFilter must be a JobHistoryFilter object.'}
      else { 
        $jobsrv.EnumJobHistory($jobHistoryFilter) 
      }
    }
    else
    { $jobsrv.EnumJobHistory() }

} #Get-AgentJobHistory

