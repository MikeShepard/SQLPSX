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
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], "IsSystemObject")
    #trap { "Check $SqlServer Name"; continue} $server.ConnectionContext.Connect() 
    Write-Output $server
    
} #Get-SqlServer

#######################
function Get-SqlDatabase
{ 
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$dbname
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
    else
    #Skip systems databases
    { $server.Databases | where {$_.IsSystemObject -eq $false -and $_.IsAccessible -eq $true} }

} # Get-SqlDatabase

#######################
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
                    $member += @($(Get-SqlUserMember $user))
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
function New-SqlUserMember
{
    Write-Verbose "New-SqlUserMember"

    #__SQLPSXUserMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXUserMember))
    { Set-Variable __SQLPSXUserMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SQLUserMember

#######################
function Get-SqlUserMember
{
    param([Microsoft.SqlServer.Management.Smo.User]$user,[Microsoft.SqlServer.Management.Smo.Database]$database)

    Write-Verbose "Get-SqlUserMember $($user.Name) $($database.Name)"

    New-SqlUserMember

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
    { throw 'Get-SqlUserMember:Param `$user or `$database missing.' }

} # Get-SqlUserMember

#######################
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
            $member += @($(Get-SqlDatabaseRoleMember $role))

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
function New-SqlDatabaseRoleMember
{
    Write-Verbose "New-SqlDatabaseRoleMember"

    #__SQLPSXDatabaseRoleMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXDatabaseRoleMember))
    { Set-Variable __SQLPSXDatabaseRoleMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SqlDatabaseRoleMember

#######################
function Get-SqlDatabaseRoleMember
{
    param([Microsoft.SqlServer.Management.Smo.DatabaseRole]$role,[Microsoft.SqlServer.Management.Smo.Database]$database)

    Write-Verbose "Get-SqlDatabaseRoleMember $($role.Name) $($database.Name)"

    New-SqlDatabaseRoleMember

    if ($role)
    {
        $key = $null
        $key = $role.parent.parent.name + "." + $role.parent.name

        if(!($__SQLPSXDatabaseRoleMember.$key.$($role.Name))) {
            $user = @{}
            $user = Get-SqlUserMember -database $role.parent

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
    { throw 'Get-SqlDatabaseRoleMember:Param `$role or `$database missing' }

} # Get-SqlDatabaseRoleMember

#######################
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
        $member += @($(Get-SqlLoginMember $login))

        #Return Login Object
        $login | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                 add-Member -memberType noteProperty -name members -value $member -passthru | 
                 add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                 add-Member -memberType noteProperty -name Server -value $server.Name -passthru

    }

} # Get-SqlLogin

#######################
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
function New-SqlLoginMember
{
    Write-Verbose "New-SqlLoginMember"

    #__SQLPSXLoginMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXLoginMember))
    { Set-Variable __SQLPSXLoginMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SQLLoginMember

#######################
function Get-SqlLoginMember
{
    param([Microsoft.SqlServer.Management.Smo.Login]$login,[Microsoft.SqlServer.Management.Smo.Server]$server)

    Write-Verbose "Get-SqlLoginMember $($login.Name) $($server.Name)"

    New-SqlLoginMember

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
    { throw 'Get-SqlLoginMember:Param `$login or `$server missing.' }

} # Get-SqlLoginMember

#######################
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
    $login = Get-SqlLoginMember -server $server
 
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
    {$perm = Get-SqlServerPermission90 $server; $perm += Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master'); $perm}
    else {Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master')}

}# Get-SqlServerPermission

#######################
function Get-SqlServerPermission90
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Server]$server
    )

    Write-Verbose "Get-SqlServerPermission90 $($server.Name)"
    
    #SQL 2000 Does not suppport the concept of Server Permissions. SQL Server 2000 relies on Server Roles to grant server level permissions
    #There are only three grantable permissions in SQL 2000/2005 only applicable to the master database: CREATE DATABASE; BACKUP DATABASE; BACKUP LOG
    #Although we may think Create Database, Backup and Backup Log are server level permissions the SQL development team apparently does not
    #share the same opinion and EnumServerPermissions will not enumerate these permissions.
    #since I think they should I'll create a custom object and append to accomplish this in Get-SqlServerPermission

    $principal = @{}
    #Get-SqlLogin $server | foreach  { $principal[$_.Name] = $_.members }
    $principal = Get-SqlLoginMember -server $server

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
} #Get-SqlServerPermission90

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
                $user = Get-SqlUserMember -database $database
                $role = Get-SqlDatabaseRoleMember -database $database
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
                $user = Get-SqlUserMember -database $database
                $role = Get-SqlDatabaseRoleMember -database $database

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
function Get-Permission90
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Database]$database
    )

    Write-Verbose "Get-Permission90 $($database.Name)"

$qry = @"
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.state WHEN 'W' THEN 'GRANT_W_GRANT' WHEN 'G' THEN 'GRANT' WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE'END AS [PermissionState],
'ObjectOrColumn' AS [ObjectClass],
COL_NAME(prmssn.major_id,prmssn.minor_id) AS [ColumnName],
obj.name AS [ObjectName],
schema_name(obj.schema_id) AS [ObjectSchema],
prmssn.major_id AS [ObjectID],
CASE grantee_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GranteeType],
CASE grantor_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GrantorType],
CASE prmssn.type
WHEN 'AL' THEN 'ALTER'
WHEN 'CL' THEN 'CONTROL'
WHEN 'DL' THEN 'DELETE'
WHEN 'EX' THEN 'EXECUTE'
WHEN 'IN' THEN 'INSERT'
WHEN 'RC' THEN 'RECEIVE'
WHEN 'RF' THEN 'REFERENCES'
WHEN 'SL' THEN 'SELECT'
WHEN 'TO' THEN 'TAKE OWNERSHIP'
WHEN 'UP' THEN 'UPDATE'
WHEN 'VW' THEN 'VIEW DEFINITION'
END AS [PermissionType]
FROM
sys.database_permissions AS prmssn
INNER JOIN sys.database_principals AS grantee_principal ON grantee_principal.principal_id = prmssn.grantee_principal_id
INNER JOIN sys.database_principals AS grantor_principal ON grantor_principal.principal_id = prmssn.grantor_principal_id
INNER JOIN sys.all_objects AS obj ON obj.object_id = prmssn.major_id and prmssn.class = 1
WHERE prmssn.major_id > 0
UNION
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.state WHEN 'W' THEN 'GRANT_W_GRANT' WHEN 'G' THEN 'GRANT' WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE'END AS [PermissionState],
'Schema' AS [ObjectClass],
null AS [ColumnName],
obj.name AS [ObjectName],
null AS [ObjectSchema],
prmssn.major_id AS [ObjectID],
CASE grantee_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GranteeType],
CASE grantor_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GrantorType],
CASE prmssn.type
WHEN 'AL' THEN 'ALTER'
WHEN 'CL' THEN 'CONTROL'
WHEN 'DL' THEN 'DELETE'
WHEN 'EX' THEN 'EXECUTE'
WHEN 'IN' THEN 'INSERT'
WHEN 'RC' THEN 'RECEIVE'
WHEN 'RF' THEN 'REFERENCES'
WHEN 'SL' THEN 'SELECT'
WHEN 'TO' THEN 'TAKE OWNERSHIP'
WHEN 'UP' THEN 'UPDATE'
WHEN 'VW' THEN 'VIEW DEFINITION'
END AS [PermissionType]
FROM
sys.database_permissions AS prmssn
INNER JOIN sys.database_principals AS grantee_principal ON grantee_principal.principal_id = prmssn.grantee_principal_id
INNER JOIN sys.database_principals AS grantor_principal ON grantor_principal.principal_id = prmssn.grantor_principal_id
INNER JOIN sys.schemas AS obj ON obj.schema_id = prmssn.major_id and prmssn.class = 3
"@

    Get-SqlData -dbname $database -qry $qry

}# Get-Permission90

