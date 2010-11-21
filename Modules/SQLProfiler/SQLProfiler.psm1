
# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Laerte Junior
### </Author>
### <Description>
### Work with SQL Server Profiler Traces
### </Description>
### <Usage>
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
#Test if Powershell is 64 or X86..This module only works in X86.
$ErrorActionPreference = "Stop"
$PowershellRunning = [intptr]::Size
if ($PowershellRunning -ne 4) {	
	Write-Host -ForegroundColor Red 'Attention. This module only runs on x86 Powershell. Execution interrupted'
	break
}


try {	
	add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop
} catch {
	add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"
}

try {
	add-type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop; $smoVersion = 10
} catch {
	add-type -AssemblyName "Microsoft.SqlServer.Smo"; $smoVersion = 9
}

try {
	add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfoExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop; $smoVersion = 10
} catch {
	add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfoExtended"; $smoVersion = 9
}

try {
    try {
		add-type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop
	} catch {
		add-type -AssemblyName "Microsoft.SqlServer.SMOExtended" -EA Stop
	}
}  catch {
	Write-Warning "SMOExtended not available"
}
	
#Original Function Invoke-Sqlcmd2 in http://poshcode.org/1791

function Invoke-Sqlcmd2
{
    param(
    [Parameter(Position=0, Mandatory=$true ,ValueFromPipeline = $false)] [string]$ServerInstance,
    [Parameter(Position=1, Mandatory=$true ,ValueFromPipeline = $false)] [string]$Database,
	[Parameter(Position=2, Mandatory=$false ,ValueFromPipeline = $false)] [string]$UserName,
	[Parameter(Position=3, Mandatory=$false ,ValueFromPipeline = $false)] [string]$Password,
    [Parameter(Position=4, Mandatory=$true ,ValueFromPipeline = $false)] [string]$Query,
    [Parameter(Position=5, Mandatory=$false ,ValueFromPipeline = $false)] [Int32]$QueryTimeout=30
    )

    $conn=new-object System.Data.SqlClient.SQLConnection
	if ($UserName -and $Password)
	
   		{ $conn.ConnectionString="Server={0};Database={1};User ID={2};Pwd={3}" -f $ServerInstance,$Database,$UserName,$Password }
	else
	    { $conn.ConnectionString="Server={0};Database={1};Integrated Security=True" -f $ServerInstance,$Database  }

    $conn.Open()
    $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
    $cmd.CommandTimeout=$QueryTimeout
    $ds=New-Object system.Data.DataSet
    $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    [void]$da.fill($ds)
    $conn.Close()
    $ds.Tables[0]

}


#######################
<#
.SYNOPSIS
Save SQLProfiler Trace into SQL Server Table.
.DESCRIPTION
Save SQLProfiler Trace into SQL Server Table.You can read and combine multiple SQL Server Trace files into a single SQL Server Table
.PARAMETER $TraceFile        
Mandatory Object
Object with Trace Files
.PARAMETER $ServerName        
Mandatory String
SQL Server Name
.PARAMETER $DatabaseName        
Mandatory String
SQL Server Database Name
.PARAMETER $UserName        
String
User name
.PARAMETER $Password        
String
Password
.PARAMETER $TableName        
String
SQL Server Table Name
.PARAMETER $NewTable        
Switch
IF informed, a new table will be created
.INPUTS
You can Pipe $TraceFile Object
.OUTPUTS
None
.EXAMPLE
Get-SQLProfiler -TraceFileName "c:\Temp\*.trc"  | Save-SQLTraceToSQLTable  -ServerName MyServer -DatabaseName MyDatabase -NewTable -TableName MyTable
This command gets all Trace files in c:\temp and insert into a new table called Mytable
.EXAMPLE
Get-SQLProfiler -TraceFileName "c:\Temp\*.trc"  | Save-SQLTraceToSQLTable  -ServerName MyServer -DatabaseName MyDatabase -NewTable 
This command gets all Trace files in c:\temp and insert into a new table. The name will be created by the function = SQLTraceToSQLTable_yyyyMMddhhmmss
.EXAMPLE
Get-SQLProfiler -TraceFileName "c:\Temp\*.trc"  | Save-SQLTraceToSQLTable  -ServerName MyServer -DatabaseName MyDatabase -TableName MyTable
This command gets all Trace files in c:\temp and insert into a created table called MyTable. 
.LINK
http://sqlpsx.codeplex.com/
#>

