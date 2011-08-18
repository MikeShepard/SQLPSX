# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Recurively enumerates AD or local group membership. Replaces Windows
### 2000 Resource Kit utility showmbrs.
### </Description>
### <Usage>
### import-module ShowMbrs
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

add-type -AssemblyName System.DirectoryServices.AccountManagement

#######################
function New-ShowMbrs
{
    Write-Verbose "New-ShowMbrs"

    #__SQLPSXGroupUser is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXGroupUser))
    { Set-Variable __SQLPSXGroupUser @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-ShowMbrs

#######################
function Set-ShowMbrs
{
    param($account,$groupkey)

    Write-Verbose "Set-ShowMbrs $account $groupkey"

    if (!($__SQLPSXGroupUser.Contains($groupkey)))
    { $__SQLPSXGroupUser[$groupkey] = @($account) }
    elseif (!($__SQLPSXGroupUser[$groupkey] -contains $account))
    { $__SQLPSXGroupUser[$groupkey] += @($account) }

} # Set-ShowMbrs

#######################
function Get-GroupUser
{

    param($group,$groupkey = $group) 

    Write-Verbose "Get-GroupUser $group $groupkey"

    #If we haven't already enumerated the group this Powershell session
    if (!($__SQLPSXGroupUser[$groupkey] -contains $group))
    {
            Set-ShowMbrs $group $groupkey

            $domain = $($group.ToString()).split("\")[0]
            $groupname = $($group.ToString()).split("\")[1]

            #Regex to extract Domain from DistinguishedName
            $regex = '^[A-Z0-9+_.-]+@([A-Z0-9.-]+)\.(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum)$'
            
            if ( @('NT AUTHORITY','BUILTIN','NT SERVICE') -notcontains $domain )
            {
                try {
                    $domainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain() | select -ExpandProperty Name
                    $isDomain = $domainName -match "$domain\."
                }
                catch {
                    $isDomain = $false
                }
                
                if ($isDomain)
                { $ctype = [System.DirectoryServices.AccountManagement.ContextType]::Domain }
                else
                { $ctype = [System.DirectoryServices.AccountManagement.ContextType]::Machine }
                
                $principal = new-object System.DirectoryServices.AccountManagement.PrincipalContext $ctype,$domain
                $groupPrincipal = new-object System.DirectoryServices.AccountManagement.GroupPrincipal $principal,$groupname
                $searcher = new-object System.DirectoryServices.AccountManagement.PrincipalSearcher 
                $searcher.QueryFilter = $groupPrincipal
                #Note GetMembers(true) recursively enumerates groups while GetMembers() does not
                $searcher.FindAll() | foreach {$_.GetMembers($true)} | foreach { if ($_.DistinguishedName) {$null = $_.Distinguished -match $regex; $domain = $matches[1]};
                Set-ShowMbrs "$domain\$($_.SamAccountName)" $groupkey }
                
            }
    }

} #Get-GroupUser

#######################
<#
.SYNOPSIS
Recursivley enumerates local Windows and AD groups. 
.DESCRIPTION
The Get-ShowMbrs function recursivley enumerates local Windows and AD groups. Similar to the NT Resource utility showmbrs.exe, except that Get-ShowMbrs provides fully recursive group enumeration.
.INPUTS
None
    You cannot pipe objects to Get-ShowMbrs.
.OUTPUTS
String
    Get-ShowMbrs returns a string object.
.EXAMPLE
Get-ShowMbrs "$env:computername\Administrators"
This command outputs a list of all members of the local Administrators group. If the group contains AD members, these groups are also enumerated.
.EXAMPLE
Get-ShowMbrs "Consco\PayrollUsers"
This command outputs a list of all members of the AD group. If the group contains nested groups, these groups are also enumerated.
.LINK
Get-ShowMbrs
#>
function Get-ShowMbrs
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$group
    )
    
    Write-Verbose "Get-ShowMbrs $group"

    New-ShowMbrs

    Get-GroupUser $group

    return $__SQLPSXGroupUser[$group]

} #Get-ShowMbrs
