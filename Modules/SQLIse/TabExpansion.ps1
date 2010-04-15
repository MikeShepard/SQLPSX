function tabexpansion
{
            param($line, $lastWord)
                ### START CUSTOM functions for SQLIse
                #######################
                function Write-DbObjects
                {
                     param($base,$objType,$expression)
                     
                     $objects = @()
                     $rawObjArray = $base -split '\.'
                     
                     switch ($rawObjArray.Count)
                     {
                        1 {$dbObj = $rawObjArray[0]}
                        2 {$schema = $rawObjArray[0]; $dbObj = $rawObjArray[1]}
                        3 {$db = $rawObjArray[0]; $schema = $rawObjArray[1]; $dbObj = $rawObjArray[2]}
                     }
                     
                     $expression = $expression.Trim("$dbObj")
                     $dbObj = $dbObj.Trim('*')
                     $dbObj = $dbObj + '%'
                     
                     switch ($rawObjArray.Count)
                     {
                       1 {$objQry = "Object like '$dbObj'"
                           $global:dsDbObjects.Tables["Database"].select("Database like '$dbObj'") | % {$objects += ,$_.Database}
                           $global:dsDbObjects.Tables["Schema"].select("Schema like '$dbObj'") | % {$objects += ,$_.Schema}}
                       2 {if ($schema = $global:conn.database) {
                            $objQry = "Object = '0'" 
                            $global:dsDbObjects.Tables["Schema"].select("Schema like '$dbObj'") | % {$objects += ,$_.Schema}}
                          else {$objQry = "Schema = '$schema' and Object like '$dbObj'"}}
                       3 {if ($schema) { $objQry = "Database = '$db' and Schema = '$schema' and Object like '$dbObj'"}
                           else {$objQry = "Database = '$db' and Object like '$dbObj'"}}
                     }

                     if ($objType -eq 'Table')
                     { $global:dsDbObjects.Tables["Table"].select($objQry) | % {$objects += ,$_.Object} }
                     else
                     { $global:dsDbObjects.Tables["Routine"].select($objQry) | % {$objects += ,$_.Object} }
                     
                     foreach ($object in $objects)
                     {
                        if ($object -notmatch 'True|False')
                        { $expression + $object }
                     }

                } #Write-DbObjects
                
                #######################
                function Write-Parmeters
                {
                     param($base,$pat)
                     
                     $objects = @()
                     $rawObjArray = $base -split '\.'
                     $pat = $pat.Trim('*')
                     $pat = $pat + '%'
                     
                     switch ($rawObjArray.Count)
                     {
                        1 {$dbObj = $rawObjArray[0] }
                        2 {$schema = $rawObjArray[0]; $dbObj = $rawObjArray[1]}
                        3 {$db = $rawObjArray[0]; $schema = $rawObjArray[1]; $dbObj = $rawObjArray[2]}
                     }
                     
                     switch ($rawObjArray.Count)
                     {
                       1 {$objQry = "Object = '$dbObj' and Parameter like '$pat'"}
                       2 {$objQry = "Schema = '$schema' and Object = '$dbObj' and Parameter like '$pat'"}
                       3 {if ($schema) { $objQry = "Database = '$db' and Schema = '$schema' and Object = '$dbObj' and Parameter like '$pat'"}
                           else {$objQry = "Database = '$db' and Object = '$dbObj' and Parameter like '$pat'"}}
                     }


                     $global:dsDbObjects.Tables["Parameter"].select($objQry) | % {$objects += ,$_.Parameter}
                      
                     foreach ($object in $objects)
                     {
                        if ($object -notmatch 'True|False')
                        {$object }
                     }

                } #Write-Parmeters

                #######################
                function Write-Columns
                {
                    param($base,$pat,$tableList)

                    $objects = @()
                    $pat = $pat.Trim('*')
                    $pat = $pat + '%'
                    $objQry = ''
                    
                    if ($tableList | where {$_.Alias -eq $base})
                    { $tables = $tableList | where {$_.Alias -eq $base} } 
                    else
                    { $tables = $tableList | where {$_.Object -eq $base} } 

                    foreach ($table in $tables)
                    {
                        if ($table.Database) {$objQry += "Database = '$($table.Database)' AND "}
                        if ($table.Schema) {$objQry += "Schema = '$($table.Schema)' AND "}
                        $objQry += "Object = '$($table.Object)' AND Column like '$pat'"
                    }

                    $global:dsDbObjects.Tables["Column"].select($objQry) | % {$objects += ,$_.Column}
          
                    foreach ($object in $objects)
                    {
                        if ($object -notmatch 'True|False')
                        {$base + '.' + $object }
                    }


                } #Write-Columns

                #######################
                function Invoke-Coalesce
                {
                    param ($expression1, $expression2)

                    if ($expression1)
                    { $expression1 }
                    else
                    { $expression2 }

                } #Invoke-Coalesce

                ######################
                function Get-TableList
                {
                    
                    param($sqlList)

                    $obj = '[\w]+|\"(?:[^\"]|\"\")+\"|\[(?:[^\]]|\]\])+\]'
                    $re = "($obj)\.($obj)?\.($obj)(\s+AS\s+[']*(\w+)[']*)?|(?:($obj)\.)?($obj)(\s+AS\s+[']*(\w+)[']*)?"
                    $from  = '(\bFROM\b|\bJOIN\b|\bUPDATE\b|\bINSERT\b|\bDELETE\b)\s+(.*$)'

                    foreach ($sql in $sqlList)
                    {
                        if ($sql -match $from)
                        {
                            $expression = $matches[2]
                            $expression -match $re | out-null
                            $db = $matches[1] -replace '\[|\]|"'
                            $schema = $(invoke-coalesce $matches[2] $matches[6]) -replace '\[|\]|"'
                            $dbObj = $(invoke-coalesce $matches[3] $matches[7]) -replace '\[|\]|"'
                            $alias = $(invoke-coalesce $matches[5] $matches[9])

                             new-object PSObject -Property @{
                                Database = $db
                                Schema = $schema
                                Object = $dbObj
                                Alias = $alias
                             }
                         }
                    }
                   
                } #Get-TableList

                ### END CUSTOM functions for SQLIse

                switch -regex ($line)
                {
                    ### START CUSTOM Code for SQLIse
                    '(\bFROM\b|\bJOIN\b|\bUPDATE\b|\bINSERT\b|\bDELETE\b)\s+(.*$)' {
                        $expression = $matches[2] #Original expression
                        $base = $matches[2] -replace '\[|\]|"' #Normalized Object
                        Write-DbObjects -base $base -objType 'Table' -expression $expression
                        break;
                    }
                    '(?<![\w\@\#\$])EXEC(UTE)?\s+(\@.+?=\s*)?([^@]+)' {
                        $expression = $matches[3] #Original expression
                        $base = $matches[3] -replace '\[|\]|"' #Normalized Object
                        Write-DbObjects -base $base -objType 'Proc' -expression $expression
                        break;
                    }
                    ### END CUSTOM Code for SQLIse
                 }

                 switch -regex ($lastWord)
                 {
                    ### START CUSTOM Code for SQLIse
                    '^@([*\w0-9]*)' {
                        $pat = $matches[1] + '*'
                        $line -match '(?<![\w\@\#\$])EXEC(UTE)?\s+(\@.+?=\s*)?([^(\s]+)' | out-null
                        $base = $matches[3] -replace '\[|\]|"' #Normalized Object
                        Write-Parmeters -base $base -pat $pat
                        break;
                    }
                 
                    '(?<![\$])(\w)+\.(\w*)' {
                            $base = $matches[1]
                            $pat = $matches[2] + '*'
                            $sqlList = $psise.CurrentFile.Editor.Text
                            $tableList = Get-TableList $sqlList
                            if ($tableList | where {$_.Object -eq $base -or $_.Alias -eq $base})
                            {
                                Write-Columns -base $base -pat $pat -tableList $tableList
                                break;
                            }
                      }
                   }

                    ### END CUSTOM Code for SQLIse
}
