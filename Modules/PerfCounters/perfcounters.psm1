#PerfCounters 1.1
# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Laerte Junior
### </Author>
### <Credits>
### Allen White --> http://sqlblog.com/blogs/allen_white/archive/2009/10/09/performance-data-gathering.aspx
### </Credits>
### <Description>
### Work with Performance Counters
### </Description>
### <Usage>
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

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


function Get-ProcessPerfcounter
{
	param ( $DateTimeStart,$DateTimeEnd,$total,$Interval,$PathOutputFile,$PathConfigFile,$Machine_Name,$xmldata,$ServerName,$DatabaseName,$UserName,$Password,$CommandInsert)
	

	$Total = $xmldata.SelectNodes("ConfigP/Counter").Count
	$PerfCounters = New-Object 'object[]' $Total
	
	
	$Increment = 0
	[string]$Header = "DateTime,"
	$xmldata.SelectNodes("ConfigP/Counter") | % {
	
		$InstanceObj = $_.Instance_Name
		if ( $_.Instance_Name -eq "Single Instance")
			{ $InstanceObj = ""}
			
		$PerfCounters[$Increment] = New-Object System.Diagnostics.PerformanceCounter( $_.Category_Name, $_.Counter_Name,$InstanceObj,$_.Machine_Name)
		$PerfCounters[$Increment].nextvalue() | Out-Null

		$Header +=  "$($_.Machine_Name)_$($_.Category_Name)_$($_.Instance_Name)_$($_.Counter_Name),"
		$Increment ++
	}
	
	$Header | Out-File $PathOutputFile -Encoding "ASCII"
	
	$CommandInsertSQL = $CommandInsert
	
	$now = Get-Date

	while($now -ge $DateTimeStart -AND $now -le $DateTimeEnd)
	{
		
		$Values = "'$(get-date)',"
		0..($total -1) | % {
		
					$Values += "$($PerfCounters[$_].nextvalue()),"

		}	
		sleep $Interval
		$ValuesToFile = ($Values.substring(0,$Values.length -1)) -replace "'",""
		$ValuesToFile |  out-file $PathOutputFile -Append -Encoding "ASCII"
		$CommandInsertSQL = "$($CommandInsert) values ($($values.substring(0,$values.length -1)))"
		if ($ServerName -ne "") {
			try {
				Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $CommandInsertSQL
			} finally {
				continue
			}
		}
		
		$now = Get-Date
	}	
						 
}		

function Write-LogText
{
	param($msg = "",$date = (get-date -Format "yyyyMMdd") ,$ReportOn = $home)
	

	if ($ReportOn -ne "")
		{	Add-Content -Path (Join-Path $ReportOn "PerfCounters_$($date).log") -Value  $msg}
	Write-Output $msg	
}

#######################
<#
.SYNOPSIS
Gets a Performance Counter Category.
.DESCRIPTION
The Get-PerfCounterCategory function  gets a Object with information about Performance Counter Category  to the specified Machine.
.INPUTS
ComputerName - string with the computer name. default is local 
Categoryname - string with the category
.OUTPUTS
Object[] System.Management.Automation.PSMethod
    Get-SqlConnection returns a Object[] System.Management.Automation.PSMethod.
.EXAMPLE
Get-PerfCounterCategory
This command gets information about all categories 
.EXAMPLE
Get-PerfCounterCategory -CategoryName "SQLServer*"
This command gets information about category SQLServer in local machine
.EXAMPLE
get-content "servers.txt" | Get-PerfCounterCategory -CategoryName "SQLServer*"
This command gets information about category SQLServer in all servers in servers.txt
.LINK
Get-PerfCounterCategory 
#>

