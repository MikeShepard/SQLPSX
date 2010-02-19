Getting Started with SQLPSX
** NOTE: You must have SMO installed to run the SQLPSX, SMO is installed with SQL Server Management Studio ***
** Powershell 2.0 is required **
1. Copy all Modules to $env:psmodulepath directory and Script files to any directory. 
2. Run import-module 
    import-module SQLServer
    import-module Agent
    import-module Repl
    import-module SSIS
    import-module SQLParser
    import-module Showmbrs
    import-module adolib
    import-module sqlmaint
3. Add import-module commands to your Profile if desired

Optional Database and Reporting Services Components
4. Create a database, for example SQLPSX and run the SQLPSX.AllObject.sql script to create the all database objects
5. Modify SSRS Data Source file SQLPSX.rds to point to the newly created database
6. Deploy the SSRS reports and Data Source files to a SSRS Server or run locally
7. Modify Run-SmoToCsvFile.ps1, Write-SmoCsvToDb.ps1 and Write-SmoToCsvFile.ps1 scripts with your parameters
8. Insert the SQL Server instances you wish to report into the SqlServer table
9. Run Run-SmoToCsvFile.ps1 to create csv files of all available security information
10. Run Write-SmoToCsvFile.ps1 to import the csv file into the database

What's New
    Version 2.02
        Added SQLMaint module.
        Removed Invoke-DbMaintBackup script (replaced by SQLMaint module)
    Version 2.01
        Modified Get-SqlDatabase function to return system databases when -force parameter is used.
        Added Invoke-DbMaintBackup to scripts
    Version 2.0
        Converted function libraries and snapins to modules
        Created comment-based help for all functions
        Made helper functions private through use of module manifests (psd1 files)
        Converted functions to advanced functions with parameter bindings
        Refactored code to use Powershell V2 features:
            try/catch
            valuefrompipeline
            validatescript
            validateset
            new-object -property hashtable
            add-type
        Renamed Set-SqlScriptingOptions to New-SqlScriptingOptions
        Renamed Get-ReplScriptOptions to New-ReplScriptOptions
        Removed scriptopts and replscriptopts text files in favor of script option objects
        Moved Get-InvalidLogins.ps1 and Get-SessionTimeStamp.ps1 into SQLServer module
        Removed Init-SqlParser.ps1 script (not needed since SQLParser is now a module)
        Added new ADO.NET module
        Added format file for SSIS packages
        More rigorous testing was performed using PSUnit testing framework
        Fixed issues discovered in testing
        Added 5 aliases for Information_Schema and sysdatabases functions. These functions were renamed with a Get-Sql* prefix
        All parameters are strongly typed where possible
                        
    Version 1.6
        Get-SqlConnection
        Maintenane Release
        +Added support for SQL authentication
        +Add better error handling using technique described in post by Allen White:
            http://sqlblog.com/blogs/allen_white/archive/2009/06/08/handling-errors-in-powershell.aspx
        +Changed all boolean value parameters to switch data type
        +Added SMOVersion global variable
        +Fixed issue with CopyOnly backups
        +Fixed issue with role names containing the word public
        +Fixed issue with Invoke-SqlRestore and relocatefiles param
        +Updated SqlParser cmdlets to VSDB R2
    Version 1.5
        Invoke-SqlBackup (Database,Log) Invoke-SqlRestore (Database, Log) Invoke-SqlDatabaseCheck Invoke-SqlIndexRebuild Get-SqlIndexFragmentation
        Invoke-SqlIndexDefrag Update-SqlStatistic Add-SqlDatabase Remove-SqlDatabase Add-SqlFileGroup Add-SqlDataFile Add-SqlLogFile Get-SqlDefaultDir
        Add-SqlUser Remove-SqlUser Add-SqlLogin Remove-SqlLogin Add-SqlServerRoleMember Remove-SqlServerRoleMember Add-SqlDatabaseRole
        Remove-SqlDatabaseRole Add-SqlDatabaseRoleMember Remove-SqlDatabaseRolemember Set-SqlServerPermission (GRANT, REVOKE, DENY)
        Set-SqlDatabasePermission (GRANT, REVOKE, DENY) Set-SqlObjectPermission (GRANT, REVOKE, DENY) Get-SqlErrorLog Get-SqlSchema Get-SqlProcess
        Get-SqlTransaction Get-SqlEdition Test-SqlScript Out-SqlScript
    Version 1.4
        Added the following functions:
        Copy-ISItemSQLToSQL Copy-ISItemSQLToFile Copy-ISItemFileToSQL Get-ISData Get-ISItem Get-ISPackage Get-ISRunningPackage Get-ISSqlConfigurationItem
        New-ISApplication New-ISItem Remove-ISItem Rename-ISItem Set-ISConnectionString Set-ISPackage Test-ISPath
    Version 1.3
        Added the following functions:
        Get-SqlConnection Get-ReplServer Get-ReplLightPublication New-ReplTransPublication New-ReplMergePublication Get-ReplSubscriberSubscription
        Get-ReplPublication Get-ReplSubscription Get-ReplArticle Get-ReplMonitor Get-ReplPublisherMonitor Get-ReplPublicationMonitor
        Get-ReplEnumPublications Get-ReplEnumPublications2 Get-ReplEnumSubscriptions Get-ReplEnumSubscriptions2 Get-ReplTransPendingCommandInfo
        Get-ReplEnumLogReaderAgent Get-ReplEnumSnapshotAgent Set-ReplScriptOptions Get-ReplScript
    Version 1.2
        Added the following functions:
        Get-AgentJobServer  Get-AgentAlertCategory  Get-AgentAlert  Get-AgentJob  Get-AgentJobSchedule  Get-AgentJobStep  Get-AgentOperator
        Get-AgentOperatorCategory  Get-AgentProxyAccount  Get-AgentSchedule  Get-AgentTargetServerGroup  Get-AgentTargetServer  Get-AgentJobHistory
    Version 1.1
        Added the following functions:
        Get-SqlTable Get-SqlStoredProcedure Get-SqlView Get-SqlUserDefinedDataType Get-SqlUserDefinedFunction Get-SqlSynonym Get-SqlTrigger Get-SqlColumn
        Get-SqlIndex Get-SqlStatistic Get-SqlCheck Get-SqlForeignKey Set-SqlScriptingOptions Get-SqlScripter Get-Information_Schema.Tables
        Get-Information_Schema.Columns Get-Information_Schema.Views Get-Information_Schema.Routines Get-SysDatabases Get-SqlDataFile Get-SqlLogFile
        Get-SqlVersion Get-SqlPort ConvertTo-ExtendedPropertyXML Get-Sql ConvertTo-StatisticColumnXML ConvertTo-IndexedColumnXML

