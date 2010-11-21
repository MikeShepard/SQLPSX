#######################
function Protect-String 
{
    param([string]$InputString)
    $secure = ConvertTo-SecureString $InputString -asPlainText -force
    $export = $secure | ConvertFrom-SecureString
    write-output $export

} #Protect-String

#######################
function UnProtect-String 
{
    param([string]$InputString)

    $secure = ConvertTo-SecureString $InputString
    $helper = New-Object system.Management.Automation.PSCredential("SQLPSX", $secure)
    $plain = $helper.GetNetworkCredential().Password
    write-output $plain

} #UnProtect-String
