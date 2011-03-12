[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Mike Shepard
### </Author>
### <Description>
### Defines functions for executing Ado.net queries with mySQL
### </Description>
### <Usage>
### import-module mySQLLib
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------


<#
	.SYNOPSIS
		Tests to see if a value is a SQL NULL or not

	.DESCRIPTION
		Returns $true if the value is a SQL NULL.

	.PARAMETER  value
		The value to test

	

	.EXAMPLE
		PS C:\> Is-NULL $row.columnname

	
    .INPUTS
        None.
        You cannot pipe objects to New-Connection

	.OUTPUTS
		Boolean

#>
function Is-NULL{
  param([Parameter(Position=0, Mandatory=$true)]$value)
  return  [System.DBNull]::Value.Equals($value)
}


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
		PS C:\> New-Connection -server MYSERVER -database master

	.EXAMPLE
		PS C:\> Get-Something -server MYSERVER -user sa -password sapassword

    .INPUTS
        None.
        You cannot pipe objects to New-Connection

	.OUTPUTS
		System.Data.SqlClient.SQLConnection

#>
function New-MySQLConnection{
param([Parameter(Position=0, Mandatory=$true)][string]$server, 
      [Parameter(Position=1, Mandatory=$false)][string]$database='',
      [string]$user='',
      [string]$password='',
      [int]$port=3306)

	if($database -ne ''){
	  $dbclause="Database=$database;"
	}
	$conn=new-object MySql.Data.MySqlClient.MySqlConnection
	
	if ($user -ne ''){
		$conn.ConnectionString="Server=$Server;Port=$port;Database=$DataBase;Uid=$User;Pwd=$Password;allow zero datetime=yes"
	} else {
		$conn.ConnectionString="Server=$server;Port=$port;$dbclause`Integrated Security=True"
	}
	$conn.Open()
    write-debug $conn.ConnectionString
	return $conn
}

function Get-Connection{
param([MySql.Data.MySqlClient.MySqlConnection]$conn,
      [string]$server, 
      [string]$database,
      [string]$user,
      [string]$password)
	if (-not $conn){
		if ($server){
			$conn=New-Connection -server $server -database $database -user $user -password $password 
		} else {
		    throw "No connection or connection information supplied"
		}
	}
	return $conn
}

function Put-OutputParameters{
param([Parameter(Position=0, Mandatory=$true)][MySql.Data.MySqlClient.MySqlCommand]$cmd, 
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

function Get-Outputparameters{
param([Parameter(Position=0, Mandatory=$true)][MySql.Data.MySqlClient.MySqlCommand]$cmd,
      [Parameter(Position=1, Mandatory=$true)][hashtable]$outparams)
	foreach($p in $cmd.Parameters){
		if ($p.Direction -eq [System.Data.ParameterDirection]::Output){
		  $outparams[$p.ParameterName.Replace("@","")]=$p.Value
		}
	}
}
#>


function Get-ParamType{
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

function Copy-HashTable{
param([hashtable]$hash,
[String[]]$include,
[String[]]$exclude)

	if($include){
	   $newhash=@{}
	   foreach ($key in $include){
	    if ($hash.ContainsKey($key)){
	   		$newhash.Add($key,$hash[$key]) | Out-Null 
		}
	   }
	} else {
	   $newhash=$hash.Clone()
	   if ($exclude){
		   foreach ($key in $exclude){
		        if ($newhash.ContainsKey($key)) {
		   			$newhash.Remove($key) | Out-Null 
				}
		   }
	   }
	}
	return $newhash
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
function Get-CommandResults{
param([Parameter(Position=0, Mandatory=$true)][System.Data.Dataset]$ds
    ,       [Parameter(Position=1, Mandatory=$true)][HashTable]$outparams
    )   

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
		Create a sql command object

	.DESCRIPTION
		This function uses the information contained in the parameters to create a sql command object.  In general, you will want to use the invoke- functions directly, 
        but if you need to manipulate a command object in ways that those functions don't allow, you will need this.  Also, the invoke-bulkcopy function allows you to pass 
        a command object instead of a set of records in order to "stream" the records into the destination in cases where there are a lot of records and you don't want to
        allocate memory to hold the entire result set.

	.PARAMETER  sql
		The sql to be executed by the command object (although it is not executed by this function).

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
		PS C:\> $cmd=new-sqlcommand "ALTER DATABASE AdventureWorks Modify Name = Northwind" -server MyServer
        PS C:\> $cmd.ExecuteNonQuery()


	.EXAMPLE
		PS C:\> $cmd=new-sqlcommand -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-sqlbulkcopy -records $cmd -server MyOtherServer -table CopyOfMyTable

    .INPUTS
        None.
        You cannot pipe objects to new-sqlcommand

	.OUTPUTS
		System.Data.SqlClient.SqlCommand

#>
function New-MySQLCommand{
param([Parameter(Position=0, Mandatory=$true)][Alias('storedProcName')][string]$sql,
      [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][ MySql.Data.MySqlClient.MySQLConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][int]$timeout=30,
      [Parameter(ParameterSetName="AdHocConnection",Position=4, Mandatory=$false)][string]$server,
      [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$database,
      [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$user,
      [Parameter(Position=7, Mandatory=$false)][string]$password,
      [Parameter(Position=8, Mandatory=$false)][MySql.Data.MySqlClient.MySqlTransaction]$transaction=$null
	  ,[Parameter(Position=9, Mandatory=$false)][hashtable]$outparameters=@{}
     )
   
    $dbconn=Get-Connection -conn $connection -server $server -database $database -user $user -password $password
    $close=($dbconn.State -eq [System.Data.ConnectionState]'Closed')
    if ($close) {
        $dbconn.Open()
    }	
    $cmd=new-object  MySql.Data.MySqlClient.MySqlCommand($sql,$dbconn)
    $cmd.CommandTimeout=$timeout
    foreach($p in $parameters.Keys){
	    $parm=$cmd.Parameters.AddWithValue("@$p",$parameters[$p])
        if (Is-NULL $parameters[$p]){
           $parm.Value=[DBNull]::Value
        }
    }
    put-outputparameters $cmd $outparameters

    if ($transaction -is [MySql.Data.MySqlClient.MySqlTransaction]){
	   $cmd.Transaction = $transaction
    }
    return $cmd


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
		PS C:\> $con=New-Connection MyServer
        PS C:\> invoke-sql "Update Table1 set Col1=null where TableID=@ID" -parameters @{ID=5}

    .INPUTS
        None.
        You cannot pipe objects to invoke-sql

	.OUTPUTS
		Integer

#>
function Invoke-MySql{
param([Parameter(Position=0, Mandatory=$true)][string]$sql,
      [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][MySql.Data.MySqlClient.MySqlConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
      [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
      [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$server,
      [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$database,
      [Parameter(ParameterSetName="AdHocConnection",Position=7, Mandatory=$false)][string]$user,
      [Parameter(ParameterSetName="AdHocConnection",Position=8, Mandatory=$false)][string]$password,
      [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null)
	

       $cmd=new-mysqlcommand @PSBoundParameters

       #if it was an ad hoc connection, close it
       if ($server){
          $cmd.connection.close()
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
        PS C:\> $c=New-Connection '.\sqlexpress'
        PS C:\> $res=invoke-query 'select * from master.dbo.sysdatabases' -conn $c
        PS C:\> $res 
   .EXAMPLE
        This is an example of a query that returns 2 distinct result sets.  
        PS C:\> $c=New-Connection '.\sqlexpress'
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
function Invoke-MySQLQuery{
param( [Parameter(Position=0, Mandatory=$true)][string]$sql,
       [Parameter(ParameterSetName="SuppliedConnection", Position=1, Mandatory=$false)][MySql.Data.MySqlClient.MySqlConnection]$connection,
       [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
       [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
       [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
       [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$server,
       [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$database,
       [Parameter(ParameterSetName="AdHocConnection",Position=7, Mandatory=$false)][string]$user,
       [Parameter(ParameterSetName="AdHocConnection",Position=8, Mandatory=$false)][string]$password,
       [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null,
       [Parameter(Position=10, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow", "Dynamic")] [string]$AsResult="Dynamic"
       )
    
	$connectionparameters=copy-hashtable $PSBoundParameters -exclude AsResult
    $cmd=new-mysqlcommand @connectionparameters
    $ds=New-Object system.Data.DataSet
    $da=New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd)
    $da.fill($ds) | Out-Null
    
    #if it was an ad hoc connection, close it
    if ($server){
       $cmd.connection.close()
    }
    get-outputparameters $cmd $outparameters
    switch ($AsResult)
    {
        'DataSet'   { $result = $ds }
        'DataTable' { $result = $ds.Tables }
        'DataRow'   { $result = $ds.Tables[0] }
        'Dynamic'   { $result = get-commandresults $ds $outparameters  } 
    }
    return $result
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
        PS C:\> $c=New-Connection -server '.\sqlexpress' 
        PS C:\> invoke-storedprocedure 'sp_who2' -conn $c
    .EXAMPLE 
        #Calling a stored procedure that has an output parameter and multiple result sets
        PS C:\> $c=New-Connection '.\sqlexpress'
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
function Invoke-MySQLStoredProcedure{
param([Parameter(Position=0, Mandatory=$true)][string]$storedProcName,
      [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][MySql.Data.MySqlClient.MySqlConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable] $parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
      [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
      [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$server,
      [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$database,
      [Parameter(ParameterSetName="AdHocConnection",Position=7, Mandatory=$false)][string]$user,
      [Parameter(ParameterSetName="AdHocConnection",Position=8, Mandatory=$false)][string]$password,
      [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null) 

	$cmd=new-MySqlCommand @PSBoundParameters
	$cmd.CommandType=[System.Data.CommandType]::StoredProcedure  
    $ds=New-Object system.Data.DataSet
    $da=New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd)
    $da.fill($ds) | out-null

    get-outputparameters $cmd $outparameters

    #if it was an ad hoc connection, close it
    if ($server){
       $cmd.connection.close()
    }	
	
    return (get-commandresults $ds $outparameters )
}




export-modulemember New-MySQLConnection
export-modulemember new-MySqlCommand
export-modulemember invoke-MySql
export-modulemember invoke-MySqlquery
export-modulemember invoke-MySqlStoredProcedure