#######################
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
            $user = Get-SqlUserMember -database $database
            $role = Get-SqlDatabaseRoleMember -database $database

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
            $user = Get-SqlUserMember -database $database
            $role = Get-SqlDatabaseRoleMember -database $database

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
function Get-SqlTable
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($table in $database.Tables)
        {
            if ($table.IsSystemObject -eq $false -and ($table.name -like "*$name*" -or $name.Contains($table.name)))
            {
            #Return Table Object
            $table | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $table.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlTable

#######################
function Get-SqlStoredProcedure
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($storedProcedure in $database.StoredProcedures)
        {
            if ($storedProcedure.IsSystemObject -eq $false -and ($storedProcedure.name -like "*$name*" -or $name.Contains($storedProcedure.name)))
            {
            #Return StoredProcedure Object
            $storedProcedure | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
      add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $storedProcedure.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlStoredProcedure

#######################
function Get-SqlView
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($view in $database.Views)
        {
            if ($view.IsSystemObject -eq $false -and ($view.name -like "*$name*" -or $name.Contains($view.name)))
            {
            #Return View Object
            $view | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $view.ExtendedProperties) -passthru |
                    add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                    add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlView

#######################
function Get-SqlUserDefinedDataType
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
       foreach ($userDefinedDataType in $database.UserDefinedDataTypes)
       {
           if ($userDefinedDataType.name -like "*$name*" -or $name.Contains($userDefinedDataType.name))
           { 
            #Return UserDefinedDataType Object
            $userDefinedDataType | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedDataType.ExtendedProperties) -passthru |
                                   add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                                   add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlUserDefinedDataType

#######################
function Get-SqlUserDefinedFunction
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($userDefinedFunction in $database.UserDefinedFunctions)
        {
           if ($userDefinedFunction.IsSystemObject -eq $false -and ($userDefinedFunction.name -like "*$name*" -or $name.Contains($userDefinedFunction.name)))
            {
            #Return UserDefinedFunction Object
            $userDefinedFunction | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedFunction.ExtendedProperties) -passthru |
                                   add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                                   add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlUserDefinedFunction

#######################
function Get-SqlSynonym
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($synonym in $database.Synonyms)
        {
            if ($synonym.name -like "*$name*" -or $name.Contains($synonym.name))
            {
            #Return Synonym Object
            $synonym | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $synonym.ExtendedProperties) -passthru |
                       add-Member -memberType noteProperty -name Server -value $database.parent.Name -passthru |
                       add-Member -memberType noteProperty -name dbname -value $database.Name -passthru
            }
        }

    }

} #Get-SqlSynonym

#######################
function Get-SqlTrigger
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] $smo,
    [Parameter(Position=1, Mandatory=$false)] [String]$name="*"
    )

    process
    {
        foreach ($trigger in $smo.Triggers)
        {
            if ($trigger.name -like "*$name*" -or $name.Contains($trigger.name))
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
function New-SqlScriptingOptions
{
    Write-Verbose "New-SqlScriptingOptions"

    New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions

} #New-SqlScriptingOptions

#######################
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
function Get-Information_Schema.Tables
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

} #Get-Information_Schema.Tables

#######################
function Get-Information_Schema.Columns
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
} #Get-Information_Schema.Columns

#######################
function Get-Information_Schema.Views
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
} #Get-Information_Schema.Views

#######################
function Get-Information_Schema.Routines
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
} #Get-Information_Schema.Routines

