CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerSummary
    @StartDate   DATE,
    @EndDate     DATE,
    @Region      NVARCHAR(50) = NULL   -- Optional filter; NULL = all regions
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Validate date range
    IF @StartDate > @EndDate
    BEGIN
        RAISERROR('StartDate cannot be later than EndDate.', 16, 1);
        RETURN;
    END
 
    BEGIN TRY
 
        SELECT
            c.CustomerID,
            c.FullName,
            c.Region,
            COUNT(o.OrderID)                            AS TotalOrders,
            SUM(o.OrderTotal)                           AS TotalRevenue,
            CAST(AVG(o.OrderTotal) AS DECIMAL(10,2))    AS AvgOrderValue,
            MAX(o.OrderDate)                            AS LastOrderDate
        FROM
            dbo.Customers   c
            INNER JOIN dbo.Orders o
                ON  c.CustomerID = o.CustomerID
                AND o.OrderDate BETWEEN @StartDate AND @EndDate
                AND o.IsDeleted = 0
        WHERE
            (@Region IS NULL OR c.Region = @Region)
        GROUP BY
            c.CustomerID,
            c.FullName,
            c.Region
        ORDER BY
            TotalRevenue DESC;
 
    END TRY
    BEGIN CATCH
 
        -- Surface the error to the caller with context
        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Sev INT            = ERROR_SEVERITY();
        DECLARE @Sta INT            = ERROR_STATE();
        RAISERROR(@Msg, @Sev, @Sta);
 
    END CATCH
END;
GO
 
-- ============================================================
-- Sample usage
-- ============================================================
-- All regions, Q1 2024:
EXEC dbo.usp_GetCustomerSummary
    @StartDate = '2024-01-01',
    @EndDate   = '2024-03-31';
 
-- Dubai region only:
EXEC dbo.usp_GetCustomerSummary
    @StartDate = '2024-01-01',
    @EndDate   = '2024-12-31',
    @Region    = 'Dubai';
GO
 
