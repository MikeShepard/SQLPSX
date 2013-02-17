#Requires -Version 2.0
Set-StrictMode -Version 2.0
Import-Module SQLServer -Force -ErrorAction Stop

#The type should be available once we import the SQLServer module.
#These will not be available for export for now.
#Enum Mirror Options
$DBM_OPT_FORCEFAIL      = [Microsoft.SqlServer.Management.Smo.MirroringOption]::ForceFailoverAndAllowDataLoss
$DBM_OPT_FAILOVER		= [Microsoft.SqlServer.Management.Smo.MirroringOption]::Failover
$DBM_OPT_RMWITNESS      = [Microsoft.SqlServer.Management.Smo.MirroringOption]::RemoveWitness
$DBM_OPT_RESUME         = [Microsoft.SqlServer.Management.Smo.MirroringOption]::Resume
$DBM_OPT_SUSPEND  		= [Microsoft.SqlServer.Management.Smo.MirroringOption]::Suspend
$DBM_OPT_TURNOFF  		= [Microsoft.SqlServer.Management.Smo.MirroringOption]::Off
#Enum Mirror Roles:
$DBM_ROLE_PRINCIPAL 	= $DBM_ROLE_PRINCIPAL
$DBM_ROLE_MIRROR    	= [Microsoft.SqlServer.Management.Smo.MirroringRole]::Mirror
$DBM_ROLE_NONE          = [Microsoft.SqlServer.Management.Smo.MirroringRole]::None
#Enum Mirror Safety Level:
$DBM_SFTYLVL_FULL 		= [Microsoft.SqlServer.Management.Smo.MirroringSafetyLevel]::Full
$DBM_SFTYLVL_OFF  		= [Microsoft.SqlServer.Management.Smo.MirroringSafetyLevel]::Off
$DBM_SFTYLVL_UNKWN      = [Microsoft.SqlServer.Management.Smo.MirroringSafetyLevel]::Unknown
$DBM_SFTYLVL_NONE 		= [Microsoft.SqlServer.Management.Smo.MirroringSafetyLevel]::None
#Enum Mirror status:
$DBM_STATUS_SYNCHED     = [Microsoft.SqlServer.Management.Smo.MirroringStatus]::Synchronized
$DBM_STATUS_PENDFAIL	= [Microsoft.SqlServer.Management.Smo.MirroringStatus]::PendingFailover
$DBM_STATUS_SYNCHING	= [Microsoft.SqlServer.Management.Smo.MirroringStatus]::Synchronizing
$DBM_STATUS_DISCNTD     = [Microsoft.SqlServer.Management.Smo.MirroringStatus]::Disconnected
$DBM_STATUS_SUSPEND     = [Microsoft.SqlServer.Management.Smo.MirroringStatus]::Suspended
$DBM_STATUS_NONE  		= [Microsoft.SqlServer.Management.Smo.MirroringStatus]::None


<#
      ***************************************************************************
                                    Region-Begin: Helper Functions
      ***************************************************************************
#>
Function Find-SqlDatabase
{
    <#
    .SYNOPSIS
        Searches if a database is available on the given SqlServer instance.

    .DESCRIPTION
        The Find-SqlDatabase function accepts a SqlServer SMO Connection object and
        a database name. It will then search through the list of available databases
        and see if there is a database on the server with given name.
        
     .PARAMETER SqlServer
      Name of the SQL Server instance in the following format: SQLServer\InstanceName
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false

    .PARAMETER DatabaseName
      Name of the database that we need to search for.
      
      Required                         false
      Position                         named
      Default value                    
      Accept pipeline input            false
      Accept wildcard characters       false

    
    .EXAMPLE
            Find-SqlDatabase when Database is available.
      PS H:\> Find-SqlDatabase -SqlServer $sqlServer -DatabaseName 'dba_Test'
        True

    .EXAMPLE
        Find-SqlDatabase when database is not available.
            PS H:\> Find-SqlDatabase -SqlServer $sqlServer -DatabaseName 'dba_Test_old'
        False
    
    .NOTES
        Scripts to manage SQL Server
    #>
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SqlServer.Management.Smo.Server]$SqlServer,
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName
     )
    try
    {
        $status = $false
            if($DatabaseName)
            {
            if ($SqlServer.Databases.Contains("$DatabaseName"))
                  {
                        $status = $true
                  }else{
                        Write-Host "The database: $DatabaseName, was not found on: $($SqlServer.Name)" -ForegroundColor Yellow
                  }
            }
    }
    catch
    {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host $ex.Message -Fore Red
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
           Write-Host "`t" $ex.InnerException.Message -Fore Red
           $excMsg = $ex.InnerException.Message.ToString()
        }
    }
    finally
    {
        return $status
    }
     
} 

