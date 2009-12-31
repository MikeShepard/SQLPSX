# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Mike Shepard
### </Author>
### <Description>
### Defines functions for executing Ado.net queries
### </Description>
### <Usage>
### import-module adolib
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------

<#
	.SYNOPSIS
		Create a SQLConnection object with the given parameters

	.DESCRIPTION
		This function creates a SQLConnection object, using the parameters provided to construct the connection string.  You may optionally provide the initial database, and SQL credentials (to use instead of NT Authentication).

	.PARAMETER  Server
		The name of the SQL Server to connect to.  To connect to a named instance, enclose the server name in quotes (e.g. "Laptop\SQLExpress")

	.PARAMETER  Database
		The InitialDatabase for the connection.
	
    .PARAMETER  User
		The SQLUser you wish to use for the connection (instead of using NT Authentication)
        
	.PARAMETER  Password
		The password for the user specified by the User parameter.

	.EXAMPLE
		PS C:\> new-connection -server MYSERVER -database master

	.EXAMPLE
		PS C:\> Get-Something -server MYSERVER -user sa -password sapassword

    .INPUTS
        None.
        You cannot pipe objects to New-connection

	.OUTPUTS
		System.Data.SqlClient.SQLConnection

#>
function new-connection{
param([Parameter(Position=0, Mandatory=$true)][string]$server, 
      [Parameter(Position=1, Mandatory=$false)][string]$database='',
      [string]$user='',
      [string]$password='')

	if($database -ne ''){
	  $dbclause="Database=$database;"
	}
	$conn=new-object System.Data.SqlClient.SQLConnection
	
	if ($user -ne ''){
		$conn.ConnectionString="Server=$server;$dbclause`User ID=[$user];Password=$password"
	} else {
		$conn.ConnectionString="Server=$server;$dbclause`Integrated Security=True"
	}
	$conn.Open()
    write-debug $conn.ConnectionString
	return $conn
}

function get-connection{
param([System.Data.SqlClient.SQLConnection]$conn,
      [string]$server, 
      [string]$database,
      [string]$user,
      [string]$password)
	if (-not $conn){
		if ($server){
			$conn=new-connection -server $server -database $database -user $user -password $password 
		} else {
		    throw "No connection or connection information supplied"
		}
	}
	return $conn
}

function put-outputparameters{
param([Parameter(Position=0, Mandatory=$true)][System.Data.SqlClient.SQLCommand]$cmd, 
      [Parameter(Position=1, Mandatory=$false)][hashtable]$outparams)
    if ($outparams){
    	foreach($outp in $outparams.Keys){
            $paramtype=get-paramtype $outparams[$outp]
            $p=$cmd.Parameters.Add("@$outp",$paramtype)
    		$p.Direction=[System.Data.ParameterDirection]::Output
            if ($paramtype -like '*char*'){
               $p.Size=[int]$outparams[$outp].Replace($paramtype.ToString().ToLower(),'').Replace('(','').Replace(')','')
            }
    	}
    }
}

function get-outputparameters{
param([Parameter(Position=0, Mandatory=$true)][System.Data.SqlClient.SQLCommand]$cmd,
      [Parameter(Position=1, Mandatory=$true)][hashtable]$outparams)
	foreach($p in $cmd.Parameters){
		if ($p.Direction -eq [System.Data.ParameterDirection]::Output){
		  $outparams[$p.ParameterName.Replace("@","")]=$p.Value
		}
	}
}



function get-paramtype{
param([string]$typename)
	$type=switch -wildcard ($typename.ToLower()) {
		'uniqueidentifier' {[System.Data.SqlDbType]::UniqueIdentifier}
		'int'  {[System.Data.SQLDbType]::Int}
		'datetime'  {[System.Data.SQLDbType]::Datetime}
		'tinyint'  {[System.Data.SQLDbType]::tinyInt}
		'smallint'  {[System.Data.SQLDbType]::smallInt}
		'bigint'  {[System.Data.SQLDbType]::BigInt}
		'bit'  {[System.Data.SQLDbType]::Bit}
		'char*'  {[System.Data.SQLDbType]::char}
		'nchar*'  {[System.Data.SQLDbType]::nchar}
		'date'  {[System.Data.SQLDbType]::date}
		'datetime'  {[System.Data.SQLDbType]::datetime}
        'varchar*' {[System.Data.SqlDbType]::Varchar}
        'nvarchar*' {[System.Data.SqlDbType]::nVarchar}
		default {[System.Data.SqlDbType]::Int}
	}
	return $type
	
}


