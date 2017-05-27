# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Patrick Keisler
### </Author>
### <Description>
### Defines function wrappers around the classes to get access to a PBM server.
### It is critical that all assemblies must be of the same version, including the 
### Invoke-PolicyEvaluation from the SQLPS module, or else the evaluation may return errors.
### </Description>
### </Script>
# ---------------------------------------------------------------------------

#Attempt to load assemblies by name starting with the latest version
try {
  #SMO v14 - SQL Server vNext
  Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop; $smoVersion = 14
  Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
}
catch {
  try {
    #SMO v13 - SQL Server 2016
	Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop; $smoVersion = 13
	Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  }
  catch {
	try {
	#SMO v12 - SQL Server 2014
	Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop; $smoVersion = 12
	Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	}
	catch {
  	  try {
		#SMO v11 - SQL Server 2012
		Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop; $smoVersion = 11
		Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	  }
	  catch {
		try {
		  #SMO v10 - SQL Server 2008
		  Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop; $smoVersion = 10
		  Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		  Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		  Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		}
		catch {
		  Write-Warning 'SMO components not installed. Download from https://goo.gl/E700bG'
		  Break
		}
	  }
	}
  }
}

<#
    This will attempt to load the SQLPS version that matches the version of the SMO assembly loaded first on the list.
	It is critical the versions match, because we need to call Invoke-PolicyEvaluation from this module.
    Based on code from here the following link.
    https://social.msdn.microsoft.com/Forums/sqlserver/en-US/0573fc94-3f31-4718-a683-4b7091fe16b2/invokepolicyevaluation-fails-with-value-cannot-be-null-parameter-name-policy?forum=sqlsmoanddmo
#>
$assemblyList = [appdomain]::CurrentDomain.GetAssemblies() | Where-Object {$_.Location -like '*\Microsoft.SqlServer.Smo.dll'} | Select-Object Location -First 1
if ($assemblyList.Location.Contains('14.0.0.0')) {
  Get-Module SQLPS -ListAvailable | Where-Object {($_.Version -eq '14.0') -and ($_.ModuleBase -like '*140*')} | Import-Module -Cmdlet Invoke-PolicyEvaluation -DisableNameChecking -WarningAction Ignore
}
elseif ($assemblyList.Location.Contains('13.0.0.0')) {
  Get-Module SQLPS -ListAvailable | Where-Object {($_.Version -eq '1.0') -and ($_.ModuleBase -like '*130*')} | Import-Module -Cmdlet Invoke-PolicyEvaluation -DisableNameChecking -WarningAction Ignore
}
elseif ($assemblyList.Location.Contains('12.0.0.0')) {
  Get-Module SQLPS -ListAvailable | Where-Object {($_.Version -eq '1.0') -and ($_.ModuleBase -like '*120*')} | Import-Module -Cmdlet Invoke-PolicyEvaluation -DisableNameChecking -WarningAction Ignore
}
elseif ($assemblyList.Location.Contains('11.0.0.0')) {
  Get-Module SQLPS -ListAvailable | Where-Object {($_.Version -eq '1.0') -and ($_.ModuleBase -like '*110*')} | Import-Module -Cmdlet Invoke-PolicyEvaluation -DisableNameChecking -WarningAction Ignore
}
elseif ($assemblyList.Location.Contains('10.0.0.0')) {
  Get-Module SQLPS -ListAvailable | Where-Object {($_.Version -eq '1.0') -and ($_.ModuleBase -like '*100*')} | Import-Module -Cmdlet Invoke-PolicyEvaluation -DisableNameChecking -WarningAction Ignore
}

<#
    .SYNOPSIS
    Processes errors encoutered in PowerShell code.
    .DESCRIPTION
    The Get-SqlConnection function processes either PowerShell errors or application errors defined within your code.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    try { 1/0 } catch { Get-Error $Error }
    This passes the common error object (System.Management.Automation.ErrorRecord) for processing.
    .EXAMPLE
    try { 1/0 } catch { Get-Error "You attempted to divid by zero. Try again." }
    This passes a string that is output as an error message.
    .LINK
    http://www.patrickkeisler.com/