Function Get-DBMDatabases
{
    <#
    .SYNOPSIS
        Lists all mirrored databases on a give SqlServer instance.

    .DESCRIPTION
        The Get-DBMDatabases function accepts a SqlServer SMO Connection 
        object. It will return, the list of available mirrored databases.
        
    .PARAMETER SqlServer
      Name of the SQL Server instance in the following format: SQLServer\InstanceName
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false

        
    .EXAMPLE
            Get-DBMDatabases to list all mirrored databases
      PS H:\> $sqlServer = Get-SqlServer -SqlServer SQLCHOW01\INS001 -CommandTimeout 10
        PS H:\> Get-DBMDatabases -SqlServer $sqlServer

        Name              MirroringRole MirroringPartnerInstance MirroringStatus MirroringSafetyLevel
        ----              ------------- ------------------------ --------------- --------------------
        dba_TestdataCopy2        Mirror SQLCHOW02\INS002           Suspended                  Off

    
    .NOTES
        Scripts to manage SQL Server
    #>
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SqlServer.Management.Smo.Server]$SqlServer,
        [switch]$DisplayOnly
    )
    try
    {
            $mrrDb = @()
            $mrrDb +=  $sqlserver.Databases |?{$_.IsMirroringEnabled}

            if(-not ($mrrDb))
            {
                  Write-Host "No Mirrored database found on $($SqlServer.Name)" -ForegroundColor Yellow
            }
            elseif($mrrDb)
            {
                  $selList =  $mrrDb |
                                          Select-Object Name, `
                                @{Name="MirroringRole";Expression={$_.Properties["MirroringRole"].Value}}, `
                                MirroringPartnerInstance, MirroringStatus, MirroringSafetyLevel
            }
            
            if($DisplayOnly)
            {     #worried about the data going to outputstream. get clarification.
                  Write-Host -Object $selList
                  #Select-Object -InputObject $selList
                  #Write-Output -InputObject $selList
            }
            else
            {
                  return $selList                     
            }
      }
    catch
    {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host $ex.Message -Fore Red
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
           Write-Host "`t" $ex.InnerException.Message -Fore Red
           $excMsg = $ex.InnerException.Message.ToString()
        }
    }
} 
<#
      ***************************************************************************
                                    Region-End  : Helper Functions
      ***************************************************************************
#>

<#
      ***************************************************************************
                                    Region-Begin: Script Functions
      ***************************************************************************