Function Save-InfoToSQLTable {

	
	PARAM(
			[Parameter(Position=1,Mandatory=$true, ValueFromPipeline=$true,HelpMessage="Object SQL Server Trace")] 
			[ValidateScript({$_.GetType().Name -is [System.Object]})] $TraceFile ,
			[Parameter(Position=2, Mandatory=$true, ValueFromPipeline = $false,HelpMessage="SQL Server Name")] [String] $ServerName,
			[Parameter(Position=3, Mandatory=$true, ValueFromPipeline = $false,HelpMessage="SQL Server Database Name")] [String] $DatabaseName,
			[Parameter(Position=4, Mandatory=$false, ValueFromPipeline = $false,HelpMessage="SQL Server Server User Name")] [string] $UserName,
			[Parameter(Position=5, Mandatory=$false, ValueFromPipeline = $false,HelpMessage="Password")] [string] $Password,
			[Parameter(Position=6, Mandatory=$false, ValueFromPipeline = $false,HelpMessage="SQL Server Table Name")] [String] $TableName ="",
			[Parameter(Position=7, Mandatory=$false, ValueFromPipeline = $false,HelpMessage="New Table will be created")] [switch] $NewTable = $false

			
		)	

		Begin 
		{
		
			function ConvertTo-SQLDataType 
			{
				param ([string] $DataType)
				switch -regex  ($DataType) {
					('^System.Int32|^System.Int16|^System.Int64') {'Int'}
					'^System.Boolean' {'Bit'}
					('^System.Decimal|^System.Double') {'Float'}
					'^System.DateTime' { 'DateTime'}
					default {'Varchar(max)'}
				}
			
			}
		

			$verbosePreference="continue" 
			$CreatedTable = $false
			$NewTablename = $Tablename
			$TodayDate = Get-Date -Format "yyyy-MM-dd"
			$FirsTime = $true
			
		

			if ($TableName -eq "" -and !$NewTable) {
				Write-output "Save-InfoToSQLTable Error Detail : You need to specify table name or -newtable"
				throw New-Object System.Management.Automation.PipelineStoppedException 
			}

			try {
				if ($TableName) {
					$query = "sp_tables  $TableName"
				} else {
					$query = 'Select getdate()'
				}
			
				Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $query | Out-Null
	
				if ($UserName -and $Password)
					{ $ConnectionString="Server={0};Database={1};User ID={2};Pwd={3}" -f $ServerName,$DatabaseName,$UserName,$Password }
				else
					{ $ConnectionString="Server={0};Database={1};Integrated Security=True" -f $ServerName,$DatabaseName  }


			} catch {

				Write-output "Save-InfoToSQLTable Error Detail : Connection to SQL Server. Please Verify parameters"
				throw New-Object System.Management.Automation.PipelineStoppedException 

			}
			


		}
		Process {
				try {
						if ($FirsTime) {
						
										
							$ColumnsInsert = "" ;	$Columns ="" ;	$SQLCol="" ;	$SQLData="" ;	$Command="" ;	$CommandCreate="" 
							$ColumnsInsert = "SQLCommand.Parameters.Add(""@datetime"", '$(get-date)') | Out-Null  ; "
		
							$TraceFile | Get-Member -MemberType NoteProperty | % { 

								$Columns += "$($_.name) $(ConvertTo-SQLDataType $_.definition.substring(0,$_.definition.indexof(' ')))," 
								$ColumnsInsert += "SQLCommand.Parameters.Add(""@$($_.name)"", NewTrace.$($_.name)) | Out-Null  ; "
								$SQLCol += "$($_.name),"
								$SQLData += "@$($_.name),"
							}
							$SQLCol = "$($SQLCol.substring(0,$SQLCol.Length-1))"
							$SQLData = "$($SQLData.substring(0,$SQLData.Length-1))"
							$Command += "$($Columns.Substring(0,$Columns.Length-1)))"
							$ColumnsInsert = (($ColumnsInsert.substring(0,$ColumnsInsert.Length-1)) -replace 'NewTrace','$NewTrace') -replace 'SQLCommand','$SQLCommand'
							$FirsTime = $false
						}	
			
						if (!$CreatedTable -and $Newtable )	{
		
							if ($tableName -eq "")
								{	$NewTablename = "SQLTraceToSQLTable_$(get-date -format yyyyMMddhhmmss)"}
		
								
							$CommandCreate = " Create table dbo.$NewTablename([DateTime] Datetime,$($command)"
						
							$drop = "IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[$NewTablename]') AND type in (N'U'))
									DROP TABLE [dbo].[$NewTablename]"
	
									
							Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $drop | Out-Null
							Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $CommandCreate | Out-Null


							$CreatedTable = $true
							
							Write-Host "Saving into SQL Server Table $($NewTableName) Server $($ServerName) Database $($DatabaseName)"
							
						}
						
						$SQLInsert = "Insert into $DatabaseName.dbo.$NewTablename ([DateTime],$($SQLCol)) values (@DateTime,$($SQLdata))"
						foreach ($NewTrace in $TraceFile) {


							$SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
							$SqlConnection.open()
							$SQLCommand = new-object System.Data.SqlClient.SqlCommand($SQLInsert,$SqlConnection)
							Invoke-Expression $ColumnsInsert 
							$SQLCommand.executenonquery() | Out-Null
							$SqlConnection.close()
					
						}
					} Catch {
						Write-output - "Save-SQLTraceToSQLTable Error Detail : $Error[0]"
						throw New-Object System.Management.Automation.PipelineStoppedException 
					
					}
								
		}		
					
}

