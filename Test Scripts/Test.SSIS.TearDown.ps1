get-isitem '\sqlpsx' 'msdb' "$env:computername\sql2k8"  | remove-isitem
get-isitem '\sqlpsx2' 'msdb' "$env:computername\sql2k8"  | remove-isitem
get-isitem '\' 'msdb' "$env:computername\sql2k8" | ?{$_.name -like "sqlpsx*"} | remove-isitem
remove-item c:\users\u00\bin\SSIS\*.dtsx

