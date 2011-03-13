# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the Microsoft.SqlServer.Dts.Runtime (SSIS) Classes
### </Description>
### <Usage>
### import-module SSIS
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
if ( $Args[0] -eq 2005 )
{
    add-type -AssemblyName "Microsoft.SqlServer.ManagedDTS, Version=9.0.242.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" 
    #add-type -Path "C:\Program Files\Microsoft SQL Server\90\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll"
}
else
{
    add-type -AssemblyName "Microsoft.SqlServer.ManagedDTS, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
    #add-type -Path "C:\Program Files\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll"
}

#######################
<#
.SYNOPSIS
Creates a new Microsoft.SqlServer.Dts.Runtime.Application.
.DESCRIPTION
The New-ISApplication function creates a new Microsoft.SqlServer.Dts.Runtime.Application. This is the base class used by ManagedDTS.
.INPUTS
None
    You cannot pipe objects to New-ISApplication
.OUTPUTS
Microsoft.SqlServer.Dts.Runtime.Application
    New-ISApplication returns a Microsoft.SqlServer.Dts.Runtime.Application object.
.EXAMPLE
$app = New-ISApplication
This command creates a new IS Application object and assigns output to $app variable.
.LINK
New-ISApplication
#>
function New-ISApplication
{
   Write-Verbose "New-ISApplication"
    
   new-object ("Microsoft.SqlServer.Dts.Runtime.Application") 

} #New-ISApplication


#######################
<#
.SYNOPSIS
Copies an SSIS item from one SQL Server to another.
.DESCRIPTION
The Copy-ISItemSQLToSQL function copies SSIS item from one SQL Server to another. The item can be an SSIS folder or package. Recursive copies are supported.
.INPUTS
None
    You cannot pipe objects to Copy-ISItemSQLToSQL.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
copy-isitemsqltosql -path '\sqlpsx' -topLevelFolder 'msdb' -serverName 'Z002\SQL2K8' -destination 'msdb\sqlpsx2' -destinationServer 'Z002' -recurse -connectionInfo @{SSISCONFIG='.\SQL2K8'}
This command Recursively copies all SSIS packages and folders from the Integration Server Z002 folder sqlpsx to Z002 sqlpsx2. In addition changes the Connection Manager named SSISCONFIG data source to .\SQL2K8 during the copy process.
.LINK
Copy-ISItemSQLToSQL
#>
function Copy-ISItemSQLToSQL
{
    [CmdletBinding(SupportsShouldProcess=$true)] param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$topLevelFolder,
    [Parameter(Position=2, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=3, Mandatory=$true)] [string]$destination,
    [Parameter(Position=4, Mandatory=$true)] [string]$destinationServer,
    [Parameter(Position=5, Mandatory=$false)] [switch]$recurse,
    [Parameter(Position=6, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$include="*",
    [Parameter(Position=7, Mandatory=$false)] [string]$exclude=$null,
    [Parameter(Position=8, Mandatory=$false)] [switch]$force,
    [Parameter(Position=9, Mandatory=$false)] [hashtable]$connectionInfo,
#Valid values are: DontSaveSensitive, EncryptSensitiveWithUserKey, EncryptSensitiveWithPassword, EncryptAllWithPassword, EncryptAllWithUserKey, ServerStorage
    [Parameter(Position=10, Mandatory=$false)]
    [ValidateScript({[Enum]::GetNames([Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]) -ccontains $_ })] [string]$protectionLevel
    )

    #If destinationServer contains instance i.e. server\instance, convert to just servername:
    $destinationServer = $destinationserver -replace "\\.*"

Write-Verbose "Copy-ISItemSQLToSQL path:$path serverName:$serverName destination:$destination destinationServer:$destinationServer recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    $literalPath = $($topLevelFolder + "\" + $path) -replace "\\\\","\"
    Write-Verbose "literalPath:$literalPath"

    if (Test-ISPath $literalPath $serverName 'Package')
    {
        if ($PSCmdlet.ShouldProcess(
            "Set-ISPackage path: $literalPath destination: $destination destinationServer: $destinationServer force: $($force.IsPresent)",
            "Copy-ISItemSQLToSQL"))
        { 
          $package = Get-ISPackage $literalPath $serverName
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
              if ($protectionLevel)
              { $package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]$protectionLevel }
              if ($force)
              { Set-ISPackage  -package $package -path $destination -serverName $destinationServer -force }
              else
              { Set-ISPackage  -package $package -path $destination -serverName $destinationServer }
          }
        }
    }
    elseif (Test-ISPath $literalPath $serverName 'Folder')
    {
        if ($recurse)
        { $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -recurse $include $exclude }
        else
        { $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -include $include -exclude $exclude }

        $count = $pInfos | Measure-Object | Select Count
        $hasSubFolders = [bool]($pInfos | where {$_.Flags -eq 'Folder'})
        foreach ($pInfo in $pInfos)
        {
           $i++
           if ($hasSubFolders)
           { $folder = $($destination + $pInfo.Folder) }
           else
           { $folder = $destination }
           Write-Verbose "folder:$folder"

           if ($pInfo.Flags -eq 'Folder')
           {
               $testPath = $($folder + "\" -replace "\\$") + $pInfo.Name
               Write-Verbose "testPath:$testPath"
               if (!(Test-ISPath $testPath $destinationServer 'Folder'))
               { 
                    if ($PSCmdlet.ShouldProcess("New-ISItem path: $Folder value: $($pInfo.Name) serverName: $destinationServer", "Copy-ISItemSQLToSQL"))
                    { 
                        Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100) 
                        New-ISItem $Folder $pInfo.Name $destinationServer
                    }
               }
           }
           elseif ($pInfo.Flags -eq 'Package')
           {
               $destPath = $($folder + "\" -replace "\\\\","\") + $pInfo.Name
                if ($PSCmdlet.ShouldProcess(
                    "Set-ISPackage package: $($pInfo.Name) path: $destPath serverName: $destinationServer force: $($force.IsPresent)",
                    "Copy-ISItemSQLToSQL"))
                { 
                  $package = Get-ISPackage $pInfo.literalPath $serverName
                  if ($package)
                  { 
                    Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100)
                    if ($connectionInfo)
                    { Set-ISConnectionString $package $connectionInfo }
                    if ($protectionLevel)
                    { $package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]$protectionLevel }
                    if ($force)
                    { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer -force }
                    else
                    { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer }
                  }
                }
           }
        }
    }
    else
    { throw "Package $path does not exist on server $serverName" }
    
} #Copy-ISItemSQLToSQL

