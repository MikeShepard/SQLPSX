New-ListBox -MaxHeight 350 -DataContext {
    Get-PowerShellDataSource -Script {
        Get-Process | ForEach-Object { $_ ; Start-Sleep -Milliseconds 100 }
    }
} -DataBinding @{
    ItemsSource = New-Binding -IsAsync -UpdateSourceTrigger PropertyChanged -Path Output
} -On_Loaded {
    Register-PowerShellCommand -Run -In "0:0:2.5" -ScriptBlock {
        $window.Content.DataContext.Script = $window.Content.DataContext.Script
    }
} -asjob