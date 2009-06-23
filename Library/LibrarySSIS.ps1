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
[reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=9.0.242.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
#[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\90\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
#[reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
#[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
#[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.ManagedDTS") > $null

#######################
function New-ISApplication
{
   Write-Verbose "New-ISApplication"
    
   new-object ("Microsoft.SqlServer.Dts.Runtime.Application") 

} #New-ISApplication


#######################
function Copy-ISItemSQLToSQL
{
    param([string]$path, [string]$topLevelFolder, [string]$serverName,
    [string]$destination, [string]$destinationServer, [switch]$recurse,
    [string]$include="*", [string]$exclude=$null, [switch]$whatIf, [switch]$force, $connectionInfo)

    #If destinationServer contains instance i.e. server\instance, convert to just servername:
    $destinationServer = $destinationserver -replace "\\.*"

Write-Verbose "Copy-ISItemSQLToSQL path:$path serverName:$serverName destination:$destination destinationServer:$destinationServer recurse:$($recurse.IsPresent) include:$include exclude:$exclude whatIf:$($whatIf.IsPresent)"

    $literalPath = $($topLevelFolder + "\" + $path) -replace "\\\\","\"
    Write-Verbose "literalPath:$literalPath"

    if (Test-ISPath $literalPath $serverName 'Package')
    {
        if ($whatIf.IsPresent)
        { Write-Host "What if:Set-ISPackage $literalPath $destination $destinationServer $($force.IsPresent)" }
        else
        { 
          $package = Get-ISPackage $literalPath $serverName
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
              if ($force.IsPresent)
              { Set-ISPackage  -package $package -path $destination -serverName $destinationServer -force }
              else
              { Set-ISPackage  -package $package -path $destination -serverName $destinationServer }
          }
        }
    }
    elseif (Test-ISPath $literalPath $serverName 'Folder')
    {
        $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -recurse $include $exclude
        $count = $pInfos | Measure-Object | Select Count
        foreach ($pInfo in $pInfos)
        {
           $i++
           $folder = $($destination + $pInfo.Folder) 
           Write-Verbose "folder:$folder"

           if ($pInfo.Flags -eq 'Folder')
           {
               $testPath = $($folder + "\" -replace "\\$") + $pInfo.Name
               Write-Verbose "testPath:$testPath"
               if (!(Test-ISPath $testPath $destinationServer 'Folder'))
               { 
                    if ($whatIf.IsPresent)
                    { Write-Host "What if:New-ISItem $Folder $($pInfo.Name) $destinationServer" }
                    else
                    { 
                  Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100) 
                        New-ISItem $Folder $pInfo.Name $destinationServer
                    }
               }
           }
           elseif ($pInfo.Flags -eq 'Package')
           {
               $destPath = $($folder + "\" -replace "\\\\","\") + $pInfo.Name
                if ($whatIf.IsPresent)
                { Write-Host "What if:Set-ISPackage -package $($pInfo.Name) -path $destPath -serverName $destinationServer -force $($force.IsPresent)" }
                else
                { 
                  $package = Get-ISPackage $pInfo.literalPath $serverName
                  if ($package)
                  { 
                    Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100)
                    if ($connectionInfo)
                    { Set-ISConnectionString $package $connectionInfo }
                    if ($force.IsPresent)
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
function Copy-ISItemSQLToFile
{
    param([string]$path, [string]$topLevelFolder, [string]$serverName, [string]$destination,
    [switch]$recurse, [string]$include="*", [string]$exclude=$null, [switch]$whatIf, [switch]$force, $connectionInfo)

Write-Verbose "Copy-ISItemSQLToFile path:$path serverName:$serverName destination:$destination recurse:$($recurse.IsPresent) include:$include exclude:$exclude whatIf:$($whatIf.IsPresent)"

    $literalPath = $($topLevelFolder + "\" + $path) -replace "\\\\","\"
    Write-Verbose "literalPath:$literalPath"

    if (Test-ISPath $literalPath $serverName 'Package')
    {
        if ($whatIf.IsPresent)
        { Write-Host "What if:Set-ISPackage $($package.Name) $destination $($force.IsPresent)" }
        else
        { 
          $package = Get-ISPackage $literalPath $serverName
          if ($package)
          {
              if ($connectionInfo)
              { Set-ISConnectionString $package $connectionInfo }
              if ($force.IsPresent)
              { Set-ISPackage  -package $package -path $destination -force }
              else
              { Set-ISPackage  -package $package -path $destination }
          }
        }
    }
    elseif (Test-ISPath $literalPath $serverName 'Folder')
    {
        $pInfos = Get-ISItem -path $path $topLevelFolder $serverName -recurse $include $exclude
        $count = $pInfos | Measure-Object | Select Count
        foreach ($pInfo in $pInfos)
        {
           $i++
           $folder = $($destination + $pInfo.Folder) -replace "\\\\","\"
           Write-Verbose "folder:$folder"

           if ($pInfo.Flags -eq 'Folder')
           {
               $testPath = $($folder + "\" + $pInfo.Name) -replace "\\\\","\"
               Write-Verbose "testPath:$testPath"
               if (!(Test-Path -literalPath $testPath))
               {
                if ($whatIf.IsPresent)
                 { Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100) 
                   Write-Host "What if:New-Item -path $Folder -name $($pInfo.Name) -ltype directory" }
                else
                { New-Item -path $Folder -name $pInfo.Name -type directory }
               }
           }
           elseif ($pInfo.Flags -eq 'Package')
           {
               $destPath = $($folder + "\" + $pInfo.Name + ".dtsx") -replace "\\\\","\"
                if ($whatIf.IsPresent)
                { Write-Host "What if:Set-ISPackage -package $($pInfo.Name) -path $destPath -force $($force.IsPresent)" }
                else
                {
                   $package = Get-ISPackage $pInfo.literalPath $serverName
                   if ($package)
                   { 
                    Write-Progress -activity "Copying ISItems..." -status "Copying $($pInfo.Name)" -percentcomplete ($i/$count.count*100) 
                    if ($connectionInfo)
                    { Set-ISConnectionString $package $connectionInfo }
                     if ($force.IsPresent)
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
function Copy-ISItemFileToSQL
{
    param([string]$path, [string]$destination,
    [string]$destinationServer, [switch]$recurse,
    [string]$include="*", [string]$exclude=$null, [switch]$whatIf, [switch]$force, $connectionInfo)

    #If destinationServer contains instance i.e. server\instance, convert to just servername:
    $destinationServer = $destinationserver -replace "\\.*"

 Write-Verbose "Copy-ISItemFileToSQL path:$path destination:$destination destinationServer$desinationServer recurse:$($recurse.IsPresent) include:$include exclude:$exclude whatIf:$($whatIf.IsPresent)"

    #######################
    function Copy-ISChildItemFileToSQL
    {
        param($item, [string]$path, [string]$destination, [string]$destinationServer, [switch]$force, $connectionInfo)

        $parentPath = $item.PSParentPath -replace 'Microsoft.PowerShell.Core\\FileSystem::'
        $itemPath = $path -replace $($parentPath -replace '\\', '\\') -replace $item.Name
        Write-Verbose "itemPath:$itemPath"
        $folder = $destination + $itemPath 
        Write-Verbose "folder:$folder"

        if ($item.PSIsContainer)
        {
           $testPath = $($folder + "\" + $item.Name) -replace "\\\\","\"
           Write-Verbose "testPath:$testPath"
           if (!(Test-ISPath $testPath $destinationServer 'Folder'))
           {
               if ($whatIf.IsPresent)
               { Write-Host "What if:New-ISItem $Folder $item.Name $destinationServer" }
               else
               { New-ISItem $Folder $item.Name $destinationServer }
           }
        }
        else 
        {
            $destPath = $($folder + "\" + $item.BaseName) -replace "\\\\","\"
            if ($whatIf.IsPresent)
            { Write-Host "What if:Set-ISPackage $($package.Name) $folder" }
            else
            {
              $package = Get-ISPackage $item.FullName
              if ($package)
              {
                  if ($connectionInfo)
                  { Set-ISConnectionString $package $connectionInfo }
                  if ($force.IsPresent)
                  { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer -force }
                  else
                  { Set-ISPackage  -package $package -path $destPath -serverName $destinationServer }
              }
            }
        }

    } #Copy-ISChildItemFileToSQL

    if (Test-Path $path)
    { 
       if ($recurse.IsPresent)
       {
           $items = Get-ChildItem -path $path -include $include -exclude $exclude -recurse
           $count = $items | Measure-Object | Select Count
           foreach ($item in $items)
           { 
             $i++
             Write-Progress -activity "Copying Items..." -status "Copying $($item.Name)" -percentcomplete ($i/$count.count*100) 
             if ($force.IsPresent)
             { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer -force -connectionInfo $connectionInfo }
             else
             { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer -connectionInfo $connectionInfo }
           }
       }
       else
       {
           $items = Get-ChildItem -path $path -include $include -exclude $exclude
           $count = $items | Measure-Object | Select Count
           foreach ($item in  $items)
           {
             $i++
             Write-Progress -activity "Copying Items..." -status "Copying $($item.Name)" -percentcomplete ($i/$count.count*100) 
             if ($force.IsPresent)
             { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer -force -connectionInfo $connectionInfo }
             else
             { Copy-ISChildItemFileToSQL -item $item -path $path -destination $destination -destinationServer $destinationServer -connectionInfo $connectionInfo }
           }
       }
    }
    else
    { throw "Package $path does not exist" }

} #Copy-ISItemFileToSQL

#######################
function Get-ISItem
{
    param([string]$path="\", [string]$topLevelFolder, [string]$serverName=$(throw 'serverName is required.'), 
          [switch]$recurse, [string]$include="*", [string]$exclude=$null)

    Write-Verbose "Get-ISItem path:$path topLevelFolder:$topLevelFolder serverName:$serverName recurse:$($recurse.IsPresent) include:$include exclude:$exclude"

    #Note: Unlike SSMS, specify an instance name. There are some inconsistencies in the implementation of methods in the Application class
    #GetPackagesInfos unlike every other method expects a SQL instance as the server name while the other methods expect an Integration Services server.
    #This inconsistency applies to folder as well path where GetPackagesInfo defaults to the TopLevelFolders path defined in MsDtsSrvr.ini.xml and the 
    #other methods expect you to fully qualify the path with the TopLevelFolder name. There does not appear to be programatic way to determine the
    #TopLevelFolders which seems odd given that SSMS shows the top level folders. To workaround the TopLevelFolder issue we will pass the value as parameter

    $app = New-ISApplication

    if ($recurse.IsPresent)
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
function Test-ISPath
{
    param([string]$path=$(throw 'path is required.'), [string]$serverName=$(throw 'serverName is required.'), [string]$pathType='Any')

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
        default { throw 'pathType must be Package, Folder, or Any' }
    }

} #Test-ISPath

#######################
function New-ISItem
{
    param([string]$path=$(throw 'path is required.'), [string]$value=$(throw 'value is required.'), [string]$serverName=$(throw 'serverName is required.'))

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
function Rename-ISItem
{
    param([string]$path=$(throw 'path is required.'), [string]$oldName=$(throw 'oldName is required.'),
          [string]$newName=$(throw 'newName is required.'), [string]$serverName=$(throw 'serverName is required.'))

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
function Remove-ISItem
{
    param($pInfo, [switch]$whatIf)
    begin
    {
        #######################
        function Remove-ISChildItem
        {
            param($pInfo, [switch]$whatIf)

            $app = New-ISApplication
            #If serverName contains instance i.e. server\instance, convert to just servername:
            $serverName = $pInfo.serverName -replace "\\.*"
            switch ($pInfo.Flags)
            {
                'Package' { 
                            if (Test-ISPath $pInfo.literalPath $serverName 'Package')
                            { 
                                if ($whatIf.IsPresent)
                                { Write-Host "What if:RemoveFromDtsServer($($pInfo.literalPath),$serverName)" }
                                else
                                { $app.RemoveFromDtsServer($pInfo.literalPath,$serverName) }
                            }
                            else
                            { throw "Package $($pInfo.literalPath) does not exist on server $serverName" }
                          }
                'Folder'  { 
                            if (Test-ISPath $pInfo.literalPath $serverName 'Folder')
                            {
                                if ($whatIf.IsPresent)
                                { Write-Host "What if:RemoveFolderFromDtsServer($($pInfo.literalPath),$serverName)" }
                                else
                                { $app.RemoveFolderFromDtsServer($pInfo.literalPath,$serverName) }
                            }
                            else
                            { throw "Folder $($pInfo.literalPath) does not exist on server $serverName" }
                          }
            }
        } #Remove-ISChildItem
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'PackageInfo')
            { 
              Write-Verbose "Remove-ISChildItem $($_.literalPath) $($whatIf.IsPresent)"
              if ($whatif.IsPresent)
              { Remove-ISChildItem $_ -whatIf }
              else
              { Remove-ISChildItem $_ }
            }
            else
            { throw 'Remove-ISChildItem:Param pInfo must be a PackageInfo object.' }
        }
    }
    end
    {
        if ($pInfo)
        { 
            if ($whatIf.IsPresent)
            { $pInfo | Remove-ISChildItem -whatIf }
            else
            { $pInfo | Remove-ISChildItem }
        }
    }

} #Remove-ISItem

#######################
function Get-ISPackage
{
    param([string]$path, [string]$serverName)

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Get-ISPackage path:$path serverName:$serverName"

    $app = New-ISApplication

    #SQL Server Store
    if ($path -and $serverName)
    { 
        if (Test-ISPath $path $serverName 'Package')
        { $app.LoadFromDtsServer($path, $serverName, $null) }
        else
        { Write-Error "Package $path does not exist on server $serverName" }
    }
    #File Store
    elseif ($path -and !$serverName)
    { 
        if (Test-Path -literalPath $path)
        { $app.LoadPackage($path, $null) }
        else
        { Write-Error "Package $path does not exist" }
    }
    else
    { throw 'You must specify a file path or package store path and server name' }
    
} #Get-ISPackage

#######################
function Set-ISPackage
{
    param($package=$(throw 'package is required.'), [string]$path, [string]$serverName, [switch]$force)

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Set-ISPackage package:$($package.Name) path:$path serverName:$serverName"

    $app = New-ISApplication

    #SQL Server Store
    if ($path -and $serverName)
    { 
        if (!(Test-ISPath $path $serverName 'Package') -or $($force.IsPresent))
        { $app.SaveToDtsServer($package, $null, $path, $serverName) }
        else
        { throw "Package $path already exists on server $serverName" }
    }
    #File Store
    elseif ($path -and !$serverName)
    { 
        if (!(Test-Path -literalPath $path) -or $($force.IsPresent))
        { $app.SaveToXml($path, $package, $null) }
        else
        { throw "Package $path already exists" }
    }
    else
    { throw 'You must specify a file path or package store path and server name' }
    
} #Set-ISPackage

#######################
function Get-ISRunningPackage
{
    param($serverName=$(throw 'serverName is required.'))

    #If serverName contains instance i.e. server\instance, convert to just servername:
    $serverName = $serverName -replace "\\.*"

    Write-Verbose "Get-ISRunningPackage serverName:$serverName"

    $app = New-ISApplication

    $app.GetRunningPackages($serverName)

} #Get-ISRunningPackage

#######################
function Set-ISConnectionString
{
    param($package=$(throw 'package is required.'), $connectionInfo=$(throw 'value is required.'))

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
function Get-ISData
{
    param([string]$serverName=$(throw 'serverName is required.'), [string]$databaseName=$(throw 'databaseName is required.'),
          [string]$query=$(throw 'query is required.'))

    Write-Verbose "Get-ISData serverName:$serverName databaseName:$databaseName query:$query"

    $connString = "Server=$serverName;Database=$databaseName;Integrated Security=SSPI;"
    $da = New-Object "System.Data.SqlClient.SqlDataAdapter" ($query,$connString)
    $dt = New-Object "System.Data.DataTable"
    $da.fill($dt) > $null
    $dt

} #Get-ISData

#######################
function Get-ISSqlConfigurationItem
{
    param($serverName, $databaseName, [string]$configurationTable=$(throw 'configurationTable is required.'),
          [string]$configurationFilter=$(throw 'configurationFilter is required.'), [string]$packagePath=$(throw 'packagePath is required.'))

Write-Verbose "Get-ISSqlConfigurationItem serverName:$serverName db:$databaseName table:$configurationTable filer:$configurationFilter path:$packagePath query:$query"

$query = @"
Select ConfiguredValue FROM $configurationTable
 WHERE ConfigurationFilter = '$configurationFilter'
 AND PackagePath = '$packagePath'
"@

    $item = Get-ISData $serverName $databaseName $query
    $item | foreach { $_.ConfiguredValue }

} #Get-ISSqlPackageConfiguration
