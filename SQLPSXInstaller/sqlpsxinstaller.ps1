$env:SQLPSX = "C:\Users\u00\Projects\SQLPSX\trunk\SQLPSXInstaller\Modules"

heat dir "$($env:SQLPSX)\adoLib" -nologo -sfrag -suid -ag -srd -dir adoLib -out adoLib.wxs -cg adoLib -dr adoLib -var var.adoLib
heat dir "$($env:SQLPSX)\Agent" -nologo -sfrag -suid -ag -srd -dir Agent -out Agent.wxs -cg Agent -dr Agent -var var.Agent
heat dir "$($env:SQLPSX)\ISECreamBasic" -nologo -sfrag -suid -ag -srd -dir ISECreamBasic -out ISECreamBasic.wxs -cg ISECreamBasic -dr ISECreamBasic -var var.ISECreamBasic
heat dir "$($env:SQLPSX)\OracleClient" -nologo -sfrag -suid -ag -srd -dir OracleClient -out OracleClient.wxs -cg OracleClient -dr OracleClient -var var.OracleClient
heat dir "$($env:SQLPSX)\OracleIse" -nologo -sfrag -suid -ag -srd -dir OracleIse -out OracleIse.wxs -cg OracleIse -dr OracleIse -var var.OracleIse
heat dir "$($env:SQLPSX)\Repl" -nologo -sfrag -suid -ag -srd -dir Repl -out Repl.wxs -cg Repl -dr Repl -var var.Repl
heat dir "$($env:SQLPSX)\ShowMbrs" -nologo -sfrag -suid -ag -srd -dir ShowMbrs -out ShowMbrs.wxs -cg ShowMbrs -dr ShowMbrs -var var.ShowMbrs
heat dir "$($env:SQLPSX)\SQLIse" -nologo -sfrag -suid -ag -srd -dir SQLIse -out SQLIse.wxs -cg SQLIse -dr SQLIse -var var.SQLIse
heat dir "$($env:SQLPSX)\SQLMaint" -nologo -sfrag -suid -ag -srd -dir SQLMaint -out SQLMaint.wxs -cg SQLMaint -dr SQLMaint -var var.SQLMaint
heat dir "$($env:SQLPSX)\SQLParser" -nologo -sfrag -suid -ag -srd -dir SQLParser -out SQLParser.wxs -cg SQLParser -dr SQLParser -var var.SQLParser
heat dir "$($env:SQLPSX)\SQLParser\en-US" -nologo -sfrag -suid -ag -srd -dir en-US -out en-US.wxs -cg en_US -dr en-US -var var.en
heat dir "$($env:SQLPSX)\SQLPSX" -nologo -sfrag -suid -ag -srd -dir SQLPSX -out SQLPSX.wxs -cg SQLPSX -dr SQLPSX -var var.SQLPSX
heat dir "$($env:SQLPSX)\SQLServer" -nologo -sfrag -suid -ag -srd -dir SQLServer -out SQLServer.wxs -cg SQLServer -dr SQLServer -var var.SQLServer
heat dir "$($env:SQLPSX)\SQLServer\Database" -nologo -sfrag -suid -ag -srd -dir Database -out Database.wxs -cg Database -dr Database -var var.Database
heat dir "$($env:SQLPSX)\SQLServer\Reports" -nologo -sfrag -suid -ag -srd -dir Reports -out Reports.wxs -cg Reports -dr Reports -var var.Reports
heat dir "$($env:SQLPSX)\SSIS" -nologo -sfrag -suid -ag -srd -dir SSIS -out SSIS.wxs -cg SSIS -dr SSIS -var var.SSIS
heat dir "$($env:SQLPSX)\WPK" -nologo -sfrag -suid -ag -srd -dir WPK -out WPK.wxs -cg WPK -dr WPK -var var.WPK
heat dir "$($env:SQLPSX)\WPK\Examples" -nologo -sfrag -suid -ag -srd -dir Examples -out Examples.wxs -cg Examples -dr Examples -var var.Examples
heat dir "$($env:SQLPSX)\WPK\GeneratedControls" -nologo -sfrag -suid -ag -srd -dir GeneratedControls -out GeneratedControls.wxs -cg GeneratedControls -dr GeneratedControls -var var.GeneratedControls
heat dir "$($env:SQLPSX)\WPK\Rules" -nologo -sfrag -suid -ag -srd -dir Rules -out Rules.wxs -cg Rules -dr Rules -var var.Rules

#Download Install sed
#http://gnuwin32.sourceforge.net/
set-alias -Name sed -Value "C:\Program Files (x86)\GnuWin32\bin\sed.exe"
dir *.wxs -Exclude sqlpsxAll.wxs | foreach {sed -e "2i <?include `$(sys.CURRENTDIR)\\Config.wxi?>" -i $_.Name}
remove-item sed*

#candle.exe sqlpsxAll.wxs adolib.wxs Agent.wxs ISECreamBasic.wxs OracleClient.wxs OracleIse.wxs Repl.wxs ShowMbrs.wxs SQLIse.wxs SQLMaint.wxs SQLParser.wxs en-US.wxs SQLPSX.wxs SQLServer.wxs Database.wxs Reports.wxs SSIS.wxs WPK.wxs Examples.wxs GeneratedControls.wxs Rules.wxs
#Fix duplicate files in ISECreamBasic and OralceISE -- give unique prefix ICB and Ora

candle.exe sqlpsxAll.wxs adolib.wxs Agent.wxs ISECreamBasic.wxs OracleClient.wxs OracleIse.wxs Repl.wxs ShowMbrs.wxs SQLIse.wxs SQLMaint.wxs SQLParser.wxs SQLPSX.wxs SQLServer.wxs SSIS.wxs WPK.wxs

#light.exe -ext WixUIExtension -out SQLPSX.msi sqlpsxAll.wixobj adolib.wixobj Agent.wixobj ISECreamBasic.wixobj OracleClient.wixobj OracleIse.wixobj Repl.wixobj ShowMbrs.wixobj SQLIse.wixobj SQLMaint.wixobj SQLParser.wixobj en-US.wixobj SQLPSX.wixobj SQLServer.wixobj Database.wixobj Reports.wixobj SSIS.wixobj WPK.wixobj Examples.wixobj GeneratedControls.wixobj Rules.wixobj
light.exe -ext WixUIExtension -out SQLPSX.msi sqlpsxAll.wixobj adolib.wixobj Agent.wixobj ISECreamBasic.wixobj OracleClient.wixobj OracleIse.wixobj Repl.wixobj ShowMbrs.wixobj SQLIse.wixobj SQLMaint.wixobj SQLParser.wixobj SQLPSX.wixobj SQLServer.wixobj SSIS.wixobj WPK.wixobj -b "$($env:SQLPSX)"