function Get-PerfCounterCategory
{
    param(
    [Parameter(Position=0, Mandatory=$false ,ValueFromPipeline = $true)] [string]$ComputerName = $env:COMPUTERNAME,
    [Parameter(Position=1, Mandatory=$false)] [string]$CategoryName = "*"
    )
	
	
	process {
	
		

			try {
		
					$ErrorActionPreference = "Stop"
				
					Write-Verbose "Get-PerfCounterCategory $env:COMPUTERNAME"
			
			
					[system.Diagnostics.PerformanceCounterCategory]::GetCategories($ComputerName)| where-object { $_.CategoryName -like $CategoryName  } | 	Select-Object 	@{Expression={$_.MachineName};Label="Machine_Name"}, 
																																											@{Expression={$_.CategoryName};Label="Category_Name"},
																																											@{Expression={$_.CategoryType};Label="Category_Type"},
																																											@{Expression={$_.CategoryHelp};Label="Category_Description"}


					
				} catch {
					Write-LogText -msg "Get-PerfCounterCategory Error Detail :$Error[0]" 
					throw New-Object System.Management.Automation.PipelineStoppedException 
					#throw break
				}
		} 
}
	
#######################
<#
.SYNOPSIS
Gets a Instance information from category.
.DESCRIPTION
The Get-PerfCounterInstance function  gets a Object with information about Instances  from Category.
.INPUTS
CategoryName - Object[] with the categories
InstanceName - string with the Instance Name
.OUTPUTS
Object[] System.Management.Automation.PSMethod
    Get-PerfCounterInstance returns a Object[] System.Management.Automation.PSMethod.
.EXAMPLE
Get-PerfCounterCategory | Get-PerfCounterInstance
This command gets information about all instaces in all categories 
.EXAMPLE
Get-PerfCounterCategory -CategoryName "SQLServer*" | Get-PerfCounterInstance
This command gets information about all instances in all category SQLServer
.EXAMPLE
Get-PerfCounterCategory -CategoryName "Processor*" | Get-PerfCounterInstance -InstanceName "_Total"
This command gets information about instance _Total in  category Processor
.LINK
Get-PerfCounterInstance 
#>

function Get-PerfCounterInstance
{


	 param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] 
	[ValidateScript({$_.GetType().Name -is [System.Object]})] $CategoryName,
	[Parameter(Position=1, Mandatory=$false, ValueFromPipeline = $false)] $InstanceName = "*"
	)

	process {

			
			try {
			
		
				Write-Verbose "Get-PerfCounterInstance"
				$ErrorActionPreference = "Stop"
				
		
	
				$Result = @()
				foreach ($Instances in $CategoryName) {
				
					$InstanceNames = new-object system.Diagnostics.PerformanceCounterCategory($Instances.Category_name,$Instances.MAchine_name)
				
					#$InstanceNames.categoryname = $Instances.Category_name
					
					$Obj = $InstanceNames.GetInstanceNames()
					
					if ($Obj.count -eq 0)
					{
							$object =  New-Object PSObject -Property @{
								Machine_Name = $Instances.Machine_Name
								Category_Name = $Instances.category_name
								Instance_Name = ""
							}
							
							$Result += $object
							
					} else {		
					
							$obj  | Where-Object { $_ -like $InstanceName } | % {
						
		
								$object =  New-Object PSObject -Property @{
									Machine_Name = $Instances.Machine_Name
									Category_Name = $Instances.category_name
									Instance_Name =$_
									
								}
								
								$Result += $object
							}	
					}		
						
		
		
					
				}
				
				$Result
			} catch {
				Write-LogText -msg "Get-PerfCounterInstance Error Detail :$Error[0]"  
				throw New-Object System.Management.Automation.PipelineStoppedException 
				#throw break
			}
	}	
}
#######################
<#
.SYNOPSIS
Gets a Counters information from category/Instance.
.DESCRIPTION
The Get-PerfCounterCounters function  gets a Object with information about counters  from Category and instance.
.INPUTS
ObjectPerf - Object[] with the categories and instance
CounterName - string with the Counter Name
.OUTPUTS
Object[] System.Management.Automation.PSMethod
    Get-PerfCounterInstance returns a Object[] System.Management.Automation.PSMethod.
