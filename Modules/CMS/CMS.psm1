# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Patrick Keisler
### </Author>
### <Description>
### Defines function wrappers around the classes to get access to a CMS server.
### </Description>
### </Script>
# ---------------------------------------------------------------------------

#Attempt to load assemblies by name starting with the latest version
try {
	Add-Type -AssemblyName "Microsoft.SqlServer.SMO, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop; $smoVersion = 13
	Add-Type -AssemblyName "Microsoft.SqlServer.Management.RegisteredServers, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
    Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
}
catch {
	try {
		Add-Type -AssemblyName "Microsoft.SqlServer.SMO, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop; $smoVersion = 12
		Add-Type -AssemblyName "Microsoft.SqlServer.Management.RegisteredServers, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
		Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
	}
	catch {
		try {
			Add-Type -AssemblyName "Microsoft.SqlServer.SMO, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop; $smoVersion = 11
			Add-Type -AssemblyName "Microsoft.SqlServer.Management.RegisteredServers, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
			Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
		}
		catch {
			try {
				Add-Type -AssemblyName "Microsoft.SqlServer.SMO, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop; $smoVersion = 10
				Add-Type -AssemblyName "Microsoft.SqlServer.Management.RegisteredServers, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
				Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
			}
			catch {
				Write-Warning "SMO components not installed. Download from https://goo.gl/E700bG"
				Break
			}
		}
	}
}

<#
No documentation yet.
#>
function Get-Errors ($Error) {
	if ($Error.GetType().Name -eq "String") {
		#Process an application error
		Write-Host "******************************"
		Write-Host "Error Count: 1"
		Write-Host "******************************"
		Write-Host $Error
		Throw
	}
	else {
		#Process a PowerShell error
		Write-Host "******************************"
		Write-Host "Error Count: $($Error.Count)"
		Write-Host "******************************"

		$error = $_.Exception
		Write-Host $error.Message
		$error = $error.InnerException
		while ($error.InnerException) {
			Write-Host $error.InnerException.Message
			$error = $error.InnerException
		}
		Throw
	}
} #Get-Errors

#######################
<#
.SYNOPSIS
Gets a ServerConnection.
.DESCRIPTION
The Get-SqlConnection function  gets a ServerConnection to the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlConnection 
.OUTPUTS
Microsoft.SqlServer.Management.Common.ServerConnection
    Get-SqlConnection returns a Microsoft.SqlServer.Management.Common.ServerConnection object.
.EXAMPLE
Get-SqlConnection "Z002\sql2K8"
This command gets a ServerConnection to SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlConnection "Z002\sql2K8" "sa" "Passw0rd"
This command gets a ServerConnection to SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-SqlConnection 
#>
function Get-SqlConnection
{
    param(
    [Parameter(Mandatory=$true)] [string]$sqlserver,
    [string]$username, 
    [string]$password,
	[Parameter(Mandatory=$false)] [string]$applicationName="SQLPSX"
    )

    Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password)
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver,$username,$password }
    else
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver }
	
	$con.ApplicationName = $applicationName
    $con.Connect()

    Write-Output $con
    
} #Get-ServerConnection

#######################
<#
.SYNOPSIS
Returns a list of SQL Servers from a CMS server.

.DESCRIPTION
Parses registered servers in CMS to return a list of SQL Servers for processing.

.INPUTS
None
    You cannot pipe objects to Get-CmsServers 

.OUTPUTS
Microsoft.SqlServer.Management.Smo.Server
    Get-CmsServers returns a PowerShell custom object.
 
.PARAMETER cmsServer
The name of the CMS SQL Server including instance name.

.PARAMETER cmsGroup
OPTIONAL. The name of a group (and path) in the CMS server.

.PARAMETER recurse
OPTIONAL. Return all servers that may exist in subfolders below cmsFolder.

.PARAMETER unique
OPTIONAL. Returns a unique list of servers. This is helpful if you have the same SQL server registered in multiple groups.

.NOTES
Includes code from Chrissy LeMarie (@cl).
https://blog.netnerds.net/smo-recipes/central-management-server/

