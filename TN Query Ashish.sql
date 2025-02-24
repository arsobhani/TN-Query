WITH CTE_ProcText1 AS (
    SELECT value AS LineText
    FROM STRING_SPLIT(
        CAST(OBJECT_DEFINITION(OBJECT_ID('SBO_SP_TransactionNotification_AR')) AS NVARCHAR(MAX)),
        CHAR(10)
    )
)
SELECT LineText
FROM CTE_ProcText1
WHERE LineText LIKE '%SET @error%' OR LineText LIKE '%/n SET @error_message%'   OR LineText LIKE '%SELECT @error%' OR LineText LIKE '%/n @error_message%'
go
WITH CTE_ProcText AS (
    SELECT LTRIM(RTRIM(value)) AS LineText
    FROM STRING_SPLIT(
        CAST(OBJECT_DEFINITION(OBJECT_ID('SBO_SP_TransactionNotification_AR')) AS NVARCHAR(MAX)),
        CHAR(10)
    )
)
SELECT distinct
    CASE
        WHEN CHARINDEX('@Error =', LineText) > 0
        THEN SUBSTRING(LineText, CHARINDEX('@Error =', LineText) + 9,
                        CHARINDEX(',', LineText + ',') - CHARINDEX('@Error =', LineText) - 9)
    END AS ErrorCode,
    CASE
        WHEN CHARINDEX('@error_message =', LineText) > 0
        THEN SUBSTRING(LineText, CHARINDEX('@error_message =', LineText) + 17, LEN(LineText))
    END AS ErrorMessage
FROM CTE_ProcText
WHERE
LineText LIKE '%SET @error%' OR LineText LIKE '%/n SET @error_message%'   OR LineText LIKE '%SELECT @error%' OR LineText LIKE '%/n @error_message%'
--LineText LIKE '%@Error%'  and LineText LIKE '%@error_message%'

