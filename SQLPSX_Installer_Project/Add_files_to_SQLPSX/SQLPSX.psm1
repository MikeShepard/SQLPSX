# ==============================================================================================
# Microsoft PowerShell Source File -- Created with SAPIEN Technologies PrimalScript 2009
# NAME: SQLPSX_LoadModules.ps1 (renamed to SQLPSX.psm1)
# AUTHOR: Max Trinidad , PutItTogether
# DATE  : 1/3/2010
# 
# COMMENT: Script to load all SQLPSX module into PS Session.
# 03/24/2010 - added new modules: adolib,SQLmaint, & SQLIse.
# 04/04/2010 - Fix $DestinationLocation using split and to end in ";".
# 05/07/2010 - Script remaned to a *psm1 
# 05/11/2010 - Commented out the module path to SQLPSX\Modules to go to modules by default.
# ==============================================================================================

# Building Module destination path and adding it to the PowerShell PSModulePath variable
$mpath = $env:PSModulePath.Split(";") ; $DestinationLocation = "SQLPSX\Modules;" + $mpath[0] + "\SQLPSX\Modules;";
$env:PSModulePath = $env:PSModulePath + $DestinationLocation;

# Here's the SQLPSX modules to be loaded: (feel free to manually customized to your need)
# the following ones are turned off from the list of modules being loaded: WPK, ISECreamBasic, OracleClient, OracleIse, and SQLIse.
$PSXloadModules = "SQLServer","Agent","Repl","SSIS","SQLParser","Showmbrs","SQLmaint","adolib";

# Here's the loop that will load the modules
foreach($PSXmodule in $PSXloadModules){
  Write-Host "Loading SQLPSX Module - $PSXModule";
  Import-Module $PSXmodule;
}
Write-Host "Loading SQLPSX Modules is Done!"

