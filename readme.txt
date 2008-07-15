Getting Started with SQLPSX
** NOTE: You must have SMO installed to run the SQLPSX, SMO is installed with SQL Server Management Studio ***
1. Copy all Library and Script files to the same directory. Add sourcing of LibrarySmo.ps1 to
   your Profile if desired

Optional Database and Reporting Services Components
2. Create a database, for example SQLPSX and run the SQLPSX.AllObject.sql script to create the all database objects
3. Modify SSRS Data Source file SQLPSX.rds to point to the newly created database
4. Deploy the SSRS reports and Data Source files to a SSRS Server or run locally
5. Modify Run-SmoToCsvFile.ps1, Write-SmoCsvToDb.ps1 and Write-SmoToCsvFile.ps1 scripts with your parameters
6. Insert the SQL Server instances you wish to report into the SqlServer table
7. Run Run-SmoToCsvFile.ps1 to create csv files of all available security information
8. Run Write-SmoToCsvFile.ps1 to import the csv file into the database

Libraries
    LibrarySmo.ps1 functions
        Get-SqlServer 
            Returns a Microsoft.SqlServer.Management.Smo.Server Object
        Get-SqlDatabase
            Returns an SMO Database object or collection of Database objects
        Get-SqlData
            Executes a query returns an ADO.NET DataTable
        Set-SqlData
            Executes a query that does not return a result set 
        Get-SqlShowMbrs
            Recursively enumerates AD/local groups handling built-in SQL Server Windows groups
        Get-SqlUser
            Returns a SMO User object with additional properties including all of the objects owned by the user
            and the effective members of the user. Recursively enumerates nested AD/local groups
        Get-SqlUserMember
            Helper function enumerates effective members of a user.
        Get-SqlDatabaseRole
            Returns a SMO DatabaseRole object with additional properties including the effective members of a
            role recursively enumerates nested roles, and users
        Get-SqlDatabaseRoleMember
            Helper function enumerates effective members of a role
        Get-SqlLogin
            Returns a SMO Login object with additional properties including the effective members of the login
        Get-SqlLinkedServerLogin
            Returns a SMO LinkedServerLogin object with additional properties including LinkedServer and DataSource
        Get-SqlLoginMember
            Helper function enumerates effective members of a login
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

SQL Server Reporting Services (2005) reports
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