Modules
    SQLMaint Module functions
        Invoke-DbMaint
            Implements full database maintenance including backups, index maintenance, statistics, and backup cleanup. 
            Equivalent to Database Maintenance Wizard
    AdoLib Module functions
        New-Connection
            Create a SQLConnection object with the given parameters
        Invoke-Sql
            Execute a sql statement, ignoring the result set. Returns the number of rows modified by the statement (or -1 if it was not a DML staement
        Invoke-Query
            Execute a sql statement, returning the results of the query
        Invoke-StoredProcedure
            Execute a stored procedure, returning the results of the query
    SqlParser Module cmdlets
        Test-SqlScript
            Determines whether a SQL script is valid.
        Out-SqlScript
            Sends out to the host as a SQL script.
    SQLServer Module functions
        Get-SqlServer
            Returns a Microsoft.SqlServer.Management.Smo.Server Object
        Get-SqlDatabase
            Returns an SMO Database object or collection of Database objects
        Get-SqlData
            Executes a query returns an array of System.Data.DataRow
        Set-SqlData
            Executes a query that does not return a result set
        Get-SqlShowMbrs
            Recursively enumerates AD/local groups handling built-in SQL Server Windows groups
        Get-SqlUser
            Returns a SMO User object with additional properties including all of the objects owned by the user
            and the effective members of the user. Recursively enumerates nested AD/local groups
        Get-SqlDatabaseRole
            Returns a SMO DatabaseRole object with additional properties including the effective members of a
            role recursively enumerates nested roles, and users
        Get-SqlLogin
            Returns a SMO Login object with additional properties including the effective members of the login
        Get-SqlLinkedServerLogin
            Returns a SMO LinkedServerLogin object with additional properties including LinkedServer and DataSource
        Get-SqlServerRole
            Returns a SMO ServerRole object with additional properties including the effective members of a role.
            Recursively enumerates nested AD/local groups
        Get-SqlServerPermission
            Returns a SMO ServerPermission object with additional properties including the effective members of a
            grantee. Recursively enumeates nested roles and logins
        Get-SqlDatabasePermission
            Returns a SMO DatabasePermission object with additional properites including the effective members of a
            grantee. Recursively enumerates nested roles and users
        Get-SqlObjectPermission
            Returns a SMO ObjectPermission object with additional properties including the effective members of a
            grantee. Recursively enumerates nested roles and users
        Get-SqlTable
            Returns a SMO Table object with additional properties
        Get-SqlStoredProcedure
            Returns a SMO StoredProcedure object with additional properties
        Get-SqlView
            Returns a SMO View object with additional properties
        Get-SqlUserDefinedDataType
            Returns a SMO UserDefinedDataType object with additional properites
        Get-SqlUserDefinedFunction
            Returns a SMO UserDefinedFunction object with additional properites
        Get-SqlSynonym
            Returns a SMO Synonym object with additional properites
        Get-SqlTrigger
            Returns a SMO Trigger object with additional properites. Note: A Trigger can have a Server, Database or Table/View parent object.
        Get-SqlColumn
            Returns a SMO Column object with additional properites. Note: A Column can have either a Table or View parent object.
        Get-SqlIndex
            Returns a SMO Index object with additional properites. Note: An Index can have either a Table or View parent object.
        Get-SqlStatistic
            Returns a SMO Statistic object with additional properites
        Get-SqlCheck
            Returns a SMO Check object with additional properites. Note: A Check can have either a Table or View parent object.
        Get-SqlForeignKey
            Returns a SMO ForeignKey object with additional properites
        New-SqlScriptingOptions
            Sets scripting option used in Get-SqlScripter function by reading in the text file scriptopts.txt
        Get-SqlScripter
            Returns a SMO Scripter object. Any function which returns a SMO object can pipe to Get-SqlScripter. For example to script out all table
            in the pubs database: Get-SqlDatabase MyServer | Get-SqlTable | Get-SqlScripter
        Get-SqlInformation_Schema.Tables
            Returns the result set from INFORMATION_SCHEMA.Tables for the specified database(s) along with the Server name
        Get-SqlInformation_Schema.Columns
            Returns the result set from INFORMATION_SCHEMA.Columns for the specified database(s) along with the Server name
        Get-SqlInformation_Schema.Views
            Returns the result set from INFORMATION_SCHEMA.Views for the specified database(s) along with the Server name
        Get-SqlInformation_Schema.Routines
            Returns the result set from INFORMATION_SCHEMA.Routines for the specified database(s) along with the Server name
        Get-SqlSysDatabases
            Returns the result set from sysdatases for the specified server along with the Server name
        Get-SqlDataFile
            Returns a SMO DataFile object with additional properties
        Get-SqlLogFile
            Returns a SMO LogFile object with additional properties
        Get-SqlVersion
            Returns a custom object with the Server name and version number
        Get-SqlPort
            Uses SQL-DMO to return the port number of the specified SQL Server
        Get-Sql
            Uses WMI to list all of the SQL Server related services running on the specified computer along with the service state and service account
        Invoke-SqlBackup (Database,Log)
            Performs a SQL Backup
        Invoke-SqlRestore (Database, Log)
            Performs a SQL Restore
        Invoke-SqlDatabaseCheck
            Performs the equivalent of a DBCC CHECKDB
        Invoke-SqlIndexRebuild
            Performs a reindex 
        Get-SqlIndexFragmentation
            Returns index fragmentation similar to DBCC SHOWCONTIG
        Invoke-SqlIndexDefrag
            Defragments an index. Performs the equivalent of a DBCC INDEXDEFRAG
        Update-SqlStatistic
            Updates statistics
        Add-SqlDatabase
            Adds a new database to a SQL Server
        Remove-SqlDatabase
            Removes a database from a SQL Server
        Add-SqlFileGroup
            Adds a new filegroup to a database
        Add-SqlDataFile
            Adds a new datafile to a filegroup
        Add-SqlLogFile
            Adds a new logfile to a database
        Get-SqlDefaultDir
           Returns the default location for data and log files for a SQL Server 
        Add-SqlUser
            Adds a new user to a database
        Remove-SqlUser
            Removes a user from a database
        Add-SqlLogin
            Adds a login to a SQL Server
        Remove-SqlLogin
            Removes a login from a SQL Server
        Add-SqlServerRoleMember
            Adds a login to a server role
        Remove-SqlServerRoleMember
            Removes a login from a server role
        Add-SqlDatabaseRole
            Adds a new database role to a database
        Remove-SqlDatabaseRole
            Removes a database roel from a database
        Add-SqlDatabaseRoleMember
            Adds a user or role to a database role
        Remove-SqlDatabaseRolemember
            Removes a user or role from a database role
        Set-SqlServerPermission (GRANT, REVOKE, DENY)
            Sets server level permissions to a login
        Set-SqlDatabasePermission (GRANT, REVOKE, DENY)
            Sets database level permissiosn to a user or role
        Set-SqlObjectPermission (GRANT, REVOKE, DENY)
            Sets database object level permissions to a user or role
        Get-SqlErrorLog
            Returns the SQL Server Errorlog
        Get-SqlSchema
            Returns a SMO Schema object with additional properties
        Get-SqlProcess
            Returns the current proccesses on a SQL Server. Equivalent to sp_who
        Get-SqlTransaction
            Returns the current open transactions for a database
        Get-SqlEdition
            Returns the SQL Server edition
    Agent Module functions
        Get-AgentJobServer
            Returns a Microsoft.SqlServer.Management.Smo.Agent.JobServer Object. This is the top level object for Agent.Smo
        Get-AgentAlertCategory
            Returns an SMO.Agent AlertCategory object or collection of AlertCategory objects
        Get-AgentAlert
            Returns an SMO.Agent Alert object or collection of Alert objects
        Get-AgentJob
            Returns an SMO.Agent Job object or collection of Job objects
        Get-AgentJobSchedule
            Returns an SMO.Agent JobSchedule object or collection of JobSchedule objects for Job Objects
        Get-AgentJobStep
            Returns an SMO.Agent JobStep object or collection of JobStep objects
        Get-AgentOperator
            Returns an SMO.Agent Operator object or collection of Operator objects
        Get-AgentOperatorCategory
            Returns an SMO.Agent OperatorCategory object or collection of OperatorCategory objects
        Get-AgentProxyAccount
            Returns an SMO.Agent ProxyAccount object or collection of ProxyAccount objects
        Get-AgentSchedule
            Returns an SMO.Agent JobSchedule object or collection of JobSchedule objects for JobServer Shared Schedules
        Get-AgentTargetServerGroup
            Returns an SMO.Agent TargetServerGroup object or collection of TargetServerGroup objects
        Get-AgentTargetServer
            Returns an SMO.Agent TargetServer object or collection of TargetServer objects
        Set-AgentJobHistoryFilter
            Sets filtering option used in Get-AgentJobHistory function
        Get-AgentJobHistory
            Returns an array of System.Data.DataRow of job history, filtering can be applied by using the Set-AgentJobHistoryFilter function
    Repl Module functions
        Get-SqlConnection
            Returns a ServerConnection object
        Get-ReplServer
            Returns an RMO.ReplicationServer
        Get-ReplLightPublication
            Returns an RMO.LightPublication
        New-ReplTransPublication
            Constructor for RMO.TransPublication
        New-ReplMergePublication
            Constructor for RMO.MergePublication
        Get-ReplSubscriberSubscription
            Returns an RMO.SubscriberSubscription. Note: this is the only function executed on a subscriber
        Get-ReplPublication
            Returns either an RMO.TransPublication or RMO.MergePublication object
        Get-ReplSubscription
            Returns an RMO.TransSubscription or RMO.MergeSubscription object from a Publication
        Get-ReplArticle
            Returns an RMO.TransArticle or RMO.MergeArticle object from a Publication
        Get-ReplMonitor
            Returns an RMO.ReplicationMonitor
        Get-ReplPublisherMonitor
            Returns an RMO.PublisherMonitor
        Get-ReplPublicationMonitor
            Returns an RMO.PublicationMonitor
        Get-ReplEnumPublications
            Calls the EnumPublications method on a PublisherMonitor object
        Get-ReplEnumPublications2
            Calls the EnumPublications method on a PublisherMonitor object
        Get-ReplEnumSubscriptions
            Calls the EnumSubscriptions method on a PublicationMonitor object
        Get-ReplEnumSubscriptions2
            Calls the EnumSubscriptions2 method on a PublicationMonitor object
        Get-ReplTransPendingCommandInfo
            Calls the TransPendingCommandInfo method on a PublicationMonitor object
        Get-ReplEnumLogReaderAgent
            Calls the EnumLogReaderReader method on a PublicationMonitor object
        Get-ReplEnumSnapshotAgent
            Calls the EnumSnapshotAgent method on a PublicationMonitor object
        New-ReplScriptOptions
            Sets the Enum ScriptOptions for scripting RMO objects. Unlike SMO which has a default script options
            RMO at at a minimum CREATION enum must be specified.
        Get-ReplScript
            Calls Script Method on RMO objects include ReplicationServer, Publication, Subscription and Articles
    SSIS Module functions:
        Copy-ISItemSQLToSQL
            Copies a Package or SSIS folder from SQL to SQL
        Copy-ISItemSQLToFile
            Copies a Package or SSIS folder from SQL to file
        Copy-ISItemFileToSQL
            Copies a Package or SSIS folder from file to SQL
        Get-ISData
            Executes a query and returns an array of System.Data.DataRow
        Get-ISItem
            Retrieves a list of SQL Server Integration Services folders and packages from the specified SQL Server instance. Returns a PackInfo Object.
            Note: Unlike the other SSIS functions this function requires a SQL instance name i.e. serverName\instanceName
        Get-ISPackage
            Retrieves an SSIS package from the specified Integration Services server or file path. Returns a Package Object
        Get-ISRunningPackage
            Returns a list of running packages on the specified Integration Services server. Returns a RunningPackage object or collection of objects
        Get-ISSqlConfigurationItem
            Executes a query to retrieve a configuration item
        New-ISApplication
            Base object for all other functions. Executes new-object ("Microsoft.SqlServer.Dts.Runtime.Application") 
        New-ISItem
            Creates a SQL storage folder for the specified Integration Services server
        Remove-ISItem
            Deletes a SQL storage folder or package on the specified Integration Services server
        Rename-ISItem
            Renames a SQL storage folder or package on the specified Integration Services server
        Set-ISConnectionString
            Sets the Connection string for an SSIS package. Useful for package configuration connection string which cannot be set dynamically at run 
            or deploy time
        Set-ISPackage
            Saves an SSIS package to an Integration Services server or file path as a dtsx file.
        Test-ISPath
            Test the existance of a SQL storage folder or package on the specified Integration Services server
    LibraryShowmbrs.ps1 functions
        Get-ShowMbrs
            Recursivley enumerates local Windows and AD groups similar to the NT Resource utility showmbrs.exe

Scripts
    Get-InvalidLogins.ps1
        Lists invalid AD/NT logins/groups which have been granted access to the
        specified SQL Server instance. Script calls the system stored procedure
        sp_validatelogins and validates the output by attempting to resolve the sid
        against AD. The second level of validation is done because sp_validatelogins
        incorrectly reports logins/groups which have been renamed in AD. SQL Server
        stores the AD sid so renamed accounts still have access to the instance.
        Renamed logins/groups are listed with the renamed value in the newAccount
        property.
    Get-SessionTimeStamp.ps1
        Creates a global session timestamp
    Run-SmoToCsvFile.ps1
        Runs Write-SmoToCsvFile.ps1 with the specified number of threads.
    Test-SqlConn.ps1
        Verifies Sql connectivity and writes successful connection to stdout and
        failed connections to stderr. Script is useful when combined with other
        scripts which would otherwise produce a terminating error on connectivity
    Write-SmoCsvToDb.ps1
        Load the SMO Csv file into the specified database
    Write-SmoToCsvFile.ps1
        Generates an a csv file for all SQL Server security settings
    Invoke-DbMaintBackup.ps1
        Backs up all user, system or both user and system database, logs, or files. Includes logging and cleanup routines. See get-help 
        invoke-DbMaintBackup.ps1 for details.
    formatsql.bat
        Simple bat file for calling powershell.exe with the command set to out-sqlscript

SQL Server Reporting Services (2008) reports
    See the screenshots_sqlpsx.docx for sample output of reports

    SQLPSXChangedDatabasePermission.rdl
    SQLPSXChangedDatabaseRole.rdl
    SQLPSXChangedLogin.rdl
    SQLPSXChangedObjectPermission.rdl
    SQLPSXChangedServerPermission.rdl
    SQLPSXChangedServerRole.rdl
    SQLPSXChangedSqlUser.rdl
    SQLPSXChangedSqlUserOwnedObject.rdl
    SQLPSXDatabasePermission.rdl
    SQLPSXDatabaseRole.rdl
    SQLPSXLinkedServerLogin.rdl
    SQLPSXLogin.rdl
    SQLPSXLoginGrouped.rdl
    SQLPSXObjectPermission.rdl
    SQLPSXServerPermission.rdl
    SQLPSXServerRole.rdl
    SQLPSXSqlUser.rdl
    SQLPSXSqlUserGrouped.rdl
    SQLPSXSqlUserOwnedObject.rdl

Global Variables
    The following global session variables are used to cache information used across functions

    $__SQLPSXUserMember
    $__SQLPSXDatabaseRoleMember
    $__SQLPSXLoginMember
    $__SQLPSXGroupUser
    $__SQLPSXIsDomain
    $__SQLPSXInvalidLogin
    $__SQLPSXSessionTimeStamp

SQLPSX Database
    SQLPSX.AllObject.sql
        Single script for all database objects
    SQLPSX.Job.sql
        SQL Agent job to schedule running of Run-SmoToCsvFile.ps1 and importing into database using Write-SmoCsvToDb.ps1