#>
function Get-Error {
  param(
    [CmdletBinding()]
    [Parameter(Position=0,ParameterSetName='PowerShellError',Mandatory=$true)] [System.Management.Automation.ErrorRecord]$PSError,
    [Parameter(Position=0,ParameterSetName='ApplicationError',Mandatory=$true)] [string]$AppError
  )

  if ($PSError) {
    #Process a PowerShell error
    Write-Host '******************************'
    Write-Host "Error Count: $($PSError.Count)"
    Write-Host '******************************'

    $Error = $PSError.Exception
    Write-Host $Error.Message
    $Error = $Error.InnerException
    while ($Error.InnerException) {
      Write-Host $Error.InnerException.Message
      $Error = $Error.InnerException
    }
    Throw
  }
  elseif ($AppError) {
    #Process an application error
    Write-Host '******************************'
    Write-Host 'Error Count: 1'
    Write-Host '******************************'
    Write-Host $AppError
    Throw
  }
} #Get-Error

#######################
<#
    .SYNOPSIS
    Gets a ServerConnection.
    .DESCRIPTION
    The Get-SqlConnection function  gets a ServerConnection to the specified SQL Server.
    .INPUTS
    None
    You cannot pipe objects to Get-SqlConnection 
    .OUTPUTS
    Microsoft.SqlServer.Management.Common.ServerConnection
    Get-SqlConnection returns a Microsoft.SqlServer.Management.Common.ServerConnection object.
    .EXAMPLE
    Get-SqlConnection "Z002\sql2K8"
    This command gets a ServerConnection to SQL Server Z002\SQL2K8.
    .EXAMPLE
    Get-SqlConnection "Z002\sql2K8" "sa" "Passw0rd"
    This command gets a ServerConnection to SQL Server Z002\SQL2K8 using SQL authentication.
    .LINK
    Get-SqlConnection 
#>
function Get-SqlConnection {
  param(
    [Parameter(Mandatory=$true)] [string]$sqlserver,
    [string]$username, 
    [string]$password,
    [Parameter(Mandatory=$false)] [string]$applicationName='SQLPSX'
  )

  Write-Verbose "Get-SqlConnection $sqlserver"
    
  if($Username -and $Password)
  { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver,$username,$password }
  else
  { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver }
	
  $con.ApplicationName = $applicationName
  $con.Connect()

  Write-Output $con
    
} #Get-ServerConnection

#######################
<#
    .SYNOPSIS
    Gets an SMO Server object.
    .DESCRIPTION
    The Get-SqlServer function gets a SMO Server object for the specified SQL Server.
    .INPUTS
    None
    You cannot pipe objects to Get-SqlServer 
    .OUTPUTS
    Microsoft.SqlServer.Management.Smo.Server
    Get-SqlServer returns a Microsoft.SqlServer.Management.Smo.Server object.
    .EXAMPLE
    Get-SqlServer "Z002\sql2K8"
    This command gets an SMO Server object for SQL Server Z002\SQL2K8.
    .EXAMPLE
    Get-SqlServer "Z002\sql2K8" "sa" "Passw0rd"
    This command gets a SMO Server object for SQL Server Z002\SQL2K8 using SQL authentication.
    .LINK
    Get-SqlServer 
#>
function Get-SqlServer {
  param(
    [Parameter(Mandatory=$true)] [string]$sqlserver,
    [string]$username, 
    [string]$password,
    [string]$StatementTimeout=0,
    [Parameter(Mandatory=$false)] [string]$applicationName='SQLPSX'
  )
  #When $sqlserver passed in from the SMO Name property, brackets
  #are automatically inserted which then need to be removed
  $sqlserver = $sqlserver -replace '\[|\]'

  Write-Verbose "Get-SqlServer $sqlserver"

  $con = Get-SqlConnection $sqlserver $Username $Password $applicationName

  $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $con
  #Some operations might take longer than the default timeout of 600 seconnds (10 minutes). Set new default to unlimited
  $server.ConnectionContext.StatementTimeout = $StatementTimeout
  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], 'IsSystemObject')
  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], 'IsSystemObject')
  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], 'IsSystemObject')
  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], 'IsSystemObject')
  #trap { "Check $SqlServer Name"; continue} $server.ConnectionContext.Connect() 
  Write-Output $server
    
} #Get-SqlServer

