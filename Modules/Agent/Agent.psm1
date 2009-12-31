# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the SMO.Agent Classes
### </Description>
### <Usage>
### import-module Agent 
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
try {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"}

try {add-type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.Smo"; $smoVersion = 9}

#######################
function Get-SqlConnection
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password
    )

    Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password)
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver,$username,$password }
    else
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver }
	
    $con.Connect()

    Write-Output $con
    
} #Get-ServerConnection

#######################
function Get-SqlServer
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password
    )
    #When $sqlserver passed in from the SMO Name property, brackets
    #are automatically inserted which then need to be removed
    $sqlserver = $sqlserver -replace "\[|\]"

    Write-Verbose "Get-SqlServer $sqlserver"

    $con = Get-SqlConnection $sqlserver $Username $Password

    $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $con
    Write-Output $server
    
} #Get-SqlServer

#######################
<#
.SYNOPSIS
Gets a JobServer.
.DESCRIPTION
The Get-AgentJobServer function  gets the JobServer specified. This is the top level object for SMO.Agent.
.INPUTS
None
    You cannot pipe objects to Get-AgentJobServer
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.JobServer
    Get-AgentJobServer returns a Microsoft.SqlServer.Management.Smo.Agent.JobServer object.
.EXAMPLE
Get-AgentJobServer "Z002\sql2K8"
This command gets the JobServer for SQL Server Z002\SQL2K8.
.LINK
Get-AgentJobServer
#>
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
<#
.SYNOPSIS
Gets an SMO.Agent AlertCategory object or collection of AlertCategory objects.
.DESCRIPTION
The Get-AgentAlertCategory function  gets  an SMO.Agent AlertCategory object or a collection of AlertCategory objects from the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentAlertCategory
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.AlertCategory
    Get-AgentAlertCategory returns a Microsoft.SqlServer.Management.Smo.Agent.AlertCategory object.
.EXAMPLE
Get-AgentAlertCategory "Z002\sql2K8"
This command gets a collection of AlertCategory objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentAlertCategory
#>
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
<#
.SYNOPSIS
Gets an Alert object or collection of Alert objects.
.DESCRIPTION
The Get-AgentAlert function  gets an Alert object or a collection of Alert objects from the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentAlert
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.Alert
    Get-AgentAlert returns a Microsoft.SqlServer.Management.Smo.Agent.Alert object.
.EXAMPLE
Get-AgentAlert "Z002\sql2K8"
This command gets a collection of Alert objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentAlert
#>
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
<#
.SYNOPSIS
Gets an Job object or collection of Job objects.
.DESCRIPTION
The Get-AgentJob function  gets an Job object or a collection of Job objects from the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentJob
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.Job
    Get-AgentJob returns a Microsoft.SqlServer.Management.Smo.Agent.Job object.
.EXAMPLE
Get-AgentJob "Z002\sql2K8"
This command gets a collection of Job objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentJob
#>
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
<#
.SYNOPSIS
Gets an JobSchedule object or collection of JobSchedule objects.
.DESCRIPTION
The Get-AgentJobSchedule function  gets an JobSchedule object or a collection of JobSchedule objects for the specified Job.
.INPUTS
None
    You can pipe job Job to Get-AgentJobSchedule.
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.JobSchedule
    Get-AgentJobSchedule returns a Microsoft.SqlServer.Management.Smo.Agent.JobSchedule object.
.EXAMPLE
Get-AgentJob "Z002\sql2K8" | Get-AgentJobSchedule
This command gets a collection of JobSchedule objects for all jobs on SQL Server Z002\SQL2K8.
.LINK
Get-AgentJobSchedule
Get-AgentJob
#>
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
<#
.SYNOPSIS
Gets an JobStep object or collection of JobStep objects.
.DESCRIPTION
The Get-AgentJobStep function  gets an JobStep object or a collection of JobStep objects for the specified Job.
.INPUTS
None
    You can pipe job Job to Get-AgentJobStep.
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.JobStep
    Get-AgentJobStep returns a Microsoft.SqlServer.Management.Smo.Agent.JobStep object.
.EXAMPLE
Get-AgentJob "Z002\sql2K8" | Get-AgentJobStep
This command gets a collection of JobStep objects for all jobs on SQL Server Z002\SQL2K8.
.LINK
Get-AgentJobStep
Get-AgentJob
#>
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
<#
.SYNOPSIS
Gets an AgentOperator object or collection of AgentOperator objects.
.DESCRIPTION
The Get-AgentOperator function  gets an Operator object or a collection of Operator objects for the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentOperator
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.Operator
    Get-AgentOperator returns a Microsoft.SqlServer.Management.Smo.Agent.Operator object.
