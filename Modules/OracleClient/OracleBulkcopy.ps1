<#
	.SYNOPSIS
		Uses the .NET OracleBulkCopy class to quickly copy rows into a destination table.

	.DESCRIPTION
        
		Also, the Invoke-OracleBulkcopy function allows you to pass a command object instead of a set of records in order to "stream" the records
        into the destination in cases where there are a lot of records and you don't want to allocate memory to hold the entire result set.

	.PARAMETER  records
		Either a datatable (like one returned from invoke-query or invoke-storedprocedure) or
        A sql command object (use new-sqlcommand)

	.PARAMETER  TNS
		The destination server TNS to connect to.  

	.PARAMETER  User
		The sql user to use for the connection.  If user is not passed, NT Authentication is used.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Table
		The destination table for the bulk copy operation.

	.PARAMETER  dbaPrivilege
		"DBA Privilege" for the connection 

	.PARAMETER  Mapping
		A dictionary of column mappings of the form DestColumn=SourceColumn

	.PARAMETER  BatchSize
		The batch size for the bulk copy operation.

	.PARAMETER  NotifyAfter
		The number of rows to fire the notification event after transferring.  0 means don't notify.
        Ex: 1000 means to fire the notify event after each 1000 rows are transferred.
        
    .PARAMETER  NotifyFunction
        A scriptblock to be executed after each $notifyAfter records has been copied.  The second parameter ($param[1]) 
        is a SqlRowsCopiedEventArgs object, which has a RowsCopied property.  The default value for this parameter echoes the
        number of rows copied to the console
        
    .PARAMETER  Options
        An object containing special options to modify the bulk copy operation.
        See http://download.oracle.com/docs/html/E10927_01/OracleBulkCopyOptionsEnumeration.htm#CHDEHFFF for values.


	.EXAMPLE
		PS C:\> $cmd=new-sqlcommand -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-Oraclebulkcopy -records $cmd -tns MyOtherServer -user myuser -password topsecret -table CopyOfMyTable

	.EXAMPLE
		PS C:\> $rows=invoke-query -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-Oraclebulkcopy -records $rows -tns MyOtherServer -password topsecret -table CopyOfMyTable

    .INPUTS
        None.
        You cannot pipe objects to Invoke-OracleBulkcopy

	.OUTPUTS
		None.

#>
function Invoke-OracleBulkcopy{
  param([Parameter(Position=0, Mandatory=$true)]$records,
        [Parameter(Position=1, Mandatory=$true)]$tns,
        [Parameter(Position=2, Mandatory=$false)][string]$user,
        [Parameter(Position=3, Mandatory=$false)][string]$password,
        [Parameter(Position=4, Mandatory=$true)][string]$table,
        [Parameter(Position=5, Mandatory=$false)][string]$dbaPrivilege,
        [Parameter(Position=6, Mandatory=$false)]$mapping=@{},
        [Parameter(Position=7, Mandatory=$false)]$batchsize=0,
        [Parameter(Position=8, Mandatory=$false)]$notifyAfter=0,
        [Parameter(Position=9, Mandatory=$false)][scriptblock]$notifyFunction={Write-Host "$($args[1].RowsCopied) rows copied."}
        #[Parameter(Position=10, Mandatory=$false)][Oracle.DataAccess.Client.OracleBulkCopyOptions ]$options=[Oracle.DataAccess.Client.OracleBulkCopyOptions ]::Default
        )

	# I#m not using existing "New-Oracle_connection" function to create a connection string.        
    # because I do not get back the password 
    
    $ConnectionString = "Data Source=$tns;User ID=$user;Password=$password"
    Write-host $ConnectionString
    if ($dbaPrivilege)
    {
        $ConnectionString += ";DBA Privilege=$dbaPrivilege"
    }

    if ($options)
    {
	   $bulkCopy = new-object "Oracle.DataAccess.Client.OracleBulkCopy" $connectionString $options
    }
    else
    {
	   $bulkCopy = new-object "Oracle.DataAccess.Client.OracleBulkCopy" $connectionString
    }
       
	$bulkCopy.BatchSize = $batchSize
	$bulkCopy.DestinationTableName = $table
	$bulkCopy.BulkCopyTimeout = 10000000
	if ($notifyAfter -gt 0){
		$bulkCopy.NotifyAfter = $notifyafter
		$bulkCopy.Add_OracleRowscopied($notifyFunction)
	}

	#Add column mappings if they were supplied
	foreach ($key in $mapping.Keys){
	    $bulkCopy.ColumnMappings.Add($mapping[$key],$key) | out-null
	}
	
	write-debug "Bulk copy starting at $(get-date)"
	if ($records -is [System.Data.Common.DBCommand]){
		#if passed a command object (rather than a datatable), ask it for a datareader to stream the records
		$bulkCopy.WriteToServer($records.ExecuteReader())
    } elsif ($records -is [System.Data.Common.DbDataReader]){
		#if passed a Datareader object use it to stream the records
		$bulkCopy.WriteToServer($records)
	} else {
		$bulkCopy.WriteToServer($records)
	}
	write-debug "Bulk copy finished at $(get-date)"
}
