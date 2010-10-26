1. Create an empty SQL Server database (or use existing database). For example "MDW"
2. Run the 2 table creation scripts dbo.PolicyEval.Table and dbo.PolicyEvalError.Table.sql
3. Copy PBM PowerShell module folder to a directory listed in your $env:psmodulepath
4. Modify PBM.psm1 Script-level variables to point to the server and database created in step 1
5. Import Policies from Policies folder or use your existing policy
6. Ensure policies have a Category set
    
    In SSMS >> Policy Management >> Policies >> <YOUR POLICY> >> Select Description Tabl

7. Source the module in sqlps (The SQL Server Mini-Shell). For example:
    
    . C:\Users\u00\Documents\WindowsPowerShell\Modules\PBM\PBM.psm1

8. Run Import-PolicyEvaluation specifying a ConfigurationGroup (the CMS Server Registration Group) and PolicyCategoryFilter (as defined in step 6)
   For example:
    
    Import-PolicyEvaluation "XA" "EPM: Configuration"

9. Optionally create SQL Agent job for each configuration group with the following PowerShell Job Step:

. C:\<path-to-module>\PBM.psm1
Import-PolicyEvaluation "XA" "EPM: Configuration"
