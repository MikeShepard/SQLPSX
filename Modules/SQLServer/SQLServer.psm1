# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the SMO Classes and implements 2000 
### (80) versions of functions where the SMO class does not support SQL 2000.
### Also defines several utility functions: Get-SqlData, Set-SqlData and Get-SqlShowMbrs
### </Description>
### <Usage>
### . ./LibrarySmo.ps1
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
try {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"}

try {add-type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop; $smoVersion = 10}
catch {add-type -AssemblyName "Microsoft.SqlServer.Smo"; $smoVersion = 9}

try
{
    try {add-type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
    catch {add-type -AssemblyName "Microsoft.SqlServer.SMOExtended" -EA Stop}
}
catch {Write-Warning "SMOExtended not available"}

$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)

Set-Alias Get-InvalidLogins $scriptRoot\Get-InvalidLogins.ps1
Set-Alias Get-SessionTimeStamp $scriptRoot\Get-SessionTimeStamp.ps1

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
<#
.SYNOPSIS
Gets an SMO Server object.
.DESCRIPTION
The Get-SqlServer function  gets a SMO Server object for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlServer 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Server
    Get-SqlServer returns a Microsoft.SqlServer.Management.Smo.Server object.
.EXAMPLE
Get-SqlServer "Z002\sql2K8"
This command gets an SMO Server object for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlServer "Z002\sql2K8" "sa" "Passw0rd"
This command gets a SMO Server object for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-SqlServer 
#>
function Get-SqlServer
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password,
    [Parameter(Position=3, Mandatory=$false)] [string]$StatementTimeout=0
    )
    #When $sqlserver passed in from the SMO Name property, brackets
    #are automatically inserted which then need to be removed
    $sqlserver = $sqlserver -replace "\[|\]"

    Write-Verbose "Get-SqlServer $sqlserver"

    $con = Get-SqlConnection $sqlserver $Username $Password

    $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $con
    #Some operations might take longer than the default timeout of 600 seconnds (10 minutes). Set new default to unlimited
    $server.ConnectionContext.StatementTimeout = $StatementTimeout
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], "IsSystemObject")
    #trap { "Check $SqlServer Name"; continue} $server.ConnectionContext.Connect() 
    Write-Output $server
    
} #Get-SqlServer

#######################
<#
.SYNOPSIS
Gets an SMO Database object.
.DESCRIPTION
The Get-SqlDatabase function  gets an SMO Database object for the specified SQL Database or collection of Database objects.
.INPUTS
None
    You cannot pipe objects to Get-SqlDatabase 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Database
    Get-SqlDatabase returns a Microsoft.SqlServer.Management.Smo.Database object.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8"
This command gets a collection of SMO Database objects for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase $(Get-SqlServer "Z002\sql2K8" "sa" "Passw0rd") "pubs"
This command gets a SMO Database object for SQL database pubs on the SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-SqlDatabase 
#>
function Get-SqlDatabase
{ 
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$false)] [switch]$force
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlDatabase:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlDatabase $($server.Name) $dbname"

    if ($dbname)
    { if ($server.Databases.Contains("$dbname") -and $server.Databases[$dbname].IsAccessible)
        {$server.Databases[$dbname]} 
      else
        {throw "Database $dname does not exist or is not accessible."}
    }
    elseif ($force)
    { $server.Databases | where {$_.IsAccessible -eq $true} }
    #Skip systems databases
    else
    { $server.Databases | where {$_.IsSystemObject -eq $false -and $_.IsAccessible -eq $true} }

} # Get-SqlDatabase

#######################
<#
.SYNOPSIS
Executes a query and returns an array of System.Data.DataRow.
.DESCRIPTION
The Get-SqlData function executes a query and returns an array of System.Data.DataRow.
.INPUTS
None
    You cannot pipe objects to Get-SqlData 
.OUTPUTS
System.Data.DataRow
    Get-SqlData returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlData "Z002\sql2K8" "pubs" "select * from authors"
This command executes the specified SQL query using Windows authentication.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2K8" "sa" "Passw0rd"
Get-SqlData $server "pubs" "select * from authors"
This command executes the specified SQL query using SQL authentication.
.LINK
Get-SqlData 
#>
function Get-SqlData
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$qry
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Get-SqlData:Param '`$dbname' must be a String or Database object." }
    }

    #Write-Verbose "Get-SqlData $($database.Parent.Name) $($database.Name) $qry"
    Write-Verbose "Get-SqlData $($database.Parent.Name) $($database.Name)"

    $ds = $database.ExecuteWithResults("$qry")
    $ds.Tables | foreach { $_.Rows}    

}# Get-SqlData

#######################
<#
.SYNOPSIS
 Executes a query that does not return a result set.
.DESCRIPTION
The Set-SqlData function executes a query that does not return a result set.
.INPUTS
None
    You cannot pipe objects to Set-SqlData 
.OUTPUTS
None
    Set-SqlData does not produce any output.
.EXAMPLE
Set-SqlData "Z002\sql2K8" "pubs" "Update authors set au_lname = 'Brown' WHERE au_lname = 'White'"
This command executes the specified SQL query using Windows authentication.
.EXAMPLE
$server = Set-SqlServer "Z002\sql2K8" "sa" "Passw0rd"
Set-SqlData $server "pubs" "Update authors set au_lname = 'Brown' WHERE au_lname = 'White'"
This command executes the specified SQL query using SQL authentication.
.LINK
Set-SqlData 
#>
function Set-SqlData
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$qry
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Set-SqlData:Param '`$dbname' must be a String or Database object." }
    } 
    
    #Write-Verbose "Set-SqlData $($database.Parent.Name) $($database.Name) $qry"
    Write-Verbose "Set-SqlData $($database.Parent.Name) $($database.Name)"
    
    $database.ExecuteNonQuery("$qry")

}# Set-SqlData

#######################
function ConvertTo-MemberXml
{
    param($member)

    $xmlMember = $null
    $member | foreach { $xmlMember += "<member>$_</member>"}
    return $xmlMember

}# ConvertTo-MemberXml

#######################
<#
.SYNOPSIS
Recursively enumerates AD and local groups handling built-in SQL Server Windows groups.
.DESCRIPTION
The Get-SqlShowMbrs function recursively enumerates AD/local groups handling built-in SQL Server Windows groups.
.INPUTS
None
    You cannot pipe objects to Get-SqlShowMbrs 
.OUTPUTS
System.String
    Get-SqlShowMbrs returns an array of System.String.
.EXAMPLE
Get-SqlShowMbrs $(Get-SqlServer "Z002\sql2K8") "Z002\PayrollUsers"
This command gets a fully recursive list of members for the Windows group Z002\PayrollUsers.
.LINK
Get-SqlShowMbrs 
#>
function Get-SqlShowMbrs
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Server]$server,
    [Parameter(Position=1, Mandatory=$true)] [string]$group
    )

    Write-Verbose "Get-SqlShowMbrs $($server.Name) $group"

    New-ShowMbrs

    #The call to EnumWindowsGroupInfo will error out on groups which have been removed from AD or 
    #which have been renamed. We need to check for this condition when enumerating groups
    #Individual logins may also be orphaned so we will skip orphaned and enumerate the renamed group 
    #for renamed groups. As a best practice you should run Get-InvalidLogins to identifiy logins/groups and drop
    #orphaned logins or recreate renamed logins to maintain consistency with Active Directory
    $invalidLogin = @()
    Get-InvalidLogins $server.Name | foreach {$invalidLogin += $_.NTLogin}
    $renamed = @{}
    Get-InvalidLogins $server.Name | where {$_.IsRenamed -eq $true} | foreach {$renamed[$_.NTLogin] = $_.NewNTAccount}

    #if group is a valid login i.e. not in invalidLogin array then enumerate it
    if (!($invalidLogin -contains $group ))
    {
        #EnumWindowsGroupInfo is somewhat unreliable, for instance MyServer\SQLServer2005MSSQLUser$MyServer$Myinstance
        #will return null but using a WMI query will return group information. EnumWindowsGroupInfo does not work
        #for groups which have not been granted access to the SQ instnace. since we are using a global session variable
        #to store group user membership the Builtin group is not unique (all other group members should be i.e. a domain
        #or computer cannot have duplicate group names). So Builtin needs to be handled specially
        if ($group -eq 'BUILTIN\Administrators')
        {
           #if we've already enumerated Builtin perhaps for another server remove it and re-enumerate it
            $__SQLPSXGroupUser.remove('BUILTIN\Administrators')

            if ($server.Information.IsClustered)
            {   $allNodes = Get-WmiObject -class MSCluster_Node -namespace "root\mscluster" -computername $($server.Information.NetName) | select name
                foreach ($node in $allNodes)
                { Get-GroupUser "$($node.name)\Administrators" 'BUILTIN\Administrators'}}
            else

            { Get-GroupUser "$($server.Information.NetName)\Administrators" 'BUILTIN\Administrators'}
        }
        else
            { Get-GroupUser $group }
    }
    #if the group is invalid but has been renamed in AD thus still has access to SQL Server enumerate the new group name
    elseif ($renamed.Contains($group))
    {
        Get-GroupUser $renamed[$group]
    }

    return $__SQLPSXGroupUser[$group]

} #Get-SqlShowMbrs

#######################
<#
.SYNOPSIS
Gets an SMO User object.
.DESCRIPTION
The Get-SqlUser function  gets a collection of SMO User objects for the specified SQL Database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe database objects to Get-SqlUser 
.OUTPUTS
Microsoft.SqlUser.Management.Smo.User
    Get-SqlUser returns a Microsoft.SqlServer.Management.Smo.User object.