#>
Function Switch-DBMTranSafety
{
    <#
    .SYNOPSIS
      Toggle transaction safety for mirrored databases.

    .DESCRIPTION
      The Switch-DBMTranSafety function, allows you to toggle transaction safety. 
     
    .PARAMETER Principal
      Name of the current Principal instance in the following format: SQLServer\InstanceName
      
      Required                        true
      Position                        named
      Default value                                 
      Accept pipeline input           false
      Accept wildcard characters      false

    .PARAMETER DbName
      Name of the database that is configured for mirroring.
      
      Required                        false
      Position                        named
      Default value                                 
      Accept pipeline input           false
      Accept wildcard characters      false

    .EXAMPLE
            Switch-DBMTranSafety function with named parameters.
      Switch-DBMTranSafety -Principal "ServerName\InstanceName" -DbName "DatabaseName" 
        Current transaction safety level is : Off
        Do you want to switch the transaction safety level (Y/N): Y
        Setting transaction safety level to : FULL
        Current transaction safety level is : Full
        
    .NOTES
        Scripts to manage SQL Server Database Mirroring
    #>
    Param(
      [alias("P")]
      [parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [String]
      $Principal,
      [alias("D")]
      [parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [String]
      $DbName
      )
      try
    {
            #Being optimistically greedy and getting the connection object and database object at the begining.
          $principalSrvr = Get-SqlServer -SqlServer $Principal -StatementTimeout 10 #In case of typo with server name we can exit.
            $principalSrvr.ConnectionContext.ApplicationName = "SQLPSX-DBMUtilities"
            
            $isDBExist = Find-SqlDatabase -SqlServer $principalSrvr -DatabaseName $DbName
            if($isDBExist)
            {
                  if($principalSrvr.Databases("$DbName").IsMirroringEnabled){
                        $principalDB = $principalSrvr.Databases[$DbName]
                  }else{
                        $(throw "The specified database $($DbName) on $($Principal) is not mirrored.")
                  }
            }
            else
            {
                  $(throw "The specified database $($DbName) does not exist on $($Principal)")
            }
            
            if($principalDB.Properties["MirroringRole"].Value -eq $DBM_ROLE_PRINCIPAL)
            {
                  $tranSftyLvl = $principalDB.MirroringSafetyLevel.ToString()
                  Write-Host "Current transaction safety level for $DbName is : $($tranSftyLvl)"
                  
                  $switchSfty = Read-Host "Do you want to switch the transaction safety level (Y/N)"
                  if($switchSfty -ieq "Y" ){
                        if($tranSftyLvl -eq "Off"){
                              Write-Host "Setting transaction safety level for $DbName to : FULL"
                              $principalDB.MirroringSafetyLevel = $DBM_SFTYLVL_FULL
                              $principalDB.Alter()
                        }elseif($tranSftyLvl -eq "Full"){
                              Write-Host "Setting transaction safety level for $DbName to : OFF"
                              $principalDB.MirroringSafetyLevel = $DBM_SFTYLVL_OFF
                              $principalDB.Alter()
                        }else{
                              Write-Host "The script can only toggle transaction safety level between full and off"         
                        }
                        
                  }elseif($switchSfty -ieq "N"){
                        Write-Host "Not resetting transaction safety level"
                        
                  }else{
                        Write-Host "Invalid option selected"
                  }
            $principalDB.Refresh()
            $tranSftyLvl = $principalDB.MirroringSafetyLevel.ToString()
            Write-Host "Current transaction safety level is : $($tranSftyLvl)"
            
            }else{
            
        }
      }
    catch
    {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host "[Switch-DBMTranSafety]: $($excMsg)" -Fore Red
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
               Write-Host "`t" $ex.InnerException.Message -Fore Red
           $excMsg = $ex.InnerException.Message.ToString()
           Write-Host "`t $($excMsg)"   
        }
      }
}

Function Move-DBMSessionForced
{
    <#
    .SYNOPSIS
        Forces service (with possible data loss). To be used only as a disaster 
      recovery method.

    .DESCRIPTION
        The Move-DBMSessionForced function, allows you to force service. Forcing 
      service is possible only if the principal server is disconnected from 
      the mirror server in a mirroring session. So, the assumption is that the
      principal is not available. 
     
     .PARAMETER Mirror
      Name of the current Mirror instance in the following format: SQLServer\InstanceName
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false

    .PARAMETER DbName
      Name of the database that is configured for mirroring.
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false

    .EXAMPLE
            Move-DBMSessionForced function with named parameters.
            Move-DBMSessionForced -Mirror "ServerName\InstanceName" -DbName "DatabaseName"

    .NOTES
        Scripts to manage SQL Server Database Mirroring
    #>
      Param(
                  [alias("M")]
                  [parameter(Mandatory=$true)]
                  [ValidateNotNullOrEmpty()]
                  [String]
                  $Mirror,
                  [alias("D")]
                  [parameter(Mandatory=$true)]
                  [ValidateNotNullOrEmpty()]
                  [String]
                  $DbName
            )
      try
    {
      $dbConn = Get-SqlServer -SqlServer $Mirror -StatementTimeout 10 #In case of typo with server name we can exit.
            $dbConn.ConnectionContext.ApplicationName = "SQLPSX-DBMUtilities"
            
            $isDBExist = Find-SqlDatabase -SqlServer $dbConn -DatabaseName $DbName
            if($isDBExist)
            {
                  if($dbConn.Databases("$DbName").IsMirroringEnabled){
                        $dbToForce = $dbConn.Databases[$DbName]
                        if($dbToForce.Properties["MirroringRole"].Value -eq $DBM_ROLE_PRINCIPAL){
                              $(throw "The specified databases $($DbName) role is 'Principal'")
                        }
                  }else{
                        $(throw "The specified database $($DbName) on $($Mirror) is not mirrored.")
                  }
            }
            else
            {
                  $(throw "The specified database $($DbName) does not exist on $($Mirror)")
            }
        
            Write-Host "Forcing Service. Failing over to $Mirror!!" -ForegroundColor Yellow
        $dbToForce.ChangeMirroringState($DBM_OPT_FORCEFAIL)
            
            Write-Host "`tWaiting for $dbToForce to recover..."
        Start-Sleep -Seconds 15
            do
            {     
                  Write-Host "`tWaiting for $dbToForce to recover..."   
                  Start-Sleep -Seconds 15
                  $dbConn = Get-SqlServer -SqlServer $Mirror -StatementTimeout 10 -ErrorAction stop
                  $dbToForce = $dbConn.Databases[$DbName]
            }until((($dbToForce.Properties["IsAccessible"].Value) -match $true) -and (($dbToForce.Status.Tostring()) -eq 'Normal'))
            
        Write-Host "Removing mirroring on Partner: $Mirror"       
        $dbToForce.ChangeMirroringState($DBM_OPT_TURNOFF)
            
      }
    catch
    {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host "[Move-DBMSessionForced]: $($excMsg)" -ForegroundColor Red
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
           Write-Host "`t" $ex.InnerException.Message -ForegroundColor Red
           $excMsg = $ex.InnerException.Message.ToString()
           Write-Host "`t $($excMsg)"   -ForegroundColor Red
        }
    }
    finally{
            $dbConn.ConnectionContext.Disconnect()
      }
}

