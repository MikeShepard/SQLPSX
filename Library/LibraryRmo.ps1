# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the RMO Classes
### </Description>
### <Usage>
### . ./LibraryRmo.ps1
### get-sqlconnection 'Z002\Sql1'
### get-replserver 'Z002\Sql1'
### $replServer = get-replserver 'Z002\Sql1'
### get-repllightpublication $replServer
### get-replSubscriberSubscription $replServer
### Get-ReplPublication $replServer
### Get-ReplPublication $replServer | Get-ReplSubscription
### Get-ReplPublication $replServer | Get-ReplArticle
### $replMon = Get-ReplMonitor 'Z002\Sql1'
### $publisherMon = Get-ReplPublisherMonitor 'Z002\Sqlqa1
### $pubMon = Get-ReplPublicationMonitor 'Z002\Sql1'
### $pubMon | Get-ReplTransPendingCommandInfo
### $publisherMon | Get-ReplEnumPublications
### $publisherMon | Get-ReplEnumPublications2
### $pubMon | get-replEnumSubscriptions
### $pubMon | get-replEnumSubscriptions2
### $pubMon | get-replenumlogreaderagent
### $pubMon | get-replenumsnapshotagent
### $replServer | get-replscript
### get-replpublication 'Z002\Sql1' | Get-ReplScript
### get-replpublication 'Z002\Sql1' | Get-ReplSubscription | Get-ReplScript
### get-replpublication 'Z002\Sql1' | Get-ReplArticle | Get-ReplScript
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Common") > $null
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") > $null

#######################
function Get-SqlConnection
{
    param([string]$sqlserver=$(Throw 'Get-SqlConnection:`$sqlserver is required.'),[string]$Username,[string]$Password)

    Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password)
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver $Username $Password }
    else
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver }
	
    $con.Connect()

    return $con
    
} #Get-ServerConnection

#######################
function Get-ReplServer
{
    param($replServer=$(throw 'Get-ReplServer:`$sqlserver is required'))

    Write-Verbose "Get-ReplServer $($con.ServerInstance)"
    
    $con = Get-SqlConnection $replServer $Username $Password

    $repl = new-object ("Microsoft.SqlServer.Replication.ReplicationServer") $con

    return $repl

} #Get-ReplServer

#######################
function Get-ReplLightPublication
{
    #The following note appears in documentaton about this class "supports the SQL Server 2005 infrastructure and is not intended to be used directly
    #from your code. This is a bit a of problem as enumlightpublications() appears to be the only method to retrieve a list of publications from a
    #ReplicationServer. So this method will be used by Get-ReplPublication.
    param($replServer=$(throw 'Get-ReplLighPublication:`$replServer is required.'))
    
    switch ($replServer.GetType().Name)
    {
        'String' { $repl = Get-ReplServer $replServer }
        'ReplicationServer' { $repl = $replServer }
        default { throw 'Get-ReplLightPublication:Param `$replServer must be a String or ReplicationServer object.' }
    }

    Write-Verbose "Get-ReplLightPublication $($repl.Name)"

    #(Name of database, [1 = trans, 2 = merge, 3 = all], return hetro, return empty tran)
    $lightPub = $repl.enumlightpublications($null, 3, $true, $true) 
    $lightPub | add-Member -memberType noteProperty -name ConnectionContext -value $repl.ConnectionContext -passthru

} #Get-ReplLightPublication

#######################
function New-ReplTransPublication
{
    param([string]$name=$(throw 'Get-ReplTransPublication:`$name is required.'),
          [string]$databaseName=$(throw 'Get-ReplTransPublication:`$databaseName is required.'),
          $connectionContext=$(throw 'Get-ReplTransPublication:`$connectionContext is required.'),[switch]$createSnapshotAgent)

    Write-Verbose "New-ReplTransPublication $name"

    $pub = new-object ("Microsoft.SqlServer.Replication.TransPublication") $name,$databaseName,$connectionContext,$($createSnapshotAgent.IsPresent)

    return $pub

} #New-ReplTransPublication

#######################
function New-ReplMergePublication
{
    param([string]$name=$(throw 'Get-ReplMergePublication:`$name is required.'),
          [string]$databaseName=$(throw 'Get-ReplMergePublication:`$databaseName is required.'),
          $connectionContext=$(throw 'Get-ReplMergePublication:`$connectionContext is required.'),[switch]$createSnapshotAgent)

    Write-Verbose "New-ReplMergePublication $name"

    $pub = new-object ("Microsoft.SqlServer.Replication.MergePublication") $name,$databaseName,$connectionContext,$($createSnapshotAgent.IsPresent)

    return $pub

} #New-ReplMergePublication

#######################
function Get-ReplSubscriberSubscription
{
    #Note: This function is meant to be called on the subscriber. All other functions are called from the publisher/distributor
    param($replServer=$(throw 'Get-ReplSubscriberSubscription:`$replServer is required.'))
        
    switch ($replServer.GetType().Name)
    {
        'String' { $repl = Get-ReplServer $replServer }
        'ReplicationServer' { $repl = $replServer }
        default { throw 'Get-ReplSubscriberSubscription:Param `$replServer must be a String or ReplicationServer object.' }
    }

    Write-Verbose "Get-ReplSubscriberSubscription $($repl.Name)"

    $repl.EnumSubscriberSubscriptions($null,3)
   
} #Get-ReplSubscriberSubscription