.NOTES
Additional properties including all of the objects owned by the user and the effective members of the user are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure.
.EXAMPLE
Get-SqlUser $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO User objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlUser
This command gets a collection SMO User objects for all SQL databases on the SQL Server Z002\SQL2K8.
.LINK
Get-SqlUser 
#>
function Get-SqlUser
{
   param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    process
    {
            foreach ($user in $database.Users | where {$_.UserType.ToString() -ne 'Certificate'})
            {
                $member = @()

                if ($user.HasDBAccess -and $user.Login) 
                {
                    $member += @($(Get-UserMember $user))
                    $object = $null

                    #Get objects owned by user, this part is slow with SQL 2000, In 2005 if user owns an object only the schema is listed
                    #as the owned object, so even though SQL 2000 does really doesn't have schemas, will just report they do.
                    if ($database.Parent.Information.Version.Major -ge 9)
                    {
                        foreach ($urn in $user.EnumOwnedObjects())
                        { 
                            $object += [string] "<Object ObjectType=`"" + $urn.Type+ "`" ObjectName=`"" + $urn.GetNameForType($urn.Type) + "`"></Object>"
                        }
                    }
                    elseif ($user.EnumOwnedObjects() -ne $null)
                    { $object += [string] "<Object ObjectType=`"Schema`" ObjectName=`"" + $user.Name + "`"></Object>" }

                    #Return SqlUser Object
                    $user | add-Member -memberType noteProperty -name members -value $member -passthru | 
                            add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                            add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                            add-Member -memberType noteProperty -name objects -value $object -passthru |
                            add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                            add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
                    
                }  
             }

    }

} # Get-SqlUser

#######################
function New-UserMember
{
    Write-Verbose "New-UserMember"

    #__SQLPSXUserMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXUserMember))
    { Set-Variable __SQLPSXUserMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-UserMember

#######################
function Get-UserMember
{
    param([Microsoft.SqlServer.Management.Smo.User]$user,[Microsoft.SqlServer.Management.Smo.Database]$database)

    Write-Verbose "Get-UserMember $($user.Name) $($database.Name)"

    New-UserMember

    if ($user)
    {
        $key = $null
        $key = "$($user.parent.parent.name).$($user.parent.name)"

        if(!($__SQLPSXUserMember.$key.$($user.Name))) {
            $member = @()
            $tmpMember = $null        
            if ($user.LoginType -eq 1)
            {
                if ($user.Login)
                { $tmpMember = Get-SqlShowMbrs $user.parent.parent $user.Login }
                if ($tmpMember -ne $null)
                 {$member += $tmpMember}
            }

            #If Guest user i.e. UserType = NoLogin
            if ($user.UserType.ToString() -eq 'NoLogin' -or $user.Name -eq 'guest')
            { $member += $user.Name }
            elseif ($member -notcontains $user.Login)
            { $member += $user.Login }
            #Add member to global hash
            $__SQLPSXUserMember[$key] += @{$user.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $($__SQLPSXUserMember).$($key).$($user.Name) }
    }
    elseif ($database)
    {
        $key = $null
        $key = "$($database.parent.name).$($database.name)"
        if(!($__SQLPSXUserMember[$key])) {
            Get-SqlUser $database > $null
            #Return User Hash
            $__SQLPSXUserMember[$key]
        }
        else
        #Return Login Hash
        { $__SQLPSXUserMember[$key] }
    }
    else
    { throw 'Get-UserMember:Param `$user or `$database missing.' }

} # Get-UserMember

#######################
<#
.SYNOPSIS
Returns a SMO DatabaseRole object with additional properties.
.DESCRIPTION
The Get-SqlDatabaseRole function  gets a collection of SMO DatabaseRole objects for the specified SQL Database. 
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe database objects to Get-SqlDatabaseRole 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.DatabaseRole
    Get-SqlDatabaseRole returns a Microsoft.SqlServer.Management.Smo.DatabaseRole object.
.NOTES
Additional properties are returned including the effective members of a role recursiving enumerates nested roles, and Windows Groups.
.EXAMPLE
Get-SqlDatabaseRole $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO DatabaseRole objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlDatabaseRole
This command gets a collection SMO DatabaseRole objects for all SQL databases on the SQL Server Z002\SQL2K8.
.LINK
Get-SqlDatabaseRole 
#>
function Get-SqlDatabaseRole
{
   param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    process
    {

        foreach ($role in $database.Roles)
        {
            $member = @()
            $member += @($(Get-DatabaseRoleMember $role))

            #Return DatabaseRole Object
            $role | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                    add-Member -memberType noteProperty -name members -value $member -passthru | 
                    add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
        }

    }
    

} #Get-SqlDatabaseRole

#######################
function New-DatabaseRoleMember
{
    Write-Verbose "New-DatabaseRoleMember"

    #__SQLPSXDatabaseRoleMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXDatabaseRoleMember))
    { Set-Variable __SQLPSXDatabaseRoleMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-DatabaseRoleMember

#######################
function Get-DatabaseRoleMember
{
    param([Microsoft.SqlServer.Management.Smo.DatabaseRole]$role,[Microsoft.SqlServer.Management.Smo.Database]$database)

    Write-Verbose "Get-DatabaseRoleMember $($role.Name) $($database.Name)"

    New-DatabaseRoleMember

    if ($role)
    {
        $key = $null
        $key = $role.parent.parent.name + "." + $role.parent.name

        if(!($__SQLPSXDatabaseRoleMember.$key.$($role.Name))) {
            $user = @{}
            $user = Get-UserMember -database $role.parent

            $member = @()
            $tmpMember = @()        

            #Although public is a role its members cannot be enumerated using EnumMembers()
            if (!($role.Name -eq "public"))
            {
                 #The EnumMembers() method will recursively (reports nested role members) enumerate role membership for you
                 #Thank You Microsoft SMO Developers!
                 #List only members that are Roles or valid users i.e. users which meet condition in get-sqluser, this will 
                 #eliminate users that do not have access to the database (orphaned DB users)
                 $tmpMember = $role.EnumMembers() | where { $role.parent.Roles.Contains($_) -or $user.Contains($_) }
                 if ($tmpMember -ne $null)
                 {$member += $tmpMember}
                 $member += $role.Name
                 #Now let's re-enumerate and flatten out Windows group membership, adding the SqlUser Objects members array
                 #However we will ensure we only list an individual login once
                 $member | where { $user.Contains($_) } | foreach { $member += $user[$_] }
                 $member = $member | Sort-Object -unique
                
            }
            #enumerate public role by extractng unique values from user hash
            else
            {
                $user.values | foreach { $member += $_ } 
                $member += $role.Name
                $member = $member | Sort-Object -unique
            }
            #Add member to global hash
            $__SQLPSXDatabaseRoleMember[$key] += @{$role.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $__SQLPSXDatabaseRoleMember.$key.$($role.Name) }
    }
    elseif ($database)
    {
        $key = $null
        $key = $database.parent.name + "." + $database.name
        if(!($__SQLPSXDatabaseRoleMember[$key])) {
            Get-SqlDatabaseRole $database > $null
            #Return User Hash
            $__SQLPSXDatabaseRoleMember[$key]
        }
        else
        #Return Login Hash
        { $__SQLPSXDatabaseRoleMember[$key] }
    }
    else
    { throw 'Get-DatabaseRoleMember:Param `$role or `$database missing' }

} # Get-DatabaseRoleMember

#######################
<#
.SYNOPSIS
Gets an SMO Login object.
.DESCRIPTION
The Get-SqlLogin function  gets a collection of SMO Login objects for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlLogin 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Login
    Get-SqlLogin returns a Microsoft.SqlServer.Management.Smo.Login object.
.NOTES
Additional properties including the effective members of the Login are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure.
.EXAMPLE
Get-SqlLogin "Z002\sql2K8"
This command gets a collection of SMO Login objects for SQL Server Z002\SQL2K8.
.LINK
Get-SqlLogin 
#>
function Get-SqlLogin
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlLogin $($server.Name)"

    foreach ($login in $server.Logins | where {$_.LoginType.ToString() -ne 'Certificate'})
    {
        $member = @()
        $member += @($(Get-LoginMember $login))

        #Return Login Object
        $login | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                 add-Member -memberType noteProperty -name members -value $member -passthru | 
                 add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                 add-Member -memberType noteProperty -name Server -value $server.Name -passthru

    }

} # Get-SqlLogin

#######################
<#
.SYNOPSIS
Gets an SMO LinkedServerLogin object.
.DESCRIPTION
The Get-SqlLinkedServerLogin function  gets a collection of SMO LinkedServerLogin objects for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlLinkedServerLogin 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.LinkedServerLogin
    Get-SqlLinkedServerLogin returns a Microsoft.SqlServer.Management.Smo.LinkedServerLogin object.
.NOTES
Additional properties including the DataSource property are returned.
.EXAMPLE
Get-SqlLinkedServerLogin "Z002\sql2K8"
This command gets a collection of SMO LinkedServerLogin objects for SQL Server Z002\SQL2K8.
.LINK
Get-SqlLinkedServerLogin 
#>
function Get-SqlLinkedServerLogin
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlLogin $($server.Name)"

    foreach ($linkedSrv in $server.LinkedServers)
    {
        #Some DataSources contains commas such as "myserver.mydomain.com,1433"
        #This can cause problems when exporting to csv so replace , with ;
        $dataSource = $linkedSrv.DataSource -replace ",",";"

        foreach ($linkedSrvLogin in $linkedSrv.LinkedServerLogins)
        {
        #Return linked Server Login Object
        $linkedSrvLogin | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                          add-Member -memberType noteProperty -name LinkedServer -value $linkedSrv.Name -passthru |
                          add-Member -memberType noteProperty -name DataSource -value $dataSource -passthru |
                          add-Member -memberType noteProperty -name Server -value $server.Name -passthru
        }
    }
}# Get-SqlLinkedServerLogin

#######################
function New-LoginMember
{
    Write-Verbose "New-LoginMember"

    #__SQLPSXLoginMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXLoginMember))
    { Set-Variable __SQLPSXLoginMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-LoginMember

#######################
function Get-LoginMember
{
    param([Microsoft.SqlServer.Management.Smo.Login]$login,[Microsoft.SqlServer.Management.Smo.Server]$server)

    Write-Verbose "Get-LoginMember $($login.Name) $($server.Name)"

    New-LoginMember

    if ($login)
    {
        if(!($__SQLPSXLoginMember.$($login.parent.name).$($login.Name))) {
            $member = @()
            $tmpMember = $null        
            if ($login.LoginType -eq 1)
            {
                $tmpMember = Get-SqlShowMbrs $login.parent $login.Name
                if ($tmpMember -ne $null)
                 {$member += $tmpMember}
            }

            if ($member -notcontains $login.Name)
            { $member += $login.Name }
            #Add member to global hash
            $__SQLPSXLoginMember[$login.parent.name] += @{$login.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $__SQLPSXLoginMember.$($login.parent.name).$($login.Name) }

    }
    elseif ($server)
    {
        if(!($__SQLPSXLoginMember[$server.name])) {
            Get-SqlLogin $server > $null
            #Return Login Hash
            $__SQLPSXLoginMember[$server.name]
        }
        else
        #Return Login Hash
        { $__SQLPSXLoginMember[$server.name] }
    }
    else
    { throw 'Get-LoginMember:Param `$login or `$server missing.' }

} # Get-LoginMember

#######################
<#
.SYNOPSIS
Gets an SMO ServerRole object.
.DESCRIPTION
The Get-SqlServerRole function  gets a collection of SMO ServerRole objects for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlServerRole 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.ServerRole
    Get-SqlServerRole returns a Microsoft.SqlServer.Management.Smo.ServerRole object.
.NOTES
Additional properties including the effective members of the ServerRole are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure.
.EXAMPLE
Get-SqlServerRole "Z002\sql2K8"
This command gets a collection of SMO ServerRole objects for SQL Server Z002\SQL2K8.
.LINK
Get-SqlServerRole 
#>
function Get-SqlServerRole
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlServerRole:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlServerRole $($server.Name)"

    $login = @{}
    $login = Get-LoginMember -server $server
 
    foreach ($svrole in $server.Roles)
    {
        $member = @()
        
        #Although public is a role its members cannot be enumerated using EnumServerRoleMembers()
        if (!($svrole.Name -eq "public"))
        {
            #EnumMembers and flatten out Windows group membership, adding the Sqllogin Objects members array
            #However we will ensure we only list an individual login once
            $svrole.EnumServerRoleMembers() | foreach {$login.$_} | foreach {if (!($member -contains $_)) {$member += $_}}
        }
        #enumerate public role by extractng unique values from login hash
        else
        {
            $login.values | foreach { $member += $_ }
            $member = $member | Sort-Object -unique
        }

        $member += $svrole.Name

        #Return ServerRole Object
        $svrole | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                  add-Member -memberType noteProperty -name members -value $member -passthru | 
                  add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                  add-Member -memberType noteProperty -name Server -value $server.Name -passthru
    }

} #Get-SqlServerRole

#######################
<#
.SYNOPSIS
Gets an SMO ServerPermissionInfo object.
.DESCRIPTION
The Get-SqlServerPermission function  gets a collection of SMO ServerPermissionInfo objects for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlServerPermission 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.ServerPermissionInfo
    Get-SqlServerPermission returns a Microsoft.SqlServer.Management.Smo.ServerPermissionInfo object.
.NOTES
Additional properties including the effective members of the ServerPermissionInfo are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure. There are only three grantable permissions only applicable to the master database: CREATE DATABASE; BACKUP DATABASE; BACKUP LOG. These permission are included in the output. SQL 2000 does not support this SMO method, instead a System.DataRow is returned of master database permissions.
.EXAMPLE
Get-SqlServerPermission "Z002\sql2K8"
This command gets a collection of SMO ServerPermissionInfo objects for SQL Server Z002\SQL2K8.
.LINK
Get-SqlServerPermission 
#>
function Get-SqlServerPermission
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlServerPermission:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlServerPermission $($server.Name)"

    if ($server.Information.Version.Major -ge 9)
    {$perm = Get-ServerPermission90 $server; $perm += Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master'); $perm}
    else {Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master')}

}# Get-SqlServerPermission

#######################
function Get-ServerPermission90
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Server]$server
    )

    Write-Verbose "Get-ServerPermission90 $($server.Name)"
    
    #SQL 2000 Does not suppport the concept of Server Permissions. SQL Server 2000 relies on Server Roles to grant server level permissions
    #There are only three grantable permissions in SQL 2000/2005 only applicable to the master database: CREATE DATABASE; BACKUP DATABASE; BACKUP LOG
    #Although we may think Create Database, Backup and Backup Log are server level permissions the SQL development team apparently does not
    #share the same opinion and EnumServerPermissions will not enumerate these permissions.
    #since I think they should I'll create a custom object and append to accomplish this in Get-SqlServerPermission

    $principal = @{}
    #Get-SqlLogin $server | foreach  { $principal[$_.Name] = $_.members }
    $principal = Get-LoginMember -server $server

        #Apparently having a login to SQL Server is considered a ServePermission in SQL 2005, all logins have this permission
        #I'd rather eliminate the CONNECT SQL permissionType from the output
      foreach ($perm in $server.EnumServerPermissions() | where {$_.PermissionType.ToString() -ne 'CONNECT SQL'})
      {
        $member = @()
        $member = $principal["$($perm.Grantee)"]
        #Return ServerPermission Object
        $perm | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                   add-Member -memberType noteProperty -name members -value $member -passthru | 
                   add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                   add-Member -memberType noteProperty -name dbname 'master' -passthru |
                   add-Member -memberType noteProperty -name Server -value $server.Name -passthru
      }
} #Get-ServerPermission90

#######################
function Get-Permission80
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    Write-Verbose "Get-Permission80 $($database.Name)"

$qry = @"
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.protecttype WHEN 204 THEN 'GRANT_W_GRANT' WHEN 205 THEN 'GRANT' WHEN 206 THEN 'DENY' END AS [PermissionState],
CASE prmssn.id WHEN 0 THEN 'Database' ELSE 'ObjectOrColumn' END  AS [ObjectClass],
null AS [ColumnName],
CASE prmssn.id WHEN 0 THEN DB_NAME() ELSE object_name(prmssn.id) END AS [ObjectName],
user_name(prmssn.uid) AS [ObjectSchema],
CASE prmssn.id WHEN 0 THEN DB_ID() ELSE prmssn.id END AS [ObjectID],
CASE 
	WHEN 1 = grantee_principal.issqlrole THEN 'DatabaseRole'
	WHEN 1 = grantee_principal.isapprole THEN 'ApplicationRole'
	ELSE 'User'
END AS [GranteeType],
CASE
	WHEN 1 = grantor_principal.issqlrole THEN 'DatabaseRole'
	WHEN 1 = grantor_principal.isapprole THEN 'ApplicationRole'
	ELSE 'User'
END AS [GrantorType],
CASE CAST(prmssn.action AS int) 
	WHEN 26 THEN 'REFERENCES'
	WHEN 178 THEN 'CREATE FUNCTION'
	WHEN 193 THEN 'SELECT'
	WHEN 195 THEN 'INSERT'
	WHEN 196 THEN 'DELETE'
	WHEN 197 THEN 'UPDATE'
	WHEN 198 THEN 'CREATE TABLE'
	WHEN 203 THEN 'CREATE DATABASE'
	WHEN 207 THEN 'CREATE VIEW'
	WHEN 222 THEN 'CREATE PROCEDURE'
	WHEN 224 THEN 'EXECUTE'
	WHEN 228 THEN 'BACKUP DATABASE'
	WHEN 233 THEN 'CREATE DEFAULT'
	WHEN 235 THEN 'BACKUP LOG'
	WHEN 236 THEN 'CREATE RULE'
END AS [PermissionType]
FROM
dbo.sysprotects AS prmssn
INNER JOIN sysusers AS grantee_principal ON grantee_principal.uid = prmssn.uid
INNER JOIN sysusers AS grantor_principal ON grantor_principal.uid = prmssn.grantor
WHERE (prmssn.id > 0 AND OBJECTPROPERTY(prmssn.id,'IsMSShipped') = 0)
OR prmssn.id = 0
"@
    Get-SqlData -dbname $database -qry $qry

}# Get-Permission80

# Note: From BOL "sp_helprotect does not return information about securables that are introduced in SQL Server 2005."
# The output of 90 and 80 versions of Get-SqlDatabasePermission and Get-SqlObjectPermissions will not match when 
# run against a SQL 2005 or higher server
#######################
<#
.SYNOPSIS
Gets an SMO DatabasePermissionInfo object.
.DESCRIPTION
The Get-SqlDatabasePermission function  gets a collection of SMO DatabasePermissionInfo objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlDatabasePermission 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.DatabasePermissionInfo
    Get-SqlDatabasePermission returns a Microsoft.SqlServer.Management.Smo.DatabasePermissionInfo object.
.NOTES
Additional properties including the effective members of the DatabasePermissionInfo are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure. SQL 2000 does not support this SMO method, instead a System.DataRow is returned of database permissions.
.EXAMPLE
Get-SqlDatabasePermission $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO DatabasePermissionInfo objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlDatabasePermission
This command gets a collection of SMO DatabasePermissionInfo objects for all user databases on SQL Server Z002\SQL2K8.
.LINK
Get-SqlDatabasePermission 
#>
function Get-SqlDatabasePermission
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    begin
    {
        #######################
        function Select-SqlDatabasePermission90 ($database)
        {
                Write-Verbose "Get-SqlDatabasePermission90 $($database.Name)"

                $user = @{}
                $role = @{}
                $user = Get-UserMember -database $database
                $role = Get-DatabaseRoleMember -database $database
                #Unfortunately on case sensitive servers you can have a role and user with the same name. So instead of using a single hash called
                #principal we will use two different hashes and use the GranteeType to determine which one to use for listing the effective members
                #of the permission.

            foreach ($perm in $database.EnumDatabasePermissions() | where {$_.PermissionType.ToString() -ne 'CONNECT'})
            {
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return DatabasePermission Object
                $perm | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                          add-Member -memberType noteProperty -name members -value $member -passthru | 
                          add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                          add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                          add-Member aliasproperty dbname ObjectName -passthru
            }

        }# Select-SqlDatabasePermission90

        #######################
        function Select-SqlDatabasePermission80 ($database)
        {
                Write-Verbose "Get-SqlDatabasePermission80 $($database.Name)"

                $user = @{}
                $role = @{}
                $user = Get-UserMember -database $database
                $role = Get-DatabaseRoleMember -database $database

            foreach ($perm in Get-Permission80 $database | where {$_.ObjectClass -eq 'Database'})
            { 
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return DatabasePermission Object
                $perm | add-member -memberType NoteProperty -name timestamp  -value $(Get-SessionTimeStamp)  -passthru |
                          add-member -memberType NoteProperty -name members -value $member -passthru |
                          add-member -memberType NoteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                          add-member -memberType NoteProperty -name Server  -value $database.parent.Name -passthru |
                          add-member aliasproperty dbname  ObjectName -passthru
            }
            
        }# Select-SqlDatabasePermission80
    }
    process
    {
        if ($database.Parent.Information.Version.Major -ge 9)
        { Select-SqlDatabasePermission90 $database }
        else { Select-SqlDatabasePermission80 $database }
    }

}# Get-SqlServerPermission

#######################
<#
.SYNOPSIS
Gets an SMO ObjectPermissionInfo object.
.DESCRIPTION
The Get-SqlObjectPermission function  gets a collection of SMO ObjectPermissionInfo objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlObjectPermission 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.ObjectPermissionInfo
    Get-SqlObjectPermission returns a Microsoft.SqlServer.Management.Smo.ObjectPermissionInfo object.
.NOTES
Additional properties including the effective members of the ObjectPermissionInfo are returned. Nested AD/local groups are recursively enumerated and returned in a flat structure. SQL 2000 does not support this SMO method, instead a System.DataRow is returned of object permissions.
.EXAMPLE
Get-SqlObjectPermission $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO ObjectPermissionInfo objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlObjectPermission
This command gets a collection of SMO ObjectPermissionInfo objects for all user databases on SQL Server Z002\SQL2K8.
.LINK
Get-SqlObjectPermission 
#>
function Get-SqlObjectPermission
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    begin
    {
        #######################
        function Select-SqlObjectPermission90 ($database)
        {
            Write-Verbose "Get-SqlObjectPermission90 $($database.Name)"

            $user = @{}
            $role = @{}
            $user = Get-UserMember -database $database
            $role = Get-DatabaseRoleMember -database $database

            Write-Verbose "EnumObjectPermissions"

            #Skip object permissions for system objects i.e. ObjectID > 0
            #EnumObjectPermissions() will take a long time to return data for very large permission sets
            #in my testing a database with over 57,000 permission will take 10 min. 
            #dtproperties is an annoying little MS table used for DB diagrams it shows up as user table and
            #is automatically created when someone clicks on DB Diagrams in SSMS/EM, permissions default to public
            foreach ($perm in $database.EnumObjectPermissions() | where {$_.ObjectID -gt 0 -and $_.ObjectName -ne 'dtproperties'})
            {
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return ObjectPermission Object
                $perm |  add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                           add-Member -memberType noteProperty -name members -value $member -passthru |
                           add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                           add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                           add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }

        } #Select-SqlObjectPermission90

        #######################
        function Select-SqlObjectPermission80 ($database)
        {
            Write-Verbose "Get-SqlObjectPermission80 $($database.Name)"

            $user = @{}
            $role = @{}
            $user = Get-UserMember -database $database
            $role = Get-DatabaseRoleMember -database $database

            foreach ($perm in Get-Permission80 $database | where {$_.ObjectClass -eq 'ObjectOrColumn' -and $_.ObjectID -gt 0 -and $_.ObjectName -ne 'dtproperties'})
            { 
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return ObjectPermission Object
                $perm | add-member -memberType NoteProperty -name timestamp  -value $(Get-SessionTimeStamp)  -passthru |
                          add-member -memberType NoteProperty -name members -value $member -passthru |
                          add-member -memberType NoteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                          add-member -memberType NoteProperty -name Server  -value $database.parent.Name -passthru |
                          add-member -memberType NoteProperty -name dbname -value $database.name -passthru
            }

        } #Select-SqlObjectPermission80
    }
    process
    {
        if ($database.Parent.Information.Version.Major -ge 9)
        { Select-SqlObjectPermission90 $database }
        else { Select-SqlObjectPermission80 $database }
    }

}# Get-SqlObjectPermission

#######################
<#
.SYNOPSIS
Gets an SMO Table object.
.DESCRIPTION
The Get-SqlTable function  gets a collection of SMO Table objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlTable 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Table
    Get-SqlTable returns a Microsoft.SqlServer.Management.Smo.Table object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlTable $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO Table objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlTable
This command gets a collection of SMO Table objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlTable -name "authors"
This command gets an SMO Table object for the authors table in the pubs database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlTable 
#>
function Get-SqlTable
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force
    )

    process
    {
        if ($Name -and $Schema)
        { $tables = $Database.Tables.Item($Name,$Schema) }
        elseif ($Name)
        { $tables = $Database.Tables.Item($Name) }
        elseif ($Schema)
        { $tables = $Database.Tables | where-object {$_.Schema -eq "$Schema"} }
        else { $tables = $Database.Tables }

        foreach ($table in $tables)
        {
            if (($Force.IsPresent -or (-not($Force.IsPresent) -and $table.IsSystemObject -eq $false)) `
            -and  (-not($Include)  -or ($Include -and $table.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $table.name -notlike "$Exclude")))
            {
            #Return Table Object
            $table | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $table.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlTable

#######################
<#
.SYNOPSIS
Gets an SMO StoredProcedure object.
.DESCRIPTION
The Get-SqlStoredProcedure function  gets a collection of SMO StoredProcedure objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlStoredProcedure 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.StoredProcedure
    Get-SqlStoredProcedure returns a Microsoft.SqlServer.Management.Smo.StoredProcedure object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlStoredProcedure $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO StoredProcedure objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlStoredProcedure
This command gets a collection of SMO StoredProcedure objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlStoredProcedure -name "byroyalty"
This command gets an SMO StoredProcedure object for the byroyalty stored procedure in the pubs database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlStoredProcedure 
#>
function Get-SqlStoredProcedure
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force
    )

    process
    {
        if ($Name -and $Schema)
        { $storedProcedures = $Database.StoredProcedures.Item($Name,$Schema) }
        elseif ($Name)
        { $storedProcedures = $Database.StoredProcedures.Item($Name) }
        elseif ($Schema)
        { $storedProcedures = $Database.StoredProcedures | where-object {$_.Schema -eq "$Schema"} }
        else { $storedProcedures = $Database.StoredProcedures }

        foreach ($storedProcedure in $storedProcedures)
        {
            if (($Force.IsPresent -or (-not($Force.IsPresent) -and $storedProcedure.IsSystemObject -eq $false)) `
            -and  (-not($Include)  -or ($Include -and $storedProcedure.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $storedProcedure.name -notlike "$Exclude")))
            {
            #Return StoredProcedure Object
            $storedProcedure | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
      add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $storedProcedure.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlStoredProcedure

#######################
<#
.SYNOPSIS
Gets an SMO View object.
.DESCRIPTION
The Get-SqlView function  gets a collection of SMO View objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlView 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.View
    Get-SqlView returns a Microsoft.SqlServer.Management.Smo.View object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlView $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO View objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlView
This command gets a collection of SMO View objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlView -name "titleview"
This command gets an SMO View object for the titleview view in the pubs database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlView 
#>
function Get-SqlView
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force
    )

    process
    {
        if ($Name -and $Schema)
        { $views = $Database.Views.Item($Name,$Schema) }
        elseif ($Name)
        { $views = $Database.Views.Item($Name) }
        elseif ($Schema)
        { $views = $Database.Views | where-object {$_.Schema -eq "$Schema"} }
        else { $views = $Database.Views }

        foreach ($view in $views)
        {
            if (($Force.IsPresent -or (-not($Force.IsPresent) -and $view.IsSystemObject -eq $false)) `
            -and  (-not($Include)  -or ($Include -and $view.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $view.name -notlike "$Exclude")))
            {
            #Return View Object
            $view | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
              add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $view.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlView

#######################
<#
.SYNOPSIS
Gets an SMO UserDefinedDataType object.
.DESCRIPTION
The Get-SqlUserDefinedDataType function  gets a collection of SMO UserDefinedDataType objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlUserDefinedDataType 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.UserDefinedDataType
    Get-SqlUserDefinedDataType returns a Microsoft.SqlServer.Management.Smo.UserDefinedDataType object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlUserDefinedDataType $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO UserDefinedDataType objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlUserDefinedDataType
This command gets a collection of SMO UserDefinedDataType objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlUserDefinedDataType -name "empid"
This command gets an SMO UserDefinedDataType object for the empid user defined dataType in the pubs database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlUserDefinedDataType 
#>
function Get-SqlUserDefinedDataType
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude
    )

    process
    {
        if ($Name -and $Schema)
        { $userDefinedDataTypes = $Database.UserDefinedDataTypes.Item($Name,$Schema) }
        elseif ($Name)
        { $userDefinedDataTypes = $Database.UserDefinedDataTypes.Item($Name) }
        elseif ($Schema)
        { $userDefinedDataTypes = $Database.UserDefinedDataTypes | where-object {$_.Schema -eq "$Schema"} }
        else { $userDefinedDataTypes = $Database.UserDefinedDataTypes }

        foreach ($userDefinedDataType in $userDefinedDataTypes)
        {
            if ((-not($Include)  -or ($Include -and $userDefinedDataType.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $userDefinedDataType.name -notlike "$Exclude")))
            {
            #Return UserDefinedDataType Object
            $userDefinedDataType | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedDataType.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlUserDefinedDataType

#######################
<#
.SYNOPSIS
Gets an SMO UserDefinedFunction object.
.DESCRIPTION
The Get-SqlUserDefinedFunction function  gets a collection of SMO UserDefinedFunction objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlUserDefinedFunction 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.UserDefinedFunction
    Get-SqlUserDefinedFunction returns a Microsoft.SqlServer.Management.Smo.UserDefinedFunction object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlUserDefinedFunction $(Get-SqlDatabase "Z002\sql2K8" AdventureWorks)
This command gets a collection of SMO UserDefinedFunction objects for SQL Server Z002\SQL2K8, AdventureWorks database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlUserDefinedFunction
This command gets a collection of SMO UserDefinedFunction objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" AdventureWorks | Get-SqlUserDefinedFunction -name "ufnGetAccountingEndDate"
This command gets an SMO UserDefinedFunction object for the ufnGetAccountingEndDate user defined function in the AdventureWorks database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlUserDefinedFunction 
#>
function Get-SqlUserDefinedFunction
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force
    )

    process
    {
        if ($Name -and $Schema)
        { $userDefinedFunctions = $Database.UserDefinedFunctions.Item($Name,$Schema) }
        elseif ($Name)
        { $userDefinedFunctions = $Database.UserDefinedFunctions.Item($Name) }
        elseif ($Schema)
        { $userDefinedFunctions = $Database.UserDefinedFunctions | where-object {$_.Schema -eq "$Schema"} }
        else { $userDefinedFunctions = $Database.UserDefinedFunctions }

        foreach ($userDefinedFunction in $userDefinedFunctions)
        {
            if (($Force.IsPresent -or (-not($Force.IsPresent) -and $userDefinedFunction.IsSystemObject -eq $false)) `
            -and  (-not($Include)  -or ($Include -and $userDefinedFunction.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $userDefinedFunction.name -notlike "$Exclude")))
            {
            #Return UserDefinedFunction Object
            $userDefinedFunction | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedFunction.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlUserDefinedFunction

#######################
<#
.SYNOPSIS
Gets an SMO Synonym object.
.DESCRIPTION
The Get-SqlSynonym function  gets a collection of SMO Synonym objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlSynonym 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Synonym
    Get-SqlSynonym returns a Microsoft.SqlServer.Management.Smo.Synonym object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlSynonym $(Get-SqlDatabase "Z002\sql2K8" AdventureWorks)
This command gets a collection of SMO Synonym objects for SQL Server Z002\SQL2K8, AdventureWorks database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlSynonym
This command gets a collection of SMO Synonym objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" AdventureWorks | Get-SqlSynonym -name "GrossRevenue"
This command gets an SMO Synonym object for the GrossRevenue synonym in the AdventureWorks database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlSynonym 
#>
function Get-SqlSynonym
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$Database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=2, Mandatory=$false)] [String]$Schema,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force
    )

    process
    {
        if ($Name -and $Schema)
        { $synonyms = $Database.Synonyms.Item($Name,$Schema) }
        elseif ($Name)
        { $synonyms = $Database.Synonyms.Item($Name) }
        elseif ($Schema)
        { $synonyms = $Database.Synonyms | where-object {$_.Schema -eq "$Schema"} }
        else { $synonyms = $Database.Synonyms }

        foreach ($synonym in $synonyms)
        {
            if ((-not($Include)  -or ($Include -and $synonym.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $synonym.name -notlike "$Exclude")))
            {
            #Return Synonym Object
            $synonym | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
              add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $synonym.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $Database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $Database.Name -passthru
            }
        }
    }

} #Get-SqlSynonym

#######################
<#
.SYNOPSIS
Gets an SMO Trigger object.
.DESCRIPTION
The Get-SqlTrigger function  gets a collection of SMO Trigger objects for the specified smo object.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database or
Microsoft.SqlServer.Management.Smo.Server or
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlTrigger 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Trigger or
Microsoft.SqlServer.Management.Smo.DatabaseDdlTrigger or
Microsoft.SqlServer.Management.Smo.ServerDdlTrigger
    Get-SqlTrigger returns a Microsoft.SqlServer.Management.Smo.Trigger/DatabaseDdlTrigger/ServerDdlTrigger object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. The output type depends on whether a server, database or table/view object is passed to the smo parameter.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" "pubs" | Get-SqlTrigger -name tr_MStran_alterview 
This command gets the SMO database Trigger, tr_MStran_alterview for SQL Server Z002\SQL2K8, AdventureWorks database.
.EXAMPLE
 Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlTable | Get-SqlTrigger
This command gets a collection of SMO Trigger objects for all user tables in the pubs database.
.LINK
Get-SqlTrigger 
#>
function Get-SqlTrigger
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] $smo,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude,
    [Switch] $Force

    )

    process
    {
        foreach ($trigger in $smo.Triggers)
        {
            if (($Force.IsPresent -or (-not($Force.IsPresent) -and $trigger.IsSystemObject -eq $false)) `
            -and  (-not($Include)  -or ($Include -and $trigger.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $trigger.name -notlike "$Exclude")))
            {
                switch ($smo.GetType().Name)
                {
                    'Server' { $server = $smo.Name }
                    'Database' { $server = $smo.parent.Name; $dbname = $smo.Name }
                    #Default is table or view
                    Default { $server = $smo.parent.parent.Name; $dbname = $smo.parent.Name; $schema = $smo.parent.schema; $tbl = $smo.Name }
                }
                #Return Trigger Object
                if ($trigger -ne $null)
                {
                $trigger | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $trigger.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $server -passthru |
                        add-Member -memberType noteProperty -name dbname -value $dbname -passthru |
                        add-Member -memberType noteProperty -name Schema -value $schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $tbl -passthru 
                }
            }
        }

    }

} #Get-SqlTrigger

#######################
<#
.SYNOPSIS
Gets an SMO Column object.
.DESCRIPTION
The Get-SqlColumn function  gets a collection of SMO Column objects for the specified table or view.
.INPUTS
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlColumn 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Column
    Get-SqlColumn returns a Microsoft.SqlServer.Management.Smo.Column object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name "authors" | Get-SqlColumn
This command gets a collection of SMO Column objects for the authors table.
.LINK
Get-SqlColumn 
#>
function Get-SqlColumn
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View'})] $table
    )

    process
    {
        foreach ($column in $table.Columns)
        {
            #Return Column Object
            $column | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $column.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                    add-Member -memberType noteProperty -name Schema -value $table.schema -passthru |
                    add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
        }

    }

} #Get-SqlColumn

#######################
<#
.SYNOPSIS
Gets an SMO Index object.
.DESCRIPTION
The Get-SqlIndex function  gets a collection of SMO Index objects for the specified table or view.
.INPUTS
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlIndex 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Index
    Get-SqlIndex returns a Microsoft.SqlServer.Management.Smo.Index object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name "authors" | Get-SqlIndex
This command gets a collection of SMO Index objects for the authors table.
.LINK
Get-SqlIndex 
#>
function Get-SqlIndex
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View'})] $table
    )

    process
    {
        foreach ($index in $table.Indexes)
        {
            #Return Index Object
            $index | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $index.ExtendedProperties) -passthru |
  add-Member -memberType noteProperty -name XMLIndexedColumns -value $(ConvertTo-IndexedColumnXML $index.IndexedColumns) -passthru |
                    add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                    add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                    add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
        }

    }

} #Get-SqlIndex

#######################
<#
.SYNOPSIS
Gets an SMO Statistic object.
.DESCRIPTION
The Get-SqlStatistic function  gets a collection of SMO Statistic objects for the specified table or view.
.INPUTS
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlStatistic 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Statistic
    Get-SqlStatistic returns a Microsoft.SqlServer.Management.Smo.Statistic object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "Northwind" | Get-SqlTable | Get-SqlStatistic
This command gets a collection of SMO Statistic objects for all user tables in the Northwind database.
.LINK
Get-SqlStatistic 
#>
function Get-SqlStatistic
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View'})] $table
    )

    process
    {
        foreach ($statistic in $table.Statistics)
        {
            #Only return statistics not associated with indexes
            if ($statistic.IsFromIndexCreation -eq $false)
            {
            #Return Statistic Object
            $statistic | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $statistic.ExtendedProperties) -passthru |
            add-Member -memberType noteProperty -name XMLStatisticColumns -value $(ConvertTo-StatisticColumnXML $statistic.StatisticColumns) -passthru |
                    add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                    add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                    add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
            }
        }

    }

} #Get-SqlStatistic

#######################
<#
.SYNOPSIS
Gets an SMO Check object.
.DESCRIPTION
The Get-SqlCheck function  gets a collection of SMO Check objects for the specified table or view.
.INPUTS
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlCheck 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Check
    Get-SqlCheck returns a Microsoft.SqlServer.Management.Smo.Check object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable | Get-SqlCheck
This command gets a collection of SMO Check objects for all user tables in the pubs database.
.LINK
Get-SqlCheck 
#>
function Get-SqlCheck
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View'})] $table
    )

    process
    {
        foreach ($Check in $table.Checks)
        {
            #Return Check Object
            $Check | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $check.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                    add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                    add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
        }
    }

} #Get-SqlCheck

#######################
<#
.SYNOPSIS
Gets an SMO ForeignKey object.
.DESCRIPTION
The Get-SqlForeignKey function  gets a collection of SMO ForeignKey objects for the specified table or view.
.INPUTS
Microsoft.SqlServer.Management.Smo.Table or
Microsoft.SqlServer.Management.Smo.View
    You can pipe SMO objects to Get-SqlForeignKey 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.ForeignKey
    Get-SqlForeignKey returns a Microsoft.SqlServer.Management.Smo.ForeignKey object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable | Get-SqlForeignKey
This command gets a collection of SMO ForeignKey objects for all user tables in the pubs database.
.LINK
Get-SqlForeignKey 
#>
function Get-SqlForeignKey
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View'})] $table
    )

    process
    {
        foreach ($ForeignKey in $table.ForeignKeys)
        {
            #Return ForeignKey Object
            $ForeignKey | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
           add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $ForeignKey.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                    add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                    add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
        }
    }

} #Get-SqlForeignKey

#######################
<#
.SYNOPSIS
Creates a new Microsoft.SqlServer.Management.Smo.ScriptingOptions.
.DESCRIPTION
The New-SqlScriptingOptions function creates a new Microsoft.SqlServer.Management.Smo.ScriptingOptions. This class is used for setting various SMO scripting options.
.INPUTS
None
    You cannot pipe objects to New-SqlScriptingOptions
.OUTPUTS
Microsoft.SqlServer.Management.Smo.ScriptingOptions
    New-SqlScriptingOptions returns a Microsoft.SqlServer.Management.Smo.ScriptingOptions object.
.NOTES
ScriptingOptions can be used with Get-SqlScripter. See get-help Get-SqlScripter for additional information.
.EXAMPLE
$scriptingOptions = New-SqlScriptingOptions
This command creates a new SqlScriptingOptions object and assigns output to $scriptingOptions variable.
.LINK
New-SqlScriptingOptions
Get-SqlScripter
#>
function New-SqlScriptingOptions
{
    Write-Verbose "New-SqlScriptingOptions"

    New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions

} #New-SqlScriptingOptions

#######################
<#
.SYNOPSIS
Scripts an SMO object.
.DESCRIPTION
The Get-SqlScripter function  calls the script method for an SMO object(s).
.INPUTS
Microsoft.SqlServer.Management.Smo.*
    You can pipe SMO objects to Get-SqlScripter 
.OUTPUTS
System.String
    Get-SqlScripter returns an array System.String.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable | Get-SqlScripter
This command scripts out all user tables in the pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name "authors" | Get-SqlScripter
This command scripts out the authors table.
.EXAMPLE
$scriptingOptions = New-SqlScriptingOptions
$scriptingOptions.Permissions = $true
$scriptingOptions.IncludeIfNotExists = $true
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable | Get-SqlScripter -scriptingOptions $scriptingOptions
This command scripts out all users tables in the pubs database and passes a scriptingOptions.
.LINK
Get-SqlScripter 
New-SqlScriptingOptions
#>
function Get-SqlScripter
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Namespace -like "Microsoft.SqlServer.Management.Smo*"})] $smo,
    [Parameter(Position=1, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$scriptingOptions=$(New-SqlScriptingOptions)
    )

    process
    { $smo.Script($scriptingOptions) }

} #Get-SqlScripter

#######################
<#
.SYNOPSIS
Returns the result set from INFORMATION_SCHEMA.Tables for the specified database(s).
.DESCRIPTION
The Get-SqlInformation_Schema.Tables function returns the result set from Information_Schema.Tables for the specified database(s).
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe Database objects to Get-SqlInformation_Schema.Tables
.OUTPUTS
System.Data.DataRow
    Get-SqlInformation_Schema.Tables returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Tables
This command returns the result set from INFORMATION_SCHEMA.Tables for the pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Tables -name "authors"
This command returns the result set from INFORMATION_SCHEMA.Tables for the pubs database where the table name is like authors.
.LINK
Get-SqlInformation_Schema.Tables
#>
function Get-SqlInformation_Schema.Tables
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name='%'
    )

    process
    {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND TABLE_NAME LIKE '%$name%'
"@
            Get-SqlData -dbname $database -qry $qry
    }

} #Get-SqlInformation_Schema.Tables

#######################
<#
.SYNOPSIS
Returns the result set from INFORMATION_SCHEMA.Columns for the specified database(s).
.DESCRIPTION
The Get-SqlInformation_Schema.Columns function returns the result set from Information_Schema.Columns for the specified database(s).
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe Database objects to Get-SqlInformation_Schema.Columns
.OUTPUTS
System.Data.DataRow
    Get-SqlInformation_Schema.Columns returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Columns
This command returns the result set from INFORMATION_SCHEMA.Columns for the pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Columns -tblname "authors" -colname "au_fname"
This command returns the result set from INFORMATION_SCHEMA.Columns for the pubs database where the table name is like authors and the column name is like au_fname.
.LINK
Get-SqlInformation_Schema.Columns
#>
function Get-SqlInformation_Schema.Columns
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$tblname='%',
    [Parameter(Position=2, Mandatory=$false)] [String]$colname='%'
    )

    process
    {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME LIKE '%$tblname%'
AND COLUMN_NAME LIKE '%$colname%'
"@
            Get-SqlData -dbname $database -qry $qry
    }
} #Get-SqlInformation_Schema.Columns

#######################
<#
.SYNOPSIS
Returns the result set from INFORMATION_SCHEMA.Views for the specified database(s).
.DESCRIPTION
The Get-SqlInformation_Schema.Views function returns the result set from Information_Schema.Views for the specified database(s).
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe Database objects to Get-SqlInformation_Schema.Views
.OUTPUTS
System.Data.DataRow
    Get-SqlInformation_Schema.Views returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Views
This command returns the result set from INFORMATION_SCHEMA.Views for the pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Views -name "titleview"
This command returns the result set from INFORMATION_SCHEMA.Views for the pubs database where the view name is like titleview.
.LINK
Get-SqlInformation_Schema.Views
#>
function Get-SqlInformation_Schema.Views
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name='%'
    )

    process
    {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_NAME like '%$name%'
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
"@
            Get-SqlData -dbname $database -qry $qry
    }
} #Get-SqlInformation_Schema.Views

#######################
<#
.SYNOPSIS
Returns the result set from INFORMATION_SCHEMA.Routines for the specified database(s).
.DESCRIPTION
The Get-SqlInformation_Schema.Routines function returns the result set from Information_Schema.Routines for the specified database(s).
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe Database objects to Get-SqlInformation_Schema.Routines
.OUTPUTS
System.Data.DataRow
    Get-SqlInformation_Schema.Routines returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Routines
This command returns the result set from INFORMATION_SCHEMA.Routines for the pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-Information_Schema.Routines -name "reptq1"
This command returns the result set from INFORMATION_SCHEMA.Routines for the pubs database where the routine name is like reptq1.
.LINK
Get-SqlInformation_Schema.Routines
#>
function Get-SqlInformation_Schema.Routines
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name='%',
    [Parameter(Position=2, Mandatory=$false)] [String]$text='%'
    )

    process
    {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME NOT LIKE 'sp_%diagram%'
AND OBJECTPROPERTY(OBJECT_ID('['+ROUTINE_SCHEMA+'].['+ROUTINE_NAME+']'),'IsMSShipped') = 0
AND ROUTINE_NAME LIKE '%$name%'
AND ROUTINE_DEFINITION LIKE '%$text%'
"@
            Get-SqlData -dbname $database -qry $qry
    }
} #Get-SqlInformation_Schema.Routines

#######################
<#
.SYNOPSIS
Returns the result set from sysdatabases for the specified SQL server.
.DESCRIPTION
The Get-SqlSysDatabases function returns the result set from SysDatabases for the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Get-SqlSysDatabases
.OUTPUTS
System.Data.DataRow
    Get-SqlSysDatabases returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlSysDatabases "Z002\sql2k8"
This command returns the result set from SysDatabases for the Z002\sql2k8 SQL server.
.EXAMPLE
Get-SqlSysDatabases "Z002\sql2k8" -name "pubs"
This command returns the result set from SysDatabases where the database name is like pubs.
.LINK
Get-SqlSysDatabases
#>
function Get-SqlSysDatabases
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [String]$name='%'
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlSysDatabases:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlSysDatabases $($server.Name)"

    $database = Get-SqlDatabase $server 'master'
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, name FROM sysdatabases
WHERE name LIKE '%$name%'
"@
    Get-SqlData -dbname $database -qry $qry

} #Get-SqlSysDatabases

#######################
<#
.SYNOPSIS
Gets an SMO DataFile object.
.DESCRIPTION
The Get-SqlDataFile function  gets a collection of SMO DataFile objects for the database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlDataFile 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.DataFile
    Get-SqlDataFile returns a Microsoft.SqlServer.Management.Smo.DataFile object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlDataFile
This command gets a collection of SMO DataFile objects for all data files in the pubs database.
.LINK
Get-SqlDataFile 
#>
function Get-SqlDataFile
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    process
    {
        foreach ($dataFile in $database.FileGroups | % {$_.Files})
        {
            #Return DataFile Object
            $dataFile | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                    add-Member -memberType noteProperty -name FileGroup -value $dataFile.parent.Name -passthru |
                    add-Member -memberType noteProperty -name FreeSpace -value $($dataFile.Size - $dataFile.UsedSpace) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
        }
    }
} #Get-SqlDataFile

#######################
<#
.SYNOPSIS
Gets an SMO LogFile object.
.DESCRIPTION
The Get-SqlLogFile function  gets a collection of SMO LogFile objects for the database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlLogFile 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.LogFile
    Get-SqlLogFile returns a Microsoft.SqlServer.Management.Smo.LogFile object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlLogFile
This command gets a collection of SMO LogFile objects for all data files in the pubs database.
.LINK
Get-SqlLogFile 
#>
function Get-SqlLogFile
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    process
    {
        foreach ($logFile in $database.LogFiles)
        {
            #Return LogFile Object
            $logFile | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                    add-Member -memberType noteProperty -name FreeSpace -value $($logFile.Size - $logFile.UsedSpace) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
        }
    }
} #Get-SqlLogFile

#######################
<#
.SYNOPSIS
Returns a custom object with the Server name and version number.
.DESCRIPTION
The Get-SqlVersion function returns a custom object with the Server name and version number for the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Get-SqlVersion 
.OUTPUTS
Selected.Microsoft.SqlServer.Management.Smo.Information
    Get-SqlVersion returns a Selected.Microsoft.SqlServer.Management.Smo.Information object.
.EXAMPLE
Get-SqlVersion "Z002\sql2k8"
This command returns SQL version information for the Z002\sql2k8 SQL Server. 
.LINK
Get-SqlVersion 
#>
function Get-SqlVersion
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlVersion:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlVersion $($server.Name)"

    $server.information | Select @{name='Server';Expression={$server.Name}}, Version

}#Get-SqlVersion

#######################
<#
.SYNOPSIS
Uses SQL-DMO to return the port number of the specified SQL Server.
.DESCRIPTION
The Get-SqlPort function uses SQL-DMO to return the port number of the specified SQL Server for the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Get-SqlPort 
.OUTPUTS
System.Management.Automation.PSCustomObject
    Get-SqlPort returns a System.Management.Automation.PSCustomObject object.
.EXAMPLE
Get-SqlPort "Z002\sql2k8" "pubs"
This command returns SQL port information for the Z002\sql2k8 SQL Server. 
.LINK
Get-SqlPort 
#>
function Get-SqlPort
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$sqlserver
    )

    #This can be done using Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer,
    #but it has some severe limitations -- only support in 2005 or higher and must have a SQL 
    #instance installed locally, so back SQLDMO instead of SMO for this one

    $ErrorActionPreference = "Stop"
    try {   
            $dmoServer = New-Object -comobject "SQLDMO.SQLServer"
            $dmoServer.loginsecure = $true
            $dmoServer.connect($sqlserver)
            $tcpPort = $dmoServer.registry.tcpport
            $dmoServer.close()
            
            New-Object PSObject -Property @{Server = $sqlserver; TcpPort = $tcpPort}
    }
    catch {Write-Error "SQLDMO is not installed."}

}#Get-SqlPort

#######################
function ConvertTo-ExtendedPropertyXML
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $extendedProperty
    )

    Write-Verbose "ConvertTo-SqlExtendedPropertyXML"
    
    foreach ($xp in $extendedProperty)
    {
            if ($xp.Name -ne $null -and $xp.Value -ne $null)
            { $xpXML += [string] "<ExtendedProperty Name=`"" + $xp.Name + "`" Value=`"" + $xp.Value + "`"></ExtendedProperty>" }
    }

    Return $xpXML

} #ConvertTo-ExtendedPropertyXML

