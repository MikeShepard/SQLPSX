# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the RMO Classes
### </Description>
### <Usage>
### import-module repl
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------
try {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"}
try {add-type -AssemblyName "Microsoft.SqlServer.Rmo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.Rmo"}

$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)

#######################
function Get-SqlConnection
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$sqlserver,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password
    )

    Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password)
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver,$username,$password }
    else
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $sqlserver }
	
    $con.Connect()

    Write-Output $con
    
} #Get-ServerConnection

#######################
<#
.SYNOPSIS
Gets a ReplServer.
.DESCRIPTION
The Get-ReplServer function  gets the ReplServer specified. This is the top level object for RMO.
.INPUTS
None
    You cannot pipe objects to Get-ReplServer
.OUTPUTS
Microsoft.SqlServer.Replication.ReplicationServer
    Get-ReplServer returns a Microsoft.SqlServer.Replication.ReplicationServer object.
.EXAMPLE
Get-ReplServer "Z002\sql2K8"
This command gets the ReplServer for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplServer "Z002\SQL2K8" sa Passw0rd
This command gets the ReplServer for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplServer
#>
function Get-ReplServer
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$replServer,
    [Parameter(Position=1, Mandatory=$false)] [string]$username, 
    [Parameter(Position=2, Mandatory=$false)] [string]$password
    )

    [Microsoft.SqlServer.Management.Common.ServerConnection]$con = Get-SqlConnection $replServer $username $password

    Write-Verbose "Get-ReplServer $($con.ServerInstance)"

    $repl = new-object ("Microsoft.SqlServer.Replication.ReplicationServer") $con

    Write-Output $repl

} #Get-ReplServer

#######################
function Get-ReplLightPublication
{
    #The following note appears in documentaton about this class "supports the SQL Server 2005 infrastructure and is not intended to be used directly
    #from your code. This is a bit a of problem as enumlightpublications() appears to be the only method to retrieve a list of publications from a
    #ReplicationServer. So this method will be used by Get-ReplPublication.
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )
    
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
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$name,
    [Parameter(Position=1, Mandatory=$true)] [string]$databaseName,
    [Parameter(Position=2, Mandatory=$true)] $connectionContext,
    [Parameter(Position=3, Mandatory=$false)] [switch]$createSnapshotAgent
    )

    Write-Verbose "New-ReplTransPublication $name"

    $pub = new-object ("Microsoft.SqlServer.Replication.TransPublication") $name,$databaseName,$connectionContext,$($createSnapshotAgent.IsPresent)

    Write-Output $pub

} #New-ReplTransPublication

#######################
function New-ReplMergePublication
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$name,
    [Parameter(Position=1, Mandatory=$true)] [string]$databaseName,
    [Parameter(Position=2, Mandatory=$true)] $connectionContext,
    [Parameter(Position=3, Mandatory=$false)] [switch]$createSnapshotAgent
    )

    Write-Verbose "New-ReplMergePublication $name"

    $pub = new-object ("Microsoft.SqlServer.Replication.MergePublication") $name,$databaseName,$connectionContext,$($createSnapshotAgent.IsPresent)

    Write-Output $pub

} #New-ReplMergePublication

#######################
<#
.SYNOPSIS
Gets a SubscriberSubscription.
.DESCRIPTION
The Get-ReplSubscriberSubscription function  gets the registiered subscribers of a subscrption on the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ReplicationServer object returned from Get-ReplServer.
.INPUTS
None
    You cannot pipe objects to Get-ReplSubscriberSubscription
.OUTPUTS
Microsoft.SqlServer.Replication.SubscriberSubscription
    Get-ReplSubscriberSubscription returns a Microsoft.SqlServer.Replication.SubscriberSubscription object.
