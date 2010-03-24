# ==============================================================================================
# Microsoft PowerShell Source File -- Created with SAPIEN Technologies PrimalScript 2009
# NAME: SQLPSX_LoadModules.ps1
# AUTHOR: Max Trinidad , PutItTogether
# DATE  : 1/3/2010
# 
# COMMENT: Script to load all SQLPSX module into PS Session.
# 
# ==============================================================================================

$DestinationLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\SQLPSX";
$env:PSModulePath = $env:PSModulePath + ";" + $DestinationLocation;
$PSXloadModules = "SQLServer","Agent","Repl","SSIS","SQLParser","Showmbrs";
foreach($PSXmodule in $PSXloadModules){
  Write-Host "Loading SQLPSX Module - $PSXModule";
  Import-Module $PSXmodule
}
Write-Host "Loading SQLPSX Modules is Done!"