#######################
<#
.SYNOPSIS
Uses WMI to list all of the SQL Server related services along with the service state and service account.
.DESCRIPTION
The Get-Sql function uses WMI to list all of the SQL Server related services running on the specified computer along with the service state and service account.
.INPUTS
None
    You cannot pipe objects to Get-Sql 
.OUTPUTS
System.Management.Automation.PSCustomObject
    Get-Sql returns a System.Management.Automation.PSCustomObject object.
.EXAMPLE
Get-Sql "Z002"
This command returns SQL service information for the Z002 Server. 
.LINK
Get-Sql 
#>
function Get-Sql
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$computername
    )

    if((get-wmiobject win32_pingstatus -Filter "address='$computername'").protocoladdress) 
    {
        Get-WmiObject win32_service -computer $computername |
Where {($_.Name -Like "MSSQL*" -or $_.Name -Like "SQLAgent*" -or $_.Name -Like "SQLServer*" -or $_.Name -eq 'MSDTC') -and $_.Name -ne 'MSSQLServerADHelper'} | Select SystemName, Name, State, StartName
    }
} #Get-Sql

#######################
function ConvertTo-StatisticColumnXML
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $statisticColumn
    )

    Write-Verbose "ConvertTo-SqlStatisticColumnXML"
    
    foreach ($wa in $statisticColumn)
    {
        $waXML += [string] "<StatisticColumn Name=`"" + $wa.Name + "`"</StatisticColumn>"
    }

    Return $waXML

} #ConvertTo-StatisticColumnXML

#######################
function ConvertTo-IndexedColumnXML
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $indexedColumn
    )

    Write-Verbose "ConvertTo-SqlIndexedColumnXML"
    
    foreach ($ix in $indexedColumn)
    {
$ixXML += [string] "<IndexedColumn Name=`"" + $ix.Name + "`" Descending=`"" +$($ix.Descending.ToString()) + "`" IsComputed=`"" + $($ix.IsComputed.ToString())  + "`"</IndexedColumn>"
    }

    Return $ixXML

} #ConvertTo-IndexedColumnXML

#######################
<#
.SYNOPSIS
Performs a database consistency check.
.DESCRIPTION
The Invoke-SqlDatabaseCheck function performs a database consistency check of the specified database.
.INPUTS
None
    You can pipe SMO Database objects to Invoke-SqlDatabaseCheck 
.OUTPUTS
None
    This function does not generate any output.
.NOTES
Performs the equivalent of a DBCC CHECKDB.
.EXAMPLE
 Get-SqlDatabase "Z002\sql2k8" "pubs" | Invoke-SqlDatabaseCheck
This command performs a database consistency check of the pubs database. 
.LINK
Invoke-SqlDatabaseCheck 
#>
function Invoke-SqlDatabaseCheck
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    begin
    { $ErrorActionPreference = "Stop" }
    process
    {
        Write-Verbose "Invoke-SqlDatabaseCheck $($database.Name)"
        try   { $database.CheckTables('None') }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }
    }

} #Invoke-SqlDatabaseCheck

#######################
<#
.SYNOPSIS
Performs a reindex.
.DESCRIPTION
The Invoke-SqlIndexRebuild function performs a reindex operation on the specified index. 
.INPUTS
None
    You can pipe SMO Index objects to Invoke-SqlIndexRebuild 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name authors | Get-SqlIndex | Invoke-SqlIndexRebuild
This command performs a reinidex of the authors table
.LINK
Invoke-SqlIndexRebuild 
#>
function Invoke-SqlIndexRebuild
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Index]$index
    )

    begin
    { $ErrorActionPreference = "Stop" }
    process
    {
        Write-Verbose "Invoke-SqlIndexRebuild $($index.Name)"
        try   { $index.Rebuild() }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }
    }

} #Invoke-SqlIndexRebuild

#######################
<#
.SYNOPSIS
Defragments an index.
.DESCRIPTION
The Invoke-SqlIndexDefrag function defragments the specified index. 
.INPUTS
None
    You can pipe SMO Index objects to Invoke-SqlIndexDefrag 
.OUTPUTS
None
    This function does not generate any output.
.NOTES
Performs the equivalent of DBCC INDEXDEFRAG
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name authors | Get-SqlIndex | Invoke-SqlIndexDefrag
This command defragments the indexes of the authors table
.LINK
Invoke-SqlIndexDefrag 
#>
function Invoke-SqlIndexDefrag
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Index]$index
    )

    begin
    { $ErrorActionPreference = "Stop" }
    process
    {
        Write-Verbose "Invoke-SqlIndexDefrag $($index.Name)"
        try   { $index.Reorganize() }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }
    }

} #Invoke-SqlIndexDefrag

#######################
<#
.SYNOPSIS
Returns index fragmentation.
.DESCRIPTION
The Get-SqlIndexFragmentation function returns index fragmentation of the specified index. 
.INPUTS
None
    You can pipe SMO Index objects to Get-SqlIndexFragmentation 
.OUTPUTS
System.Data.DataRow
    Get-SqlIndexFragmentation returns an array of System.Data.DataRow.
.NOTES
Performs the equivalent of DBCC SHOWCONTIG
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name authors | Get-SqlIndex | Get-SqlIndexFragmentation
This command gets index fragmentation of the indexes of the authors table
.LINK
Get-SqlIndexFragmentation 
#>
function Get-SqlIndexFragmentation
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Index]$index
    )

    process
    {
        Write-Verbose "Get-SqlIndexFragmentation $($index.Name)"
        $index.EnumFragmentation()
    }

} #Get-SqlIndexFragmentation

#######################
<#
.SYNOPSIS
Updates statistics.
.DESCRIPTION
The Update-SqlStatistic function updates the specified statistic. 
.INPUTS
None
    You can pipe SMO Statistic objects to Update-SqlStatistic 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Get-SqlDatabase "Z002\sql2k8" "pubs" | Get-SqlTable -name authors | Get-SqlStatistic | Update-SqlStatistic
This command updates the SQL statistics of the authors table
.LINK
Update-SqlStatistic 
#>
function Update-SqlStatistic
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Statistic]$statistic,
    [Parameter(Position=1, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.StatisticsScanType]$scanType='Default',
    [Parameter(Position=2, Mandatory=$false)] [int]$sampleValue,
    [Parameter(Position=3, Mandatory=$false)] [switch]$recompute
    )

    begin
    { $ErrorActionPreference = "Stop" }
    process
    {
        Write-Verbose "Update-Statistic $($statistic.Name)"

        try {
            if ($sampleValue -and $recompute)
            { $statistic.Update($scanType, $sampleValue, $true) }
            elseif ($sampleValue)
            { $statistic.Update($scanType, $sampleValue) }
            else
            { $statistic.Update($scanType) }
        }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }
    }

} #Update-SqlStatistic

#######################
<#
.SYNOPSIS
Performs a SQL database or log backup.
.DESCRIPTION
The Invoke-SqlBackup function performs a SQL database or log backup of the specified database.
.INPUTS
None
    You cannot pipe objects to Invoke-SqlBackup 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Invoke-SqlBackup "Z002\sql2k8" "pubs"  "C:\sqlrec\pubs.bak"
This command backs up the pubs database to disk. 
.LINK
Invoke-SqlBackup 
#>
function Invoke-SqlBackup
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$filepath,
    [Parameter(Position=3, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.BackupActionType]$action='Database',
    [Parameter(Position=4, Mandatory=$false)] [string]$description='',
    [Parameter(Position=5, Mandatory=$false)] [string]$name='',
    [Parameter(Position=6, Mandatory=$false)] [switch]$force,
    [Parameter(Position=7, Mandatory=$false)] [switch]$incremental,
    [Parameter(Position=8, Mandatory=$false)] [switch]$copyOnly
    )

    $ErrorActionPreference = "Stop"

    #action can be Database or Log

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Invoke-SqlBackup:Param sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Invoke-SqlBackup $($server.Name) $dbname"

    $backup = new-object ("Microsoft.SqlServer.Management.Smo.Backup")
    $backupDevice = new-object ("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") $filepath, 'File'

    $backup.Action = $action
    $backup.BackupSetDescription = $description
    $backup.BackupSetName = $name
    if (!$server.Databases.Contains("$dbname")) {throw 'Database $dbname does not exist on $($server.Name).'}
    $backup.Database = $dbname
    $backup.Devices.Add($backupDevice) 
    $backup.Initialize = $($force.IsPresent)
    $backup.Incremental = $($incremental.IsPresent)
    if ($copyOnly)
    { if ($server.Information.Version.Major -ge 9 -and $smoVersion -ge 10) 
      { $backup.CopyOnly = $true }
      else
      { throw 'CopyOnly is supported in SQL Server 2005(9.0) or higher with SMO version 10.0 or higher.' }
    }
    
    $percentHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] {Write-Progress -activity "Backing up Database..." `
    -status "$($backup.Database)" -percentcomplete $($_.Percent); Write-Verbose "$($_.Percent) percent processed."}
    $backup.add_PercentComplete($percentHandler)

    $completeHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] {Write-Verbose "$($_.Error.Message)"}
    $backup.add_Complete($completeHandler)

    try { $backup.SqlBackup($server) }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }
    
} #Invoke-SqlBackup

