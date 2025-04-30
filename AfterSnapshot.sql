

-- Step 15: Take a BEFORE snapshot
DECLARE @TableName NVARCHAR(255)
DECLARE TableCursor CURSOR FOR
SELECT [name]
FROM sys.tables
WHERE is_ms_shipped = 0 -- Skip system tables


-- Step 2: Take an AFTER snapshot
OPEN TableCursor
FETCH NEXT FROM TableCursor INTO @TableName

WHILE @@FETCH_STATUS = 0
BEGIN
	/*
    DECLARE @SQL2 NVARCHAR(MAX)
    SET @SQL2 = '
        INSERT INTO #TableSnapshots (TableName, SnapshotType, RowCounts)
        SELECT ''' + @TableName + ''', ''After'', COUNT(*)
        FROM [' + @TableName + ']
    ';
    EXEC sp_executesql @SQL2
	*/
	INSERT INTO TableSnapshots (TableName, RowCounts, SnapshotType)
	--no dynamic sql....nice. I will investigate why the 0 or 1 later. how exciting
    SELECT @TableName,
           ISNULL((
               SELECT SUM(p.row_count)
               FROM sys.dm_db_partition_stats p
               WHERE p.object_id = OBJECT_ID(@TableName)
                 AND (p.index_id = 0 OR p.index_id = 1)
           ), 0), 'After' ; -- Default to 0 if table is empty / missing

    FETCH NEXT FROM TableCursor INTO @TableName
END

CLOSE TableCursor
DEALLOCATE TableCursor;

-- Step 3: Compare the Before and After snapshots
WITH BeforeSnap AS (
    SELECT TableName, RowCounts AS RowCountBefore --, ChecksumValue AS ChecksumBefore
    FROM TableSnapshots
    WHERE SnapshotType = 'Before'
),
AfterSnap AS (
    SELECT TableName, RowCounts AS RowCountAfter --, ChecksumValue AS ChecksumAfter
    FROM TableSnapshots
    WHERE SnapshotType = 'After'
)
SELECT
    a.TableName,
    b.RowCountBefore,
    a.RowCountAfter,
    --b.ChecksumBefore,
    --a.ChecksumAfter,
    CASE
        WHEN b.RowCountBefore <> a.RowCountAfter THEN 'Row count changed'
        --WHEN b.ChecksumBefore <> a.ChecksumAfter THEN 'Data changed'
        ELSE 'No Change'
    END AS ChangeType
FROM AfterSnap a
LEFT JOIN BeforeSnap b ON a.TableName = b.TableName
WHERE 
    b.RowCountBefore <> a.RowCountAfter
    --OR b.ChecksumBefore <> a.ChecksumAfter
ORDER BY a.TableName
;

DROP TABLE dbo.TableSnapshots;
