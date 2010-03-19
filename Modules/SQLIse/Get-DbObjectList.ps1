$db = @"
SELECT db_name() AS 'Database';
"@
$pk = @"
SELECT kcu.TABLE_SCHEMA + '.' + kcu.TABLE_NAME AS 'Table', kcu.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
ON kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY kcu.COLUMN_NAME;
"@

$fk = @"
SELECT DISTINCT C.TABLE_SCHEMA + '.' + C.TABLE_NAME AS 'Table', 
C2.TABLE_SCHEMA + '.' + C2.TABLE_NAME AS 'Relation'
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS C 
INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS RC 
ON C.CONSTRAINT_SCHEMA = RC.CONSTRAINT_SCHEMA 
AND C.CONSTRAINT_NAME = RC.CONSTRAINT_NAME 
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS C2 
ON RC.UNIQUE_CONSTRAINT_SCHEMA = C2.CONSTRAINT_SCHEMA 
AND RC.UNIQUE_CONSTRAINT_NAME = C2.CONSTRAINT_NAME 
WHERE  C.CONSTRAINT_TYPE = 'FOREIGN KEY';
"@

$col = @"
SELECT col.TABLE_SCHEMA + '.' + col.TABLE_NAME AS 'Table', COLUMN_NAME + ' (' +
CASE WHEN CHARACTER_MAXIMUM_LENGTH > 0 THEN DATA_TYPE + '(' +  CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR(4)) + ')'
ELSE DATA_TYPE END + ',' +
CASE IS_NULLABLE
WHEN 'YES' THEN 'null'
WHEN 'NO' THEN 'not null'
END + ')' AS 'Column'
FROM INFORMATION_SCHEMA.COLUMNS col
WHERE TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
ORDER BY col.TABLE_SCHEMA, col.TABLE_NAME, ORDINAL_POSITION;
"@

$tbl = @"
SELECT TABLE_CATALOG AS 'Database', TABLE_SCHEMA + '.' + TABLE_NAME AS 'Table'
FROM INFORMATION_SCHEMA.TABLES class
WHERE TABLE_TYPE = 'BASE TABLE'
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"@

$op = @"
IF convert(varchar(100),serverproperty('ProductVersion')) like '8%'
BEGIN
    SELECT 
    TABLE_SCHEMA + '.' + TABLE_NAME AS 'Table',
    CONSTRAINT_NAME + '(' + CONSTRAINT_TYPE + ')' AS operation
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA IS NOT NULL
    UNION
    SELECT USER_NAME(uid) + '.' + OBJECT_NAME(parent_obj) AS 'Table', name + '(Trigger)'
    FROM sysobjects
    WHERE type = 'TR'
    UNION
    SELECT (SELECT USER_NAME(o.uid) FROM sysobjects o WHERE o.id = i.id) + '.' + OBJECT_NAME(id) AS 'Table', name + '(Index)'
    FROM sysindexes i
    LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    ON TABLE_SCHEMA = (SELECT USER_NAME(o.uid) FROM sysobjects o WHERE o.id = i.id)
    AND TABLE_NAME = OBJECT_NAME(id)
    AND CONSTRAINT_NAME = name
    WHERE OBJECTPROPERTY(id,'IsMSShipped') = 0
    AND name IS NOT NULL
    AND TABLE_SCHEMA IS NULL
    ORDER BY operation
END
ELSE
BEGIN
    SELECT 
    TABLE_SCHEMA + '.' + TABLE_NAME AS 'Table',
     CONSTRAINT_NAME + '(' + CONSTRAINT_TYPE + ')' AS operation
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA IS NOT NULL
    UNION
    SELECT OBJECT_SCHEMA_NAME(parent_obj) + '.' + OBJECT_NAME(parent_obj) AS 'Table', name + '(Trigger)'
    FROM sysobjects
    WHERE type = 'TR'
    UNION
    SELECT OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) AS 'Table', name + '(Index)'
    FROM sys.indexes
    LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    ON TABLE_SCHEMA = OBJECT_SCHEMA_NAME(object_id)
    AND TABLE_NAME = OBJECT_NAME(object_id)
    AND CONSTRAINT_NAME = name
    WHERE OBJECTPROPERTY(object_id,'IsMSShipped') = 0
    AND name IS NOT NULL
    AND TABLE_SCHEMA IS NULL
    ORDER BY operation
END;
"@

$cmd = @"
$db
$tbl
$col
$pk
$fk
$op
"@

$connString = "Data Source=Z002\SQL2K8;Initial Catalog=AdventureWorks;Integrated Security=true;"

$ds = New-Object system.Data.DataSet
$da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd,$connString)

$da.TableMappings.Add("Table", "Database")
$da.TableMappings.Add("Table1", "Table")
$da.TableMappings.Add("Table2", "Column")
$da.TableMappings.Add("Table3", "Keys")
$da.TableMappings.Add("Table4", "Relations")
$da.TableMappings.Add("Table5", "Operations")

$da.Fill($ds)

$database = $ds.Tables["Database"]
$table = $ds.Tables["Table"]
$column = $ds.Tables["Column"]
$keys = $ds.Tables["Keys"]
$relations = $ds.Tables["Relations"]
$operations = $ds.Tables["Operations"]

$database2Table = new-object System.Data.DataRelation -ArgumentList "Database2Table",$database.Columns["Database"],$table.Columns["Database"],$false
$ds.Relations.Add($database2Table)

$table2Column = new-object System.Data.DataRelation -ArgumentList "Table2Column",$table.Columns["Table"],$column.Columns["Table"],$false
$ds.Relations.Add($table2Column)

$table2Keys = new-object System.Data.DataRelation -ArgumentList "Table2Keys",$table.Columns["Table"],$keys.Columns["Table"],$false
$ds.Relations.Add($table2Keys)

$table2Relations = new-object System.Data.DataRelation -ArgumentList "Table2Relations",$table.Columns["Table"],$relations.Columns["Table"],$false
$ds.Relations.Add($table2Relations)

$table2Operations = new-object System.Data.DataRelation -ArgumentList "Table2Operations",$table.Columns["Table"],$operations.Columns["Table"],$false
$ds.Relations.Add($table2Operations)