#######################
<#
.SYNOPSIS
Copies an SSIS item from SQL Server to File System.
.DESCRIPTION
The Copy-ISItemSQLToFile function copies SSIS item from SQL Server to File System. The item can be an SSIS folder or package. Recursive copies are supported.
.INPUTS
None
    You cannot pipe objects to Copy-ISItemSQLToFile.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
copy-isitemsqltofile -path '\sqlpsx' -topLevelFolder 'msdb' -serverName 'Z002\SQL2K8' -destination 'c:\Users\u00\SSIS' -recurse -connectionInfo @{SSISCONFIG='.\SQLEXPRESS'}
This command Recursively copies all SSIS packages and folders from the Integration Server Z002 folder sqlpsx to the file system path C:\Users\u00\SSIS. In addition changes the Connection Manager named SSISCONFIG data source to .\SQLExpress during the copy process.
.LINK
Copy-ISItemSQLToFile
#>
function Copy-ISItemSQLToFile
{
    [CmdletBinding(SupportsShouldProcess=$true)] param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$topLevelFolder,
    [Parameter(Position=2, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=3, Mandatory=$true)] [string]$destination,
    [Parameter(Position=4, Mandatory=$false)] [switch]$recurse,
    [Parameter(Position=5, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$include="*",
    [Parameter(Position=6, Mandatory=$false)] [string]$exclude=$null,
    [Parameter(Position=7, Mandatory=$false)] [switch]$force,
    [Parameter(Position=8, Mandatory=$false)] [hashtable]$connectionInfo,
#Valid values are: DontSaveSensitive, EncryptSensitiveWithUserKey, EncryptSensitiveWithPassword, EncryptAllWithPassword, EncryptAllWithUserKey, ServerStorage
    [Parameter(Position=9, Mandatory=$false)]
    [ValidateScript({[Enum]::GetNames([Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]) -ccontains $_ })] [string]$protectionLevel
    )

Write-Verbose "Copy-ISItemSQLToFile path:$path serverName:$serverName destination:$destination recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    $literalPath = $($topLevelFolder + "\" + $path) -replace "\\\\","\"
    Write-Verbose "literalPath:$literalPath"

    if (Test-ISPath $literalPath $serverName 'Package')
    {
        $package = Get-ISPackage $literalPath $serverName

        if ($PSCmdlet.ShouldProcess("Set-ISPackage package: $($package.Name) path: $destination force: $($force.IsPresent)", "Copy-ISItemSQLToFile"))
        { 
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
              if ($protectionLevel)
              { $package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]$protectionLevel }
              if ($force)
              { Set-ISPackage  -package $package -path $destination -force }
              else
              { Set-ISPackage  -package $package -path $destination }
          }
        }
    }
    elseif (Test-ISPath $literalPath $serverName 'Folder')
    {
        if ($recurse)
        { $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -recurse $include $exclude }
        else
        { $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -include $include -exclude $exclude }

        $count = $pInfos | Measure-Object | Select Count
        $hasSubFolders = [bool]($pInfos | where {$_.Flags -eq 'Folder'})
        foreach ($pInfo in $pInfos)
        {
           $i++
           if ($hasSubFolders)
           { $folder = $($destination + $pInfo.Folder) -replace "\\\\","\" }
           else
           { $folder = $destination }
           Write-Verbose "folder:$folder"

           if ($pInfo.Flags -eq 'Folder')
           {
               $testPath = $($folder + "\" + $pInfo.Name) -replace "\\\\","\"
               Write-Verbose "testPath:$testPath"
               if (!(Test-Path -literalPath $testPath))
               {
                    if ($PSCmdlet.ShouldProcess("New-Item path: $Folder name: $($pInfo.Name) ltype: directory", "Copy-ISItemSQLToFile"))
                    { 
                      Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100)
                      New-Item -path $Folder -name $pInfo.Name -type directory
                    }
               }
           }
           elseif ($pInfo.Flags -eq 'Package')
           {
               $destPath = $($folder + "\" + $pInfo.Name + ".dtsx") -replace "\\\\","\"
                if ($PSCmdlet.ShouldProcess("Set-ISPackage package: $($pInfo.Name) path: $destPath force: $($force.IsPresent)", "Copy-ISItemSQLToFile"))
                {
                   $package = Get-ISPackage $pInfo.literalPath $serverName
                   if ($package)
                   { 
                    Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100) 
                    if ($connectionInfo)
                    { Set-ISConnectionString $package $connectionInfo }
                    if ($protectionLevel)
                    { $package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]$protectionLevel }
                     if ($force)
                     { Set-ISPackage  -package $package -path $destPath -force }
                     else
                     { Set-ISPackage  -package $package -path $destPath }
                   }
                }
           }
        }
    }
    else
    { throw "Package $path does not exist on server $serverName" }

} #Copy-ISItemSQLToFile

