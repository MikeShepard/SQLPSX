$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
[Reflection.Assembly]::LoadFile("$scriptRoot\Microsoft.Data.Schema.ScriptDom.dll") > $null
[Reflection.Assembly]::LoadFile("$scriptRoot\Microsoft.Data.Schema.ScriptDom.Sql.dll") > $null

 if (!(Get-PSSnapin -registered | ?{$_.name -eq 'SQLParser'}))
 {
    $framework=$([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
    Set-Alias installutil "$($framework)installutil.exe"
    installutil "$scriptRoot\SQLParser.dll"
 }

 if (!(Get-PSSnapin | ?{$_.name -eq 'SQLParser'}))
 { Add-PSSnapin SqlParser }