.EXAMPLE
Get-ReplSubscriberSubscription "Z002\sql2K8"
This command gets the SubscriberSubscriptions for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplSubscriberSubscription $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd)
This command gets the SubscriberSubscriptions for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplSubscriberSubscription
Get-ReplServer
#>
function Get-ReplSubscriberSubscription
{
    #Note: This function is meant to be called on the subscriber. All other functions are called from the publisher/distributor
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )
        
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
<#
.SYNOPSIS
Gets a Publication.
.DESCRIPTION
The Get-ReplPublication function  gets the publications on the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ReplicationServer object returned from Get-ReplServer.
.INPUTS
None
    You cannot pipe objects to Get-ReplPublication
.OUTPUTS
Microsoft.SqlServer.Replication.TransPublication or Microsoft.SqlServer.Replication.MergePublication
    Depending on the publication type Get-ReplPublication returns either a Microsoft.SqlServer.Replication.TransPublication 
    or Microsoft.SqlServer.Replication.MergePublication object
.EXAMPLE
Get-ReplPublication "Z002\sql2K8"
This command gets the publications for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplPublication $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd)
This command gets the publications for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplPublication
Get-ReplServer
#>
function Get-ReplPublication
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )

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
<#
.SYNOPSIS
Gets a Subscription.
.DESCRIPTION
The Get-ReplSubscription function  gets the subscriptions from the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ReplicationServer object returned from Get-ReplServer.
.INPUTS
Microsoft.SqlServer.Replication.Publication
    You can pipe Publication objects to Get-ReplSubscription
.OUTPUTS
Microsoft.SqlServer.Replication.TransSubscription or Microsoft.SqlServer.Replication.MergeSubscription
    Depending on the publication type Get-ReplSubscription returns either a Microsoft.SqlServer.Replication.TransSubscription 
    or Microsoft.SqlServer.Replication.MergeSubscription object
.EXAMPLE
Get-ReplPublication "Z002\sql2K8" | Get-ReplSubscription
This command gets the subscriptions for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplPublication $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd) | Get-ReplSubscription
This command gets the subscriptions for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplSubscription
Get-ReplServer
#>
function Get-ReplSubscription
{
    #equivalent to executing sp_helpmergepublication or sp_helparticle
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] $pub
    )

    process
    {
        Write-Verbose "Get-ReplSubscription $($pub.Name)"
        switch ($pub.Type)
        {
            'Transactional' { $pub.TransSubscriptions } 
            'Merge'         { $pub.MergeSubscriptions }
            default { throw 'Get-ReplSubscription:Param `$pub must be a Publication object.' }
        }
    }
   
} #Get-ReplSubscription

#######################
<#
.SYNOPSIS
Gets an Article.
.DESCRIPTION
The Get-ReplArticle function  gets the Articles from the specified Publication. Equivalent to executing sp_helpmergepublication or sp_helparticle.
.INPUTS
Microsoft.SqlServer.Replication.Publication
    You can pipe Publication objects to Get-ReplArticle
.OUTPUTS
Microsoft.SqlServer.Replication.TransArticle or Microsoft.SqlServer.Replication.MergeArticle
    Depending on the publication type Get-ReplArticle returns either a Microsoft.SqlServer.Replication.TransArticle 
    or Microsoft.SqlServer.Replication.MergeArticle object
.EXAMPLE
Get-ReplPublication "Z002\sql2K8" | Get-ReplArticle
This command gets the Articles for all publications on SQL Server Z002\SQL2K8.
.LINK
Get-ReplArticle
Get-ReplPublication
#>
function Get-ReplArticle
{
    #equivalent to executing sp_helpmergepublication or sp_helparticle
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] $pub
    )

    process
    {
        Write-Verbose "Get-ReplArticle $($pub.Name)"
        switch ($pub.Type)
        {
            'Transactional' {$pub.TransArticles } 
            'Merge'         {$pub.MergeArticles }
            default { throw 'Get-ReplArticle:Param `$pub must be a Publication object.' }
        }
    }
   
} #Get-ReplArticle

#######################
<#
.SYNOPSIS
Gets a ReplicationMonitor.
.DESCRIPTION
The Get-ReplMonitor function  gets the ReplicationMonitor from the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ServerConnection object returned from Get-ReplServer.
.INPUTS
None
    You cannot pipe objects to Get-ReplMonitor
