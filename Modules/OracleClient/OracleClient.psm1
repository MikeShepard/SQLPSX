# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Bernd Kriszio
### </Author>
### <Description>
### Defines functions for executing Ado.net queries against Oracle
### </Description>
### <Usage>
### import-module OracleClient
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------


[System.Reflection.Assembly]::LoadWithPartialName("Oracle.DataAccess")
[System.Reflection.Assembly]::LoadWithPartialName("System.Data.OracleClient")

. $psScriptRoot\new-connection.ps1
. $psScriptRoot\invoke-query.ps1
. $psScriptRoot\get-commandresults.ps1
. $psScriptRoot\OracleBulkcopy.ps1


export-modulemember  new-oracle_connection
# export-modulemember -function invoke-sql
export-modulemember -function invoke-oracle_query, ConvertTo-oracleDataSource, Invoke-OracleBulkcopy
# export-modulemember -function invoke-storedprocedure