.EXAMPLE
Get-PerfCounterCategory | Get-PerfCounterInstance | Get-PerfCounterCounters
This command gets information about all counters in all categories and instances
.EXAMPLE
Get-PerfCounterCategory -CategoryName "SQLServer*" | Get-PerfCounterInstance | Get-PerfCounterCounters
This command gets information about all counters in all instances and category SQLServer
.EXAMPLE
Get-PerfCounterCategory -CategoryName "Processor*" | Get-PerfCounterInstance -InstanceName "_Total" | Get-PerfCounterCounters
This command gets information about all counters in instance _Total in  category Processor
.EXAMPLE
Get-PerfCounterCategory -CategoryName "SQLServer*" | Get-PerfCounterInstance | Get-PerfCounterCounters -CounterName "Memory*"
This command gets information about counters like Memory* in all instances in  category like SQLServer*
.LINK
Get-PerfCounterCounters 
#>

 
function Get-PerfCounterCounters
{

	 param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] 
	[ValidateScript({$_.GetType().Name -is [System.Object]})] $ObjectPerf ,
	[Parameter(Position=1, Mandatory=$false, ValueFromPipeline = $false)] $CounterName = "*" )

	process {
		
			try {
		
				Write-Verbose "Get-PerfCounterCounters"
				
				$Result = @()
				foreach ($Instances in $ObjectPerf) {
				
					$InstanceNames = new-object system.Diagnostics.PerformanceCounterCategory($Instances.Category_name,$Instances.Machine_Name)
					
					if ($Instances.instance_name -eq "" -or $Instances.instance_name -eq $null)
						{ $Obj = $InstanceNames.getcounters() }
					else
						{ $Obj = $InstanceNames.getcounters($Instances.instance_name) }
				
					$Obj | Where-Object { $_.countername -like $CounterName  } |  % {
					
							$Instance_Name = $Instances.Instance_name
						
							if ($Instances.Instance_name -eq $null -or $Instances.Instance_name -eq "" )
								{$Instance_Name = "Single Instance"}
				
							$object =  New-Object PSObject -Property @{
								Machine_Name = $Instances.Machine_Name
								Category_Name = $Instances.Category_name 
								Instance_Name = $Instance_Name
								Counter_Name = $_.countername
								Counter_Type = $_.CounterType
								Counter_Help = $_.CounterHelp
								
							} 
						
			
							$Result += $object
						
					}
				}
				
				$Result 
				
			} catch {
				Write-LogText -msg "Get-PerfCounterCounters Error Detail :$Error[0]"  
			    throw New-Object System.Management.Automation.PipelineStoppedException 
				#break
			
			}

	}	
	
}
#######################
<#
.SYNOPSIS
Save a XML Configure file with all informtion to starts the gathering.
.DESCRIPTION
The Get-PerfCounterInstance function  gets a Object with information about Instances  from the Categories
.PARAMETER $ObjectPerf        
Mandatory Object 
Object with The Categories
.PARAMETER $PathConfigFile        
Mandatory String
Path to save The XML File -Example C:\temp\TemplateBufferManager.XML. The name will be change to C:\temp\TemplateBufferManager_MACHINENAME.XML
.PARAMETER $NewFile        
Switch parameter
If new ConfigFile will be created. If not informed and exists, the new counters will be added to the file.
.INPUTS
You can Pipe $ObjectPerf Object
.OUTPUTS
None
.EXAMPLE
Get-PerfCounterCategory -CategoryName "SQLServer:Buffer Manager" | Get-PerfCounterInstance | Get-PerfCounterCounters | Save-ConfigPerfCounter -PathConfigFile "c:\temp\BufferManager.xml" -NewFile
This command save a XML into  c:\temp\BufferManager_MACHINENAME.xml with all counters in category SQLServer:Buffer Manager creating a new file.
.EXAMPLE
Get-PerfCounterCategory -CategoryName "processor*" | Get-PerfCounterInstance -InstanceName "_Total" | Get-PerfCounterCounters | Save-ConfigPerfCounter -PathConfigFile "c:\temp\BufferManager.xml" 
This command add to XML into  c:\temp\BufferManager_MACHINENAME.xml all counters in category Processor Instance _Total
.EXAMPLE
get-context Servers.TXT | Get-PerfCounterCategory -CategoryName "processor*" | Get-PerfCounterInstance -InstanceName "_Total" | Get-PerfCounterCounters | Save-ConfigPerfCounter -PathConfigFile "c:\temp\BufferManager.xml" 
This command save  to XML into  c:\temp\BufferManager_MACHINENAME.xml all counters in category Processor Instance _Total for each server in servers.txt
.LINK
http://sqlpsx.codeplex.com/
#>
#######################