.OUTPUTS
Microsoft.SqlServer.Replication.ReplicationMonitor
    Get-ReplMonitor returns Microsoft.SqlServer.Replication.ReplicationMonitor object
.NOTES
There is a basic hierarchy with replication monitoring ReplicationServer => PublisherMonitor => PublicationMonitor. In addition to returning higher level replication information, this function is used by Get-ReplPublisherMonitor and Get-ReplPublicationMonitor.
.EXAMPLE
Get-ReplMonitor "Z002\sql2K8"
This command gets the ReplicationMonitor for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplMonitor $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd).ConnectionContext
This command gets the ReplicationMonitor for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplMonitor
Get-ReplServer
Get-ReplPublisherMonitor
Get-ReplPublicationMonitor
#>
function Get-ReplMonitor
{
    #There is a basic hierarchy with monitoring:
    #ReplicationServer => PublisherMonitor => PublicationMonitor
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )

    switch ($replServer.GetType().Name)
    {
        'String' { $con = Get-SqlConnection $replServer }
        'ServerConnection' { $con = $replServer }
        default { throw 'Get-ReplMonitor:Param `$replServer must be a String or ServerConnection object.' }
    }

    Write-Verbose "Get-ReplMonitor $($con.ServerInstance)"
    
    $replMon = new-object ("Microsoft.SqlServer.Replication.ReplicationMonitor") $con

    Write-Output $replMon


} #Get-ReplMonitor

#######################
<#
.SYNOPSIS
Gets a PublisherMonitor.
.DESCRIPTION
The Get-ReplPublisherMonitor function  gets the PublisherMonitor from the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ServerConnection object returned from Get-ReplServer.
.INPUTS
None
    You cannot pipe objects to Get-ReplPublisherMonitor
.OUTPUTS
Microsoft.SqlServer.Replication.PublisherMonitor
    Get-ReplPublisherMonitor returns Microsoft.SqlServer.Replication.PublisherMonitor object
.NOTES
There is a basic hierarchy with replication monitoring ReplicationServer => PublisherMonitor => PublicationMonitor.
.EXAMPLE
Get-ReplPublisherMonitor "Z002\sql2K8"
This command gets the PublisherMonitor for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplPublisherMonitor $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd).ConnectionContext
This command gets the PublisherMonitor for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplPublisherMonitor
Get-ReplServer
Get-ReplMonitor
#>
function Get-ReplPublisherMonitor
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )

    Write-Verbose "Get-ReplPublisherMonitor"

    $replMon =  Get-ReplMonitor $replServer

    Write-Output $replMon.PublisherMonitors

} #Get-ReplPublisherMonitor

#######################
<#
.SYNOPSIS
Gets a PublicationMonitor.
.DESCRIPTION
The Get-ReplPublicationMonitor function  gets the PublicationMonitor from the specified ReplServer.
.PARAMETER replServer
ReplServer can be a string representing the server or a ServerConnection object returned from Get-ReplServer.
.INPUTS
None
    You cannot pipe objects to Get-ReplPublicationMonitor
.OUTPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
    Get-ReplPublicationMonitor returns Microsoft.SqlServer.Replication.PublicationMonitor object
.NOTES
There is a basic hierarchy with replication monitoring ReplicationServer => PublicationMonitor => PublicationMonitor.
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8"
This command gets the PublicationMonitor for SQL Server Z002\SQL2K8.
.EXAMPLE
Get-ReplPublicationMonitor $(Get-ReplServer "Z002\SQL2K8" sa Passw0rd).ConnectionContext
This command gets the PublicationMonitor for SQL Server Z002\SQL2K8 using SQL authentication.
.LINK
Get-ReplPublicationMonitor
Get-ReplServer
Get-ReplPublisherMonitor
Get-ReplMonitor
#>
function Get-ReplPublicationMonitor
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $replServer
    )

    Write-Verbose "Get-ReplPublicationMonitor"
    
    $publisherMon = Get-ReplPublisherMonitor $replServer

    Write-Output $publisherMon.PublicationMonitors

} #Get-ReplPublicationMonitor