#######################
<#
.SYNOPSIS
Performs a SQL database or log restore.
.DESCRIPTION
The Invoke-SqlRestore function performs a SQL database or log restore of the specified database.
.INPUTS
None
    You cannot pipe objects to Invoke-SqlRestore 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Invoke-SqlRestore "Z002\sql2k8" "pubs"  "C:\sqlrec\pubs.bak" -force
This command restores the pubs database from disk replacing the existing database if exists.
.EXAMPLE
Invoke-SqlRestore "Z002\sql2k8" "NorthwindTestRestore"  "C:\sqlrec\Northwind.bak" -relocatefiles @{Northwind='C:\Program Files\Microsoft SQL Server\MSSQL10.SQL2K8\MSSQL\DATA\northwnd2.mdf'; Northwind_log='C:\Program Files\Microsoft SQL Server\MSSQL10.SQL2K8\MSSQL\DATA\northwnd2.ldf'} -force
This command restores the Northwind database as NorthwindTestRestore, relocates database files by passing a hashtable of file names and replaces the existing database if exists.
.LINK
Invoke-SqlRestore 
#>
function Invoke-SqlRestore
{
    param(
    [CmdletBinding(DefaultParametersetName="Restore")]
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(ParameterSetName="Restore", Position=1, Mandatory=$true)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$filepath,
    [Parameter(ParameterSetName="Restore", Position=3, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.RestoreActionType]$action='Database',
    [Parameter(ParameterSetName="Restore", Position=4, Mandatory=$false)] [string]$stopat,
    [Parameter(ParameterSetName="Restore", Position=5, Mandatory=$false)] [hashtable]$relocatefiles,
    [Parameter(ParameterSetName="Restore", Position=6, Mandatory=$false)] [switch]$force,
    [Parameter(ParameterSetName="Restore", Position=7, Mandatory=$false)] [switch]$norecovery,
    [Parameter(ParameterSetName="Restore", Position=8, Mandatory=$false)] [switch]$keepreplication,
    [Parameter(ParameterSetName="FileList", Position=9, Mandatory=$false)] [switch]$FileListOnly
    )



    $ErrorActionPreference = "Stop"

    #action can be Database or Log

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Invoke-SqlRestore:Param sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Invoke-SqlRestore $($server.Name) $dbname"

    $restore = new-object ("Microsoft.SqlServer.Management.Smo.Restore")
    $restoreDevice = new-object ("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") $filepath, 'File'
    $restore.Devices.Add($restoreDevice)
    if ($FileListOnly)
    { 
        $restore.ReadFileList($server)
        return
    }
    $restore.Action = $action
    $restore.Database = $dbname
    $restore.ReplaceDatabase = $($force.IsPresent)
    $restore.NoRecovery = $($norecovery.IsPresent)
    $restore.KeepReplication = $($keepreplication.IsPresent)
   
    if ($stopat)
    { $restore.ToPointInTime = $stopAt }

    if ($relocatefiles)
    {
       foreach ($i in $relocatefiles.GetEnumerator())
        {
            $logicalName = $($i.Key); $physicalName = $($i.Value);
            $relocateFile = new-object ("Microsoft.SqlServer.Management.Smo.RelocateFile") $logicalName, $physicalName
            [void]$restore.RelocateFiles.Add($relocateFile)
        }
    }

    $percentHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] {Write-Progress -activity "Restoring Database..." `
    -status "$($restore.Database)" -percentcomplete $($_.Percent); Write-Verbose "$($_.Percent) percent processed."}
     $restore.add_PercentComplete($percentHandler)

    $completeHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] {Write-Verbose "$($_.Error.Message)"}
    $restore.add_Complete($completeHandler)

    try { $restore.SqlRestore($server) }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }
    
} #Invoke-SqlRestore

#######################
<#
.SYNOPSIS
Removes a database from a SQL Server.
.DESCRIPTION
The Remove-SqlDatabase function removes the specified database from SQL Server.
.INPUTS
None
    You cannot pipe objects to Remove-SqlDatabase 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlDatabase "Z002\sql2k8" "NorthwindTestRestore"
This command removes the NorthwindTestRestore database. 
.LINK
Remove-SqlDatabase 
#>
function Remove-SqlDatabase
{
    
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$dbname
    )
    
    $ErrorActionPreference = "Stop"

    $database = Get-SqlDatabase $sqlserver $dbname
    try { $database.Drop() }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

} #Remove-SqlDatabase

#######################
<#
.SYNOPSIS
Adds a new filegroup to a database.
.DESCRIPTION
The Add-SqlFileGroup function Adds a new filegroup to the specified database.
.INPUTS
None
    You cannot pipe objects to Add-SqlFileGroup 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.FileGroup
    Add-SqlFileGroup returns an Microsoft.SqlServer.Management.Smo.FileGroup object.
.NOTES
Add-SqlFileGroup is used by Add-SqlDatabase.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Add-SqlFileGroup $database 'FileGroup2'
$database.Alter()
This command adds the filegroup FileGroup2 to the pubs database. 
.LINK
Add-SqlFileGroup 
Add-SqlDatabase
Get-SqlDatabase
#>
function Add-SqlFileGroup
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$true)] [string]$name
    )

    $ErrorActionPreference = "Stop"

    $fileGroup = new-object ('Microsoft.SqlServer.Management.Smo.FileGroup') $database, $name
    
    try { $database.FileGroups.Add($fileGroup) }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

    Write-Output $fileGroup

} #Add-SqlFileGroup

#######################
<#
.SYNOPSIS
Adds a new dataFile to a filegroup.
.DESCRIPTION
The Add-SqlDataFile function adds a new DataFile to the specified filegroup.
.INPUTS
None
    You cannot pipe objects to Add-SqlDataFile 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.DataFile
    Add-SqlDataFile returns an Microsoft.SqlServer.Management.Smo.DataFile object.
.NOTES
Add-SqlDataFile is used by Add-SqlDatabase.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
$fileGroup = Add-SqlFileGroup $database 'FileGroup2'
Add-SqlDataFile -filegroup $fileGroup -name 'pubs_DataFile1'  -filepath 'C:\Program Files\Microsoft SQL Server\MSSQL10.SQL2K8\MSSQL\DATA\pubs_DataFile1.ndf'
$database.Alter()
This command adds the DataFile DataFile2 to the pubs database. 
.LINK
Add-SqlDataFile 
Add-SqlFileGroup
Add-SqlDatabase
Get-SqlDatabase
#>
function Add-SqlDataFile
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.FileGroup]$filegroup,
    [Parameter(Position=1, Mandatory=$true)] [string]$name,
    [Parameter(Position=2, Mandatory=$true)] [string]$filepath,
    [Parameter(Position=3, Mandatory=$false)] [double]$size,
    [Parameter(Position=4, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.FileGrowthType]$growthType,
    [Parameter(Position=5, Mandatory=$false)] [double]$growth,
    [Parameter(Position=6, Mandatory=$false)] [double]$maxSize
    )

    $ErrorActionPreference = "Stop"

    #GrowthType is KB, None, Percent
    $dataFile = new-object ('Microsoft.SqlServer.Management.Smo.DataFile') $filegroup, $name
    $dataFile.FileName = $filepath

    if ($size)
    { $dataFile.Size = $size }
    if ($growthType)
    { $dataFile.GrowthType = $growthType }
    if ($growth)
    { $dataFile.Growth = $growth }
    if ($maxSize)
    { $dataFile.MaxSize = $maxSize }

    try { $filegroup.Files.Add($dataFile) }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

} #Add-SqlDataFile

#######################
<#
.SYNOPSIS
Adds a new LogFile to a database.
.DESCRIPTION
The Add-SqlLogFile function adds a new LogFile to the specified database.
.INPUTS
None
    You cannot pipe objects to Add-SqlLogFile 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.LogFile
    Add-SqlLogFile returns an Microsoft.SqlServer.Management.Smo.LogFile object.
.NOTES
Add-SqlLogFile is used by Add-SqlDatabase.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Add-SqlLogFile -database $database -name 'pubs_LogFile1' -filepath 'C:\Program Files\Microsoft SQL Server\MSSQL10.SQL2K8\MSSQL\DATA\pubs_LogFile1.ldf'
$database.Alter()
This command adds the LogFile LogFile2 to the pubs database. 
.LINK
Add-SqlLogFile 
Add-SqlDatabase
Get-SqlDatabase
#>
function Add-SqlLogFile
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$true)] [string]$name,
    [Parameter(Position=2, Mandatory=$true)] [string]$filepath,
    [Parameter(Position=3, Mandatory=$false)] [double]$size,
    [Parameter(Position=4, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.FileGrowthType]$growthType,
    [Parameter(Position=5, Mandatory=$false)] [double]$growth,
    [Parameter(Position=6, Mandatory=$false)] [double]$maxSize
    )

    $ErrorActionPreference = "Stop"

    #GrowthType is KB, None, Percent
    $logFile = new-object ('Microsoft.SqlServer.Management.Smo.LogFile') $database, $name
    $logFile.FileName = $filepath
    if ($size)
    { $logFile.Size = $size }
    if ($growthType)
    { $logFile.GrowthType = $growthType }
    if ($growth)
    { $logFile.Growth = $growth }
    if ($maxSize)
    { $logFile.MaxSize = $maxSize }

    try { $database.LogFiles.Add($logFile) }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

} #Add-SqlLogFile

#######################
<#
.SYNOPSIS
Adds a new database to a SQL Server.
.DESCRIPTION
The Add-SqlDatabase function Adds a new database to the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Add-SqlDatabase 
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlDatabase "Z002\sql2k8" "NorthwindCopy"
This command adds the NorthwindCopy database to the Z002\sql2k8 server. 
.LINK
Add-SqlDatabase 
#>
function Add-SqlDatabase
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$false)] [string]$dataName,
    [Parameter(Position=3, Mandatory=$false)] [string]$dataFilePath,
    [Parameter(Position=4, Mandatory=$false)] [double]$dataSize,
    [Parameter(Position=5, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.FileGrowthType]$dataGrowthType='KB',
    [Parameter(Position=6, Mandatory=$false)] [double]$dataGrowth=1,
    [Parameter(Position=7, Mandatory=$false)] [double]$dataMaxSize,
    [Parameter(Position=8, Mandatory=$false)] [string]$logName,
    [Parameter(Position=9, Mandatory=$false)] [string]$logFilePath,
    [Parameter(Position=10, Mandatory=$false)] [double]$logSize,
    [Parameter(Position=11, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.FileGrowthType]$logGrowthType='Percent',
    [Parameter(Position=12, Mandatory=$false)] [double]$logGrowth=10,
    [Parameter(Position=13, Mandatory=$false)] [double]$logMaxSize
    )

    $ErrorActionPreference = "Stop"

    #GrowthType is KB, None, Percent
    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Add-SqlDatabase:Param sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Add-SqlDatabase $($server.Name) $dbname"

    if ($server.Databases.Contains("$dbname")) {throw 'Database $dbname already exists on $($server.Name).'}

    $database = new-object ('Microsoft.SqlServer.Management.Smo.Database') $server, $dbname

    #Need to implement overloaded method if migrated to compiled cmdlet

    if (!($logName))
    { $dataName = $dbname }
    if (!($dataFilePath))
    { $dataFilePath = $(Get-SqlDefaultDir $server 'Data') + '\' + $dbname + '.mdf' }
    if (!($logName))
    { $logName = $dbname + '_log' }
    if (!($logFilePath))
    { $logFilePath = $(Get-SqlDefaultDir $server 'Log') + '\' + $dbname + '_log.ldf' }

    $fileGroup = Add-SqlFileGroup $database 'PRIMARY'
Add-SqlDataFile -filegroup $fileGroup -name $dataName -filepath $dataFilePath -size $dataSize -growthtype $dataGrowthType -growth $dataGrowth -maxsize $dataMaxSize

Add-SqlLogFile -database $database -name $logName -filepath $logFilePath -size $logSize -growthtype $logGrowthType -growth $logGrowth -maxsize $logMaxSize

    try { $database.Create() }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

} #Add-SqlDatabase

#######################
<#
.SYNOPSIS
Returns the default location for data and log files for a SQL Server.
.DESCRIPTION
The Get-SqlDefaultDir function returns the default location for data and log files for the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-SqlDefaultDir 
.OUTPUTS
System.String
    Get-SqlDefaultDir returns a System.Stringt.
.NOTES
The DefaultFile and DefaultLog properties are only written to registry if you modify the properties in SSMS
even setting the properties to same value will create the registry keys. If the properties have not been created
Get-SqlDefaultDir will use the InstallDataDirectory properties. This seems to recreate how SSMS works.
.EXAMPLE
Get-SqlDefaultDir "Z002\sql2k8" "Data"
This command returns the default data directory for the Z002\sql2k8 server.
.EXAMPLE
Get-SqlDefaultDir "Z002\sql2k8" "Log"
This command returns the default log directory for the Z002\sql2k8 server.
.LINK
Get-SqlDefaultDir 
#>
function Get-SqlDefaultDir
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [ValidateSet("Data", "Log")]
    [Parameter(Position=1, Mandatory=$true)] [string]$dirtype
    )
    
    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlDefaultDir:Param sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlDefaultDir $($server.Name)"
    
    #I thought about adding this properties to the server object in Get-SqlServer, but felt it was important
    #not to mask whether the default directories had been set or not. You should always set the default directories as
    #a configuration task
    switch ($dirtype)
    {
        'Data'  { if ($server.DefaultFile) { $server.DefaultFile } else { $server.InstallDataDirectory + '\' + 'Data' } }
        'Log'   { if ($server.DefaultLog) { $server.DefaultLog } else { $server.InstallDataDirectory + '\' + 'Data' } }
    }

} #Get-SqlDefaultDir

#######################
<#
.SYNOPSIS
Adds a new user to a database.
.DESCRIPTION
The Add-SqlUser function adds a new user to the specified database.
.INPUTS
None
    You cannot pipe objects to Add-SqlUser
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlUser "Z002\sql2k8" "pubs" "TestPSUnit"
This command adds the TestPSUnit login to the pubs database.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Add-SqlUser -dbname $database "TestPSUnit"
This command adds the TestPSUnit login to the pubs database.
.LINK
Add-SqlUser 
#>
function Add-SqlUser
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name,
    [Parameter(Position=3, Mandatory=$false)] [string]$login=$name,
    [Parameter(Position=4, Mandatory=$false)] [string]$defaultSchema='dbo'
    )

    $ErrorActionPreference = "Stop"

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Add-SqlUser:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Add-SqlUser $($database.Name) $name"

    $user = new-object ('Microsoft.SqlServer.Management.Smo.User') $database, $name
    $user.Login = $login
	if ($db.parent.Information.Version.Major -ne '8')
	{ $user.DefaultSchema = $defaultschema }
    try { $user.Create() }
    catch {
            $ex = $_.Exception
            $message = $ex.message
            $ex = $ex.InnerException
            while ($ex.InnerException)
            {
                $message += "`n$ex.InnerException.message"
                $ex = $ex.InnerException
            }
            Write-Error $message
    }

} #Add-SqlUser