#######################
<#
.SYNOPSIS
Copies an SSIS item from File System to SQL Server.
.DESCRIPTION
The Copy-ISItemFileToSQL function copies SSIS item from File System to SQL Server. The item can be a File System folder or package. Recursive copies are supported.
.INPUTS
None
    You cannot pipe objects to Copy-ISItemFileToSQL.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
copy-isitemfiletosql -path "C:\Program Files\Microsoft SQL Server\100\DTS\Packages\*" -destination 'msdb\sqlpsx' -destinationServer 'Z002' -connectionInfo @{SSISCONFIG='.\SQLEXPRESS'}
This command copies all SSIS packages and folders from the File System pathC:\Program Files\Microsoft SQL Server\100\DTS\Packages to Integration Server Z002 folder sqlpsx. In addition changes the Connection Manager named SSISCONFIG data source to .\SQLEXPRESS during the copy process.
.LINK
Copy-ISItemFileToSQL
#>
function Copy-ISItemFileToSQL
{
    [CmdletBinding(SupportsShouldProcess=$true)] param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$destination,
    [Parameter(Position=2, Mandatory=$true)] [string]$destinationServer,
    [Parameter(Position=3, Mandatory=$false)] [switch]$recurse,
    [Parameter(Position=4, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$include="*",
    [Parameter(Position=5, Mandatory=$false)] [string]$exclude=$null,
    [Parameter(Position=6, Mandatory=$false)] [switch]$force,
    [Parameter(Position=7, Mandatory=$false)] [hashtable]$connectionInfo,
#Valid values are: DontSaveSensitive, EncryptSensitiveWithUserKey, EncryptSensitiveWithPassword, EncryptAllWithPassword, EncryptAllWithUserKey, ServerStorage
    [Parameter(Position=8, Mandatory=$false)]
    [ValidateScript({[Enum]::GetNames([Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]) -ccontains $_ })] [string]$protectionLevel
    )

    #If destinationServer contains instance i.e. server\instance, convert to just servername:
    $destinationServer = $destinationserver -replace "\\.*"

 Write-Verbose "Copy-ISItemFileToSQL path:$path destination:$destination destinationServer$desinationServer recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    #######################
    function Copy-ISChildItemFileToSQL
    {
        param($item, [string]$path, [string]$destination, [string]$destinationServer, [switch]$force, [hashtable]$connectionInfo)
        #$parentPath = Split-Path $item.FullName -parent | Split-Path -leaf
        #$itemPath = $parentPath -replace "$([system.io.path]::getpathroot($item.FullName) -replace '\\','\\')"
        $itemPath =  "\" + $item.FullName  -replace ($path -replace "\\","\\") -replace $item.Name
        Write-Verbose "itemPath:$itemPath"
        $folder = $destination + $itemPath
        Write-Verbose "folder:$folder"

        if ($item.PSIsContainer)
        {
           $testPath = $($folder + $item.Name) -replace "\\\\","\"
           Write-Verbose "testPath:$testPath"
           if (!(Test-ISPath $testPath $destinationServer 'Folder'))
           {
                New-ISItem $Folder $item.Name $destinationServer
           }
        }
        else 
        {
          $destPath = $($folder + $item.BaseName) -replace "\\\\","\"
          $package = Get-ISPackage $item.FullName
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
              if ($protectionLevel)
              { $package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]$protectionLevel }
              if ($force)
              { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer -force }
              else
              { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer }
          }
        }

    } #Copy-ISChildItemFileToSQL

    if (Test-Path $path)
    { 
       if ($recurse)
       {
           $items = Get-ChildItem -path $path -include $include -exclude $exclude -recurse
           $count = $items | Measure-Object | Select Count
           foreach ($item in $items)
           { 
             if ($PSCmdlet.ShouldProcess("item: $($item.FullName) path: $path destination: $destination destinationServer: $destinationServer `
             force: $($force.IsPresent)", "Copy-ISItemFileToSQL"))
             {
                 $i++
                 Write-Progress -activity "Copying Items..." -status "Copying $($item.Name)" -percentcomplete ($i/$count.count*100) 
                 if ($force)
                 { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer `
                 -force -connectionInfo $connectionInfo }
                 else
                 { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer `
                 -connectionInfo $connectionInfo }
             }
           }
       }
       else
       {
           $items = Get-ChildItem -path $path -include $include -exclude $exclude
           $count = $items | Measure-Object | Select Count
           foreach ($item in  $items)
           {
             if ($PSCmdlet.ShouldProcess("item: $($item.FullName) path: $path destination: $destination destinationServer: $destinationServer `
             force: $($force.IsPresent)", "Copy-ISItemFileToSQL"))
             {
                 $i++
                 Write-Progress -activity "Copying Items..." -status "Copying $($item.Name)" -percentcomplete ($i/$count.count*100) 
                 if ($force)
                 { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer `
                 -force -connectionInfo $connectionInfo }
                 else
                 { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer `
                 -connectionInfo $connectionInfo }
             }
           }
       }
    }
    else
    { throw "Package $path does not exist" }

} #Copy-ISItemFileToSQL

#######################
<#
.SYNOPSIS
Gets the item at the specified location.
.DESCRIPTION
The Get-ISItem function gets the item at the specified location. It does not get the contents of the item at the location unless you use a wildcard character (*) to request all the contents of the item.
.INPUTS
None
    You cannot pipe objects to Get-ISItem.
.OUTPUTS
Microsoft.SqlServer.Dts.Runtime.PackageInfo
    Get-ISItem returns a Microsoft.SqlServer.Dts.Runtime.PackageInfo object.
.EXAMPLE
get-isitem -path '\' -topLevelFolder 'msdb' -serverName 'Z002\SQL2K8' -recurse
This command recursively gets all of the SSIS packages and folders starting at the root ('\') level on SQL Server Z002\SQL2K8.
.LINK
Get-ISItem
#>
function Get-ISItem
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path="\",
    [Parameter(Position=1, Mandatory=$true)] [string]$topLevelFolder,
    [Parameter(Position=2, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=3, Mandatory=$false)] [switch]$recurse,
    [Parameter(Position=4, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$include="*",
    [Parameter(Position=5, Mandatory=$false)] [string]$exclude=$null
    )

 Write-Verbose "Get-ISItem path:$path topLevelFolder:$topLevelFolder serverName:$serverName recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    #Note: Unlike SSMS, specify an instance name. There are some inconsistencies in the implementation of methods in the Application class
    #GetPackagesInfos unlike every other method expects a SQL instance as the server name while the other methods expect an Integration Services server.
    #This inconsistency applies to folder as well path where GetPackagesInfo defaults to the TopLevelFolders path defined in MsDtsSrvr.ini.xml and the 
    #other methods expect you to fully qualify the path with the TopLevelFolder name. There does not appear to be programatic way to determine the
    #TopLevelFolders which seems odd given that SSMS shows the top level folders. To workaround the TopLevelFolder issue we will pass the value as parameter

    $app = New-ISApplication

    if ($recurse)
    {
        foreach ($pInfo in $app.GetPackageInfos($path, $serverName, $null, $null))
        {
            if ($pInfo.Name -like $include -and $pInfo.Name -notlike $exclude)
            {
                $literalPath = $($topLevelFolder + $pInfo.Folder + "\" + $pInfo.Name) -replace "\\\\","\"
                $pInfo  | add-Member -memberType noteProperty -name serverName -value $serverName -passthru |
                          add-Member -memberType noteProperty -name topLevelFolder -value $topLevelFolder -passthru |
                          add-Member -memberType noteProperty -name literalPath -value $literalPath -passthru

                if ($pInfo.flags -eq 'Folder')
                { $childItem = $($pInfo.Folder + "\" + $pInfo.Name) -replace "\\\\","\"
                  Get-ISItem $childItem $topLevelFolder $serverName -recurse $include $exclude }
            }
        }
    }
    else
    {
        foreach ($pInfo in $app.GetPackageInfos($path, $serverName, $null, $null))
        {
            if ($pInfo.Name -like $include -and $pInfo.Name -notlike $exclude)
            { 
                $literalPath = $($topLevelFolder + $pInfo.Folder + "\" + $pInfo.Name) -replace "\\\\","\"
                $pInfo  | add-Member -memberType noteProperty -name serverName -value $serverName -passthru |
                          add-Member -memberType noteProperty -name topLevelFolder -value $topLevelFolder -passthru |
                          add-Member -memberType noteProperty -name literalPath -value $literalPath -passthru
            }
        }
    }

} #Get-ISItem

#######################
<#
.SYNOPSIS
Determines whether all elements of a path exist.
.DESCRIPTION
The Test-ISPath function determines whether all elements of the path exist. It returns TRUE ($true) if all elements exist and FALSE ($false) if any are missing. It can also tell whether the path syntax is valid and whether the path leads to a container or a terminal (leaf) element.
.INPUTS
None
    You cannot pipe objects to Test-ISPath.
.OUTPUTS
Boolean
    Test-ISPath returns a Boolean representing whether the specified path exists.
.EXAMPLE
Test-ISPath 'msdb\sqlpsx' Z002 'Folder'
This command tests whether the path msdb\sqlpsx exists on the SSIS server Z002.
.LINK
Test-ISPath
#>
function Test-ISPath
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=2, Mandatory=$true)] [ValidateSet("Package", "Folder", "Any")] [string]$pathType='Any'
    )

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Test-ISPath path:$path serverName:$serverName pathType:$pathType"

    #Note: Don't specify instance name

    $app = New-ISApplication

    switch ($pathType)
    {
        'Package' { trap { $false; continue } $app.ExistsOnDtsServer($path,$serverName) }
        'Folder'  { trap { $false; continue } $app.FolderExistsOnDtsServer($path,$serverName) }
        'Any'     { $p=Test-ISPath $path $serverName 'Package'; $f=Test-ISPath $path $serverName 'Folder'; [bool]$($p -bor $f)}
    }

} #Test-ISPath

#######################
<#
.SYNOPSIS
Creates a new item.
.DESCRIPTION
The New-ISItem function creates a new item and sets its value. Only new SSIS folders are supported.
.INPUTS
None
    You cannot pipe objects to New-ISItem.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
new-isitem '\msdb' sqlpsx Z002
This command creates a new SSIS folder on the SSIS server Z002 under the root msdb path.
.LINK
New-ISItem
#>
function New-ISItem
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$value,
    [Parameter(Position=2, Mandatory=$true)] [string]$serverName
    )

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "New-ISItem path:$path value:$value serverName:$serverName"

    $app = New-ISApplication

    $testPath = $($path + "\" + $value) -replace "\\\\","\"

    if (!(Test-ISPath $testPath $serverName 'Folder'))
    { $app.CreateFolderOnDtsServer($path, $value, $serverName) }
    else
    { throw "Path $testPath already exists!" }

} #New-ISItem

#######################
<#
.SYNOPSIS
Renames an SSIS folder.
.DESCRIPTION
The Rename-ISItem function changes the name of a specified item. Only SSIS folder names are supported.
.INPUTS
None
    You cannot pipe objects to New-ISItem.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
rename-isitem '\msdb' sqlpsx sqlpsx2 Z002
This command renames the SSIS folder sqlpsx to sqlpsx on the SSIS server Z002. Only renaming of SSIS folders is supported by the rename-isitem function.
.LINK
Rename-ISItem
#>
function Rename-ISItem
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(Position=1, Mandatory=$true)] [string]$oldName,
    [Parameter(Position=2, Mandatory=$true)] [string]$newName,
    [Parameter(Position=3, Mandatory=$true)] [string]$serverName
    )

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Rename-ISItem path:$path oldName:$oldName newName:$newName serverName:$serverName"

    $app = New-ISApplication

    $testPath = $($path + "\" + $oldName) -replace "\\\\","\"

    if (Test-ISPath $testPath $serverName 'Folder')
    { $app.RenameFolderOnDtsServer($path, $oldName, $newName, $serverName) }
    else
    { throw "Path $testPath does not exist" }

} #Rename-ISItem