Function Save-ConfigPerfCounter 
{

	param (	
	    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] 
		[ValidateScript({$_.GetType().Name -is [System.Object]})] $ObjectPerf ,
		[Parameter(Position=1, Mandatory=$true, ValueFromPipeline = $false)] $PathConfigFile,
		[Parameter(Position=2, Mandatory=$false, ValueFromPipeline = $false)] 
		[switch] $NewFile = $false
	)	
	Begin {
		$FirstTime = $true
		$NewMachineName = ""
		$OldMachineName
	
	}
	
	process {
	
			try {
			
					$MachineName = $ObjectPerf.Machine_Name
					$NewMachineName = $MachineName

					
					if ($NewMachineName -ne $OldMachineName) { 
						$FirstTime = $true
						$OldMachineName = $NewMachineName 
					} 
					
		
					
					if ($FirstTime) {
					
						$NewfileName = $PathConfigFile
					
						if ( $NewFile ) { 
							$NewfileName = "$($PathConfigFile.substring(0,$PathConfigFile.length  - 4))_$($MachineName).XML"
							"<?xml version=""1.0"" standalone=""yes""?>`n<ConfigP>`n</ConfigP>" | Out-File $NewfileName 
	
						}
						$FirstTime = $false
					

					} 
					$xmldata = [xml] (Get-Content $NewfileName)
					
	
					foreach ($LocalObjectPerf in $ObjectPerf) {
					
						$string = "<Machine_Name>$($LocalObjectPerf.Machine_Name)</Machine_Name><Category_Name>$($LocalObjectPerf.Category_Name)</Category_Name><Instance_Name>$($LocalObjectPerf.Instance_Name)</Instance_Name><Counter_Name>$($LocalObjectPerf.Counter_Name)</Counter_Name>"
						$newemcounter = $xmldata.CreateElement("Counter")
						$newemcounter.set_InnerXML( "$string")
						$xmldata.get_DocumentElement().AppendChild($newemcounter) | Out-Null
						
					}
					$xmldata.Save($NewfileName) | Out-Null
					

					
				} catch {
						Write-LogText -msg "Save-ConfigPerfCounter Error Detail :$Error[0]"  
						break
				}
				
				
	
		}

	
}
#######################
<#
.SYNOPSIS
Starts gathering.
.DESCRIPTION
The Set-CollectPerfCounter function starts gathering.
.PARAMETER $PathConfigFile        
Mandatory String
Path with XML Config Files
.PARAMETER $PathOutputFile        
Mandatory String
String full path to save the output from gathering
.PARAMETER $DateTimeStart         
Mandatory parameter
 Date time to Start the gatheing 
 .PARAMETER $DateTimeEnd            
Mandatory parameter
- Date time to End the gatheing 
 .PARAMETER $Interval         
Interval in seconds to get the information 
 .PARAMETER $RunAsJob         
Switch Parameter - Run as Background Job
 .PARAMETER $ServerName         
SQL Server Name to save the data
 .PARAMETER $DatabaseName         
Database Name to save the data
 .PARAMETER $UserName         
User Name to connect
 .PARAMETER $Password         
PAssword to connect
 .PARAMETER $TableName         
Table Name to save the data
 .PARAMETER $NewTable         
Switch parameter to create the table
.INPUTS
You can Pipe Xml Config Files
.OUTPUTS
None
.EXAMPLE
Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10 -PathConfigFile c:\temp\TemplateBufferManager_MACHINENAME.xml -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob
This command starts the gathering as background job and save to txt file
.EXAMPLE
dir c:\temp\*.xml | Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10  -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob
This command starts the gathering as background job and save to txt file for each XML config file. The Txt file will be created with the machine name. Ex TemplateBufferManager_MACHINENAME.txt
.EXAMPLE
dir c:\temp\*.xml | Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10 -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob
This command starts the gathering as background job and save to txt file for each XML config file. The Txt file will be created with the machine name. Ex TemplateBufferManager_MACHINENAME.txt
.EXAMPLE
dir c:\temp\*.xml | Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10 -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob  -ServerName ObiWan -DatabaseName Teste -NewTable
This command starts the gathering as background job and save to txt file for each XML config file. Also, create one table to each Config File and save the data. The table will be created with name PERFCOUNTER_XMLFILENAME_YYYYmmDDHHMMSS
.EXAMPLE
 Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10 -PathConfigFile c:\temp\TemplateBufferManager_MACHINENAME.xml -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob  -ServerName ObiWan -DatabaseName Teste -NewTable -TableName Perfcounter
