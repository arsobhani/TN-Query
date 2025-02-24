USE [LNM_SAPB1_PROD_DAILY]



--Chapter 1
DECLARE @TransactionNotification TABLE (ProcedureName NVARCHAR(100), ProcedureDefinition NVARCHAR(MAX))
--Chapter 2
DECLARE @TNIndex TABLE (Idx INT, Variable NVARCHAR(5), SqlFile NVARCHAR(100))
--Chapter 3
DECLARE @TNRules TABLE (SqlFile NVARCHAR(100), ObjectType NVARCHAR(100), TransactionType NVARCHAR(100), ErrorNumber NVARCHAR(100), ErrorMessage NVARCHAR(100), Idx INT)


--Create table with file contents
INSERT INTO @TransactionNotification
SELECT 
    o.name AS ProcedureName,
    m.definition AS ProcedureDefinition
FROM 
    sys.sql_modules m
INNER JOIN 
    sys.objects o ON m.object_id = o.object_id
WHERE 
    o.type = 'P' -- P for stored procedure
	AND o.name LIKE 'SBO_SP_TransactionNotification%';

--Chapter 1 finished....

--==============================================================================================================

--Iterate through each file and parse for information
DECLARE @TNFileName NVARCHAR(100)
DECLARE @TNFile NVARCHAR(MAX)

DECLARE db_cursor CURSOR FOR 
SELECT * FROM @TransactionNotification

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @TNFileName, @TNFile

WHILE @@FETCH_STATUS = 0
BEGIN
	--lowercase string to reduce chaos
	SET @TNFile = LOWER(@TNFile);
-------------------------------------------------------------------------
	DECLARE @Substring VARCHAR(100) = '@transaction_type'; 
	--have to add the filename later
	DROP TABLE IF EXISTS #TempTable
	CREATE TABLE #TempTable (Idx INT, Variable NVARCHAR(5), SqlFile NVARCHAR(100)); 
	
	--Create proper numbers table 1 to LEN(@TNFile)...sorry AI, you did this one wrong
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
	

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	WHERE SUBSTRING(@TNFile, Number, LEN(@Substring)) = @Substring

	
	--Update temptable to give default values for this segment and iteration
	UPDATE #TempTable
	SET #TempTable.Variable = 'T', SqlFile = @TNFileName;

	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable
	
--------------------------------------------------------
	SET @Substring = '@object_type'
	--clear the table
	TRUNCATE TABLE #TempTable;


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

	--space doesnt matter in some cases, but it can here
	--WHOAAAAAA we have the case where @error=...this was stopping some cases
	SET @Substring = '@error';
	TRUNCATE TABLE #TempTable;
	

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	--made change to fix error overlap with error_message
	--do + 1 to check one more spot for the '_' char and the '=' char
	WHERE (SUBSTRING(@TNFile, Number, LEN(@Substring) + 1) = @Substring + ' ') OR (SUBSTRING(@TNFile, Number, LEN(@Substring) + 1) = @Substring + '=')
	
	UPDATE #TempTable
	SET #TempTable.Variable = 'E', SqlFile = @TNFileName;
	
	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable
---------------------------------------------------------------------------------------------

	SET @Substring = '@error_message'
	TRUNCATE TABLE #TempTable;
	
	

	INSERT INTO #TempTable (Idx)
	SELECT Number AS Idx
	FROM @Numbers
	WHERE SUBSTRING(@TNFile, Number, LEN(@Substring)) = @Substring

	
	UPDATE #TempTable
	SET #TempTable.Variable = 'EM', SqlFile = @TNFileName;
	
	INSERT INTO @TNIndex (Idx, Variable, SqlFile)
	SELECT Idx, Variable, SqlFile
	FROM #TempTable

	--NEED to clear the table @Numbers
	--otherwise, we get a very fascinating bug....
	DELETE FROM @Numbers;

    FETCH NEXT FROM db_cursor INTO @TNFileName, @TNFile
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

DROP TABLE IF EXISTS #TempTable

--Chapter 2 Complete