#######################
<#
.SYNOPSIS
Removes a user from a database.
.DESCRIPTION
The Remove-SqlUser function removes a user from the specified database.
.INPUTS
None
    You cannot pipe objects to Remove-SqlUser
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlUser "Z002\sql2k8" "pubs" "TestPSUnit"
This command Removes the TestPSUnit user from the pubs database.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Remove-SqlUser -dbname $database "TestPSUnit"
This command Removes the TestPSUnit user from the pubs database.
.LINK
Remove-SqlUser 
#>
function Remove-SqlUser
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Remove-SqlUser:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Remove-SqlUser $($database.Name) $name"

    $user = $database.Users[$name]
    if ($user)
    { $user.Drop() }
    else
    { throw "User $name does not exist in database $($database.Name)." }

} #Remove-SqlUser

#######################
<#
.SYNOPSIS
Adds a login to a SQL Server.
.DESCRIPTION
The Add-SqlLogin function adds a new login to the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Add-SqlLogin
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlLogin "Z002\sql2k8" "TestPSUnit" "SQLPSXTesting" 'SqlLogin' 
This command adds the TestPSUnit login to the Z002\sql2k8 server.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2k8"
Add-SqlLogin $server "TestPSUnit" "SQLPSXTesting" 'SqlLogin'
This command adds the TestPSUnit login to the Z002\sql2k8 server.
.LINK
Add-SqlLogin 
#>
function Add-SqlLogin
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$name,
    [Parameter(Position=2, Mandatory=$false)] [string]$password,
    [Parameter(Position=3, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.LoginType]$logintype='WindowsUser',
    [Parameter(Position=4, Mandatory=$false)] [string]$DefaultDatabase='master',
    [Parameter(Position=5, Mandatory=$false)] [switch]$PasswordExpirationEnabled,
    [Parameter(Position=6, Mandatory=$false)] [switch]$PasswordPolicyEnforced
    )

    $ErrorActionPreference = "Stop"

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Add-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlDatabase $($server.Name) $dbname"

    $login = new-object ('Microsoft.SqlServer.Management.Smo.Login') $server, $name
    $login.DefaultDatabase = $defaultDatabase

    if ($logintype -eq 'SqlLogin')
    {
        $login.LoginType = $logintype
        if ($server.Information.Version.Major -ne '8')
		{
			$login.PasswordExpirationEnabled = $($PasswordExpirationEnabled.IsPresent)
        	$login.PasswordPolicyEnforced = $($PasswordPolicyEnforced.IsPresent)
		}
        try { $login.Create($password) }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }
    }
    elseif ($logintype -eq 'WindowsUser' -or $logintype -eq 'WindowsGroup')
    { 
        $login.LoginType = $logintype
        try { $login.Create() }
        catch {
                $ex = $_.Exception
                $message = $ex.message
                $ex = $ex.InnerException
                while ($ex.InnerException)
                {
                    $message += "`n$ex.InnerException.message"
                    $ex = $ex.InnerException
                }
                Write-Error $message
        }

    }

} #Add-SqlLogin

