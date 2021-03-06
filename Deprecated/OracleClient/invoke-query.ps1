function invoke-oracle_query{
<#
.SYNOPSIS
    Execute a sql statement, returning the results of the query.  
.DESCRIPTION
    This function executes a sql statement, using the parameters provided (both input and output) and returns the results of the query.  
    You may optionally provide a connection or sufficient information to create a connection, as well as input and output parameters, command timeout value, and a transaction to join.
.EXAMPLE
    This is an example of a query that returns a single result.  
    PS C:\> $c=new-connection '.\sqlexpress'
    PS C:\> $res=invoke-query 'select * from master.dbo.sysdatabases' -conn $c
    PS C:\> $res 
.EXAMPLE
    This is an example of a query that returns 2 distinct result sets.  
    PS C:\> $c=new-connection '.\sqlexpress'
    PS C:\> $res=invoke-query 'select * from master.dbo.sysdatabases; select * from master.dbo.sysservers' -conn $c
    PS C:\> $res.Tables[1]
.EXAMPLE
    This is an example of a query that returns a single result and uses a parameter.  It also generates its own (ad hoc) connection.
    PS C:\> invoke-query 'select * from master.dbo.sysdatabases where name=@dbname' -param  @{dbname='master'} -server '.\sqlexpress' -database 'master'
.INPUTS
    None.
    You cannot pipe objects to invoke-query
.OUTPUTS
    Several possibilities (depending on the structure of the query and the presence of output variables)
    1.  A list of rows 
    2.  A dataset (for multi-result set queries)
    3.  An object that contains a dictionary of ouptut parameters and their values and either 1 or 2 (for queries that contain output parameters)
#>
[CmdletBinding(SupportsShouldProcess=$False)]
param( 
       # The SQL Statement
       [Parameter(Mandatory=$true)][string]$sql,
	   # An existing connection to perform the sql statement with.  
       [Oracle.DataAccess.Client.OracleConnection]$connection,
	   # A hashtable of input parameters to be supplied with the query.  See example 2. 
       [hashtable]$parameters=@{},
	   # A hashtable of output parameters to be supplied with the query.  Entries in the hashtable should have names that match the parameter names, and string values that are the type of the parameters. See example 3. 
       [hashtable]$outparameters=@{},
	   # The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.
       [int]$timeout=30,
       # The datasource to connect to. Example tns
      [string]$tns,
	   # The sql user to use for the connection.  If both User and Connection are specified, User is ignored.
       [string]$user,
	   # The password for the sql user named by the User parameter.
       [string]$password,
       # Oracle allows database administrators to connect with either SYSDBA or SYSOPER privileges.
       [string]$dbaPrivilege='',
	   # A transaction to execute the sql statement in.
       [Oracle.DataAccess.Client.OracleConnection]$transaction
       )


	$connection=get-oracle_connection -conn $connection -tns $tns -user $user -password $password  -dbaPrivilege $dbaPrivilege
 	$cmd=new-object Oracle.DataAccess.Client.OracleCommand($sql,$connection)

	$cmd.CommandTimeout=$timeout
	foreach($p in $parameters.Keys){
		$cmd.Parameters.AddWithValue("$p",$parameters[$p]).Direction=[System.Data.ParameterDirection]::Input
	}

    if ($transaction -is [Oracle.DataAccess.Client.OracleTransaction]) {
  	    write-verbose 'Setting transaction'
     	$cmd.Transaction = $transaction
    }
#	put-outputparameters $cmd $outparameters
	$ds=New-Object system.Data.DataSet
	$da=New-Object Oracle.DataAccess.Client.OracleDataAdapter($cmd)
	$da.fill($ds) | Out-Null
    
	#if ad-hoc connection, close it
    if ($tns){
      $connection.close()
    }
    
#	get-outputparameters $cmd $outparameters

	return (get-commandresults $ds $outparameters)
}