--======================================================================================
--====================================================================================================

--this part requires a PHD


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
--I could create a 'table' to inherit the datatypes and just put one entry in the table, then clear it and use again...less room for error perhaps

--could use NULLs instead of this but...
--I think one case requires a state variable
DECLARE @variableState INT;
--states for which variables have been established...
--0 : a transaction notification has not been added
--1 : a transaction notification has been added, the objectType and transactionType can be changed


--only need 2 states I believe...maybe need more for comment logic
SET @variableState = 0;
WHILE @@FETCH_STATUS = 0
BEGIN
	--create a version without spaces...
	--cant do this without indexes getting messed up...unless the string starts there
	DECLARE @SqlContents NVARCHAR(MAX);
	DECLARE @NewSqlContents NVARCHAR(MAX);
	SET @SqlContents = (SELECT TOP 1 ProcedureDefinition FROM @TransactionNotification WHERE ProcedureName = @SqlFile)
	
	--make new string without spaces, but index still works
	SET @NewSqlContents = REPLACE(SUBSTRING(@SqlContents, @Idx, LEN(@SqlContents)), ' ', '');
	SET @SqlContents = SUBSTRING(@SqlContents, @Idx, LEN(@SqlContents));

	--put check if object type and transaction type are in the same line
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
			
			--cut down to just the line, should have all the quotes
			--logic to see if objectType or transactionType came first in that line
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
	END
	ELSE IF @Variable = 'E'
	BEGIN
		IF SUBSTRING(@NewSqlContents, 7, LEN(@NewSqlContents)) LIKE '=%' AND (@ObjectType IS NOT NULL)
		BEGIN 
			SET @ErrorNumber = SUBSTRING(@NewSqlContents, 8, (PATINDEX('%[^0-9]%', SUBSTRING(@NewSqlContents, 8, LEN(@NewSqlContents)))) - 1)
			--if they have both been added, then a transaction notification can be added
			IF @ErrorMessage IS NOT NULL
			BEGIN
				INSERT INTO @TNRules (SqlFile, ObjectType, TransactionType, ErrorNumber, ErrorMessage, Idx)
				VALUES (@SqlFile, @ObjectType, @TransactionType, @ErrorNumber, @ErrorMessage, @Idx);

				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
				SET @variableState = 1;
			END
		END
	END
	--could use else, but this case is guaranteed Im sure
	ELSE IF @Variable = 'EM'
	BEGIN
		--'''' means the character '
		IF (SUBSTRING(@NewSqlContents, 15, LEN(@NewSqlContents)) LIKE '=''%' OR SUBSTRING(@NewSqlContents, 15, LEN(@NewSqlContents)) LIKE '=N%') AND (@ObjectType IS NOT NULL)
		--consider strings that have N between = and ', and without N 
		BEGIN 
			DECLARE @TempInt INT;
			--if no +1, TempInt is index of the ', so substring doesnt do anything
			SET @TempInt = CHARINDEX(CHAR(39), @SqlContents, 15) + 1;
			SET @ErrorMessage = SUBSTRING(@SqlContents, @TempInt, (CHARINDEX(CHAR(39), @SqlContents, @TempInt)) - @TempInt)
			
			IF @ErrorNumber IS NOT NULL
			BEGIN
				INSERT INTO @TNRules (SqlFile, ObjectType, TransactionType, ErrorNumber, ErrorMessage, Idx)
				VALUES (@SqlFile, @ObjectType, @TransactionType, @ErrorNumber, @ErrorMessage, @Idx);

				SET @ErrorMessage = NULL;
				SET @ErrorNumber = NULL;
				SET @variableState = 1;
			END
		END
	END
	
	FETCH NEXT FROM db_cursor2 INTO @Idx, @Variable, @SqlFile
END

CLOSE db_cursor2;
DEALLOCATE db_cursor2;
--================================================================================================= FIN

SELECT * FROM @TNRules 
ORDER BY SqlFile ASC, Idx ASC

/*
SELECT * FROM @TNIndex
ORDER BY SqlFile ASC, Idx ASC
*/