#######################
<#
    .SYNOPSIS
    Gets a PolicyStore connection object to a PBM server.
    .DESCRIPTION
    The Get-PolicyStore function gets a PolicyStore connection object for the specified SQL Server.
    .INPUTS
    None
    You cannot pipe objects to Get-PolicyStore 
    .OUTPUTS
    Get-PolicyStore returns a Microsoft.SqlServer.Management.DMF.PolicyStore object.
    .EXAMPLE
    Get-PolicyStore "Z002\sql2K8"
    This command gets a PolicyStore connection object for SQL Server Z002\SQL2K8.
    .LINK
    http://www.patrickkeisler.com/
#>
function Get-PolicyStore {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateNOTNullOrEmpty()][String]$policyServer
  )
  
  try {
    $conn = new-object Microsoft.SQlServer.Management.Sdk.Sfc.SqlStoreConnection("server=$policyServer;Trusted_Connection=true")
    $policyStore = new-object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)
  }
  catch {
    Get-Error $_
  }
  Write-Output $policyStore
} #Get-PolicyStore

#######################
<#
    .SYNOPSIS
    Exports all polices to a file on disk.
    .DESCRIPTION
    The Export-Policy function generates a script of all polices to a file.
    .INPUTS
    None
    You cannot pipe objects to Export-Policy 
    .OUTPUTS
    Export-Policy creates a SQL script on disk.
    .EXAMPLE
    Export-Policy -policyStore "Z002\sql2K8" -$outputPath "C:\temp"
    This command generates a separate SQL script for each policy on the SQL Server Z002\SQL2K8.
    .EXAMPLE
    Export-Policy -policyStore "Z002\sql2K8" -$outputPath "C:\temp" -policyCategory "CatI"
    This command generates a separate SQL script for each policy in the CatI policy group on the SQL Server Z002\SQL2K8.
    Export-Policy -policyStore "Z002\sql2K8" -$outputPath "C:\temp" -singleFile
    This command generates one SQL script for all policies on the SQL Server Z002\SQL2K8.
    .LINK
    http://www.patrickkeisler.com/