Function Move-DBMSession
{
    <#
    .SYNOPSIS
        Initiates a failover to the mirrored database.

    .DESCRIPTION
        The Move-DBMSession function, allows you to failover service. Failover
      is done only after the mirroring sessions status is 'Synchronized'.
      
    .PARAMETER Principal
      Name of the current Principal server instance in the following format: SQLServer\InstanceName
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false
      
    .PARAMETER DbName
      Name of the database that is configured for mirroring.
      
      Required                         true
      Position                         named
      Default value                                 
      Accept pipeline input            false
      Accept wildcard characters       false

    .EXAMPLE
            Move-DBMSession function with named parameters.
            Move-DBMSession -Principal "ServerName\InstanceName" -DbName "DatabaseName"

    .NOTES
        Scripts to manage SQL Server Database Mirroring
    #>
      Param(
                  [alias("P")]
                  [parameter(Mandatory=$true)]
                  [ValidateNotNullOrEmpty()]
                  [String]
                  $Principal,
                  [alias("D")]
                  [parameter(Mandatory=$true)]
                  [ValidateNotNullOrEmpty()]
                  [String]
                  $DbName
            )
      
      try
    {
            $principalSrvrConn = Get-SqlServer -SqlServer $Principal -StatementTimeout 10 #In case of typo with server name we can exit.
            $principalSrvrConn.ConnectionContext.ApplicationName = "SQLPSX-DBMUtilities"
            
            $isDBExist = Find-SqlDatabase -SqlServer $principalSrvrConn -DatabaseName $DbName
            if($isDBExist)
            {
                  if($principalSrvr.Databases("$DbName").IsMirroringEnabled){
                        $principalDB = $principalSrvr.Databases[$DbName]
                  }else{
                        $(throw "The specified database $($DbName) on $($Principal) is not mirrored.")
                  }
            }
            else
            {
                  $(throw "The specified database $($DbName) does not exist on $($Principal)")
            }
            
            #Being optimistically greedy and getting the connection object and database object at the begining.
        $Mirror = $principalDB.MirroringPartnerInstance
            $mirrorSrvrConn = Get-SqlServer -SqlServer $Mirror -CommandTimeout 10
        $isDBExist = Find-SqlDatabase -SqlServer $principalSrvrConn -DatabaseName $DbName
        if($isDBExist)
        {
              $mirrorDB = $mirrorSrvrConn.Databases[$DbName]
        }
        else
        {
            $(throw "The specified database $($DbName) does not exist on $($Mirror)")
        }
                        
        #check database role
        if($principalDB.Properties["MirroringRole"].Value -eq $DBM_ROLE_PRINCIPAL)
		{
	        $tranSftyLvl = $principalDB.MirroringSafetyLevel.ToString()
	        
	        if($tranSftyLvl -eq "Off"){
	          	Write-Host "Setting Transaction safety to Full on $DbName..."
	          	$principalDB.ExecuteNonQuery("Use master; ALTER DATABASE $dbName SET SAFETY FULL;")
	        }elseif($tranSftyLvl -eq "Full"){
	        	Write-Host "Transaction safety set to Full for $DbName..."
	        }

            Write-Host "Waiting for mirroring to synchronize..."
            do{
                #sleep for a little
                Start-Sleep -Seconds 15
        
                #refresh the connection:primary
                $primarySrvrConn = Get-SqlServer -SqlServer $Principal -CommandTimeout 10
                $primaryDB = $primarySrvrConn.Databases[$dbName]
                $pMirrorStatus = ($primaryDB.MirroringStatus).ToString()
                
                #refresh the connection:mirror
                $mirrorSrvrConn = Get-SqlServer -SqlServer $Mirror -CommandTimeout 10
                $mirrorDB = $mirrorSrvrConn.Databases[$dbName]
                $mMirrorStatus = ($mirrorDB.MirroringStatus).ToString()
            } until (($pMirrorStatus -eq 'Synchronized') -and  ($mMirrorStatus -eq 'Synchronized'))
            
			Write-Host "Failing over...."
			$primaryDB.ChangeMirroringState($DBM_OPT_FAILOVER)

			Write-Host "Waiting for mirroring to synchronize..."
			do{
                #sleep for a little
				Start-Sleep -Seconds 15
				#refresh the connection:primary
				$primarySrvrConn = Get-SqlServer -SqlServer $Principal -CommandTimeout 10
				$primaryDB = $primarySrvrConn.Databases[$dbName]
				$pMirrorStatus = ($primaryDB.MirroringStatus).ToString()

				#Refresh the connection:mirror
				$mirrorSrvrConn = Get-SqlServer -SqlServer $Mirror -CommandTimeout 10
				$mirrorDB = $mirrorSrvrConn.Databases[$dbName]
				$mMirrorStatus = ($mirrorDB.MirroringStatus).ToString()
			} until (($pMirrorStatus -eq 'Synchronized') -and  ($mMirrorStatus -eq 'Synchronized'))

			if($tranSftyLvl -eq "Off"){
				Write-Host "Setting transaction safety off for $dbName on $Mirror..."
				$mirrorDB.ExecuteNonQuery("Use master; ALTER DATABASE $dbName SET SAFETY OFF;")
			}elseif($tranSftyLvl -eq "Full"){
				Write-Host "Transaction safety already set to Full for $DbName..."
			}
        }else{
			#Write-Debug "The role of the server: $principal, is not what was expected. Kindly validate the server name." -Fore Red
			Write-Error "The role of $dbName on the server: $principal, is not what was expected. Kindly validate the database properties."

        }
	}
    catch
    {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host $ex.Message -Fore Red
        
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
           Write-Host "`t" $ex.InnerException.Message -Fore Red
           $excMsg = $ex.InnerException.Message.ToString()
        
        }

      }finally{
            $principalSrvrConn.ConnectionContext.Disconnect()
            $mirrorSrvrConn.ConnectionContext.Disconnect()
      }
}

