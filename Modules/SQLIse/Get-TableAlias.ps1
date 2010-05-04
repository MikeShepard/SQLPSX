######################
function Resolve-TableAlias
{
    
    $sqlList = $psise.CurrentFile.Editor.Text -split '\n'

    $obj = '[\w]+|\"(?:[^\"]|\"\")+\"|\[(?:[^\]]|\]\])+\]'
    $re = "($obj)\.($obj)?\.($obj)(\s+.*$)?|(?:($obj)\.)?($obj)(\s+.*$)?"
    $from  = '(\bFROM\b|\bJOIN\b|\bUPDATE\b|\bINSERT\b(?:\s+INTO\b)?|\bDELETE\b)\s+(.*$)'

    foreach ($sql in $sqlList)
    {
        if ($sql -match $from)
        {
            $expression = $matches[2]
            $expression -match $re | out-null
            $db = $matches[1] -replace '\[|\]|"'
            $schema = $(invoke-coalesce $matches[2] $matches[5]) -replace '\[|\]|"'
            $dbObj = $(invoke-coalesce $matches[3] $matches[6]) -replace '\[|\]|"'
            $rest = $(invoke-coalesce $matches[4] $matches[7])
            if ($($rest -replace "'") -match "(\s+AS)?\s+(\w+)")
            { $alias = $matches[2] }
            
             new-object PSObject -Property @{
                Database = $db
                Schema = $schema
                Object = $dbObj
                Alias = $alias
             }
         }
    }
   
} #Resolve-TableAlias

######################
function Get-TableAlias
{
    $global:TableAlias = Resolve-TableAlias
    $global:TableAlias

} #Get-TableAlias