#######################
<#
.SYNOPSIS
Calls the EnumPublications method on a PublisherMonitor object.
.DESCRIPTION
The Get-ReplEnumPublications function calls the EnumPublications method for the specified PublisherMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublisherMonitor
     You can pipe PublisherMonitor objects to Get-ReplEnumPublications
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumPublications returns an array of System.Data.DataRow objects
.EXAMPLE
Get-ReplPublisherMonitor "Z002\sql2K8" | Get-ReplEnumPublications
This command calls the EnumPublications method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumPublications
Get-ReplPublisherMonitor
#>
function Get-ReplEnumPublications
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublisherMonitor]$publisherMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumPublications $($publisherMon.Name) "
        $publisherMon.EnumPublications() | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumPublications

#######################
<#
.SYNOPSIS
Calls the EnumPublications2 method on a PublisherMonitor object.
.DESCRIPTION
The Get-ReplEnumPublications2 function calls the EnumPublications2 method for the specified PublisherMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublisherMonitor
   You can pipe PublisherMonitor objects to Get-ReplEnumPublications2
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumPublications2 returns an array of System.Data.DataRow objects
.NOTES
Equivalent to executing sp_replmonitorhelppublication. Only available for Microsoft SQL Server version 2005 or later.
.EXAMPLE
Get-ReplPublisherMonitor "Z002\sql2K8" | Get-ReplEnumPublications2
This command calls the EnumPublications2 method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumPublications2
Get-ReplPublisherMonitor
#>
function Get-ReplEnumPublications2
{
    #equivalent to executing sp_replmonitorhelppublication
    #Only available for Microsoft SQL Server version 2005 or later
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublisherMonitor]$publisherMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumPublications $($publisherMon.Name) "
        $publisherMon.EnumPublications2() | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumPublications2

#######################
<#
.SYNOPSIS
Calls the EnumSubscriptions method on a PublicationMonitor object.
.DESCRIPTION
The Get-ReplEnumSubscriptions function calls the EnumSubscriptions method for the specified PublicationMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
    You can pipe PublicationMonitor objects to Get-ReplEnumSubscriptions
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumSubscriptions returns an array of System.Data.DataRow objects
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8" | Get-ReplEnumSubscriptions
This command calls the EnumSubscriptions method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumSubscriptions
Get-ReplPublicationMonitor
#>
function Get-ReplEnumSubscriptions
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublicationMonitor]$pubMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumSubscriptions $($pubMon.Name)" 
        $pubMon.EnumSubscriptions() | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumSubscriptions

#######################
<#
.SYNOPSIS
Calls the EnumSubscriptions2 method on a PublicationMonitor object.
.DESCRIPTION
The Get-ReplEnumSubscriptions2 function calls the EnumSubscriptions2 method for the specified PublicationMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
   You can pipe PublicationMonitor objects to Get-ReplEnumSubscriptions2
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumSubscriptions2 returns an array of System.Data.DataRow objects
.NOTES
Equivalent to executing sp_replmonitorhelpSubscription. Only available for Microsoft SQL Server version 2005 or later.
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8" | Get-ReplEnumSubscriptions2
This command calls the EnumSubscriptions2 method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumSubscriptions2
Get-ReplPublicationMonitor
#>
function Get-ReplEnumSubscriptions2
{
    #equivalent to executing sp_replmonitorhelpSubscription
    #Only available for Microsoft SQL Server version 2005 or later
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublicationMonitor]$pubMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumSubscriptions2 $($pubMon.Name)" 
        $pubMon.EnumSubscriptions2(0) | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumSubscriptions2

#######################
<#
.SYNOPSIS
Calls the TransPendingCommandInfo method for all subscriptions.
.DESCRIPTION
The Get-ReplTransPendingCommandInfo function calls the TransPendingCommandInfo method for all subscriptions.
.INPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
    You can pipe PublicationMonitor objects to Get-ReplTransPendingCommandInfo