#######################
<#
.SYNOPSIS
Removes a login from a SQL Server.
.DESCRIPTION
The Remove-SqlLogin function removes a login from the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Remove-SqlLogin
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlLogin "Z002\sql2k8" "TestPSUnit"
This command removes the TestPSUnit login from the Z002\sql2k8 server.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2k8"
Remove-SqlLogin $server "TestPSUnit"
This command removes the TestPSUnit login from the Z002\sql2k8 server.
.LINK
Remove-SqlLogin 
#>
function Remove-SqlLogin
{

    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$name
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Remove-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Remove-SqlLogin $($server.Name) $name"

    $login = Get-SqlLogin $server | where {$_.name -eq $name}
    if ($login)
    { $login.Drop() }
    else
    { throw "Login $name does not exist on server $($server.Name)." }

} #Remove-SqlLogin

#######################
<#
.SYNOPSIS
Adds a login to a server role.
.DESCRIPTION
The Add-SqlServerRoleMember function adds a login to the specified server role.
.INPUTS
None
    You cannot pipe objects to Add-SqlServerRoleMember
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlServerRoleMember "Z002\sql2k8" "TestPSUnit" "bulkadmin"
This command adds the TestPSUnit login to the bulkadmin server role.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2k8"
Add-SqlServerRoleMember $server "TestPSUnit" "bulkadmin"
This command adds the TestPSUnit login to the bulkadmin server role.
.LINK
Add-SqlServerRoleMember 
#>
function Add-SqlServerRoleMember
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$loginame,
    [Parameter(Position=2, Mandatory=$true)] [string]$rolename
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Add-SqlServerRoleMember:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Add-SqlServerRoleMember $($server.Name) $name"

    if($server.Logins | where {$_.name -eq $loginame})
    {
        $svrole = Get-SqlServerRole $server | where {$_.name -eq $rolename}

        if ($svrole)
        { $svrole.AddMember($loginame) }
        else
        { throw "ServerRole $rolename does not exist on server $($server.Name)." }
    }
    else
    { throw "Login $loginame does not exist on server $($server.Name)." }

} #Add-SqlServerRoleMember