#######################
<#
.SYNOPSIS
Deletes the specified items.
.DESCRIPTION
The Remove-ISItem function deletes one or more items. Both packages and SSIS folders are supported.
.INPUTS
Microsoft.SqlServer.Dts.Runtime.PackageInfo
    You can pipe pInfo PackageInfo to Remove-ISItem.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
get-isitem '\' 'msdb' 'Z002\sql2k8' | where {$_.name -like "sqlpsx*"} | remove-isitem
This command first gets items stored on the root path of the SSIS server Z002\SQL2K8 where the name matches sqlpsx and then removes the items. Both packages and folders that match the criteria will be removed from the SSIS server.
.LINK
Remove-ISItem
#>
function Remove-ISItem
{
    [CmdletBinding(SupportsShouldProcess=$true)] param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] $pInfo)
    begin
    {
        $app = New-ISApplication
    }
    process
    {

            #If serverName contains instance i.e. server\instance, convert to just servername:
            $serverName = $pInfo.serverName -replace "\\.*"
            switch ($pInfo.Flags)
            {
                'Package' { 
                            if (Test-ISPath $pInfo.literalPath $serverName 'Package')
                            { 
                                if ($PSCmdlet.ShouldProcess("RemoveFromDtsServer($($pInfo.literalPath),$serverName)", "Remove-ISItem"))
                                { $app.RemoveFromDtsServer($pInfo.literalPath,$serverName) }
                            }
                            else
                            { throw "Package $($pInfo.literalPath) does not exist on server $serverName" }
                          }
                'Folder'  { 
                            if (Test-ISPath $pInfo.literalPath $serverName 'Folder')
                            {
                                if ($PSCmdlet.ShouldProcess("RemoveFolderFromDtsServer($($pInfo.literalPath),$serverName)", "Remove-ISItem"))
                                { $app.RemoveFolderFromDtsServer($pInfo.literalPath,$serverName) }
                            }
                            else
                            { throw "Folder $($pInfo.literalPath) does not exist on server $serverName" }
                          }
            }
    }


} #Remove-ISItem

