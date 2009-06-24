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
    param($sqlserver=$(throw 'Get-AgentJobServer:`$sqlserver is required'),[string]$Username,[string]$Password)

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver $Username $Password }
        'Server' { $server = $sqlserver }
        default { throw 'Get-AgentJobServer:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-AgentJobServer $($server.Name)"
    return $server.JobServer

} #Get-AgentJobServer

#######################
function Get-AgentAlertCategory
{
    param($jobserver=$(throw 'Get-AgentAlertCategory:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentAlert:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentJob:`$jobserver is required'),[string]$name)

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
    param($job, [string]$name="*")
    begin
    {
        function Select-AgentJobSchedule ($job, [string]$name="*")
        {

            foreach ($jobSchedule in $job.JobSchedules)
            {
                if ($jobSchedule.name -like "*$name*" -or $name.Contains($jobSchedule.name))
                {
                #Return JobSchedule Object
                $jobSchedule 
                }
            }

        } #Select-AgentJobSchedule
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Job')
            { Write-Verbose "Get-AgentJobSchedule $($_.Name)"
              Select-AgentJobSchedule $_ -name $name }
            else
            { throw 'Get-AgentJobSchedule:Param `$job must be a Job object.' }
        }
    }
    end
    {
        if ($job)
        { $job | Get-AgentJobSchedule -name $name }
    }

} #Get-AgentJobSchedule

#######################
function Get-AgentJobStep
{
    param($job, [string]$name="*")
    begin
    {
        function Select-AgentJobStep ($job, [string]$name="*")
        {

            foreach ($JobStep in $job.JobSteps)
            {
                if ($JobStep.name -like "*$name*" -or $name.Contains($jobStep.name))
                {
                #Return JobStep Object
                $JobStep 
                }
            }

        } #Select-AgentJobStep
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Job')
            { Write-Verbose "Get-AgentJobStep $($_.Name)"
              Select-AgentJobStep $_ -name $name }
            else
            { throw 'Get-AgentJobStep:Param `$job must be a Job object.' }
        }
    }
    end
    {
        if ($job)
        { $job | Get-AgentJobStep -name $name }
    }

} #Get-AgentJobStep

#######################
function Get-AgentOperator
{
    param($jobserver=$(throw 'Get-AgentOperator:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentOperatorCategory:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentProxyAccount:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentJobSchedule:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentTargetServerGroup:`$jobserver is required'),[string]$name)

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
    param($jobserver=$(throw 'Get-AgentTargetServer:`$jobserver is required'),[string]$name)

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
    param([string]$name,$endDate,$startDate,[string]$outCome)

    $jobHistoryFilter = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter
    if ($name) { $jobHistoryFilter.JobName = $name }
    if ($endDate) { $jobHistoryFilter.EndRunDate = [datetime]$endDate }
    if ($startDate) { $jobHistoryFilter.StartRunDate = [datetime]$startDate }
    #outComeTypes: Cancelled,Failed, InProgress, Retry, Succeeded, Unknow
    if ($outcome) { $jobHistoryFilter.OutComeTypes = $outCome }

    return $jobHistoryFilter
}
#######################
function Get-AgentJobHistory
{
    param($jobserver=$(throw 'Get-AgentJobHistory:`$jobserver is required'),$jobHistoryFilter)

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

