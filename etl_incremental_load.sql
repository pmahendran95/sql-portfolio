-- ============================================================
-- Script  : etl_incremental_load.sql
-- Purpose : Incremental ETL pattern using a watermark table
--           to track the last successfully loaded timestamp.
--           Loads only new/updated records from the source
--           table into the staging and target tables.
-- Author  : Paviyathachayini Mahendran
-- Stack   : SQL Server (T-SQL)
-- Pattern : Watermark-based incremental load
-- ============================================================
 
USE DataWarehouse;
GO
 
-- ============================================================
-- Step 1 — Watermark table (create once)
-- Tracks the high-water mark per source table
-- ============================================================
IF OBJECT_ID('dbo.ETL_Watermark', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_Watermark (
        SourceTable     NVARCHAR(128)   NOT NULL PRIMARY KEY,
        LastLoadedAt    DATETIME2(3)    NOT NULL DEFAULT '1900-01-01'
    );
 
    -- Initialise entry for the Orders source
    INSERT INTO dbo.ETL_Watermark (SourceTable, LastLoadedAt)
    VALUES ('SourceDB.dbo.Orders', '1900-01-01');
END;
GO
 
-- ============================================================
-- Step 2 — Incremental load procedure
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_ETL_IncrementalLoad_Orders
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE
        @LastLoaded     DATETIME2(3),
        @NewWatermark   DATETIME2(3),
        @RowsLoaded     INT = 0;
 
    -- Read current watermark
    SELECT @LastLoaded = LastLoadedAt
    FROM   dbo.ETL_Watermark
    WHERE  SourceTable = 'SourceDB.dbo.Orders';
 
    -- Capture the new watermark before loading
    -- (avoids race condition on rows inserted during the run)
    SET @NewWatermark = GETUTCDATE();
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- -------------------------------------------------------
        -- Extract & load: only rows modified since last run
        -- -------------------------------------------------------
        MERGE dbo.Fact_Orders AS tgt
        USING (
            SELECT
                OrderID,
                CustomerID,
                OrderDate,
                OrderTotal,
                Status,
                ModifiedAt
            FROM SourceDB.dbo.Orders
            WHERE ModifiedAt > @LastLoaded
              AND ModifiedAt <= @NewWatermark
        ) AS src
            ON tgt.OrderID = src.OrderID
 
        WHEN MATCHED AND src.ModifiedAt > tgt.ModifiedAt THEN
            UPDATE SET
                tgt.CustomerID  = src.CustomerID,
                tgt.OrderDate   = src.OrderDate,
                tgt.OrderTotal  = src.OrderTotal,
                tgt.Status      = src.Status,
                tgt.ModifiedAt  = src.ModifiedAt,
                tgt.ETL_LoadedAt = GETUTCDATE()
 
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (OrderID, CustomerID, OrderDate, OrderTotal, Status, ModifiedAt, ETL_LoadedAt)
            VALUES (src.OrderID, src.CustomerID, src.OrderDate, src.OrderTotal,
                    src.Status, src.ModifiedAt, GETUTCDATE());
 
        SET @RowsLoaded = @@ROWCOUNT;
 
        -- Update watermark only on success
        UPDATE dbo.ETL_Watermark
        SET    LastLoadedAt = @NewWatermark
        WHERE  SourceTable  = 'SourceDB.dbo.Orders';
 
        COMMIT TRANSACTION;
 
        -- Log result
        PRINT CONCAT('ETL complete. Rows affected: ', @RowsLoaded,
                     ' | New watermark: ', CONVERT(VARCHAR, @NewWatermark, 120));
 
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 
        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('ETL load failed: %s', 16, 1, @Msg);
    END CATCH
END;
GO
 
-- ============================================================
-- Sample usage
-- ============================================================
EXEC dbo.usp_ETL_IncrementalLoad_Orders;
GO