.EXAMPLE
Get-CmsServers -cmsServer "SOLO\CMS"
Returns a list of all registered servers that on the CMS server.

.EXAMPLE
Get-CmsServers -cmsServer "SOLO\CMS" -cmsFolder "SQL2012" -recurse
Returns a list of all registered servers that are in the SQL2012 folder and any subfolders that exist below it.

.EXAMPLE
Get-CmsServers -cmsServer "SOLO\CMS" -cmsFolder "SQL2012\Cluster" -unique
Returns a list of all unique (distinct) registered servers that are in the folder for this exact path "SQL2012\Cluster".

.LINK
http://www.patrickkeisler.com/
#>
function Get-CmsServers {
	Param
	(
	[CmdletBinding()]
	[parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsServer,
	[parameter(Position=1)][String]$cmsGroup,
	[parameter(Position=2)][Switch]$recurse,
	[parameter(Position=3)][Switch]$unique
	) 

	switch ($cmsServer.GetType().Name) {
        'String' { 
		    try {
				$sqlConnection = Get-SqlConnection -sqlserver $cmsServer
				$cmsStore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlConnection)
			}
			catch {
				Get-Errors $_
			}
		}
        'RegisteredServersStore' { $cmsStore = $cmsServer }
        default { throw 'Get-CmsGroup:Param `$cmsStore must be a String or ServerConnection object.' }
    }

    Write-Verbose "Get-CmsServers $($cmsStore.DomainInstanceName) $cmsGroup $recurse $unique"

	############### Declarations ###############

    $collection = @()
    $newcollection = @()
    $serverList = @()
    $cmsFolder = $cmsGroup.Trim("\")

    ############### Functions ###############

    Function Parse-ServerGroup($serverGroup,$collection) {
		foreach ($instance in $serverGroup.RegisteredServers) {
			$urn = $serverGroup.Urn
			$group = $serverGroup.Name
			$fullGroupName = $null
 
			for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
				$groupName = $urn.XPathExpression[$i].GetAttributeFromFilter("Name")
				if ($groupName -eq "DatabaseEngineServerGroup") { $groupName = $null }
				if ($i -ne 0 -and $groupName -ne "DatabaseEngineServerGroup" -and $groupName.Length -gt 0 ) {
					$fullGroupName += "$groupName\"
				}
			}

			$object = New-Object PSObject -Property @{
				Server = $instance.ServerName
				Group = $groupName
				FullGroupPath = $fullGroupName
			}
			$collection += $object
		}
 
		foreach($group in $serverGroup.ServerGroups)
		{
			$newobject = (Parse-ServerGroup -serverGroup $group -collection $newcollection)
			$collection += $newobject     
		}
		return $collection
    }

    ############### Main Execution ###############

    #Get a list of all servers in the CMS store
    foreach ($serverGroup in $cmsStore.DatabaseEngineServerGroup) {  
        $serverList = Parse-ServerGroup -serverGroup $serverGroup -collection $newcollection
    }

    if($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {
        Write-Host -BackgroundColor Black -ForegroundColor Yellow "DEBUG OUTPUT:"
        $serverList
    }
    else {
        if(($cmsFolder.Split("\")).Count -gt 1) {
            if($recurse.IsPresent) {
                #Return ones in this folder and subfolders
                $cmsFolder = "*$cmsFolder\*"
                if($unique.IsPresent) {
                    $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server -Unique
                }
                else {
                    $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server
                }
            }
            else {
                #Return only the ones in this folder
                $cmsFolder = "$cmsFolder\"
                if($unique.IsPresent) {
                    $serverList | Where-Object {$_.FullGroupPath -eq $cmsFolder} | Select-Object Server -Unique
                }
                else {
                    $serverList | Where-Object {$_.FullGroupPath -eq $cmsFolder} | Select-Object Server
                }
            }
        }
        elseif (($cmsFolder.Split("\")).Count -eq 1 -and $cmsFolder.Length -ne 0) {
            if($recurse.IsPresent) {
                #Return ones in this folder and subfolders
                $cmsFolder = "*$cmsFolder\*"
                if($unique.IsPresent) {
                    $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server -Unique
                }
                else {
                    $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server
                }
            }
            else {
                #Return only the ones in this folder
                if($unique.IsPresent) {
                    $serverList | Where-Object {$_.Group -eq $cmsFolder} | Select-Object Server -Unique
                }
                else {
                    $serverList | Where-Object {$_.Group -eq $cmsFolder} | Select-Object Server
                }
            }
        }
        else {
            if($unique.IsPresent) {
                #Return all unique (distinct) servers
                $serverList | Select-Object Server -Unique
            }
            else {
                #Return all servers
                $serverList | Select-Object Server
            }
        }
    }
} #Get-CmsServers

#######################
<#
.SYNOPSIS
Returns a ServerGroup object from a CMS server.

.DESCRIPTION
Parses registered servers in CMS to return a list of SQL Servers for processing.

.INPUTS
None.
You cannot pipe objects to Get-CmsGroup 

.OUTPUTS
Microsoft.SqlServer.Management.RegisteredServers.ServerGroup
Get-CmsGroup returns a ServerGroup object.
 
.PARAMETER cmsServer
The name of the CMS SQL Server including instance name.

.PARAMETER cmsGroup
The name of a group (and path) in the CMS server.

.EXAMPLE
Get-CmsGroup -cmsServer "SOLO\CMS" -cmsGroup "SQL2012\Cluster\WebSite1"
Returns all subgroups and registered servers that are in the folder for this exact path "SQL2012\Cluster\WebSite1".

.LINK
http://www.patrickkeisler.com/
#>
function Get-CmsGroup {
    Param(
        [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsServer,
        [parameter(Position=1,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsGroup
    )

	switch ($cmsServer.GetType().Name) {
        'String' { 
		    try {
				$sqlConnection = Get-SqlConnection -sqlserver $cmsServer
				$cmsStore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlConnection)
			}
			catch {
				Get-Errors $_
			}
		}
        'RegisteredServersStore' { $cmsStore = $cmsServer }
        default { throw 'Get-CmsGroup:Param `$cmsStore must be a String or ServerConnection object.' }
    }

	switch ($cmsGroup.GetType().Name)
    {
        'String' { 
		    $serverGroups = $cmsStore.DatabaseEngineServerGroup
			$cmsFolders = $cmsGroup.Split("\")
		}
        'ServerGroup' {
			$serverGroups = $cmsGroup
			$cmsFolders = $cmsGroup.Name
		}
        default { throw 'Get-CmsGroup:Param `$cmsGroup must be a String or ServerGroup object.' }
    }

	foreach ($folder in $cmsFolders) {
        $serverGroups = $serverGroups.ServerGroups[$folder]
    } 
    $serverGroups
} #Get-CmsGroup

#######################
<#
.SYNOPSIS
Registers a SQL Server on a CMS server.

.DESCRIPTION
Registers a SQL Server on a CMS server in the folder path specified.

.INPUTS
None.
You cannot pipe objects to Add-CmsServer

.OUTPUTS
None.
 
.PARAMETER cmsServer
The name of the CMS SQL Server including instance name.

.PARAMETER cmsGroup
The name of a group (and path) in the CMS server.

.PARAMETER sqlServerName
The name of the SQL Server to register.

.PARAMETER displayName
OPTIONAL. The name of the SQL Server displayed in the CMS server.

.PARAMETER description
OPTIONAL. The description for the SQL Server.

.EXAMPLE
Add-CmsServer -cmsServer "SOLO\CMS" -cmsGroup "SQL2012\Cluster\WebSite1" -sqlServerName "CHEWIE\SQL01"
Registers "CHEWIE\SQL01" in the group "SQL2012\Cluster\WebSite1" on the "SOLO\CMS" CMS server.

.LINK
http://www.patrickkeisler.com/
#>
function Add-CmsServer {
    Param (
        [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsServer,
        [parameter(Position=1,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsGroup,
        [parameter(Position=2,Mandatory=$true)][ValidateNotNullOrEmpty()][string]$sqlServerName,
        [parameter(Position=3)][string]$displayName,
        [parameter(Position=4)][string]$description
    )
	switch ($cmsServer.GetType().Name) {
        'String' { 
		    try {
				$sqlConnection = Get-SqlConnection -sqlserver $cmsServer
				$cmsStore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlConnection)
			}
			catch {
				Get-Errors $_
			}
		}
        'RegisteredServersStore' { $cmsStore = $cmsServer }
        default { throw 'Add-CmsServer:Param `$cmsStore must be a String or ServerConnection object.' }
    }

	switch ($cmsGroup.GetType().Name)
    {
        'String' { $group = Get-CmsGroup -cmsServer $cmsStore -cmsGroup $cmsGroup }
        'ServerGroup' { $group = $cmsGroup }
        default { throw 'Add-CmsServer:Param `$cmsGroup must be a String or ServerGroup object.' }
    }

	#Set the display name if user did not specify it
    if(-not $displayName) { $displayName = $sqlServerName }

	#Register the SQL Server in the group
    if ($group.RegisteredServers.Name -notcontains $displayName) {
        $registeredServer = New-Object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServer($group, $displayName)
        $registeredServer.ServerName = $sqlServerName
        $registeredServer.Description = $description
		try {
			$registeredServer.Create()
		}
		catch {
			Get-Errors $_
		}
    }
    else {
		#Display a warning if the server is already registered in the group.
        Write-Warning "$displayName is already exists in group `"$($group.Name)`""
    }
} #Add-CmsServer

#######################
<#
.SYNOPSIS
Removes a SQL Server from a CMS server.

.DESCRIPTION
Removes a SQL Server from a CMS server in the folder path specified.

.INPUTS
None.
You cannot pipe objects to Add-CmsServer

.OUTPUTS
None.
 
.PARAMETER cmsServer
The name of the CMS SQL Server including instance name.

.PARAMETER cmsGroup
The name of a group (and path) in the CMS server where the SQL server exists.

.PARAMETER sqlServerName
The name of the SQL Server to remove.

.EXAMPLE
Remove-CmsServer -cmsServer "SOLO\CMS" -cmsGroup "SQL2012\Cluster\WebSite1" -sqlServerName "CHEWIE\SQL01"
Drops "CHEWIE\SQL01" from the group "SQL2012\Cluster\WebSite1" on the "SOLO\CMS" CMS server.

.LINK
http://www.patrickkeisler.com/
#>
function Remove-CmsServer {
    Param (
        [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsServer,
        [parameter(Position=1,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsGroup,
        [parameter(Position=2,Mandatory=$true)][ValidateNotNullOrEmpty()][string]$sqlServerName
    )
	switch ($cmsServer.GetType().Name) {
        'String' { 
		    try {
				$sqlConnection = Get-SqlConnection -sqlserver $cmsServer
				$cmsStore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlConnection)
			}
			catch {
				Get-Errors $_
			}
		}
        'RegisteredServersStore' { $cmsStore = $cmsServer }
        default { throw 'Remove-CmsServer:Param `$cmsStore must be a String or ServerConnection object.' }
    }

	switch ($cmsGroup.GetType().Name)
    {
        'String' { $group = Get-CmsGroup -cmsServer $cmsStore -cmsGroup $cmsGroup }
        'ServerGroup' { $group = $cmsGroup }
        default { throw 'Remove-CmsServer:Param `$cmsGroup must be a String or ServerGroup object.' }
    }

	#Drop the server from the group.
    if ($group.RegisteredServers.Name -contains $sqlServerName) {
		try {
            $group.RegisteredServers[$sqlServerName].Drop()
		}
		catch {
		    Get-Errors $_
        }
    }
    else {
		#Display a warning if the server does not exist in the group.
        Write-Warning "$sqlServerName does not exists in group `"$($group.Name)`""
    }
} #Remove-CmsServer