#>
function Export-Policy {
  [CmdletBinding()]
  param(
    [Parameter(Position=0,Mandatory=$true)][ValidateNOTNullOrEmpty()]$policyStore,
    [Parameter(Position=1,Mandatory=$true)][ValidateNOTNullOrEmpty()][String]$outputPath,
    [Parameter(Position=2)][String[]]$policyCategory='*',
    [Parameter(Position=3)][Switch]$singleFile
  )

  switch ($policyStore.GetType().Name)
  {
    'String' { $store = Get-PolicyStore $policyStore }
    'PolicyStore' { $store = $policyStore }
    default { throw 'Export-Policy:Param `$policyStore must be a String or PolicyStore object.' }
  }

  $outputPath = $outputPath.TrimEnd('\')

  ############### Declarations ###############
    
  [Int]$count = 0
  [DateTime]$date = Get-Date
  $server = Get-SqlServer -sqlserver $store.Name
  $jobserver = $server.JobServer
  
  ############### Main Execution ###############
  
  if ($policyCategory -eq '*') { $policyCategory = $store.PolicyCategories.Name }
  
  if ($singleFile) {
    $filename = "$outputPath\$($($store.Name).replace('\','$'))_PBM_AllPolicies.sql"

    #Create comment header for the script
    Out-File -FilePath $filename -InputObject "/* Generated from:  $($store.Name) */`r`n/* Generated on:    $date */`r`n"
  
    $store.Policies | Where-Object {$_.PolicyCategory -in $policyCategory -and $_.IsSystemObject -eq $false} | foreach {
      $policy = $_
      #Create comment header for the policy
      Add-Content $filename "/***** BEGIN Policy Name: $($policy.Name) *****/"
        
      #Script the job schedule
      if($_.AutomatedPolicyEvaluationMode -eq 'CheckOnSchedule') {
        $jobschedule = $jobserver.SharedSchedules | Where-Object {$_.ScheduleUID -eq $policy.ScheduleUid}
        $jobschedule.Script() | Add-Content $filename
        Add-Content $filename "`r`nGO`r`n"
      }

      #Script the policy & its dependencies
      $script = $policy.ScriptCreateWithDependencies()
      $script.GetScript() | Add-Content $filename
      Add-Content $filename "`r`nGO`r`n/***** END Policy Name: $($policy.Name) *****/`r`n"
      $count = $count + 1
    }
  }
  else {
    $store.Policies | Where-Object {$_.PolicyCategory -in $policyCategory -and $_.IsSystemObject -eq $false} | foreach {
      $policy = $_
      $filename = "$outputPath\$($($store.Name).replace('\','$'))_$($policy.Name -replace '[<>|*:?"/\\ ]', '_')_PBM.sql"
      
      #Create comment header for the script
      Out-File -FilePath $filename -InputObject "/* Generated from:  $($store.Name) */`r`n/* Generated on:    $date */`r`n"

      #Create comment header for the policy
      Add-Content $filename "/***** BEGIN Policy Name: $($policy.Name) *****/"
      
      #Script the job schedule
      if($_.AutomatedPolicyEvaluationMode -eq 'CheckOnSchedule') {
        $jobschedule = $jobserver.SharedSchedules | Where-Object {$_.ScheduleUID -eq $policy.ScheduleUid}
        $jobschedule.Script() | Add-Content $filename
        Add-Content $filename "`r`nGO`r`n"
      }

      #Script the policy category
      $category = $store.PolicyCategories | Where-Object {$_.ID -eq $policy.CategoryId}
      $script = $category.ScriptCreate()
      $script.GetScript() | Add-Content $filename
      
      #Script the policy & its dependencies
      $script = $policy.ScriptCreateWithDependencies()
      $script.GetScript() | Add-Content $filename
      
      Add-Content $filename "`r`nGO`r`n/***** END Policy Name: $($policy.Name) *****/`r`n"
            
      $count = $count + 1
    }
  }  

  Write-Host "Policies Exported: $count"
} #Export-Policy

#######################
<#
    .SYNOPSIS
    Evaluates PBM polices against a target server.
    .DESCRIPTION
    The Invoke-SqlPSXPolicyEvaluation function evaluates polices against a target server.
    .INPUTS
    None
    You cannot pipe objects to Invoke-SqlPSXPolicyEvaluation.
    .OUTPUTS
    Invoke-SqlPSXPolicyEvaluation will either store the results in the msdb database of the PolicyStore or output to an XML file.
    .EXAMPLE
    Invoke-SqlPSXPolicyEvaluation -policyStore "Z002\sql2K8" -$targetServerName "Z044\SQL01"
    This command gets all polices from Z002\SQL2K8 and evalutes then against "Z044\SQL01". The results are stored in msdb on Z002\SQL2K8.
    .EXAMPLE
    Invoke-SqlPSXPolicyEvaluation -policyStore "Z002\sql2K8" -$targetServerName "Z044\SQL01" -policyCategory "CatI"
    This command gets all polices from CatI policy group on Z002\SQL2K8 and evalutes then against "Z044\SQL01". The results are stored in msdb on Z002\SQL2K8.
    .EXAMPLE
    Invoke-SqlPSXPolicyEvaluation -policyStore "Z002\sql2K8" -$targetServerName "Z044\SQL01" -policyCategory "CatI" -outputXML "C:\temp"
    This command gets all polices from CatI policy group on Z002\SQL2K8 and evalutes then against "Z044\SQL01". The results are stored in separate XML files on C:\temp.
    .LINK
    http://www.patrickkeisler.com/