.OUTPUTS
Microsoft.SqlServer.Replication.PendingCommandInfo
    Get-ReplPublicationMonitor returns Microsoft.SqlServer.Replication.PendingCommandInfo object
.NOTES
Equivalent to executing sp_replmonitorsubscriptionpendingcmds. Only available for Microsoft SQL Server version 2005 or later.
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8" | Get-ReplTransPendingCommandInfo
This command calls the TransPendingCommandInfo method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplTransPendingCommandInfo
Get-ReplPublicationMonitor
#>
function Get-ReplTransPendingCommandInfo
{
    #equivalent to executing sp_replmonitorsubscriptionpendingcmds
    #Only available for Microsoft SQL Server version 2005 or later
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublicationMonitor]$pubMon
    )

    process
    {
        Write-Verbose "Get-ReplTransPendingCommandInfo $($pubMon_.Name)" 
        $pubMon | Get-ReplEnumSubscriptions |  foreach { $pubMon.TransPendingCommandInfo($_.subscriber, $_.subscriber_db, $_.type) }

    }

} #Get-ReplTransPendingCommandInfo

#######################
<#
.SYNOPSIS
Calls the EnumLogReaderReader method on a PublicationMonitor object.
.DESCRIPTION
The Get-ReplEnumLogReaderAgent function calls the EnumLogReaderReader method for the specified PublicationMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
    You can pipe PublicationMonitor objects to Get-ReplEnumLogReaderAgent
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumLogReaderAgent returns an array of System.Data.DataRow objects
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8" | Get-ReplEnumLogReaderAgent
This command calls the EnumLogReaderAgent method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumLogReaderAgent
Get-ReplPublicationMonitor
#>
function Get-ReplEnumLogReaderAgent
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublicationMonitor]$pubMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumLogReaderAgent $($pubMon.Name)" 
        $pubMon.EnumLogReaderAgent() | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumLogReaderAgent

#######################
<#
.SYNOPSIS
Calls the EnumSnapshotAgent method on a PublicationMonitor object.
.DESCRIPTION
The Get-ReplEnumSnapshotAgent function calls the EnumLogReaderReader method for the specified PublicationMonitor object.
.INPUTS
Microsoft.SqlServer.Replication.PublicationMonitor
    You can pipe PublicationMonitor objects to Get-ReplEnumSnapshotAgent
.OUTPUTS
System.Data.DataRow
    Get-ReplEnumSnapshotAgent returns an array of System.Data.DataRow objects
.EXAMPLE
Get-ReplPublicationMonitor "Z002\sql2K8" | Get-ReplEnumSnapshotAgent
This command calls the EnumSnapshotAgent method for SQL Server Z002\SQL2K8.
.LINK
Get-ReplEnumSnapshotAgent
Get-ReplPublicationMonitor
#>
function Get-ReplEnumSnapshotAgent
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [Microsoft.SqlServer.Replication.PublicationMonitor]$pubMon
    )

    process
    {
        Write-Verbose "Get-ReplEnumSnapshotAgent $($pubMon.Name)" 
        $pubMon.EnumSnapshotAgent() | foreach { $_.Tables} | foreach { $_.Rows }
    }

} #Get-Get-ReplEnumSnapshotAgent

#######################
<#
.SYNOPSIS
Creates an instance of a RMO ScriptOptions object used for scripting RMO objects. 
.DESCRIPTION
The New-ReplScriptOptions function creates an instance of a custom RMO ScriptOptions object used for scripting RMO objects by the Get-ReplScript function.
.INPUTS
None
    You cannot pipe objects to New-ReplScriptOptions
.OUTPUTS
    System.int64
    New-ReplScriptOptions returns an System.int64 object.