.EXAMPLE
Get-AgentOperator "Z002\sql2K8"
This command gets a collection of Operator objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentOperator
#>
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
<#
.SYNOPSIS
Gets an OperatorCategory object or collection of OperatorCategory objects.
.DESCRIPTION
The Get-AgentOperatorCategory function  gets an OperatorCategory object or a collection of OperatorCategory objects for the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentOperatorCategory
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.OperatorCategory
    Get-AgentOperatorCategory returns a Microsoft.SqlServer.Management.Smo.Agent.OperatorCategory object.
.EXAMPLE
Get-AgentOperatorCategory "Z002\sql2K8"
This command gets a collection of OperatorCategory objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentOperatorCategory
#>
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
<#
.SYNOPSIS
Gets an ProxyAccount object or collection of ProxyAccount objects.
.DESCRIPTION
The Get-AgentProxyAccount function  gets an ProxyAccount object or a collection of ProxyAccount objects for the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentProxyAccount
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.ProxyAccount
    Get-AgentProxyAccount returns a Microsoft.SqlServer.Management.Smo.Agent.ProxyAccount object.
.EXAMPLE
Get-AgentProxyAccount "Z002\sql2K8"
This command gets a collection of ProxyAccount objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentProxyAccount
#>
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
<#
.SYNOPSIS
Gets an JobSchedule object or collection of JobSchedule objects for JobServer Shared Schedules.
.DESCRIPTION
The Get-AgentSchedule function  gets an JobSchedule object or a collection of JobSchedule objects for JobServer Shared Schedules on the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentSchedule
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.JobSchedule
    Get-AgentSchedule returns a Microsoft.SqlServer.Management.Smo.Agent.JobSchedule object.
.NOTES
The Get-AgentSchedule function differs from Get-AgentJobSchedule in that Get-AgentSchedule is used for shared server-level schedules. In most cases you will want to use Get-AgentJobSchedule rather than this one.
.EXAMPLE
Get-AgentSchedule "Z002\sql2K8"
This command gets a collection of JobSchedule objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentSchedule
Get-AgentJobSchedule
#>
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
<#
.SYNOPSIS
Gets an TargetServerGroup object or collection of TargetServerGroup objects.
.DESCRIPTION
The Get-AgentTargetServerGroup function  gets an TargetServerGroup object or a collection of TargetServerGroup objects for the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentTargetServerGroup
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.TargetServerGroup
    Get-AgentTargetServerGroup returns a Microsoft.SqlServer.Management.Smo.Agent.TargetServerGroup object.
.EXAMPLE
Get-AgentTargetServerGroup "Z002\sql2K8"
This command gets a collection of TargetServerGroup objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentTargetServerGroup
#>
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
<#
.SYNOPSIS
Gets an TargetServer object or collection of TargetServer objects.
.DESCRIPTION
The Get-AgentTargetServer function  gets an TargetServer object or a collection of TargetServer objects for the specified server.
.INPUTS
None
    You cannot pipe objects to Get-AgentTargetServer
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.TargetServer
    Get-AgentTargetServer returns a Microsoft.SqlServer.Management.Smo.Agent.TargetServer object.
.EXAMPLE
Get-AgentTargetServer "Z002\sql2K8"
This command gets a collection of TargetServer objects for SQL Server Z002\SQL2K8.
.LINK
Get-AgentTargetServer
#>
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
<#
.SYNOPSIS
Sets filtering option used in Get-AgentJobHistory function.
.DESCRIPTION
The Set-AgentJobHistoryFilter function  gets an JobHistoryFilter object that then can be used by the Get-AgentJobHistory function.
.INPUTS
None
    You cannot pipe objects to Set-AgentJobHistoryFilter
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter
    Set-AgentJobHistoryFilter returns a Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter object.
.EXAMPLE
Get-AgentJobHistory "Z002\sql2k8" $(Set-AgentJobHistoryFilter -outcome 'Failed')
This command gets the job history for all failed jobs for SQL Server Z002\SQL2K8.
.LINK
Set-AgentJobHistoryFilter
Get-AgentJobHistory
#>
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
<#
.SYNOPSIS
Gets job history.
.DESCRIPTION
The Get-AgentJobHistory function  gets Job History for the specified server. Filtering can be applied by using the Set-AgentJobHistoryFilter function.
.INPUTS
None
    You cannot pipe objects to Get-AgentJobHistory
.OUTPUTS
System.Data.DataRow
    Get-AgentJobHistory returns a System.Data.DataRow
.EXAMPLE
Get-AgentJobHistory "Z002\sql2k8" $(Set-AgentJobHistoryFilter -outcome 'Failed')
This command gets the job history for all failed jobs for SQL Server Z002\SQL2K8.
.LINK
Get-AgentJobHistory
Set-AgentJobHistoryFilter
#>
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

