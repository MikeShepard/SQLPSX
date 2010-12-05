ipmo adolib -Force 

function AssertEquals{
param($lhs,$rhs,$description)
if ($lhs -eq $rhs){ 
	Write-Host "$description PASSED" -BackgroundColor Green 
} else {
	Write-Host "$description FAILED" -BackgroundColor Red
}
}

$server = '.\SQLEXPRESS'
$db = 'TestAdoLib'
$sql = "SELECT * from Application"

#test simple query using ad hoc connection and NT authentication
$rows=invoke-query -sql $sql -server $server -database $db
AssertEquals $rows.Count 7 "ad hoc connection with NT auth" 

#test simple query using ad hoc connection and SQL login
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345
AssertEquals $rows.Count 7 "ad hoc connection with SQL Login" 

#test parameterized query with ad hoc connection and sql login
$rows=@(invoke-query -sql 'select * from Application where Application like @app' -server $server -database $db -user test_login -password 12345 -parameters @{app='CRM%'})
AssertEquals $rows.Count 1 "parameterized query with sql login" 

#test parameterized query with ad hoc connection and sql login
$rows=@(invoke-query -sql 'select * from Application where Application like @app' -server $server -database $db  -parameters @{app='CRM%'})
AssertEquals $rows.Count 1 "parameterized query with NT Auth" 

Remove-Variable conn
$conn=new-connection  -server $server -database $db

#test simple query using shared connection and NT authentication
$rows=invoke-query -sql $sql -conn $conn 
AssertEquals $rows.Count 7 "shared connection with NT auth" 

#test parameterized query with shared connection and NT Auth
$rows=@(invoke-query -sql 'select * from Application where Application like @app' -conn $conn  -parameters @{app='CRM%'})
AssertEquals $rows.Count 1 "parameterized query with shared connection and NT Auth" 

$conn.Close()

$conn=new-connection  -server $server -database $db  -user test_login -password 12345


#test simple query using shared connection and SQL login
$rows=invoke-query -sql $sql -conn $conn 
AssertEquals $rows.Count 7 "shared connection and SQL login" 

#test parameterized query with shared connection and sql login
$rows=@(invoke-query -sql 'select * from Application where Application like @app' -conn $conn  -parameters @{app='CRM%'})
AssertEquals $rows.Count 1 "parameterized query with shared connection and sql login" 
 
#test stored procedure query with shared connection and sql login and IN parameters
$rows=@(invoke-storedprocedure  -storedProcName stp_TestInParam  -conn $conn  -parameters @{app='CRM%'})
AssertEquals $rows.Count 1 "parameterized query (in) with shared connection and sql login" 

#test stored procedure query with shared connection and sql login and out parameters
$outRows=@(invoke-storedprocedure  -storedProcName stp_TestOutParam  -conn $conn  -parameters @{app='CRM%'} -outparameters @{appID='uniqueidentifier'})
AssertEquals ($outRows[0].appID -is [Guid]) $true "parameterized query (out) with shared connection and sql login" 

#test NULL parameters
$rows=invoke-query "select * from Application where @parm is NULL" -conn $conn -parameters @{parm=[System.DBNull]::Value}
AssertEquals $rows.Count 7 "shared connection null parameters" 

#test simple query using ad hoc connection and SQL Login with "-AsResult DataTable"
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataTable
AssertEquals ($rows -is [Data.DataTable]) $true  "ad hoc connection with SQL Login as DataTable" 

#test simple query using ad hoc connection and SQL Login with "-AsResult DataSet"
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataSet
AssertEquals ($rows -is [Data.DataSet]) $true  "ad hoc connection with SQL Login as DataSet" 


#test simple query using ad hoc connection and SQL Login with "-AsResult DataRow"
$rows=@(invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataRow)
AssertEquals ($rows[0] -is [Data.DataRow]) $true  "ad hoc connection with SQL Login as DataRow" 