#######################
<#
.SYNOPSIS
Removes a login from a server role.
.DESCRIPTION
The Remove-SqlServerRoleMember function removes a login from the specified server role.
.INPUTS
None
    You cannot pipe objects to Remove-SqlServerRoleMember
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlServerRoleMember "Z002\sql2k8" "TestPSUnit" "bulkadmin"
This command Removes the TestPSUnit login from the bulkadmin server role.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2k8"
Remove-SqlServerRoleMember $server "TestPSUnit" "bulkadmin"
This command Removes the TestPSUnit login from the bulkadmin server role.
.LINK
Remove-SqlServerRoleMember 
#>
function Remove-SqlServerRoleMember
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$loginame,
    [Parameter(Position=2, Mandatory=$true)] [string]$rolename
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Remove-SqlServerRoleMember:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Remove-SqlServerRoleMember $($server.Name) $name"

    if($server.Logins | where {$_.name -eq $loginame})
    {
        $svrole = Get-SqlServerRole $server | where {$_.name -eq $rolename}

        if ($svrole)
        { $svrole.DropMember($loginame) }
        else
        { throw "ServerRole $rolename does not exist on server $($server.Name)." }
    }
    else
    { throw "Login $loginame does not exist on server $($server.Name)." }

} #Remove-SqlServerRoleMember

#######################
<#
.SYNOPSIS
Adds a new database role to a database.
.DESCRIPTION
The Add-SqlDatabaseRole function adds a new database role to the specified database.
.INPUTS
None
    You cannot pipe objects to Add-SqlDatabaseRole
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlDatabaseRole "Z002\sql2k8" "pubs" "TestPSUnitDBRole"
This command adds the TestPSUnitDBRole role to the pubs database.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Add-SqlDatabaseRole -dbname $database -name "TestPSUnitDBRole"
This command adds the TestPSUnitDBRole role to the pubs database.
.LINK
Add-SqlDatabaseRole 
#>
function Add-SqlDatabaseRole
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Add-SqlDatabaseRole:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Add-SqlDatabaseRole $($database.Name) $name"

    if($database.Roles | where {$_.name -eq $name})
    { throw "DatabaseRole $name already exists in Database $($database.Name)." }
    else
    {
        $role = new-object ('Microsoft.SqlServer.Management.Smo.DatabaseRole') $database, $name
        $role.Create()
    }

} #Add-SqlDatabaseRole

#######################
<#
.SYNOPSIS
Removes a database role from a database.
.DESCRIPTION
The Remove-SqlDatabaseRole function removes a new database role from the specified database.
.INPUTS
None
    You cannot pipe objects to Remove-SqlDatabaseRole
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlDatabaseRole "Z002\sql2k8" "pubs" "TestPSUnitDBRole"
This command Removes the TestPSUnitDBRole role from the pubs database.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Remove-SqlDatabaseRole -dbname $database -name "TestPSUnitDBRole"
This command Removes the TestPSUnitDBRole role from the pubs database.
.LINK
Remove-SqlDatabaseRole 
#>
function Remove-SqlDatabaseRole
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Remove-SqlDatabaseRole:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Remove-SqlDatabaseRole $($database.Name) $name"

    $role = Get-SqlDatabaseRole $database | where {$_.name -eq $name}

    if ($role)
    { $role.Drop() }
    else
    { throw "DatabaseRole $name does not exist in database $($database.Name)." }

} #Remove-SqlDatabaseRole

#######################
<#
.SYNOPSIS
Adds a user or role to a database role.
.DESCRIPTION
The Add-SqlDatabaseRoleMember function adds a user or role to the specified database role.
.INPUTS
None
    You cannot pipe objects to Add-SqlDatabaseRoleMember
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Add-SqlDatabaseRoleMember "Z002\sql2k8" "pubs" "TestPSUnit" "TestPSUnitDBRole" 
This command adds the TestUnit user to the TestPSUnitDBRole database role.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Add-SqlDatabaseRoleMember -dbname $database -name "TestPSUnit" -rolename "TestPSUnitDBRole" 
This command adds the TestUnit user to the TestPSUnitDBRole database role.
.LINK
Add-SqlDatabaseRoleMember 
#>
function Add-SqlDatabaseRoleMember
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name,
    [Parameter(Position=3, Mandatory=$true)] [string]$rolename
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Add-SqlDatabaseRoleMember:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Add-SqlDatabaseRoleMember $($database.Name) $name $rolename"

    if(($database.Users | where {$_.name -eq $name}) -or ($database.Roles | where {$_.name -eq $name}))
    {
        $role = Get-SqlDatabaseRole $database | where {$_.name -eq $rolename}

        if ($role)
        { $role.AddMember($name) }
        else
        { throw "DatabaseRole $rolename does not exist in database $($database.Name)." }
    }
    else
    { throw "Role or User $name does not exist in database $($database.Name)." }

} #Add-SqlDatabaseRoleMember

#######################
<#
.SYNOPSIS
Removes a user or role from a database role.
.DESCRIPTION
The Remove-SqlDatabaseRoleMember function removes a user or role from the specified database role.
.INPUTS
None
    You cannot pipe objects to Remove-SqlDatabaseRoleMember
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Remove-SqlDatabaseRoleMember "Z002\sql2k8" "pubs" "TestPSUnit" "TestPSUnitDBRole" 
This command removes the TestUnit user to the TestPSUnitDBRole database role.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Remove-SqlDatabaseRoleMember -dbname $database -name "TestPSUnit" -rolename "TestPSUnitDBRole" 
This command removes the TestUnit user to the TestPSUnitDBRole database role.
.LINK
Remove-SqlDatabaseRoleMember 
#>
function Remove-SqlDatabaseRoleMember
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$name,
    [Parameter(Position=3, Mandatory=$true)] [string]$rolename
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Remove-SqlDatabaseRoleMember:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Remove-SqlDatabaseRoleMember $($database.Name) $name $rolename"

    if(($database.Users | where {$_.name -eq $name}) -or ($database.Roles | where {$_.name -eq $name}))
    {
        $role = Get-SqlDatabaseRole $database | where {$_.name -eq $rolename}

        if ($role)
        { $role.DropMember($name) }
        else
        { throw "DatabaseRole $rolename does not exist in database $($database.Name)." }
    }
    else
    { throw "Role or User $name does not exist in database $($database.Name)." }

} #Remove-SqlDatabaseRoleMember

