USE [LNM_SAPB1_PROD_DAILY]


--DECLARE @SearchText NVARCHAR(100) = 'Customers'

--Chapter 1
DECLARE @TransactionNotification TABLE (ProcedureName NVARCHAR(100), ProcedureDefinition NVARCHAR(MAX))
--DECLARE @TNRules TABLE (SqlFile NVARCHAR(100), ObjectType NVARCHAR(5), TransactionType NVARCHAR(5), ErrorNumber INT, ErrorMessage NVARCHAR(100))
--Chapter 2
DECLARE @TNIndex TABLE (Idx INT, Variable NVARCHAR(5), SqlFile NVARCHAR(100))
--Chapter 3
DECLARE @TNRules TABLE (SqlFile NVARCHAR(100), ObjectType NVARCHAR(100), TransactionType NVARCHAR(100), ErrorNumber NVARCHAR(100), ErrorMessage NVARCHAR(100), Idx INT)
--this one required? sure....no
--DECLARE @TNStrings TABLE (SQLFile NVARCHAR(100), TNString NVARCHAR(MAX))


--Create table with file contents
INSERT INTO @TransactionNotification
SELECT 
    --OBJECT_SCHEMA_NAME(o.object_id) AS SchemaName,
    --o.object_id AS SchemaName,
    o.name AS ProcedureName,
    m.definition AS ProcedureDefinition
FROM 
    sys.sql_modules m
INNER JOIN 
    sys.objects o ON m.object_id = o.object_id
WHERE 
    o.type = 'P' -- P for stored procedure
    --AND m.definition LIKE '%' + 'EXISTS' + '%'
	AND o.name LIKE 'SBO_SP_TransactionNotification%';


/*To check if the whole thing is caught in this stage....it is
DECLARE @TempDef NVARCHAR(MAX)
SET @TempDef = (SELECT TOP 1 ProcedureDefinition FROM @TransactionNotification WHERE ProcedureName = 'SBO_SP_TransactionNotification_AP');
PRINT LEN(@TempDef);
*/
--SELECT * FROM @TransactionNotification


--Chapter 1 finished....

--==============================================================================================================

--Iterate through each file and parse for information
DECLARE @TNFileName NVARCHAR(100)
DECLARE @TNFile NVARCHAR(MAX)

--Create numbers table, 1 to a million...or can be elegant and do it in the loop...but is it more efficient this way?

DECLARE db_cursor CURSOR FOR 
SELECT * FROM @TransactionNotification

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @TNFileName, @TNFile

WHILE @@FETCH_STATUS = 0
BEGIN
    --Iterate again??
	--use parse function probably better
	--lowercase string to reduce chaos
	SET @TNFile = LOWER(@TNFile);
    --PRINT @TNFileName;
-------------------------------------------------------------------------
	DECLARE @Substring VARCHAR(100) = '@transaction_type'; 
	--have to add the filename later
	DROP TABLE IF EXISTS #TempTable
	CREATE TABLE #TempTable (Idx INT, Variable NVARCHAR(5), SqlFile NVARCHAR(100)); --Variable NVARCHAR DEFAULT 'T');
	--creates list of numbers 1 to len(@TNFile)
	--this is ai method, need to adapt it accordingly
	--PRINT(LEN(@TNFile));
	--DECLARE @TempNum INT;
	--SET @TempNum = (SELECT TOP 1 * FROM (SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N FROM sys.objects));
	--PRINT(@TempNum);
	/*
	SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
	FROM sys.objects;
	*/
	--Create proper numbers table...sorry AI, you did this one wrong
	DECLARE @Numbers TABLE (Number INT);
	DECLARE @TempNum INT;
	SET @TempNum = 1;
	WHILE (@TempNum < LEN(@TNFile) + 1)
	BEGIN
		INSERT INTO @Numbers (Number)
		SELECT @TempNum;

		SET @TempNum = @TempNum + 1;
	END;
	--Bingo
	--SELECT * FROM @Numbers;
	
	WITH Numbers AS (
		SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
		FROM sys.objects
	)

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	WHERE SUBSTRING(@TNFile, Number, LEN(@Substring)) = @Substring

	

	--ALTER TABLE #TempTable
	--ADD Variable NVARCHAR, SqlFile NVARCHAR(100);

	UPDATE #TempTable
	SET #TempTable.Variable = 'T', SqlFile = @TNFileName;

	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable

	--SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
	--FROM tempdb.INFORMATION_SCHEMA.COLUMNS
	--WHERE TABLE_NAME LIKE '#TempTable%'

	--SELECT * FROM #TempTable
	