#>
function Invoke-SqlPSXPolicyEvaluation {
  [CmdletBinding()]
  param(
    [Parameter(Position=0,Mandatory=$true)][ValidateNOTNullOrEmpty()]$policyStore,
    [Parameter(Position=1,Mandatory=$true)][ValidateNOTNullOrEmpty()][String[]]$targetServerName,
    [Parameter(Position=2)][ValidateNOTNullOrEmpty()][String[]]$policyCategory='*',
    [Parameter(Position=3)][String]$outputXML=''
  )

  switch ($policyStore.GetType().Name)
  {
    'String' { $store = Get-PolicyStore $policyStore; $sqlConn = Get-SqlConnection -sqlserver $policyStore }
    'PolicyStore' { $store = $policyStore; $sqlConn = Get-SqlConnection -sqlserver $policyStore.Name }
    default { throw 'Invoke-SqlPSXPolicyEvaluation:Param `$policyStore must be a String or PolicyStore object.' }
  }

  $collection = @()
  
  #Loop through each server
  foreach($targetServer in $targetServerName){
    #If necessary, filter policies by category, name, etc.
    if($policyCategory -eq '*') {
      $policies = $store.Policies | Where-Object {$_.IsSystemObject -eq $false}
    }
    else {
      $policies = $store.Policies | Where-Object {$_.PolicyCategory -in $policyCategory -and $_.IsSystemObject -eq $false}
    }

    #Loop through each policy
    foreach($policy in $policies) {
      if($outputXML -ne ''){
        #Remove invalid characters from file name
        $outputFile = "$($outputXML.TrimEnd('\'))\$($targetServer.Replace('\','$'))_$($policy.Name -replace '[<>|*:?"/\\ ]', '_').xml"
        Write-Host $outputFile -ForegroundColor Green
        Invoke-PolicyEvaluation -Policy $policy -TargetServerName $targetServer -AdHocPolicyEvaluationMode Check -OutputXML > $outputFile
      }
      else {
        #Use Invoke-PolicyEvaluation to evaulate the policy against the target server
        $evalResult = Invoke-PolicyEvaluation -Policy $policy -TargetServerName $targetServer -AdHocPolicyEvaluationMode 'Check'
        #Loop through the collection of ConnectionEvaluationHistories
        foreach($connectionEvalHistory in $evalResult.ConnectionEvaluationHistories) {
          if ($connectionEvalHistory.Result -eq $False -and $connectionEvalHistory.Exception -ne '') {
            #Store the results in a PSobject
            $object = New-Object PSObject -Property @{
              PolicyID = $policy.ID
              PolicyName = $policy.Name
              PolicyResult = $evalResult.Result
              EvalStartDate = $evalResult.StartDate
              EvalEndDate = $evalResult.EndDate
			  TargetServer = $targetServer
              Target = "SQLSERVER:\SQL\$targetServer"
              EvalResult = 'ERROR'
              ResultDetail = ''
              Exception = $connectionEvalHistory.Exception
            }
            $collection += $object
          }
          else {
            #Loop through the collection of EvaluationDetails
            foreach($evalDetail in $connectionEvalHistory.EvaluationDetails) {
              #Store the results in a PSobject
              $object = New-Object PSObject -Property @{
                PolicyID = $policy.ID
                PolicyName = $policy.Name
                PolicyResult = $evalResult.Result
                EvalStartDate = $evalResult.StartDate
                EvalEndDate = $evalResult.EndDate
				TargetServer = $targetServer
                Target = $evalDetail.TargetQueryExpression
                EvalResult = $evalDetail.Result
                ResultDetail = $evalDetail.ResultDetail
                Exception = $evalDetail.Exception
              }
              $collection += $object
            }
          }
        }
      }
    }
  }

  #Store the results in the PBM system tables in msdb
  $prevPolicyID = -1
  $prevTargetServer = $null
  $recordOpen = $false
  for($x=0; $x -le ($collection.Count)-1; $x++) {
	#Do not insert rows into msdb if targetServer and policyStore are the same. This will cause duplicate records.
	if($collection[$x].TargetServer -ne $policyStore.Name) {
	  if($collection[$x].PolicyResult -eq $false -and $collection[$x].Exception -ne ''){
		if($recordOpen){
		  #Close the previous parent record if it is still open
		  $sqlQuery = "EXEC msdb.dbo.sp_syspolicy_log_policy_execution_end @history_id = $($historyId), @result = '$($collection[$x-1].PolicyResult)', @exception_message = N'', @exception = N''"
		  $sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
		  #Add an entry in SQL ErrorLog if the policy failed
		  if($collection[$x-1].PolicyResult -eq $False -and $collection[$x-1].Exception -eq ''){
		  	  $ErrorActionPreference = 'SilentlyContinue'
			  $sqlQuery = "RAISERROR(34052, 16, 1, N'Policy ''$($collection[$x-1].PolicyName)'' has been violated.') WITH LOG"
			  $sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
			  $ErrorActionPreference = 'Continue'
		  }
		  $recordOpen = $false
		}
		  #Insert detailed record
		  $sqlQuery = "INSERT msdb.dbo.syspolicy_policy_execution_history_internal (policy_id,start_date,end_date,result,is_full_run,exception_message,exception) VALUES ($($collection[$x].PolicyID),'$($collection[$x].EvalStartDate)','$($collection[$x].EvalEndDate)','$($collection[$x].PolicyResult)',1,'ERROR: Policy evaluation failed.','$($collection[$x].Exception -replace "'",'"')')"
		  $sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
	  }
	  else {
		if(($collection[$x].PolicyID -ne $prevPolicyID) -or ($collection[$x].TargetServer -ne $prevTargetServer)){
		  if($recordOpen -and $prevPolicyID -ne -1){
		 	#Close the previous parent record if it is still open
			$sqlQuery = "EXEC msdb.dbo.sp_syspolicy_log_policy_execution_end @history_id = $($historyId), @result = '$($collection[$x-1].PolicyResult)', @exception_message = N'', @exception = N''"
			$sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
			$recordOpen = $false
		  }
		#Open a new parent record
		$sqlQuery = "DECLARE @history_id bigint; EXEC msdb.dbo.sp_syspolicy_log_policy_execution_start @history_id = @history_id OUTPUT, @policy_id = $($collection[$x].PolicyID), @is_full_run = True; SELECT @history_id AS history_id"
		$historyId = $sqlConn.ExecuteScalar($sqlQuery)
		$recordOpen = $true
		}
		#Insert detailed record
		$sqlQuery = "EXEC msdb.dbo.sp_syspolicy_log_policy_execution_detail @history_id = $($historyId), @target_query_expression = N'$($collection[$x].Target)', @target_query_expression_with_id = N'Server', @result = '$($collection[$x].EvalResult)', @result_detail = N'$($collection[$x].ResultDetail)', @exception_message = N'', @exception = N''"
		$sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
	  }
	  $prevPolicyID = $collection[$x].PolicyID
	  $prevTargetServer = $collection[$x].TargetServer
	}
  }

  if($recordOpen) {
    #Close the previous parent record if it is still open
    $sqlQuery = "EXEC msdb.dbo.sp_syspolicy_log_policy_execution_end @history_id = $($historyId), @result = '$($collection[$x-1].PolicyResult)', @exception_message = N'', @exception = N''"
    $sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
    #Add an entry in SQL ErrorLog if the policy failed
    if($collection[$x-1].PolicyResult -eq $False -and $collection[$x-1].Exception -eq ''){
      $sqlQuery = "RAISERROR(34052, 16, 1, N'Policy ''$($collection[$x-1].PolicyName)'' has been violated.') WITH LOG"
      $ErrorActionPreference = 'SilentlyContinue'
      $sqlConn.ExecuteNonQuery($sqlQuery) | Out-Null
      $ErrorActionPreference = 'Continue'
    }
  }
  
  #Return the results
  Write-Output $collection
}