This command starts the gathering as background job and save to txt file for \TemplateBufferManager_MACHINENAME.xml  XML config file. Also, create one table called Perfcounter and save the data. 
.EXAMPLE
 Set-CollectPerfCounter -DateTimeStart  "05/24/2010 08:00:00" -DateTimeEnd "05/30/2010 22:00:00" -Interval 10 -PathConfigFile c:\temp\TemplateBufferManager_MACHINENAME.xml -PathOutputFile c:\temp\TemplateBufferManager.txt -RunAsJob  -ServerName ObiWan -DatabaseName Teste -TableName Perfcounter
This command starts the gathering as background job and save to txt file for \TemplateBufferManager_MACHINENAME.xml  XML config file. Also, the table called Perfcounter will be used to save the data. 
.LINK
http://sqlpsx.codeplex.com/
#>
#######################


Function Set-CollectPerfCounter {

	 param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)][string] $PathConfigFile  ,
		[Parameter(Position=1, Mandatory=$true, ValueFromPipeline = $false)] $PathOutputFile,
		[Parameter(Position=2, Mandatory=$true, ValueFromPipeline = $false)] [system.DateTime] $DateTimeStart = (get-date) ,
		[Parameter(Position=3, Mandatory=$true, ValueFromPipeline = $false)] [system.datetime] $DateTimeEnd ,
		[Parameter(Position=4, Mandatory=$false, ValueFromPipeline = $false)] [system.Int32] $Interval = 10,
		[Parameter(Position=5, Mandatory=$false, ValueFromPipeline = $false)] [switch] $RunAsJob = $false,
		[Parameter(Position=6, Mandatory=$false, ValueFromPipeline = $false)] [String] $ServerName ,
		[Parameter(Position=7, Mandatory=$false, ValueFromPipeline = $false)] [String] $DatabaseName ,
		[Parameter(Position=8, Mandatory=$false, ValueFromPipeline = $false)] [String] $TableName ,
		[Parameter(Position=9, Mandatory=$false, ValueFromPipeline = $false)] [String] $UserName ,
		[Parameter(Position=10, Mandatory=$false, ValueFromPipeline = $false)] [String] $Password ,
		[Parameter(Position=11, Mandatory=$false, ValueFromPipeline = $false)] [switch] $NewTable = $false

	)
	Begin {
	
			$FirstIme = $true
	
			if ( $ServerName -ne "" -and $databasename -ne "" ) {
			
				$InfoToTable = $false
				
				if ($TableName -eq "" -and !$NewTable) {
					Write-output "Set-CollectPerfCounter Error Detail : You need to specify table name or -newtable"
					throw New-Object System.Management.Automation.PipelineStoppedException 
				}

				try {
					if ($TableName) {
						$query = "sp_tables  $TableName"
					} else {
						$query = 'Select getdate()'
					}
					
					Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $query | Out-Null
					$InfoToTable = $true
				} catch {
	
					Write-output "Set-CollectPerfCounter Error Detail : Connection to SQL Server. Please Verify parameters"
					throw New-Object System.Management.Automation.PipelineStoppedException 

				}
			}
	}
			

	Process {

				try {
					
					$xmldata = [xml](Get-Content $PathConfigFile)
					$Machine_Name = $xmldata.SelectNodes("ConfigP/Counter") | select Machine_Name -First 1 


					
				
					$nameXml = (Get-ChildItem $PathConfigFile )
					[string] $NamePath = $nameXml.name
					$NamePath = "$($NamePath.substring(0,$NamePath.length -4)).txt"
					
					$namejob = "PERFCOUNTER_$($NamePath.Substring(0,$NamePath.Length -4))_$(Get-Date -Format yyyyMMddhhmmss)"
					
					


					$NewPathOutputFile = "" 
					if ($PathOutputFile.substring(($PathOutputFile.length) -4,1) -eq ".") {
						
						$NewPathName = $NamePath
						$ChangePathName = $false
						
						
						if ($NewPathName -ne $OldPathName -and !$FirstIme ) { 
							$OldPathName = $NewPathName
							$ChangePathName = $true

						} 
						
						$FirstIme = $false
						if (!$ChangePathName) {
							$NewPathOutputFile = "$($PathOutputFile.substring(0,$PathOutputFile.length -4))_$($Machine_Name.Machine_Name).$($PathOutputFile.substring($PathOutputFile.length -3,3))"
						} else {
							$NewPathOutputFile = Join-Path (Split-Path $PathOutputFile) $NamePath
						}
					} else {
						if (Test-Path $PathOutputFile) {
							$NewPathOutputFile = join-path $PathOutputFile  $NamePath
						} else {
							$NewPathOutputFile = Join-Path $HOME $NamePath
						}
					}
					$now = Get-Date
					$NewTablename = $TableName
					
					if ($InfoToTable) {
			
						$Command="" ;	$CommandCreate="" ;$InsertColumns="" 
						
						$xmldata.SelectNodes("ConfigP/Counter") | % {

							$Command  +=  "[$($_.Machine_Name)_$($_.Category_Name)_$($_.Instance_Name)_$($_.Counter_Name)] float ,"
							$InsertColumns += "[$($_.Machine_Name)_$($_.Category_Name)_$($_.Instance_Name)_$($_.Counter_Name)],"
						}	
						
						$InsertColumns = "$($InsertColumns.substring(0,$InsertColumns.length -1))"
			
						if ($Newtable )	{
		
							if ($tableName -eq "") 	{
								$NewTablename = $namejob 
							} else {
								$NewTablename = "$($TableName)_$($Machine_Name.Machine_Name)"
							}
		
								
							$CommandCreate = " Create table dbo.$NewTablename([DateTime] Datetime,$($command.substring(0,$command.length -1)))"
						
							$drop = "IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[$NewTablename]') AND type in (N'U'))
									DROP TABLE [dbo].[$NewTablename]"
									
							Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $drop
							Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $CommandCreate
							$CreatedTable = $true
							
						}
						
						$CommandInsert = "Insert into dbo.$NewTablename([DateTime],$($InsertColumns))"
					}
				
					if ( $RunAsJob)	{
							Start-Job -Name $namejob -InitializationScript  {Import-Module PerfCounters -Force} -scriptblock { Get-ProcessPerfcounter $args[0] $args[1] $args[2] $args[3] $args[4] $args[5] $args[6] $args[7] $args[8] $args[9] $args[10] $args[11] $args[12]  } -ArgumentList $DateTimeStart, $DateTimeEnd ,$total ,$Interval ,$NewPathOutputFile ,$PathConfigFile,$Machine_Name.Machine_Name,$xmldata, $ServerName ,$DatabaseName,$UserName,$Password,$CommandInsert | Format-list id,name,state
			
					}	else		{ 
							Write-Host "Starts gathering..."
							Get-ProcessPerfcounter  $DateTimeStart  $DateTimeEnd  $total  $Interval  $NewPathOutputFile $PathConfigFile $Machine_Name.Machine_Name $xmldata $ServerName $DatabaseName $UserName $Password $CommandInsert
							Write-Host "End gathering..."
					}
						
				} catch {		

					Write-LogText -msg "Set-CollectPerfCounter Error Detail :$Error[0]"  
					break
				
			}
	}
}