#######################
function Get-SysDatabases
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [String]$name='%'
    )

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SysDatabases:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SysDatabases $($server.Name)"

    $database = Get-SqlDatabase $server 'master'
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, name FROM sysdatabases
WHERE name LIKE '%$name%'
"@
    Get-SqlData -dbname $database -qry $qry

} #Get-SysDatabases

#######################
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
function Invoke-SqlRestore
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $sqlserver,
    [Parameter(Position=1, Mandatory=$true)] [string]$dbname,
    [Parameter(Position=2, Mandatory=$true)] [string]$filepath,
    [Parameter(Position=3, Mandatory=$false)] [Microsoft.SqlServer.Management.Smo.RestoreActionType]$action='Database',
    [Parameter(Position=4, Mandatory=$false)] [string]$stopat,
    [Parameter(Position=5, Mandatory=$false)] [hashtable]$relocatefiles,
    [Parameter(Position=6, Mandatory=$false)] [switch]$force,
    [Parameter(Position=7, Mandatory=$false)] [switch]$norecovery,
    [Parameter(Position=8, Mandatory=$false)] [switch]$keepreplication
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

    $restore.Action = $action
    $restore.Database = $dbname
    $restore.Devices.Add($restoreDevice) 
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
    
    #The DefaultFile and DefaultLog properties are only written to registry if you modify the properties in SSMS
    #even setting the properties to same value will create the registry keys.
    #If the properties have not been created use the InstallDataDirectory properties. This seems to recreate how
    #SSMS works. I thought about adding this properties to the server object in Get-SqlServer, but felt it was important
    #not to mask whether the default directories had been set or not. You should always set the default directories as
    #a configuration task
    switch ($dirtype)
    {
        'Data'  { if ($server.DefaultFile) { $server.DefaultFile } else { $server.InstallDataDirectory + '\' + 'Data' } }
        'Log'   { if ($server.DefaultLog) { $server.DefaultLog } else { $server.InstallDataDirectory + '\' + 'Data' } }
    }

} #Get-SqlDefaultDir

#######################
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
    $user.DefaultSchema = $defaultschema
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
        $login.PasswordExpirationEnabled = $($PasswordExpirationEnabled.IsPresent)
        $login.PasswordPolicyEnforced = $($PasswordPolicyEnforced.IsPresent)
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
function Get-SqlSchema
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Management.Smo.Database]$database,
    [Parameter(Position=1, Mandatory=$false)] [string]$name="*"
    )

    process
    {
        foreach ($schema in $database.Schemas)
        {
            if ($schema.name -like "*$name*" -or $name.Contains($schema.name))
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