#######################
<#
.SYNOPSIS
Gets the SSIS package at the specified location.
.DESCRIPTION
The Get-ISPackage function gets the SSIS package at the specified location. Both SQL Server and File System stored packages are supported.
.INPUTS
None
    You cannot pipe objects to Get-ISPackage.
.OUTPUTS
Microsoft.SqlServer.Dts.Runtime.Package
    Get-ISPackage returns a Microsoft.SqlServer.Dts.Runtime.Package object.
.EXAMPLE
$package = get-ispackage -path "C:\Program Files\Microsoft SQL Server\100\DTS\Packages\sqlpsx1.dtsx"
This command gets the package sqlpsx1.dtsx from the file systems and assigns it to the variable $package.
.LINK
Get-ISPackage
#>
function Get-ISPackage
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$path,
    [Parameter(ParameterSetName="server", Position=1, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$serverName
    )

    #If serverName contains instance i.e. server\instance, convert to just servername:
    if ($serverName)
    { $serverName = $serverName -replace "\\.*" }

    Write-Verbose "Get-ISPackage path:$path serverName:$serverName"

    $app = New-ISApplication

    $name =  ($path -split '\\')[($path -split '\\').count -1]
    $name = $name -replace ".dtsx"

    #SQL Server Store
    if ($PSCmdlet.ParameterSetName -eq "server")
    { 
        if (Test-ISPath $path $serverName 'Package')
        { $app.LoadFromDtsServer($path, $serverName, $null) | add-Member -memberType noteProperty -name DisplayName -value $name -passthru}
        else
        { Write-Error "Package $path does not exist on server $serverName" }
    }
    #File Store
    else
    { 
        if (Test-Path -literalPath $path)
        { $app.LoadPackage($path, $null) | add-Member -memberType noteProperty -name DisplayName -value $name -passthru }
        else
        { Write-Error "Package $path does not exist" }
    }
    
} #Get-ISPackage