Function Get-DBMStatus{
    <#
    .SYNOPSIS
        Check the status of the mirroring connection. It will display the time in minutes
    	the mirror server is lagging behind the principal.

    .DESCRIPTION
        The Get-DBMStatus function, allows you to check the status of the mirroring setup.
    	It will display the time in minutes	the mirror server is lagging behind the principal.
    	It uses 'sp_dbmmonitorresults' procedure to get the details of the session.
    	
    .PARAMETER Partner
    	Name of the current Partner server instance in the following format: SQLServer\InstanceName
    	
    	Required                                          true
    	Position                                            named
    	Default value                                 
    	Accept pipeline input                 false
    	Accept wildcard characters       false
    	
    .PARAMETER DbName
    	Name of the database that is configured for mirroring.
    	
    	Required                                         false
    	Position                                           named
    	Default value                                 
    	Accept pipeline input                false
    	Accept wildcard characters     false

    .EXAMPLE
       	Get-DBMStatus function with named parameters.
    		Get-DBMStatus -Partner "ServerName\InstanceName" -DbName "DatabaseName"
    .EXAMPLE
        Get-DBMStatus -Partner SQLCHOW01\INS1 -DbName dba_perfdataCopy2

        Connecting to principal: SQLVIRDEV02\INS2 ...
        Mirroring session for dba_perfTestCopy2 is either suspended or disconnected

    .NOTES
        Scripts to manage SQL Server Database Mirroring
    #>
	Param(
			[alias("P")]
			[parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[String]
			$Partner,
			[alias("D")]
			[parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[String]
			$DbName
		)
 
 try{
	#Being optimistically greedy and getting the connection object and database object at the begining.
    
	$PartnerSrvrConn = Get-SqlServer -SqlServer $Partner -CommandTimeout 10
    
    #Write-Host "Fetching DB info" -Fore Red
    $isDBExist = Find-SqlDatabase -SqlServer $PartnerSrvrConn -DatabaseName "$DbName"
    if($isDBExist)
    {
		  $PartnerDB = $PartnerSrvrConn.Databases["$DbName"]
    }
    else
    {
        $(throw "The specified database '$($DbName)' does not exist on $($Partner)")
    }
    
	Write-Debug "Got DB info" 

	#check database role
	if($PartnerDB.Properties["MirroringRole"].Value -eq [Microsoft.SqlServer.Management.Smo.MirroringRole]::Principal)
    {
		#use mode=0 to only get the last row
		$qryString=	"EXEC msdb..sp_dbmmonitorresults  $DbName,  0, 0"
		[System.Data.DataSet]$resSet = $PartnerDB.ExecuteWithResults($qryString)
        
		foreach($row in $resSet.Tables[0])
        {
            if(($row.time_behind -ne [DBNULL]::Value) -and ($row.time_recorded -ne [DBNULL]::Value))
            {
    			$timeLag = ((Get-Date $row.time_recorded)-(Get-Date $row.time_behind)).Minutes
                
                #populate the needed properties.
                $dbProperties = ""|Select PrincipalServer, MirrorServer, TimeLag, SafetyLevel, WitnessServer, WitnessStatus
                $dbProperties.PrincipalServer = $Partner
    			$dbProperties.MirrorServer = $PartnerDB.MirroringPartnerInstance
                $dbProperties.TimeLag = $timeLag
    			$dbProperties.SafetyLevel = $PartnerDB.MirroringSafetyLevel.ToString()
                if($PartnerDB.MirroringWitness -eq ''){$dbProperties.WitnessServer = "No Witness selected"}
                else{$dbProperties.WitnessServer = $PartnerDB.MirroringWitness}
                $dbProperties.WitnessStatus = $PartnerDB.MirroringWitnessstatus.ToString()
                
                #display the output|only worry is if this goes on to the pipe
    			return $dbProperties
                
	           }
            else
            {
                Write-Host "Mirroring session for $DbName is either suspended or disconnected" -ForegroundColor Yellow
            }
		}
	}
    elseif($PartnerDB.Properties["MirroringRole"].Value -eq $DBM_ROLE_MIRROR)
    {
              
        $tmpPartnerInst = $PartnerDB.MirroringPartnerInstance.ToString()
        $tmpPartnerInst = $tmpPartnerInst.Replace("[","")
        $tmpPartnerInst = $tmpPartnerInst.Replace("]","")
        $PartnerInst = $tmpPartnerInst
        Write-Host "`nConnecting to principal: $PartnerInst ..."
        
        $PartnerSrvrConn = Get-SqlServer -SqlServer $PartnerInst -CommandTimeout 10
    
        $isDBExist = Find-SqlDatabase -SqlServer $PartnerSrvrConn -DatabaseName $DbName
        if($isDBExist)
        {
    		  $PartnerDB = $PartnerSrvrConn.Databases[$DbName]
        }
        else
        {
            $(throw "The specified database $($DbName) does not exist on $($PartnerInst)")
        }
        
    	Write-Debug "Got DB info" 
        #use mode=0 to only get the last row
		$qryString=	"EXEC msdb..sp_dbmmonitorresults  $DbName,  0, 0"
		[System.Data.DataSet]$resSet = $PartnerDB.ExecuteWithResults($qryString)
                
		foreach($row in $resSet.Tables[0])
        {
            if(($row.time_behind -ne [DBNULL]::Value) -and ($row.time_recorded -ne [DBNULL]::Value))
            {
    			$timeLag = ((Get-Date $row.time_recorded)-(Get-Date $row.time_behind)).Minutes
                
                #populate the needed properties.
                $dbProperties = ""|Select PrincipalServer, MirrorServer, TimeLag, SafetyLevel, WitnessServer, WitnessStatus
                $dbProperties.PrincipalServer = $PartnerInst
    			$dbProperties.MirrorServer = $PartnerDB.MirroringPartnerInstance
                $dbProperties.TimeLag = $timeLag
    			$dbProperties.SafetyLevel = $PartnerDB.MirroringSafetyLevel.ToString()
                if($PartnerDB.MirroringWitness -eq ''){$dbProperties.WitnessServer = "No Witness selected"}
                else{$dbProperties.WitnessServer = $PartnerDB.MirroringWitness}
                $dbProperties.WitnessStatus = $PartnerDB.MirroringWitnessstatus.ToString()
                
                #display the output|only worry is if this goes on to the pipe
    			$dbProperties | Format-Table -AutoSize -Wrap
            }
            else
            {
                Write-Host "Mirroring session for $DbName is either suspended or disconnected" -ForegroundColor Yellow
            }
        }
    }
    else
    {
		#Write-Debug "The role of the server: $Partner, is not what was expected. Kindly validate the server name." -Fore Red
		Write-Error "The role of the server: $Partner, is not what was expected. Kindly validate the server name."
	}
	
	}catch{
		$ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host "[Get-DBMStatus]: $($excMsg)" -Fore Red
        
        while ($ex.InnerException)
        {
           $ex = $ex.InnerException
           Write-Host "`t" $ex.InnerException.Message -Fore Red
           $excMsg = $ex.InnerException.Message.ToString()
        }
	}finally{
		$PartnerSrvrConn.ConnectionContext.Disconnect()
	}
}
<#
	***************************************************************************
						Region-End: Script Functions
	***************************************************************************
#>
<#
	$endPoints.EnumEndpoints([Microsoft.SqlServer.Management.Smo.EndPointType]::DatabaseMirroring)
	Soap -> The HTTP endpoint type is SOAP.
	TSql -> The HTTP endpoint type is Transact-SQL.
	ServiceBroker -> The HTTP endpoint type is SQL Server Service Broker.
	DatabaseMirroring -> The HTTP endpoint type is database mirroring.
	
	[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo")  
	[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")  
	[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended")  

#>

Export-ModuleMember -function *