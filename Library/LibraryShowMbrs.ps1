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

            $domain = $($group.ToString()).split("\")[0]
            $groupname = $($group.ToString()).split("\")[1]
            
            if ($domain -ne 'NT AUTHORITY' -and $domain -ne 'BUILTIN')
            {
            
                $groupUser= [ADSI]"WinNT://$($domain + '/' + $groupname),group"
	        $groupUser.psbase.Invoke("Members") | foreach {
                    $name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
                    $type = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
                    $path = $_.GetType().InvokeMember("AdsPath", 'GetProperty', $null, $_, $null)
                    $arPath = $path.Split("/")
                    $domain = $arPath[$arPath.length - 2]	
                    $account = $domain + "\" + $name
                    if ($type -eq 'Group')
                    { Get-GroupUser $account $groupkey }
                    else
                    { Set-ShowMbrs $account $groupkey }
                }

            }
        }
    }

} #Get-GroupUser

#######################
function Get-ShowMbrs
{
    param($group=$(throw '$group is required'))
    
    Write-Verbose "Get-ShowMbrs $group"

    New-ShowMbrs

    Get-GroupUser $group

    return $__SQLPSXGroupUser[$group]

} #Get-ShowMbrs
