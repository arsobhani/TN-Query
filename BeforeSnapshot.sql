

/*
-- Step 0: Create a table to store snapshots
IF OBJECT_ID('tempdb..#TableSnapshots') IS NOT NULL
    DROP TABLE #TableSnapshots;



CREATE TABLE #TableSnapshots (
    TableName NVARCHAR(255),
    SnapshotType NVARCHAR(50),
    RowCounts INT,
    --ChecksumValue BIGINT
);
*/

IF OBJECT_ID('dbo.TableSnapshots', 'U') IS NOT NULL DROP TABLE dbo.TableSnapshots;

CREATE TABLE dbo.TableSnapshots (TableName NVARCHAR(255), SnapshotType NVARCHAR(50), RowCounts BIGINT);


-- Step 1: Take a BEFORE snapshot
DECLARE @TableName NVARCHAR(255)
DECLARE TableCursor CURSOR FOR
SELECT [name]
FROM sys.tables
WHERE is_ms_shipped = 0 -- Skip system tables

OPEN TableCursor
FETCH NEXT FROM TableCursor INTO @TableName

WHILE @@FETCH_STATUS = 0
BEGIN
	/*
    DECLARE @SQL NVARCHAR(MAX)
    SET @SQL = '
        INSERT INTO #TableSnapshots (TableName, SnapshotType, RowCounts) --, ChecksumValue)
        SELECT ''' + @TableName + ''', ''Before'', COUNT(*)
        FROM [' + @TableName + ']
    ';
    EXEC sp_executesql @SQL
	*/
	INSERT INTO TableSnapshots (TableName, RowCounts, SnapshotType)
    SELECT @TableName,
           ISNULL((
               SELECT SUM(p.row_count)
               FROM sys.dm_db_partition_stats p
               WHERE p.object_id = OBJECT_ID(@TableName)
                 AND (p.index_id = 0 OR p.index_id = 1)
           ), 0), 'Before' ; -- Default to 0 if table is empty / missing

    FETCH NEXT FROM TableCursor INTO @TableName
END

CLOSE TableCursor
DEALLOCATE TableCursor

-- *** NOW PAUSE HERE ***
-- Run your DI API Add/Update operation