#######################
<#
.SYNOPSIS
Writes or replaces the SSIS package with a new package.
.DESCRIPTION
The Set-ISPackage function writes or replaces the SSIS package with a new package. Both SQL Server and File System storage are supported.
.INPUTS
None
    You cannot pipe objects to Set-ISPackage.
.OUTPUTS
Microsoft.SqlServer.Dts.Runtime.Package
    Get-ISPackage returns a Microsoft.SqlServer.Dts.Runtime.Package object.
.EXAMPLE
$package = Get-ISPackage 'msdb\sqlpsx2' Z003
Set-ISPackage  -package $package -path '\msdb' -serverName Z002
This command gets teh SSIS package sqlpsx2 from the SSIS server Z003 and saves the package to the SSIS server Z002.
.LINK
Set-ISPackage
Get-ISPackage
#>
function Set-ISPackage
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $package,
    [Parameter(Position=1, Mandatory=$true)] [string]$path,
    [Parameter(ParameterSetName="server", Position=2, Mandatory=$false)] [ValidateNOTNullOrEmpty()] [string]$serverName,
    [Parameter(Position=3, Mandatory=$false)] [switch]$force
    )

    #If serverName contains instance i.e. server\instance, convert to just servername:
    if ($serverName)
    { $serverName = $serverName -replace "\\.*" }

    Write-Verbose "Set-ISPackage package:$($package.Name) path:$path serverName:$serverName"

    $app = New-ISApplication

    #SQL Server Store
    if ($PSCmdlet.ParameterSetName -eq "server")
    { 
        if (!(Test-ISPath $path $serverName 'Package') -or $($force))
        { $app.SaveToDtsServer($package, $null, $path, $serverName) }
        else
        { throw "Package $path already exists on server $serverName" }
    }
    #File Store
    else
    { 
        if (!(Test-Path -literalPath $path) -or $($force))
        { $app.SaveToXml($path, $package, $null) }
        else
        { throw "Package $path already exists" }
    }
    
} #Set-ISPackage