<#
Helper function figure out what kind of returned object to build from the results of a sql call (ds). 
Options are:
	1.  Dataset   (multiple lists of rows)
	2.  Datatable (list of datarows)
	3.  Nothing (no rows and no output variables
	4.  Dataset with output parameter dictionary
	5.  Datatable with output parameter dictionary
	6.  A dictionary of output parameters
	

#>
function get-commandresults{
param([Parameter(Position=0, Mandatory=$true)][System.Data.Dataset]$ds, 
      [Parameter(Position=1, Mandatory=$true)][HashTable]$outparams)   

	if ($ds.tables.count -eq 1){
		$retval= $ds.Tables[0]
	}
	elseif ($ds.tables.count -eq 0){
		$retval=$null
	} else {
		[system.Data.DataSet]$retval= $ds 
	}
	if ($outparams.Count -gt 0){
		if ($retval){
			return @{Results=$retval; OutputParameters=$outparams}
		} else {
			return $outparams
		}
	} else {
		return $retval
	}
}

<#
	.SYNOPSIS
		Execute a sql statement, ignoring the result set.  Returns the number of rows modified by the statement (or -1 if it was not a DML staement)

	.DESCRIPTION
		This function executes a sql statement, using the parameters provided and returns the number of rows modified by the statement.  You may optionally 
        provide a connection or sufficient information to create a connection, as well as input parameters, command timeout value, and a transaction to join.

	.PARAMETER  sql
		The SQL Statement

	.PARAMETER  connection
		An existing connection to perform the sql statement with.  

	.PARAMETER  parameters
		A hashtable of input parameters to be supplied with the query.  See example 2. 
        
	.PARAMETER  timeout
		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.

	.PARAMETER  Server
		The server to connect to.  If both Server and Connection are specified, Server is ignored.

	.PARAMETER  Database
		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.

	.PARAMETER  User
		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Transaction
		A transaction to execute the sql statement in.

	.EXAMPLE
		PS C:\> invoke-sql "ALTER DATABASE AdventureWorks Modify Name = Northwind" -server MyServer


	.EXAMPLE
		PS C:\> $con=new-connection MyServer
        PS C:\> invoke-sql "Update Table1 set Col1=null where TableID=@ID" -parameters @{ID=5}

    .INPUTS
        None.
        You cannot pipe objects to invoke-sql

	.OUTPUTS
		Integer

#>
function invoke-sql{
param([Parameter(Position=0, Mandatory=$true)][string]$sql,
      [Parameter(Position=1, Mandatory=$false)][System.Data.SqlClient.SQLConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][int]$timeout=30,
      [Parameter(Position=4, Mandatory=$false)][string]$server,
      [Parameter(Position=5, Mandatory=$false)][string]$database,
      [Parameter(Position=6, Mandatory=$false)][string]$user,
      [Parameter(Position=7, Mandatory=$false)][string]$password,
      [Parameter(Position=8, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$nothing)
	
	$conn=get-connection -conn $connection -server $server -database $database -user $user -password $password 
	
	
	$cmd=new-object system.Data.SqlClient.SqlCommand($sql,$connection)
	$cmd.CommandTimeout=$timeout
	foreach($p in $parameters.Keys){
				[Void] $cmd.Parameters.AddWithValue("@$p",$parameters[$p])
	}
    if ($transaction -is [System.Data.SqlClient.SqlTransaction]){
       write-verbose 'Setting transaction'
       $cmd.Transaction = $transaction
    }
	return $cmd.ExecuteNonQuery()
	
}
<#
	.SYNOPSIS
		Execute a sql statement, returning the results of the query.  

	.DESCRIPTION
		This function executes a sql statement, using the parameters provided (both input and output) and returns the results of the query.  You may optionally 
        provide a connection or sufficient information to create a connection, as well as input and output parameters, command timeout value, and a transaction to join.

	.PARAMETER  sql
		The SQL Statement

	.PARAMETER  connection
		An existing connection to perform the sql statement with.  

	.PARAMETER  parameters
		A hashtable of input parameters to be supplied with the query.  See example 2. 

	.PARAMETER  outparameters
		A hashtable of input parameters to be supplied with the query.  Entries in the hashtable should have names that match the parameter names, and string values that are the type of the parameters. See example 3. 
        
	.PARAMETER  timeout
		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.

	.PARAMETER  Server
		The server to connect to.  If both Server and Connection are specified, Server is ignored.

	.PARAMETER  Database
		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.

	.PARAMETER  User
		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Transaction
		A transaction to execute the sql statement in.
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
function invoke-query{
param( [Parameter(Position=0, Mandatory=$true)][string]$sql,
       [Parameter(Position=1, Mandatory=$false)][System.Data.SqlClient.SqlConnection]$connection,
       [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
       [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
       [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
       [Parameter(Position=5, Mandatory=$false)][string]$server,
       [Parameter(Position=6, Mandatory=$false)][string]$database,
       [Parameter(Position=7, Mandatory=$false)][string]$user,
       [Parameter(Position=8, Mandatory=$false)][string]$password,
       [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction)

	$connection=get-connection -conn $connection -server $server -database $database -user $user -password $password 
		
	$cmd=new-object system.Data.SqlClient.SqlCommand($sql,$connection)
	$cmd.CommandTimeout=$timeout
	foreach($p in $parameters.Keys){
		$cmd.Parameters.AddWithValue("@$p",$parameters[$p]).Direction=[System.Data.ParameterDirection]::Input
	}
    if ($transaction -is [System.Data.SqlClient.SqlTransaction]) {
  	    write-verbose 'Setting transaction'
     	$cmd.Transaction = $transaction
    }
	put-outputparameters $cmd $outparameters
	$ds=New-Object system.Data.DataSet
	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
	$da.fill($ds) | Out-Null
    
	#if ad-hoc connection, close it
    if ($server){
      $connection.close()
    }	
    
	get-outputparameters $cmd $outparameters

	return (get-commandresults $ds $outparameters)
}
<#
	.SYNOPSIS
		Execute a stored procedure, returning the results of the query.  

	.DESCRIPTION
		This function executes a stored procedure, using the parameters provided (both input and output) and returns the results of the query.  You may optionally 
        provide a connection or sufficient information to create a connection, as well as input and output parameters, command timeout value, and a transaction to join.

	.PARAMETER  sql
		The SQL Statement

	.PARAMETER  connection
		An existing connection to perform the sql statement with.  

	.PARAMETER  parameters
		A hashtable of input parameters to be supplied with the query.  See example 2. 

	.PARAMETER  outparameters
		A hashtable of input parameters to be supplied with the query.  Entries in the hashtable should have names that match the parameter names, and string values that are the type of the parameters. 
        Note:  not all types are accounted for by the code. int, uniqueidentifier, varchar(n), and char(n) should all work, though.
        
	.PARAMETER  timeout
		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.

	.PARAMETER  Server
		The server to connect to.  If both Server and Connection are specified, Server is ignored.

	.PARAMETER  Database
		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.

	.PARAMETER  User
		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Transaction
		A transaction to execute the sql statement in.
    .EXAMPLE
        #Calling a simple stored procedure with no parameters
        PS C:\> $c=new-connection -server '.\sqlexpress' 
        PS C:\> invoke-storedprocedure 'sp_who2' -conn $c
    .EXAMPLE 
        #Calling a stored procedure that has an output parameter and multiple result sets
        PS C:\> $c=new-connection '.\sqlexpress'
        PS C:\> $res=invoke-storedprocedure -storedProcName 'AdventureWorks2008.dbo.stp_test' -outparameters @{LogID='int'} -conne $c
        PS C:\> $res.Results.Tables[1]
        PS C:\> $res.OutputParameters
        
        For reference, here's the stored procedure:
        CREATE procedure [dbo].[stp_test]
            @LogID int output
        as
            set @LogID=5
            select * from master.dbo.sysdatabases
            select * from master.dbo.sysservers
    .EXAMPLE 
        #Calling a stored procedure that has an input parameter
        PS C:\> invoke-storedprocedure 'sp_who2' -conn $c -parameters @{loginame='sa'}
    .INPUTS
        None.
        You cannot pipe objects to invoke-storedprocedure

    .OUTPUTS
        Several possibilities (depending on the structure of the query and the presence of output variables)
        1.  A list of rows 
        2.  A dataset (for multi-result set queries)
        3.  An object that contains a hashtables of ouptut parameters and their values and either 1 or 2 (for queries that contain output parameters)
#>
function invoke-storedprocedure{
param([Parameter(Position=0, Mandatory=$true)][string]$storedProcName,
      [Parameter(Position=1, Mandatory=$false)][System.Data.SqlClient.SqlConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable] $parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
      [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
      [Parameter(Position=5, Mandatory=$false)][string]$server,
      [Parameter(Position=6, Mandatory=$false)][string]$database,
      [Parameter(Position=7, Mandatory=$false)][string]$user,
      [Parameter(Position=8, Mandatory=$false)][string]$password,
      [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$nothing) 

	$connection=get-connection -conn $connection -server $server -database $database -user $user -password $password 

	$cmd=new-object system.Data.SqlClient.SqlCommand($sql,$connection)
	$cmd.CommandType=[System.Data.CommandType]'StoredProcedure'
	$cmd.CommandTimeout=$timeout
	$cmd.CommandText=$storedProcName
	foreach($p in $parameters.Keys){
		$cmd.Parameters.AddWithValue("@$p",$parameters[$p]).Direction=[System.Data.ParameterDirection]::Input
	}
  	if ($transaction -is [System.Data.SqlClient.SqlTransaction]) {
   		$cmd.Transaction = $transaction
 	}
	
	put-outputparameters $cmd $outparameters
	$ds=New-Object system.Data.DataSet
	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
	$da.fill($ds) | out-null
	
	get-outputparameters $cmd $outparameters
		
	return (get-commandresults $ds $outparameters)
}


export-modulemember new-connection
export-modulemember invoke-sql
export-modulemember invoke-query
export-modulemember invoke-storedprocedure