--------------------------------------------------------
	SET @Substring = '@object_type'
	--clear the table
	TRUNCATE TABLE #TempTable;

	--CREATE TABLE #TempTable (Idx INT, Variable NVARCHAR(5), SqlFile NVARCHAR(100)); --Variable NVARCHAR DEFAULT 'T');
	
	WITH Numbers AS (
		SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
		FROM sys.objects
	)
	

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	WHERE SUBSTRING(@TNFile, Number, LEN(@Substring)) = @Substring

	
	UPDATE #TempTable
	SET #TempTable.Variable = 'O', SqlFile = @TNFileName;
	
	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable;

-----------------------------------------------------------------------------------------------

	--use space because there is overlap with other variable
	--space doesnt matter
	--WHOAAAAAA dude we have the case where @error=...this was stopping us yo...use 
	SET @Substring = '@error';
	TRUNCATE TABLE #TempTable;

	--PRINT (LEN(@Substring));
	
	WITH Numbers AS (
		SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
		FROM sys.objects
	)
	

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	--made change to fix error overlap with error_message
	--do + 1 to check one more spot for the '_' char
	WHERE (SUBSTRING(@TNFile, Number, LEN(@Substring) + 1) = @Substring + ' ') OR (SUBSTRING(@TNFile, Number, LEN(@Substring) + 1) = @Substring + '=') --AND (SUBSTRING(@TNFile, N, LEN(@Substring)) NOT LIKE '@error_%')
	--'\b@error\b(?!_)'
	
	UPDATE #TempTable
	SET #TempTable.Variable = 'E', SqlFile = @TNFileName;
	
	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable
---------------------------------------------------------------------------------------------

	SET @Substring = '@error_message'
	TRUNCATE TABLE #TempTable;
	
	WITH Numbers AS (
		SELECT TOP (LEN(@TNFile)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
		FROM sys.objects
	)

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	WHERE SUBSTRING(@TNFile, Number, LEN(@Substring)) = @Substring

	
	UPDATE #TempTable
	SET #TempTable.Variable = 'EM', SqlFile = @TNFileName;
	
	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable


    FETCH NEXT FROM db_cursor INTO @TNFileName, @TNFile
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

DROP TABLE IF EXISTS #TempTable

--Chapter 2 Complete

--======================================================================================
--====================================================================================================

--this part requires a PHD
/*
SELECT * FROM @TNIndex
--can sort by two different priorities...awesome
--WHERE SqlFile = 'SBO_SP_TransactionNotification_AP'
ORDER BY SqlFile ASC, Idx ASC
*/

--to extract from @TNIndex
--using SqlFile in both tables
DECLARE @Idx INT, @Variable NVARCHAR(5), @SqlFile NVARCHAR(100)
--to insert into @TNRules
DECLARE @ObjectType NVARCHAR(100), @TransactionType NVARCHAR(100), @ErrorNumber NVARCHAR(100), @ErrorMessage NVARCHAR(100)
SELECT @ObjectType = NULL, @TransactionType = NULL, @ErrorNumber = NULL, @ErrorMessage = NULL;
 
 
DECLARE db_cursor2 CURSOR FOR 
SELECT * FROM @TNIndex
ORDER BY SqlFile ASC, Idx ASC;

OPEN db_cursor2
FETCH NEXT FROM db_cursor2 INTO @Idx, @Variable, @SqlFile

--Instead of creating so many variables and making sure the datatypes match, 
--I could create a 'table' to inherit the datatypes and just put one entry in the table, then clear it and use again...too late now I think though

--could use NULLs instead of this
DECLARE @variableState INT;
--states for which variables have been established...
--0 : no transaction type or no object type // existence of IN should mean both are on same line...
--1 : both transaction type and object type are established
--2 : one TN error has been established


--only need 2 states I believe
SET @variableState = 0;
WHILE @@FETCH_STATUS = 0
BEGIN
	--this will be slow...
	--create a version without spaces...
	--no...cant do this...the indexes will get messed up...unless we do it THIS way
	DECLARE @SqlContents NVARCHAR(MAX);
	DECLARE @NewSqlContents NVARCHAR(MAX);
	SET @SqlContents = (SELECT TOP 1 ProcedureDefinition FROM @TransactionNotification WHERE ProcedureName = @SqlFile)
	--PRINT(@SqlContents)
	--make new string without spaces, but index still works
	--do full length? or cut off at about 100 maybe....lets experiment
	--no experiments please, I think we should LOWER it because of the 'IN' and 'in'...
	SET @NewSqlContents = REPLACE(SUBSTRING(@SqlContents, @Idx, LEN(@SqlContents)), ' ', '');
	--SET @NewSqlContents = REPLACE(SUBSTRING(@SqlContents, @Idx, 150), ' ', '');
	--PRINT(@NewSqlContents);
	SET @SqlContents = SUBSTRING(@SqlContents, @Idx, LEN(@SqlContents));
	--put check if object type and transaction type are checked in the same line
	IF @Variable = 'O'
	BEGIN
		IF (SUBSTRING(@NewSqlContents, 13, LEN(@NewSqlContents)) LIKE 'IN%' OR SUBSTRING(@NewSqlContents, 13, LEN(@NewSqlContents)) LIKE '=%') AND (@ObjectType IS NULL OR @variableState = 1)
			AND (PATINDEX('%@transaction_type%', LOWER(@NewSqlContents)) < CHARINDEX(CHAR(10), @NewSqlContents, 1) OR (@TransactionType IS NOT NULL AND @ObjectType IS NULL))
		BEGIN
			IF @variableState = 1
			BEGIN
				SET @variableState = 0;
				SET @ObjectType = NULL;
				SET @TransactionType = NULL;
				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
			END
			--PRINT('success!')
			--PRINT(SUBSTRING(@NewSqlContents, 13, LEN(@NewSqlContents)))
			--cut down to just the line, should have all the quotes
			SET @NewSqlContents = SUBSTRING(@NewSqlContents, 1, CHARINDEX(CHAR(10), @NewSqlContents, 1));
			IF (CHARINDEX(CHAR(10), @NewSqlContents, 1) < PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents)))) 
				--check if = 0, in case not found/ at end of file
				OR PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents))) = 0
			BEGIN
				SET @NewSqlContents = SUBSTRING(@NewSqlContents, 13, CHARINDEX(CHAR(10), @NewSqlContents, 1) - 13);
			END
			ELSE
			BEGIN
				SET @NewSqlContents = SUBSTRING(@NewSqlContents, 13, PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents))) - 13);
			END

			SET @NewSqlContents = REPLACE(@NewSqlContents, 'i', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, 'n', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '(', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, ')', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '=', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '''', '');

			SET @ObjectType = @NewSqlContents;

		END
		--PRINT('hello')
	END
	ELSE IF @Variable = 'T'
	BEGIN
		IF (SUBSTRING(@NewSqlContents, 18, LEN(@NewSqlContents)) LIKE 'IN%' OR SUBSTRING(@NewSqlContents, 18, LEN(@NewSqlContents)) LIKE '=%') AND (@TransactionType IS NULL OR @variableState = 1)
			AND (PATINDEX('%@object_type%', LOWER(@NewSqlContents)) < CHARINDEX(CHAR(10), @NewSqlContents, 1) OR (@ObjectType IS NOT NULL AND @TransactionType IS NULL))
		BEGIN
			IF @variableState = 1
			BEGIN
				SET @variableState = 0;
				SET @ObjectType = NULL;
				SET @TransactionType = NULL;
				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
			END
			--PRINT('winner!')
			SET @NewSqlContents = SUBSTRING(@NewSqlContents, 1, CHARINDEX(CHAR(10), @NewSqlContents, 1));
			IF (CHARINDEX(CHAR(10), @NewSqlContents, 1) < PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents)))) 
				--check if = 0, in case not found/ at end of file
				OR PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents))) = 0
			BEGIN
				SET @NewSqlContents = SUBSTRING(@NewSqlContents, 18, CHARINDEX(CHAR(10), @NewSqlContents, 1) - 18);
			END
			ELSE
			BEGIN
				SET @NewSqlContents = SUBSTRING(@NewSqlContents, 18, PATINDEX('%AND%', SUBSTRING(@NewSqlContents, 1, LEN(@NewSqlContents))) - 18);
			END
			--BOOOOOOOYAHHHHHH!!!! replace a few characters and we are DONE!!!!
			SET @NewSqlContents = REPLACE(@NewSqlContents, 'i', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, 'n', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '(', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, ')', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '=', '');
			SET @NewSqlContents = REPLACE(@NewSqlContents, '''', '');

			SET @TransactionType = @NewSqlContents;
		END
		--PRINT('hello')
	END
	ELSE IF @Variable = 'E'
	BEGIN
		IF SUBSTRING(@NewSqlContents, 7, LEN(@NewSqlContents)) LIKE '=%' AND (@ObjectType IS NOT NULL)
		BEGIN 
			--PRINT('chicken dinner!')
			SET @ErrorNumber = SUBSTRING(@NewSqlContents, 8, (PATINDEX('%[^0-9]%', SUBSTRING(@NewSqlContents, 8, LEN(@NewSqlContents)))) - 1)
			--PRINT @ErrorNumber;
			IF @ErrorMessage IS NOT NULL
			BEGIN
				INSERT INTO @TNRules (SqlFile, ObjectType, TransactionType, ErrorNumber, ErrorMessage, Idx)
				VALUES (@SqlFile, @ObjectType, @TransactionType, @ErrorNumber, @ErrorMessage, @Idx);

				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
				SET @variableState = 1;
			END
		END
		--PRINT('hello')
	END
	--could use else, but this case is guaranteed Im sure
	ELSE IF @Variable = 'EM'
	BEGIN
		IF (SUBSTRING(@NewSqlContents, 15, LEN(@NewSqlContents)) LIKE '=''%' OR SUBSTRING(@NewSqlContents, 15, LEN(@NewSqlContents)) LIKE '=N%') AND (@ObjectType IS NOT NULL)
		--consider strings that have N between = and ', and without N 
		BEGIN 
			--PRINT('victorious!')
			DECLARE @TempInt INT;
			--if no +1, TempInt is index of the ', so substring doesnt do anything
			SET @TempInt = CHARINDEX(CHAR(39), @SqlContents, 15) + 1;
			--PRINT(@TempInt);
			SET @ErrorMessage = SUBSTRING(@SqlContents, @TempInt, (CHARINDEX(CHAR(39), @SqlContents, @TempInt)) - @TempInt)
			--PRINT(SUBSTRING(@NewSqlContents, @TempInt, (CHARINDEX(CHAR(39), @NewSqlContents, @TempInt) - @TempInt)))
			IF @ErrorNumber IS NOT NULL
			BEGIN
				INSERT INTO @TNRules (SqlFile, ObjectType, TransactionType, ErrorNumber, ErrorMessage, Idx)
				VALUES (@SqlFile, @ObjectType, @TransactionType, @ErrorNumber, @ErrorMessage, @Idx);

				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
				SET @variableState = 1;
			END
		END
		--PRINT('hello')
	END
	
	FETCH NEXT FROM db_cursor2 INTO @Idx, @Variable, @SqlFile
END

CLOSE db_cursor2;
DEALLOCATE db_cursor2;
--================================================================================================= FIN

SELECT * FROM @TNRules --WHERE LEN(ErrorNumber) < 5--ErrorNumber = ''--SqlFile = 'SBO_SP_TransactionNotification_Ar' --AND ErrorNumber = 022002
ORDER BY SqlFile ASC, Idx ASC 


--SELECT * FROM @TNIndex ORDER BY SqlFile ASC, Idx ASC;

-------------------------------------
--Extra credit, clean up data a little?