#######################
<#
.SYNOPSIS
Gets the currently running packages on a SSIS server.
.DESCRIPTION
The Get-ISRunningPackage function gets the currently running packages on the specified SSIS server.
.INPUTS
None
    You cannot pipe objects to Get-ISRunningPackage.
.OUTPUTS
Microsoft.SqlServer.Dts.Runtime.RunningPackage
    Get-ISRunningPackage returns a Microsoft.SqlServer.Dts.Runtime.RunningPackage object.
.EXAMPLE
Get-ISRunningPackage Z002
This command gets a list of the currently running packages on SSIS server Z002.
.LINK
Get-ISRunningPackage
#>
function Get-ISRunningPackage
{
    param([Parameter(Position=0, Mandatory=$true)] [string]$serverName)

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Get-ISRunningPackage serverName:$serverName"

    $app = New-ISApplication

    $app.GetRunningPackages($serverName)

} #Get-ISRunningPackage

#######################
<#
.SYNOPSIS
Sets the Connection Manager data source to the specified SQL Server.
.DESCRIPTION
The Set-ISConnectionString function sets the Connection Manager data source to the specified SQL Server.
.INPUTS
None
    You cannot pipe objects to Set-ISConnectionString.
.OUTPUTS
None
    This function does not generate any output.
.EXAMPLE
$package = Get-ISPackage 'msdb\sqlpsx2' Z002
Set-ISConnectionString $package @{SSISCONFIG='.\SQL2K8'}
This command gets the SSIS package sqlpsx and sets the data source to '.\SQL2K8' for the Connection Manager SSISCONFIG.
.LINK
Set-ISConnectionString
#>
function Set-ISConnectionString
{
    param(
    [Parameter(Position=0, Mandatory=$true)] $package,
    [Parameter(Position=1, Mandatory=$true)] [hashtable]$connectionInfo
    )

    Write-Verbose "Set-ISConnectionString"

    foreach ($i in $connectionInfo.GetEnumerator())
    {
        $name = $($i.Key); $value = $($i.Value);
        Write-Verbose "Set-ISConnectionString name:$name value:$value "
        $connectionManager = $package.connections | where {$_.Name -eq "$name"}
        Write-Verbose "Set-ISConnectionString connString1:$($connectionManager.ConnectionString)"
        if ($connectionManager)
        {
            $connString = $connectionManager.ConnectionString
            Write-Verbose "Set-ISConnectionString connString:$connString"
            $connString -match "^Data Source=(?<server>[^;]+);" > $null
            $newConnString = $connString -replace $($matches.server -replace "\\","\\"),$value
            Write-Verbose "Set-ISConnectionString newConnString:$newConnString"
            if ($newConnString)
            { $connectionManager.ConnectionString = $newConnString }
        }
    }

} #Set-ISConnectionString