#######################
function Get-ReplPublication
{
   param($replServer=$(throw 'Get-ReplPublication:`$replServer is required.'))
    
   switch ($replServer.GetType().Name)
   {
        'String' { $repl = Get-ReplServer $replServer }
        'ReplicationServer' { $repl = $replServer }
        default { throw 'Get-ReplPublication:Param `$replServer must be a String or ReplicationServer object.' }
   }

   Write-Verbose "Get-ReplPublication $($repl.Name)"

   #Note: We are not creating a new publication, we are calling the respective Publication Constructor passing in
   #an existing publication.
   foreach ($lp in  $(Get-ReplLightPublication $repl))
   {
        switch ($lp.Type)
        {
            'Transactional' { New-ReplTransPublication $lp.name $lp.PublicationDBName $lp.ConnectionContext }
            'Merge'         { New-ReplMergePublication $lp.name $lp.PublicationDBName $lp.ConnectionContext }
        }
   }

} #Get-Publication

#######################
function Get-ReplSubscription
{
    #equivalent to executing sp_helpmergepublication or sp_helparticle
    param($pub)

    process
    {
        Write-Verbose "Get-ReplSubscription $($_.Name)"
        $p = $_
        switch ($p.Type)
        {
            'Transactional' { $p.TransSubscriptions } 
            'Merge'         { $p.MergeSubscriptions }
            default { throw 'Get-ReplSubscription:Param `$pub must be a Publication object.' }
        }
    }
    end
    {
        if ($pub)
        { $pub | Get-ReplSubscription }
    }
   
} #Get-ReplSubscription

#######################
function Get-ReplArticle
{
    #equivalent to executing sp_helpmergepublication or sp_helparticle
    param($pub)

    process
    {
        Write-Verbose "Get-ReplArticle $($_.Name)"
        $a = $_
        switch ($a.Type)
        {
            'Transactional' {$a.TransArticles } 
            'Merge'         {$a.MergeArticles }
            default { throw 'Get-ReplArticle:Param `$pub must be a Publication object.' }
        }
    }
    end
    {
        if ($pub)
        { $pub | Get-ReplArticle }
    }
   
} #Get-ReplArticle

#######################
function Get-ReplMonitor
{
    #There is a basic hierarchy with monitoring:
    #ReplicationServer => PublisherMonitor => PublicationMonitor
    param($replServer=$(throw 'Get-ReplMonitor:`$replServer is required'))

    switch ($replServer.GetType().Name)
    {
        'String' { $con = Get-SqlConnection $replServer }
        'ServerConnection' { $con = $replServer }
        default { throw 'Get-ReplMonitor:Param `$replServer must be a String or ServerConnection object.' }
    }

    Write-Verbose "Get-ReplMonitor $($con.ServerInstance)"
    
    $replMon = new-object ("Microsoft.SqlServer.Replication.ReplicationMonitor") $con

    return $replMon


} #Get-ReplMonitor

#######################
function Get-ReplPublisherMonitor
{
    param($replServer=$(throw 'Get-ReplPublisherMonitor:`$replServer is required'))
    
    Write-Verbose "Get-ReplPublisherMonitor"

    $replMon =  Get-ReplMonitor $replServer

    return $replMon.PublisherMonitors

} #Get-ReplPublisherMonitor

#######################
function Get-ReplPublicationMonitor
{
    param($replServer=$(throw 'Get-ReplPublicationMonitor:`$replServer is required'))

    Write-Verbose "Get-ReplPublicationMonitor"
    
    $publisherMon = Get-ReplPublisherMonitor $replServer

    return $publisherMon.PublicationMonitors

} #Get-ReplPublicationMonitor

