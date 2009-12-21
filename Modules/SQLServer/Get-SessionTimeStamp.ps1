#### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Define function for getting a global Session TimeStamp 
### </Description>
### <Usage>
### Get-SessionTimeStamp
### </Usage>
### </Script>
# ---------------------------------------------------------------------------

    if (!(Test-Path Variable:__SQLPSXSessionTimeStamp))
    { 
        Set-Variable __SQLPSXSessionTimeStamp $((Get-Date).ToString("yyyy-MM-dd")) -Scope Global -Option AllScope -Description "SQLPSX variable"
    }

    Get-Variable __SQLPSXSessionTimeStamp -valueonly 