#######################
<#
.SYNOPSIS
Sets a server level permissions.
.DESCRIPTION
The Set-SqlServerPermission function sets a server permission.
.INPUTS
None
    You cannot pipe objects to Set-SqlServerPermission
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Set-SqlServerPermission "Z002\sql2k8" "ViewServerState" "TestPSUnit" "Grant" 
This command grants ViewServerState permission to the TestPSUnit login.
.EXAMPLE
$server = Get-SqlServer "Z002\sql2k8"
Set-SqlServerPermission $server "ViewServerState" "TestPSUnit" "Grant"
This command grants ViewServerState permission to the TestPSUnit login.
.LINK
Set-SqlServerPermission 
#>
function Set-SqlServerPermission
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.ServerPermissionSetValue]$permission,
    [Parameter(Position=2, Mandatory=$true)] [string]$name,
    [ValidateSet("Grant", "Deny", "Revoke")]
    [Parameter(Position=3, Mandatory=$true)] [string]$action
    )

#Valid serverpermissions:
#AdministerBulkOperations AlterAnyConnection AlterAnyCredential AlterAnyDatabase AlterAnyEndpoint AlterAnyEventNotification
#AlterAnyLinkedServer AlterAnyLogin AlterAnyServerAudit   AlterResources AlterServerState AlterSettings AlterTrace AuthenticateServer
#ConnectSql ControlServer CreateAnyDatabase CreateDdlEventNotification CreateEndpoint CreateTraceEventNotification ExternalAccessAssembly
#UnsafeAssembly ViewAnyDatabase ViewAnyDefinition ViewServerState 

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Set-SqlServerPermission:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Set-SqlServerPermission $($server.Name) $serverpermission $name $action"

    if($server.Logins | where {$_.name -eq $name})
    {
        $perm = new-object ('Microsoft.SqlServer.Management.Smo.ServerPermissionSet')
        $perm.$($permission.ToString()) = $true

        switch ($action)
        { 
            'Grant'  { $server.Grant($perm,$name) }
            'Deny'   { $server.Deny($perm,$name) }
            'Revoke' { $server.Revoke($perm,$name) }
        }
    }
    else
    { throw "Login $name does not exist on server $($server.Name)." }

} #Set-SqlServerPermission

#######################
<#
.SYNOPSIS
Sets database level permissions.
.DESCRIPTION
The Set-SqlDatabasePermission function sets database level permissions.
.INPUTS
None
    You cannot pipe objects to Set-SqlDatabasePermission
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
Set-SqlDatabasePermission -sqlserver "Z002\sql2k8" -dbname $database -permission "ViewDefinition" -name "TestPSUnit" -action "Grant"
This command grants ViewDefinition permission to the TestPSUnit user.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
Set-SqlDatabasePermission -dbname $database -permission "ViewDefinition" -name "TestPSUnit" -action "Grant"
This command grants ViewDefinition permission to the TestPSUnit user.
.LINK
Set-SqlDatabasePermission 
#>
function Set-SqlDatabasePermission
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname,
    [Parameter(Position=2, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.DatabasePermissionSetValue]$permission,
    [Parameter(Position=3, Mandatory=$true)] [string]$name,
    [ValidateSet("Grant", "Deny", "Revoke")]
    [Parameter(Position=4, Mandatory=$true)] [string]$action
    )

#Valid databasepermissions:
#Alter AlterAnyApplicationRole AlterAnyAssembly AlterAnyAsymmetricKey AlterAnyCertificate AlterAnyContract AlterAnyDatabaseAudit
#AlterAnyDatabaseDdlTrigger AlterAnyDatabaseEventNotification AlterAnyDataspace AlterAnyFulltextCatalog AlterAnyMessageType
#AlterAnyRemoteServiceBinding AlterAnyRole AlterAnyRoute AlterAnySchema AlterAnyService AlterAnySymmetricKey AlterAnyUser Authenticate
#BackupDatabase BackupLog Checkpoint Connect ConnectReplication Control CreateAggregate CreateAssembly CreateAsymmetricKey CreateCertificate
#CreateContract CreateDatabase CreateDatabaseDdlEventNotification CreateDefault CreateFulltextCatalog CreateFunction CreateMessageType 
#CreateProcedure CreateQueue CreateRemoteServiceBinding CreateRole CreateRoute CreateRule CreateSchema CreateService CreateSymmetricKey 
#CreateSynonym CreateTable CreateType CreateView CreateXmlSchemaCollection Delete Execute Insert References Select Showplan 
#SubscribeQueryNotifications TakeOwnership Update ViewDatabaseState ViewDefinition 

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Set-SqlDatabasePermission:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Set-SqlDatabasePermission $($database.Name) $name $permission $action"

    if(($database.Users | where {$_.name -eq $name}) -or ($database.Roles | where {$_.name -eq $name}))
    {
        $perm = new-object ('Microsoft.SqlServer.Management.Smo.DatabasePermissionSet')
        $perm.$($permission.ToString()) = $true 

        switch ($action)
        { 
            'Grant'  { $database.Grant($perm,$name) }
            'Deny'   { $database.Deny($perm,$name) }
            'Revoke' { $database.Revoke($perm,$name) }
        }
    }
    else
    { throw "Role or User $name does not exist in database $($database.Name)." }

} #Set-SqlDatabasePermission

#######################
<#
.SYNOPSIS
Sets database object level permissions.
.DESCRIPTION
The Set-SqlObjectPermission function sets database object level permissions.
.INPUTS
Microsoft.SqlServer.Management.Smo.*
    You can pipe SMO objects to Set-SqlObjectPermission
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
$database = Get-SqlDatabase "Z002\sql2k8" "pubs"
$database | get-sqlschema -name dbo | set-sqlobjectpermission -permission Select -name TestPSUnit -action Grant
This command grants select permission on the dbo schema to the TestPSUnit user.
.LINK
Set-SqlObjectPermission 
#>
function Set-SqlObjectPermission
{

    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Namespace -like "Microsoft.SqlServer.Management.Smo*"})] $smo,
    [Parameter(Position=1, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.ObjectPermissionSetValue]$permission,
    [Parameter(Position=2, Mandatory=$true)] [string]$name,
    [ValidateSet("Grant", "Deny", "Revoke")]
    [Parameter(Position=3, Mandatory=$true)] [string]$action
    )
#Alter Connect Control Delete Execute Impersonate Insert Receive References Select Send TakeOwnership Update ViewChangeTracking ViewDefinition 
#Example: Get-SqlDatabase 'Z002\Sql1 pubs | get-sqlschema -name dbo | set-sqlobjectpermission -permission Select -name test5 -action Grant
    Write-Verbose "Set-SqlObjectPermission $($smo.Name) $permission $name $action"

    process
    {
        if(($smo.Parent.Users | where {$_.name -eq $name}) -or ($_.Parent.Roles | where {$_.name -eq $name}))
        {
            $perm = new-object ('Microsoft.SqlServer.Management.Smo.ObjectPermissionSet')
            $perm.$($permission.ToString()) = $true 

            switch ($action)
            { 
                'Grant'  { $smo.Grant($perm,$name) }
                'Deny'   { $smo.Deny($perm,$name) }
                'Revoke' { $smo.Revoke($perm,$name) }
                default  { throw 'Set-SqlObjectPermission:Param `$action must be Grant, Deny or Revoke.' }
            }
        }
        else
        { throw "Role or User $name does not exist in database $($database.Name)." }
    }

} #Set-SqlObjectPermission

#######################
<#
.SYNOPSIS
Gets an SMO schema object.
.DESCRIPTION
The Get-SqlSchema function  gets a collection of SMO schema objects for the specified database.
.INPUTS
Microsoft.SqlServer.Management.Smo.Database
    You can pipe SMO database objects to Get-SqlSchema 
.OUTPUTS
Microsoft.SqlServer.Management.Smo.Schema
    Get-SqlSchema returns a Microsoft.SqlServer.Management.Smo.Schema object.
.NOTES
Additional properties including the database, server and extended properties are included in the output. 
.EXAMPLE
Get-SqlSchema $(Get-SqlDatabase "Z002\sql2K8" pubs)
This command gets a collection of SMO schema objects for SQL Server Z002\SQL2K8, pubs database.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" | Get-SqlSchema
This command gets a collection of SMO schema objects for all user databases on SQL Server Z002\SQL2K8.
.EXAMPLE
Get-SqlDatabase "Z002\sql2K8" pubs | Get-SqlSchema -name "dbo"
This command gets an SMO schema object for the dbo schema in the pubs database on SQL Server Z002\SQL2K8.
.LINK
Get-SqlSchema 
#>
function Get-SqlSchema
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$Name,
    [Parameter(Position=3, Mandatory=$false)] [String]$Include,
    [Parameter(Position=4, Mandatory=$false)] [String]$Exclude
    )

    process
    {
        foreach ($schema in $database.Schemas)
        {
            if ((-not($Include)  -or ($Include -and $schema.name -like "$Include")) `
            -and  (-not($Exclude) -or ($Exclude -and $schema.name -notlike "$Exclude")))

            {
                #Return schema Object
                $schema | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
               add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $schema.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }
    }

} #Get-SqlSchema

#######################
<#
.SYNOPSIS
Returns the current proccesses on a SQL Server. Equivalent to sp_who.
.DESCRIPTION
The Get-SqlProcess function returns the current proccesses on a SQL Server. Equivalent to sp_who.
.INPUTS
None
    You cannot pipe objects to Get-SqlProcess
.OUTPUTS
System.Data.DataRow
    Get-SqlProcess returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlProcess "Z002\sql2k8"
This command returns the current processes on the Z002\sql2k8 server.
.LINK
Get-SqlProcess
#>
function Get-SqlProcess
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [int]$spid,
    [Parameter(Position=2, Mandatory=$false)] [string]$name,
    [Parameter(Position=3, Mandatory=$false)] [switch]$excludeSystemProcesses
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw "Get-SqlProcess:Param '`$sqlserver' must be a String or Server object." }
    }

    Write-Verbose "Get-SqlProcess $($server.Name)"
        
        if ($spid)
        { $server.EnumProcesses($spid) }
        elseif ($name)
        { $server.EnumProcesses($name) }
        else
        { $server.EnumProcesses($($excludeSystemProcesses.IsPresent)) }

} #Get-SqlProcess

#######################
<#
.SYNOPSIS
Returns the current open transactions for a database.
.DESCRIPTION
The Get-SqlTransaction function returns returns the current open transactions for a database.
.INPUTS
None
    You cannot pipe objects to Get-SqlTransaction
.OUTPUTS
System.Data.DataRow
    Get-SqlTransaction returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlTransaction "Z002\sql2k8" "pubs"
This command returns the current open transactoin in the pubs database.
.LINK
Get-SqlTransaction
#>
function Get-SqlTransaction
{
    param(
    [Parameter(Position=0, Mandatory=$false)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] $dbname
    )

    switch ($dbname.GetType().Name)
    {
        'String' { $database = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $database = $dbname }
        default { throw "Get-SqlTransaction:Param '`$dbname' must be a String or Database object." }
    }

    Write-Verbose "Get-SqlTransaction $($database.Name)"

    $database.EnumTransactions()

} #Get-SqlTransaction

#######################
<#
.SYNOPSIS
Returns the SQL Server Errorlog.
.DESCRIPTION
The Get-SqlErrorLog function returns the SQL Server Errorlog.
.INPUTS
None
    You cannot pipe objects to Get-SqlErrorLog
.OUTPUTS
System.Data.DataRow
    Get-SqlErrorLog returns an array of System.Data.DataRow.
.EXAMPLE
Get-SqlErrorLog "Z002\sql2k8"
This command returns the current SQL ErrorLog on the Z002\sql2k8 server.
.LINK
Get-SqlErrorLog
#>
function Get-SqlErrorLog
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [int]$lognumber=0
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw "Get-SqlErrorLog:Param '`$sqlserver' must be a String or Server object." }
    }

    Write-Verbose "Get-SqlErrorLog $($server.Name)"
    $server.ReadErrorLog($lognumber)
    
} #Get-SqlErrorLog

#######################
<#
.SYNOPSIS
Returns a custom object with the Server name and Edition.
.DESCRIPTION
The Get-SqlEdition function returns a custom object with the Server name and Edition for the specified SQL server.
.INPUTS
None
    You cannot pipe objects to Get-SqlEdition 
.OUTPUTS
Selected.Microsoft.SqlServer.Management.Smo.Information
    Get-SqlEdition returns a Selected.Microsoft.SqlServer.Management.Smo.Information object.
.EXAMPLE
Get-SqlEdition "Z002\sql2k8"
This command returns SQL Edition information for the Z002\sql2k8 SQL Server. 
.LINK
Get-SqlEdition 
#>
function Get-SqlEdition
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlEdition:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlEdition $($server.Name)"

    $server.information | Select @{name='Server';Expression={$server.Name}}, Edition

}#Get-SqlEdition

#Aliases
New-Alias -name Get-Information_Schema.Tables -value Get-SqlInformation_Schema.Tables -Description "SQLPSX Alias"
New-Alias -name Get-Information_Schema.Columns -value Get-SqlInformation_Schema.Columns -Description "SQLPSX Alias"
New-Alias -name Get-Information_Schema.Views -value Get-SqlInformation_Schema.Views -Description "SQLPSX Alias"
New-Alias -name Get-Information_Schema.Routines -value Get-SqlInformation_Schema.Routines -Description "SQLPSX Alias"
New-Alias -name Get-SysDatabases -value Get-SqlSysDatabases -Description "SQLPSX Alias"

Export-ModuleMember -function * -alias *