#######################
<#
.SYNOPSIS
Insert into a SQLtable the file generated by Set-CollectPerfCounter.
.DESCRIPTION
Insert into a SQLtable the file generated by Set-CollectPerfCounter.
.INPUTS
PathConfigFile - String full path with the XML configure file
PathOutputFile - String full path to save the output from gathering
ServerName     - String with SQL Server name
DatabaseName   - String with Database name
Username       - SQL Server User Name
PAssword       - Password
TableName      - Table Name to inserte the data
NewTable       - switch to create new table


.OUTPUTS
none
.EXAMPLE
Save-PerfCounterSQLTable -ServerName Vader -DatabaseName tempdb  -NewTable  -PathConfigFile c:\Testes\testes.xml -PathOutputFile c:\Testes\teste.txt 

Save-PerfCounterSQLTable -ServerName Vader -DatabaseName tempdb    -PathConfigFile c:\Testes\testes.xml -PathOutputFile c:\Testes\teste.txt 

Save-PerfCounterSQLTable -ServerName Vader -DatabaseName tempdb -TableName PerfCounterSQLTable_20100528100655   -PathConfigFile c:\Testes\testes.xml -PathOutputFile c:\Testes\teste.txt 

Save-PerfCounterSQLTable -ServerName Vader -DatabaseName tempdb -TableName PerfCounterSQLTable_20100528100655 -NewTable   -PathConfigFile c:\Testes\testes.xml -PathOutputFile c:\Testes\teste.txt 

