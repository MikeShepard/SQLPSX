#######################
function Test-UserStore
{
    param([string]$fileName,[string]$dirName)

    $userStore = [System.IO.IsolatedStorage.IsolatedStorageFile]::GetUserStoreForAssembly()  

    if ($userStore.GetDirectoryNames($dirName))
    { 
        if ($userStore.GetFileNames("$dirName\$fileName"))
        { Write-Output $true }
        else
        { Write-Output $false }
    }
    else
    { Write-Output $false }
   
} #Test-UserStore

#######################
function Initialize-UserStore
{
    param([string]$fileName,[string]$dirName,[string]$defaultFile)

    if (-not (Test-UserSTore $fileName $dirName))
    { 
        $defaults = &"$defaultFile"
        Write-UserStore $fileName $dirName $defaults
    }

} #Initialize-UserStore
    
#######################
function Write-UserStore
{
    param([string]$fileName,[string]$dirName,$object)

    $userStore = [System.IO.IsolatedStorage.IsolatedStorageFile]::GetUserStoreForAssembly()  

    if (-not $userStore.GetDirectoryNames($dirName))
    { $userStore.CreateDirectory($dirName) }

    try {
        #$file = New-Object System.IO.IsolatedStorage.IsolatedStorageFileStream("$dirName\$fileName",[System.IO.FileMode]::OpenOrCreate,$userStore)
        if (Test-UserSTore $fileName $dirName)
        { $file = New-Object System.IO.IsolatedStorage.IsolatedStorageFileStream("$dirName\$fileName",[System.IO.FileMode]::Truncate,$userStore) }
        else
        { $file = New-Object System.IO.IsolatedStorage.IsolatedStorageFileStream("$dirName\$fileName",[System.IO.FileMode]::OpenOrCreate,$userStore) }
        
        if ($object -is [Hashtable])
        {
            $string = $object | ConvertTo-StringData
            $sw = New-Object System.IO.StreamWriter($file)
            $sw.Write($string)
            $sw.Close()
        }
        else
        {
            $object | where {$_.Password} | foreach {$_.Password = Protect-String $_.Password}
            $xml = $object | ConvertTo-Xml -noTypeInformation
            $xml.Save($file)
        }
    }
    finally {
        $file.Close()
        $userStore.Close()
    }


} #Write-UserStore

#######################
function Read-UserStore
{
    param([string]$fileName,[string]$dirName,[string]$typeName)

    $userStore = [System.IO.IsolatedStorage.IsolatedStorageFile]::GetUserStoreForAssembly()

    try {
        $file = New-Object System.IO.IsolatedStorage.IsolatedStorageFileStream("$dirName\$fileName",[System.IO.FileMode]::Open,$userStore)
    }
    catch {
        Write-Error "Cannot open file $dirName\$fileName"
        break
    }            

    try {

         if ($typeName -eq "Hashtable")
        {
            $sr = New-Object System.IO.StreamReader($file)
            $object = $sr.ReadToEnd()
            $sr.Close()
            invoke-expression "$object"
        }
        else
        {
            $xmlReader = New-Object System.Xml.XmlTextReader($file)
            $xml = New-Object System.Xml.XmlDocument
            $xml.Load($xmlReader)
            $object =  ConvertFrom-Xml -xml $xml
            $object | where {$_.Password} | foreach {$_.Password = UnProtect-String $_.Password}
            Write-Output $object
        }
    }
    finally { 
        $file.Close()
        $userStore.Close()
    }
    
} #Read-UserStore

#######################
function Remove-UserStore
{
    param([string]$fileName,[string]$dirName)

    $userStore = [System.IO.IsolatedStorage.IsolatedStorageFile]::GetUserStoreForAssembly()
    $userStore.DeleteFile("$dirName\$fileName")
    $userStore.DeleteDirectory("$dirName")
    $userStore.Close()

} #Remove-UserStore

#######################
function New-UserStore
{
    param([string]$dirName)

    $userStore = [System.IO.IsolatedStorage.IsolatedStorageFile]::GetUserStoreForAssembly()
    $userStore.CreateDirectory("$dirName")
    $userStore.Close()

} #New-UserStore
