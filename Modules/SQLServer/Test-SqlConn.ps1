# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Verifies Sql connectivity and writes successful conenction to stdout and 
### failed connections to stderr. Script is useful when combined with other
### scripts which would otherwise produce a terminating error on connectivity
### </Description>
### <Usage>
### Get-Content ./servers.txt | ./Test-SqlConn.ps1
### </Usage>
### </Script>
# --------------------------------------------------------------------------
foreach ($i in $input) { 
 $connectionString = "Data Source=$i;Integrated Security=true;Initial Catalog=master;Connect Timeout=3;"
 $sqlConn = new-object ("Data.SqlClient.SqlConnection") $connectionString                                          
 trap {Write-Error "Cannot connect to $i.";continue} $sqlConn.Open()
 if ($sqlConn.State -eq 'Open') {$sqlConn.Close();$i}
}


