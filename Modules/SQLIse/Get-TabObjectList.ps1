function Get-TabObjectList
{
    $db = @"
SELECT db_name() AS 'Database';
"@
    $col = @"
SELECT TABLE_CATALOG AS 'Database', TABLE_SCHEMA AS 'Schema', TABLE_NAME AS 'Object',
COLUMN_NAME AS 'Column'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;
"@

    $tbl = @"
SELECT TABLE_CATALOG AS 'Database', TABLE_SCHEMA AS 'Schema', TABLE_NAME AS 'Object'
FROM INFORMATION_SCHEMA.TABLES
WHERE OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
UNION
SELECT  ROUTINE_CATALOG, ROUTINE_SCHEMA, ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE =  'FUNCTION'
ORDER BY [Database], [Schema], [Object];
"@

    $rtn = @"
SELECT  ROUTINE_CATALOG AS 'Database', ROUTINE_SCHEMA AS 'Schema', ROUTINE_NAME AS 'Object'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE =  'PROCEDURE'
ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME;
"@

    $prm = @"
SELECT SPECIFIC_CATALOG AS 'Database', SPECIFIC_SCHEMA AS 'Schema', SPECIFIC_NAME AS 'Object',
PARAMETER_NAME AS 'Parameter'
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE PARAMETER_NAME IS NOT NULL AND PARAMETER_NAME != ''
ORDER BY SPECIFIC_CATALOG, SPECIFIC_SCHEMA, SPECIFIC_NAME, PARAMETER_NAME;
"@

    $sch = @"
SELECT CATALOG_NAME AS 'Database', SCHEMA_NAME AS 'Schema'
FROM INFORMATION_SCHEMA.SCHEMATA 
ORDER BY SCHEMA_NAME
"@    
    $cmd = @"
$db
$tbl
$col
$rtn
$prm
$sch
"@

    $global:dsDbObjects = New-Object system.Data.DataSet
    $da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd,$conn)

    [void]$da.TableMappings.Add("Table", "Database")
    [void]$da.TableMappings.Add("Table1", "Table")
    [void]$da.TableMappings.Add("Table2", "Column")
    [void]$da.TableMappings.Add("Table3", "Routine")
    [void]$da.TableMappings.Add("Table4", "Parameter")
    [void]$da.TableMappings.Add("Table5", "Schema")

    [void]$da.Fill($global:dsDbObjects)

}