#######################
<#
.SYNOPSIS
Gets data from a SQL Server.
.DESCRIPTION
The Get-ISData function gets data a SQL Server.
.INPUTS
None
    You cannot pipe objects to Get-ISData.
.OUTPUTS
System.Data.DataRow
    Get-ISData returns a System.Data.DataRow object.
.EXAMPLE
get-isdata 'Z002\SQL2K8' pubs 'select * from authors'
This command executes a SQL query against the pubs database on the Z002\SQL2K8 server and returns the authors table.
.LINK
Get-ISData
#>
function Get-ISData
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=1, Mandatory=$true)] [string]$databaseName,
    [Parameter(Position=2, Mandatory=$true)] [string]$query
    )

    Write-Verbose "Get-ISData serverName:$serverName databaseName:$databaseName query:$query"

    $connString = "Server=$serverName;Database=$databaseName;Integrated Security=SSPI;"
    $da = New-Object "System.Data.SqlClient.SqlDataAdapter" ($query,$connString)
    $dt = New-Object "System.Data.DataTable"
    [void]$da.fill($dt)
    $dt

} #Get-ISData

#######################
<#
.SYNOPSIS
Gets the SSIS configuration items.
.DESCRIPTION
The Get-ISSqlConfigurationItem function gets the SSIS configuration items using a SQL Server table store.
.INPUTS
None
    You cannot pipe objects to Get-ISSqlConfigurationItem.
.OUTPUTS
System.Data.DataRow
    Get-ISSqlConfigurationItem returns a System.Data.DataRow object.
.EXAMPLE
Get-ISSqlConfigurationItem 'Z002\SQL2K8' 'ssisconfig' '[SSIS Configurations]' 'sqlpsx_ssis' '\Package.Connections[Destination].Properties[ConnectionString]'
This command gets the configuration item sqlpsx_ssis from the table [SSIS Configurations] from the database ssisconfig on the SQL Server Z002\SQL2K8. Only rows matching the \Package.Connections[Destination].Properties[ConnectionString] are returned.
.LINK
Get-ISSqlConfigurationItem
#>
function Get-ISSqlConfigurationItem
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [string]$serverName,
    [Parameter(Position=1, Mandatory=$true)] [string]$databaseName, 
    [Parameter(Position=2, Mandatory=$true)] [string]$configurationTable,
    [Parameter(Position=3, Mandatory=$true)] [string]$configurationFilter,
    [Parameter(Position=4, Mandatory=$true)] [string]$packagePath
    )

Write-Verbose "Get-ISSqlConfigurationItem serverName:$serverName db:$databaseName table:$configurationTable filer:$configurationFilter path:$packagePath query:$query"

$query = @"
Select ConfiguredValue FROM $configurationTable
 WHERE ConfigurationFilter = '$configurationFilter'
 AND PackagePath = '$packagePath'
"@

    $item = Get-ISData $serverName $databaseName $query
    $item | foreach { $_.ConfiguredValue }

} #Get-ISSqlPackageConfiguration