#######################
<#
.SYNOPSIS
Read SQL Server Profiler Traces.
.DESCRIPTION
Read SQL Server Profiler Traces.You can read and combine multiple SQL Server Trace files and differents events.
.PARAMETER $TraceFileName        
Mandatory Object
Object with Trace Files
.PARAMETER $FileToTable        
String
Switch indicate that each SQL Server Trace will inserted on New SQL Server Table. Each table will be called PowershellTraceTable_ and .trc Name.
.PARAMETER $ServerName        
 String
SQL Server  Name
.PARAMETER $ServerName        
String
SQL Server Name
.PARAMETER $DatabaseName        
String
SQL Server Database Name
.INPUTS
You can Pipe $TraceFileName Files
.OUTPUTS
PowerShell Object 
.EXAMPLE
Get-SQLProfiler -TraceFileName "c:\Temp\*.trc"  
This command gets all Trace files in c:\temp 
.EXAMPLE
Get-SQLProfiler -TraceFileName "c:\Temp\*.trc"  | where-object {$_.TexTdata -like '*usp_dosomething*'} | Select *
This command gets all Trace files in c:\temp and filter only textdata like *usp_dosomething*
.EXAMPLE
(Get-SQLProfiler -TraceFileName "c:\Temp\SQL*.trc"  | where-object {$_.TexTdata -like '*usp_dosomething*'} | ConvertTo-XML -Notypeinformation).save("c:\temp\TraceOut.XML)
This command gets all Trace files started with SQL in c:\temp filter by usp_dosomething and output to XML
.EXAMPLE
Get-SqlProfiler  -TraceFileName  "c:\Temp\SQL*.trc"  -FileToTable -ServerName MyServer -DatabaseName MyDatabase
This command gets all Trace files started with SQL in c:\temp  and create a SQL Server Table for each Trace File called PowershellTraceTable_ and .trc Name
.LINK
http://sqlpsx.codeplex.com/
#>


Function Get-SQLProfiler () 


{

	[CmdletBinding()]
	
	PARAM(
			[Parameter(Position=1,Mandatory=$true, ValueFromPipeline=$true,HelpMessage="SQL Server Profiler Trace File")]
			[String] $TraceFileName
			
		
		)	
		
	
	begin   {
	
			
		$verbosePreference="continue" 

	}
	process {

			try {
				

				$LineNumber = 1

						
				# Get All .trc files (one or various)
				foreach ($TraceFilePath in Get-ChildItem $TraceFileName -ErrorAction Stop ) {
				
					try 	{
						
						#get trace name to create table
						$TraceFileNameTRC = ($TraceFilePath.PSChildName).trim()
						$TraceFileNameTRC = $TraceFileNameTRC.Trim()

						[String] $TraceFilePathString = $TraceFilePath

						$TableName = "PowershellTraceTable_" + $TraceFileNameTRC.substring(0,$TraceFileNameTRC.length -4)
						#$TableName = "Powershell" 
						
						$TraceFileReader = New-Object Microsoft.SqlServer.Management.Trace.TraceFile
						$TraceFileReader.InitializeAsReader($TraceFilePathString) 
						
						if ($TraceFileReader.Read()-eq $true) 	{
					
							#get all columns from the trace
							$TotalFields = ($TraceFileReader.FieldCount) -1
						
							for($Count = 0;$Count -le $TotalFields;$Count++)	{

								$block += 	'$FieldName = $TraceFileReader.GetName(' + $Count + ');
								$FieldValue = $TraceFileReader.GetValue($TraceFileReader.GetOrdinal($FieldName));
								if ($FieldValue -eq $Null){	$FieldValue = ''''};


								$ObjectTrace| add-member Noteproperty $FieldName  	$FieldValue ;	'


							}
						
							while ($TraceFileReader.Read())	{
								
							
								$ObjectTrace = New-Object PSObject
								
							
								$ObjectTrace | add-member Noteproperty LineNumber  	$LineNumber 		
								$ObjectTrace | add-member Noteproperty TraceFile  	$TraceFileNameTRC 	

								Invoke-Expression $block
								
								$ObjectTrace
								
								$LineNumber ++ 
							
							}
							$TraceFileReader.close() 
						
						}
						
			
				}	Catch {
							$msg = $error[0]
							write-warning $msg	
				}			

			} 	
		
		} Catch {
					$msg = $error[0]
					write-warning $msg	
		}	
		
	}
}
