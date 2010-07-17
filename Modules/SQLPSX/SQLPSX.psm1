#----------------------------------------------------------------#
# SQLPSX.PSM1
# Author: Bernd, 05/18/2010
# 
# Comment: Replaces Max version of the SQLPSX.psm1
#----------------------------------------------------------------#

$PSXloadModules = @()
$PSXloadModules = "SQLmaint","SQLServer","Agent","Repl","SSIS","Showmbrs"
$PSXloadModules += "SQLParser","adolib" 
if ($psIse) { 
   $PSXloadModules += "SQLIse" 
}

$oraAssembly = [System.Reflection.Assembly]::LoadWithPartialName("Oracle.DataAccess") 
if ($oraAssembly) {
   $PSXloadModules += "OracleClient"
   if ($psIse) { 
       $PSXloadModules += "OracleIse" 
   }
}
else { Write-Host -BackgroundColor Black -ForegroundColor Yellow "No Oracle found" }


$PSXremoveModules = $PSXloadModules[($PSXloadModules.count)..0]

$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module
$mInfo.OnRemove = {
   foreach($PSXmodule in $PSXremoveModules){
       if (gmo $PSXmodule)
       {    
         Write-Host -BackgroundColor Black -ForegroundColor Yellow "Removing SQLPSX Module - $PSXModule"
         Remove-Module $PSXmodule
       }
   }

   Write-Host -BackgroundColor Black -ForegroundColor Yellow "$($MyInvocation.MyCommand.ScriptBlock.Module.name) removed on $(Get-Date)"
}

foreach($PSXmodule in $PSXloadModules){
 Write-Host -BackgroundColor Black -ForegroundColor Yellow "Loading SQLPSX Module - $PSXModule"
 Import-Module $PSXmodule -global
}
Write-Host -BackgroundColor Black -ForegroundColor Yellow "Loading SQLPSX Modules is Done!"
