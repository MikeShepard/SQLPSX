# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the Microsoft.SqlServer.Dts.Runtime (SSIS) Classes
### </Description>
### <Usage>
### . ./LibrarySSIS.ps1
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
#[reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=9.0.242.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
#[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\90\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
[reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
#[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
#[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.ManagedDTS") > $null

#######################
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
function New-ISApplication
{
   Write-Verbose "New-ISApplication"
    
   new-object ("Microsoft.SqlServer.Dts.Runtime.Application") 

} #New-ISApplication


#######################
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
    [Parameter(Position=9, Mandatory=$false)] [hashtable]$connectionInfo
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
    [Parameter(Position=8, Mandatory=$false)] [hashtable]$connectionInfo
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
    [Parameter(Position=7, Mandatory=$false)] [hashtable]$connectionInfo
    )

    #If destinationServer contains instance i.e. server\instance, convert to just servername:
    $destinationServer = $destinationserver -replace "\\.*"

 Write-Verbose "Copy-ISItemFileToSQL path:$path destination:$destination destinationServer$desinationServer recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    #######################
    function Copy-ISChildItemFileToSQL
    {
        param($item, [string]$path, [string]$destination, [string]$destinationServer, [switch]$force, [hashtable]$connectionInfo)
        $parentPath = Split-Path $item.FullName -parent | Split-Path -leaf
        $itemPath = $parentPath -replace "$([system.io.path]::getpathroot($item.FullName) -replace '\\','\\')"
        Write-Verbose "itemPath:$itemPath"
        $folder = $destination
        Write-Verbose "folder:$folder"

        if ($item.PSIsContainer)
        {
           $testPath = $($folder + "\" + $item.Name) -replace "\\\\","\"
           Write-Verbose "testPath:$testPath"
           if (!(Test-ISPath $testPath $destinationServer 'Folder'))
           {
                New-ISItem $Folder $item.Name $destinationServer
           }
        }
        else 
        {
          $destPath = $($folder + "\" + $item.BaseName) -replace "\\\\","\"
          $package = Get-ISPackage $item.FullName
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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

    #SQL Server Store
    if ($PSCmdlet.ParameterSetName -eq "server")
    { 
        if (Test-ISPath $path $serverName 'Package')
        { $app.LoadFromDtsServer($path, $serverName, $null) }
        else
        { Write-Error "Package $path does not exist on server $serverName" }
    }
    #File Store
    else
    { 
        if (Test-Path -literalPath $path)
        { $app.LoadPackage($path, $null) }
        else
        { Write-Error "Package $path does not exist" }
    }
    
} #Get-ISPackage

#######################
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
function Set-ISPackage
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Dts.Runtime.Package]$package,
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
function Set-ISConnectionString
{
    param(
    [Parameter(Position=0, Mandatory=$true)] [Microsoft.SqlServer.Dts.Runtime.Package]$package,
    [Parameter(Position=1, Mandatory=$true)] [hashtable]$connnectionInfo
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
#  .ExternalHelp C:\Users\u00\Documents\WindowsPowerShell\Modules\SSIS\SSIS.psm1-help.xml
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