.NOTES
Unlike SMO which has default script options, RMO at at a minimum requires CREATION be specified. The CREATION property is set to default to true.
The RMO implementation of scripting uses an enum with flagsattribute set to combine multiple options. In order to make RMO scripting options
discoverable and easier to use a custom object with all available RMO script options as properties is created. For any property set to true the
function will perform a bitwise operation that can then be use by an RMO script method.
There are 35 settable scripting options at the time of this writing, see link below for detailed explanation of each option.
.EXAMPLE
$scriptOpts = New-ReplScriptOptions; $scriptOpts.Deletion = $true; Get-ReplServer "Z002\sql2K8" | Get-replscript -scriptOpts $scriptOpts
This command creates an RMO Scriptoptions object, sets the Deletion property to true and finally calls Get-replscript passing the script options.
.LINK
New-ReplScriptOptions
Get-ReplScript
http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.replication.scriptoptions(SQL.90).aspx
#>
function New-ReplScriptOptions
{
    Write-Verbose "New-ReplScriptOptions"

    #There 35 settable scripting options at the time of this writing, rather than set the options as parameters
    #I've choosen to set them through a separate file. Modify the passed in file to set
    #the various scriptingOptions to your liking. See the following MSDN link for a description of the settable options:
    #http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.replication.scriptoptions(SQL.90).aspx
    #NOTE: UNLIKE SMO SCRIPTER CLASS, YOU MUST SET THE SCRIPTING OPTIONS IN RMO TO AT LEAST CREATION

    new-object PSObject -property (&"$scriptRoot\replscriptopts.ps1") | add-member scriptproperty ScriptOptions `
    {
    $scriptOptions = [Microsoft.SqlServer.Replication.ScriptOptions]::None
    $this | get-member -type NoteProperty | where {$this.($_.name)} | 
                foreach {$scriptOptions = $scriptOptions -bor [Microsoft.SqlServer.Replication.ScriptOptions]::($_.name)}
    $scriptOptions
    } -passthru 
    
} #New-ReplScriptOptions

#######################
<#
.SYNOPSIS
Calls Script Method on RMO objects including ReplicationServer, Publication, Subscription and Articles.
.DESCRIPTION
The Get-ReplScript function calls the Script Method for RMO object that support the method including ReplicationServer, Publication, Subscription and Articles.
.INPUTS
Microsoft.SqlServer.Replication.*
    You can pipe rmo objects to Get-ReplScript that support the Script method
.OUTPUTS
    System.String
    Get-ReplScript returns an array of System.String objects
.NOTES
Validation that the object piped is in the namespace Microsoft.SqlServer.Replication is performed.
.EXAMPLE
Get-ReplServer "Z002\sql2K8" | Get-replscript
This command scripts out the replication server settings for SQL Server Z002\sql2K8.
.EXAMPLE
$scriptOpts = New-ReplScriptOptions; $scriptOpts.Deletion = $true; Get-ReplServer "Z002\sql2K8" | Get-replscript -scriptOpts $scriptOpts
This command creates an RMO Scriptoptions object, sets the Deletion property to true and finally calls Get-replscript passing the script options.
.EXAMPLE
Get-ReplPublication 'Z002\Sql2k8' | Get-ReplScript
This command scripts out the publications for SQL Server Z002\sql2K8.
.EXAMPLE
Get-ReplPublication 'Z002\Sql2k8' | Get-ReplSubscription | Get-ReplScript
This command scripts out the subscriptions for SQL Server Z002\sql2K8.
.EXAMPLE
Get-ReplPublication 'Z002\Sql2k8' | Get-ReplArticle | Get-ReplScript
This command scripts out the articles for SQL Server Z002\sql2K8.
.LINK
Get-ReplScript
New-ReplScriptOptions
#>
function Get-ReplScript
{
    param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [ValidateScript({$_.GetType().Namespace -like "Microsoft.SqlServer.Replication*"})] $rmo,
    [Parameter(Position=1, Mandatory=$false)] $scriptOpts=$(New-ReplScriptOptions).ScriptOptions
    )
    process
    { 
        $rmo.Script($scriptOpts)
    }

} #Get-ReplScript