Set-CollectPerfCounter 
#>


Function Save-PerfCounterSQLTable 
{
 param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $false)] 
		[ValidateScript({Test-Path -path $_})] [string] $PathConfigFile  ,
		[Parameter(Position=1, Mandatory=$true, ValueFromPipeline = $false)]
		[ValidateScript({Test-Path -path $_})] [string] $PathOutputFile,
		[Parameter(Position=2, Mandatory=$true, ValueFromPipeline = $false)] [String] $ServerName,
		[Parameter(Position=3, Mandatory=$true, ValueFromPipeline = $false)] [String] $DatabaseName,
		[Parameter(Position=4, Mandatory=$false, ValueFromPipeline = $false)] [string] $UserName,
		[Parameter(Position=5, Mandatory=$false, ValueFromPipeline = $false)] [string] $Password,
		[Parameter(Position=6, Mandatory=$false, ValueFromPipeline = $false)] [String] $TableName ="",
		[Parameter(Position=7, Mandatory=$false, ValueFromPipeline = $false)] [switch] $NewTable = $false
	
	)
	
		$Error.Clear()

		if ( $ServerName -ne "" -and $databasename -ne "" ) {
			

				
				if ($TableName -eq "" -and !$NewTable) {
					Write-output "Set-CollectPerfCounter Error Detail : You need to specify table name or -newtable"
					throw New-Object System.Management.Automation.PipelineStoppedException 
				}

				try {
					if ($TableName) {
						$query = "sp_tables  $TableName"
					} else {
						$query = 'Select getdate()'
					}
					
					Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $query | Out-Null

				} catch {
	
					Write-output "Set-CollectPerfCounter Error Detail : Connection to SQL Server. Please Verify parameters"
					throw New-Object System.Management.Automation.PipelineStoppedException 

				}
		}

		$NewTablename = $tablename
		
		if ($Newtable)
		{	

					
			try 
			{
				$xmldata = [xml](Get-Content $PathConfigFile)
				if ($tableName -eq "")
					{	$NewTablename = "PerfCounterSQLTable_$(get-date -format yyyyMMddhhmmss)" ; $command = " Create table dbo.$NewTablename ([DateTime] Datetime,"}
				else
					{   $NewTablename = "$TableName" ; $command = " Create table dbo.$NewTablename([DateTime] Datetime,"}
					
				$xmldata.SelectNodes("ConfigP/Counter") | select @{Expression={"[$($_.Category_Name)_$($_.Instance_Name)_$($_.Counter_Name)]~float ,"};Label="Valor"} |  % { $Columns+= $_.valor}
				$columns = ((($Columns.Substring(0,$Columns.Length-1)) -replace " ","") -replace "~"," ") + ")"
				$command = $command + $Columns
				$drop = "IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[$NewTablename]') AND type in (N'U'))
						DROP TABLE [dbo].[$NewTablename]"
						

				Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $Drop | Out-Null
				Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $command | Out-Null
			} catch {	
					Write-LogText -msg "Save-PerfCounterSQLTable Error Detail : $Error[0]";break
			}		
		
		}	
		
		try
		{
			
			$bulk = "	BULK INSERT $Databasename.dbo.$NewTablename
						FROM '$PathOutputFile'
						WITH
							(   FIRSTROW = 2,
								fieldTERMINATOR = ','
	
							)
					"
					
			Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -UserName $UserName -Password $Password -Query $bulk | Out-Null
					
	
			Write-Host "$PathOutputFile imported Lines with success"
		} catch {	
		
			Write-LogText -msg "Save-PerfCounterSQLTable Error Detail : $error[0]";break
		}	
	
}