#######################
function Get-ReplEnumPublications
{
    param($publisherMon)

    process
    {
        if ($_.GetType().Name -eq 'PublisherMonitor')
        { 
            Write-Verbose "Get-ReplEnumPublications $($_.Name) "
            $_.EnumPublications() | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumPublications:Param `$publisherMon must be a PublisherMonitor object.' }
    }
    end
    {
        if ($publisherMon)
        { $publisherMon | Get-ReplEnumPublications }
    }

} #Get-Get-ReplEnumPublications

#######################
function Get-ReplEnumPublications2
{
    #equivalent to executing sp_replmonitorhelppublication
    #Only available for Microsoft SQL Server version 2005 or later
    param($publisherMon)

    process
    {
        if ($_.GetType().Name -eq 'PublisherMonitor')
        { 
            Write-Verbose "Get-ReplEnumPublications $($_.Name) "
            $_.EnumPublications2() | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumPublications2:Param `$publisherMon must be a PublisherMonitor object.' }
    }
    end
    {
        if ($publisherMon)
        { $publisherMon | Get-ReplEnumPublications2 }
    }

} #Get-Get-ReplEnumPublications2

#######################
function Get-ReplEnumSubscriptions
{
    param($pubMon)

    process
    {
        if ($_.GetType().Name -eq 'PublicationMonitor')
        { 
            Write-Verbose "Get-ReplEnumSubscriptions $($_.Name)" 
            $_.EnumSubscriptions() | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumSubscriptions:Param `$pubMon must be a PublicationMonitor object.' }
    }
    end
    {
        if ($pubMon)
        { $pubMon | Get-ReplEnumSubscriptions }
    }

} #Get-Get-ReplEnumSubscriptions

#######################
function Get-ReplEnumSubscriptions2
{
    #equivalent to executing sp_replmonitorhelpSubscription
    #Only available for Microsoft SQL Server version 2005 or later
    param($pubMon)

    process
    {
        if ($_.GetType().Name -eq 'PublicationMonitor')
        { 
            Write-Verbose "Get-ReplEnumSubscriptions2 $($_.Name)" 
            $_.EnumSubscriptions2(0) | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumSubscriptions2:Param `$pubMon must be a PublicationMonitor object.' }
    }
    end
    {
        if ($pubMon)
        { $pubMon | Get-ReplEnumSubscriptions2 }
    }

} #Get-Get-ReplEnumSubscriptions2

#######################
function Get-ReplTransPendingCommandInfo
{
    #equivalent to executing sp_replmonitorsubscriptionpendingcmds
    #Only available for Microsoft SQL Server version 2005 or later
    param($pubMon)

    process
    {
        if ($_.GetType().Name -eq 'PublicationMonitor')
        { 
            Write-Verbose "Get-ReplTransPendingCommandInfo $($_.Name)" 
            $p = $_
            $p | Get-ReplEnumSubscriptions |  foreach { $p.TransPendingCommandInfo($_.subscriber, $_.subscriber_db, $_.type) }
        }
        else
        { throw 'Get-ReplTransPendingCommandInfo:Param `$pubMon must be a PublicationMonitor object.' }

    }
    end
    {
        if ($pubMon)
        { $pubMon | Get-TransPendingCommandInfo }
    }

} #Get-ReplTransPendingCommandInfo

#######################
function Get-ReplEnumLogReaderAgent
{
    param($pubMon)

    process
    {
        if ($_.GetType().Name -eq 'PublicationMonitor')
        { 
            Write-Verbose "Get-ReplEnumLogReaderAgent $($_.Name)" 
            $_.EnumLogReaderAgent() | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumLogReaderAgent:Param `$pubMon must be a PublicationMonitor object.' }
    }
    end
    {
        if ($pubMon)
        { $pubMon | Get-ReplEnumLogReaderAgent }
    }

} #Get-Get-ReplEnumLogReaderAgent

#######################
function Get-ReplEnumSnapshotAgent
{
    param($pubMon)

    process
    {
        if ($_.GetType().Name -eq 'PublicationMonitor')
        { 
            Write-Verbose "Get-ReplEnumSnapshotAgent $($_.Name)" 
            $_.EnumSnapshotAgent() | foreach { $_.Tables} | foreach { $_.Rows }
        }
        else
        { throw 'Get-ReplEnumSnapshotAgent:Param `$pubMon must be a PublicationMonitor object.' }
    }
    end
    {
        if ($pubMon)
        { $pubMon | Get-ReplEnumSnapshotAgent }
    }

} #Get-Get-ReplEnumSnapshotAgent

#######################
function Set-ReplScriptOptions
{
    param($optsFile="replscriptopts.txt")

    #There 35 settable scripting options at the time of this writing, rather than set the options as parameters
    #I've choosen to set them through a separate file. Modify the passed in file to set
    #the various scriptingOptions to your liking. See the following MSDN link for a description of the settable options:
    #http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.replication.scriptoptions(SQL.90).aspx
    #NOTE: UNLIKE SMO SCRIPTER CLASS, YOU MUST SET THE SCRIPTING OPTIONS IN RMO TO AT LEAST CREATION
    Write-Verbose "Set-ReplScriptOptions $optsFile"
    
    $ScriptOpts = @()
    if (test-path $scriptRoot\$optsFile)
    {
        $include = [System.IO.File]::ReadAllText("$scriptRoot\$optsFile")
        invoke-expression $include
    }
    elseif (test-path $optsFile)
    {
        $include = [System.IO.File]::ReadAllText("$optsFile")
        invoke-expression $include
    }

    return $scriptOpts

} #Set-ReplScriptOptions

#######################
function Get-ReplScript
{
    param($rmo, $scriptOpts=$(Set-ReplScriptOptions))
    begin
    {
        function Select-ReplScript ($rmo, $scriptOpts=$(Set-ReplScriptOptions))
        {
            $rmo.Script($scriptOpts)

        } #Select-ReplScript
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Namespace -like "Microsoft.SqlServer.Replication*")
            { Write-Verbose "Get-ReplScript $($_.Name)"
              Select-ReplScript $_ $scriptOpts }
            else
            { throw 'Get-ReplScript:Param `$rmo must be an rmo object.' }

        }
    }
    end
    {
        if ($rmo)
        { $rmo | Get-ReplScript -scriptOpts $scriptOpts }
    }

} #Get-ReplScript
