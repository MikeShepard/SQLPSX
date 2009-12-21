# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Lists invalid AD/NT logins/groups which have been granted access to the
### specified SQL Server instance. Script calls the system stored procedure
### sp_validatelogins and validates the output by attempting to resolve the sid
### against AD. The second level of validation is done because sp_validatelogins
### incorrectly reports logins/groups which have been renamed in AD. SQL Server
### stores the AD sid so renamed accounts still have access to the instance.
### Renamed logins/groups are listed with the renamed value in the newAccount
### property.
### </Description>
### <Usage>
### Get-InvalidLogins "MyServer" 
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
param($sqlserver)

#######################
function New-InvalidLogin
{
    Write-Verbose "New-InvalidLogin"

    #__SQLPSXInvalidLogin is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXInvalidLogin))
    { Set-Variable __SQLPSXInvalidLogin @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-InvalidLogin


#######################
function processInvalidLogin
{
    param($sqlserver)

    Write-Verbose "processInvalidLogins $sqlserver"

    foreach ($r in Get-SqlData $sqlserver 'master' 'sp_validatelogins')
    {
        $NTLogin = $r.'NT Login'
        $SID = new-object security.principal.securityidentifier($r.SID,0)
        $newAccount = $null
        trap { $null; continue } $newAccount = $SID.translate([system.security.principal.NTAccount])
       if ($newAccount -eq $null) { 
        $isOrphaned = $true
        $isRenamed = $false
        }
       else {
        $isOrphaned = $false
        $isRenamed = $true
        }
        if ($NTLogin -ne $newAccount) {
        new-object psobject |
        add-member -pass NoteProperty NTLogin $NTLogin |
        add-Member -pass NoteProperty TSID $SID |
        add-Member -pass NoteProperty Server $sqlserver |
        add-Member -pass NoteProperty IsOrphaned $isOrphaned |
        add-Member -pass NoteProperty IsRenamed $isRenamed |
        add-Member -pass NoteProperty NewNTAccount $newAccount
        }
    }

} #processInvalidLogin

#Main
New-InvalidLogin

if (!($__SQLPSXInvalidLogin.Contains($sqlserver)))
{
    $__SQLPSXInvalidLogin[$sqlserver] = processInvalidLogin $sqlserver
}

return $__SQLPSXInvalidLogin[$sqlserver]

