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
### . ./LibraryShowMbrs.ps1
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
#######################
function New-ShowMbrs
{
    Write-Verbose "New-ShowMbrs"

    #__SQLPSXGroupUser is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXGroupUser))
    { Set-Variable __SQLPSXGroupUser @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-ShowMbrs

#######################
function New-IsDomain
{
    Write-Verbose "New-IsDomain"

    #__SQLPSXIsDomain is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXIsDomain))
    { Set-Variable __SQLPSXIsDomain @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-IsDomain

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
        if ($__SQLPSXGroupUser.Contains($group))
        { Set-ShowMbrs $__SQLPSXGroupUser[$group] $groupkey }
        else
        {
            Set-ShowMbrs $group $groupkey

            $p = '.*Win32_(?<type>[^.]+)\.Domain="(?<domain>[^"]+)",Name="(?<Name>[^"]+)'
            $domain = $($group.ToString()).split("\")[0]
            $groupname = $($group.ToString()).split("\")[1]
            
            if ($domain -ne 'NT AUTHORITY' -and $domain -ne 'BUILTIN')
            {
            
                if (Get-IsDomain $domain)
                { $node = "" }
                else
                { $node = "/NODE:`"$domain`"" }

                $cmd = "wmic $node path Win32_groupuser WHERE (GroupComponent = `"Win32_Group.Domain='$domain',Name='$groupname'`") get PartComponent"
                cmd /c $cmd | foreach { if($_ -match $p)
                                        {   $account = $($matches.Domain+"\"+$matches.Name)
                                            if ($matches.type -eq 'Group')
                                            {
                                                Get-GroupUser $account $groupkey
                                            }
                                            else { Set-ShowMbrs $account $groupkey }
                                        }
                                       }
            }
        }
    }

} #Get-GroupUser

#######################
function Get-IsDomain
{
    param($domain)

    Write-Verbose "Get-IsDomain $domain"
    
    New-IsDomain

    if (!($__SQLPSXIsDomain.Contains($domain)))
    {
       trap {$script:Exception = $_; continue} $mydomain = Get-WmiObject Win32_NTDomain | select DomainName
         $flag = $false
       if ($script:Exception -eq $null)
       {
            for ( $i=0; $i -le ($mydomain.length - 1); $i++)
            {
                    if ( $mydomain[$i].DomainName -eq $domain )
                    {
                            $flag = $true
                            break
                    }
            }
        }
        
        $__SQLPSXIsDomain[$domain] = $flag
    }

    return $__SQLPSXIsDomain[$domain]

} #Get-IsDomain

#######################
function Get-ShowMbrs
{
    param($group=$(throw '$group is required'))
    
    Write-Verbose "Get-ShowMbrs $group"

    New-ShowMbrs

    Get-GroupUser $group

    return $__SQLPSXGroupUser[$group]

} #Get-ShowMbrs
