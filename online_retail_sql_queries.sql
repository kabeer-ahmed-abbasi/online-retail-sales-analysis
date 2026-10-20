/*
ONLINE RETAIL SALES ANALYSIS — SQL SERVER (T-SQL)
Source: online_retail.csv
Columns: InvoiceNo, StockCode, Description, Quantity, InvoiceDate,
         UnitPrice, CustomerID, Country

IMPORTANT: The supplied CSV stores InvoiceDate as an Excel serial date
(e.g. 40513.351388888892), NOT as an ISO date. This script converts it.
The scripts below use SQL Server / SSMS syntax.

How to use:
1) Create a database or select your existing database in SSMS.
2) Run SECTION A to create the staging table.
3) Import online_retail.csv into dbo.online_retail_raw using the SSMS
   Import Flat File wizard, mapping every field to its VARCHAR column.
   (The file is UTF-8 with BOM.) Do not import the header as a data row.
4) Run SECTION B to create the cleaned table.
5) Run any of the analysis queries in SECTION C.

All dashboard sales KPIs in this script EXCLUDE rows with Quantity <= 0
or UnitPrice <= 0. They also exclude rows with an InvoiceNo starting 'C'
(cancellations). This makes sales revenue, order count, and AOV consistent.
For net revenue including returns, see Query 15.
*/

-- SECTION A: RAW IMPORT TABLE
IF OBJECT_ID('dbo.online_retail_raw','U') IS NULL
BEGIN
    CREATE TABLE dbo.online_retail_raw (
        InvoiceNo VARCHAR(50) NULL,
        StockCode VARCHAR(50) NULL,
        Description NVARCHAR(500) NULL,
        Quantity VARCHAR(50) NULL,
        InvoiceDate VARCHAR(60) NULL,
        UnitPrice VARCHAR(60) NULL,
        CustomerID VARCHAR(50) NULL,
        Country NVARCHAR(150) NULL
    );
END;
GO

-- SECTION B: CLEANED ANALYSIS TABLE
-- Re-running this section rebuilds the cleaned table from raw imported rows.
IF OBJECT_ID('dbo.online_retail','U') IS NOT NULL
    DROP TABLE dbo.online_retail;
GO

SELECT
    NULLIF(LTRIM(RTRIM(InvoiceNo)), '') AS InvoiceNo,
    NULLIF(LTRIM(RTRIM(StockCode)), '') AS StockCode,
    NULLIF(LTRIM(RTRIM(Description)), '') AS Description,
    TRY_CONVERT(INT, Quantity) AS Quantity,
    -- Excel's date epoch for Windows serial dates is 1899-12-30.
    CASE WHEN TRY_CONVERT(FLOAT, InvoiceDate) BETWEEN 1 AND 2958465
         THEN DATEADD(SECOND,
                 CONVERT(INT, ROUND((TRY_CONVERT(FLOAT, InvoiceDate)
                        - FLOOR(TRY_CONVERT(FLOAT, InvoiceDate))) * 86400, 0)),
                 DATEADD(DAY, CONVERT(INT, FLOOR(TRY_CONVERT(FLOAT, InvoiceDate))),
                         CAST('1899-12-30' AS DATETIME2)))
         ELSE TRY_CONVERT(DATETIME2, InvoiceDate, 103)
    END AS InvoiceDate,
    TRY_CONVERT(DECIMAL(18,4), UnitPrice) AS UnitPrice,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(CustomerID)), '')) AS CustomerID,
    NULLIF(LTRIM(RTRIM(Country)), '') AS Country
INTO dbo.online_retail
FROM dbo.online_retail_raw
WHERE NULLIF(LTRIM(RTRIM(InvoiceNo)), '') IS NOT NULL;
GO

-- Inspect conversion results before analysis.
SELECT TOP (20) * FROM dbo.online_retail ORDER BY InvoiceDate;
SELECT COUNT(*) AS ImportedRows,
       SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS InvalidDates
FROM dbo.online_retail;
GO

-- SECTION C: DASHBOARD QUERIES
-- Each query can be run independently after Sections A and B.

-- 01. Total sales revenue (positive sales only)
SELECT ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS TotalRevenue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%';

-- 02. Total unique orders (NOT number of product rows)
SELECT COUNT(DISTINCT InvoiceNo) AS TotalOrders
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%';

-- 03. Total unique customers (exclude missing IDs)
SELECT COUNT(DISTINCT CustomerID) AS TotalCustomers
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND CustomerID IS NOT NULL;

-- 04. Average order value = sales revenue / distinct orders
SELECT ROUND(
    SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice)
    / NULLIF(COUNT(DISTINCT InvoiceNo), 0), 2) AS AverageOrderValue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%';

-- 05. All four KPIs in one result
SELECT
    ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS TotalRevenue,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    COUNT(DISTINCT CustomerID) AS TotalCustomers,
    ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice)
          / NULLIF(COUNT(DISTINCT InvoiceNo), 0), 2) AS AverageOrderValue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%';

-- 06. Monthly revenue trend (year and month together)
SELECT YEAR(InvoiceDate) AS SalesYear,
       MONTH(InvoiceDate) AS SalesMonth,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS Revenue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND InvoiceDate IS NOT NULL
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;

-- 07. Yearly sales and order counts
SELECT YEAR(InvoiceDate) AS SalesYear,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS Revenue,
       COUNT(DISTINCT InvoiceNo) AS Orders
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND InvoiceDate IS NOT NULL
GROUP BY YEAR(InvoiceDate)
ORDER BY SalesYear;

-- 08. Top 10 products by revenue
SELECT TOP (10) StockCode, Description,
       SUM(Quantity) AS UnitsSold,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS Revenue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND Description IS NOT NULL
GROUP BY StockCode, Description
ORDER BY Revenue DESC;

-- 09. Revenue by country (also suitable for a map)
SELECT Country,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS Revenue,
       COUNT(DISTINCT InvoiceNo) AS Orders
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND Country IS NOT NULL
GROUP BY Country
ORDER BY Revenue DESC;

-- 10. Top 10 customers by spending
SELECT TOP (10) CustomerID,
       COUNT(DISTINCT InvoiceNo) AS Orders,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS CustomerSpend
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY CustomerSpend DESC;

-- 11. Most popular products by quantity sold
SELECT TOP (10) StockCode, Description, SUM(Quantity) AS UnitsSold
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND Description IS NOT NULL
GROUP BY StockCode, Description
ORDER BY UnitsSold DESC;

-- 12. Monthly order counts
SELECT YEAR(InvoiceDate) AS SalesYear,
       MONTH(InvoiceDate) AS SalesMonth,
       COUNT(DISTINCT InvoiceNo) AS Orders
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND InvoiceDate IS NOT NULL
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;

-- 13. Monthly unique customers
SELECT YEAR(InvoiceDate) AS SalesYear,
       MONTH(InvoiceDate) AS SalesMonth,
       COUNT(DISTINCT CustomerID) AS Customers
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND CustomerID IS NOT NULL AND InvoiceDate IS NOT NULL
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;

-- 14. Data quality / returns overview
SELECT COUNT(*) AS AllRows,
       SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS MissingCustomerIDRows,
       SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS MissingDateRows,
       SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END) AS NonPositiveQuantityRows,
       SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS NonPositivePriceRows,
       SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS CancellationRows
FROM dbo.online_retail;

-- 15. Net revenue INCLUDING negative-quantity returns/cancellations
-- This will generally differ from the sales-only revenue in Query 01.
SELECT ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS NetRevenue
FROM dbo.online_retail
WHERE Quantity IS NOT NULL AND UnitPrice IS NOT NULL;

-- 16. Daily revenue
SELECT CAST(InvoiceDate AS DATE) AS SalesDate,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS Revenue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  AND InvoiceDate IS NOT NULL
GROUP BY CAST(InvoiceDate AS DATE)
ORDER BY SalesDate;

-- 17. Revenue share by country (percentage)
WITH country_sales AS (
    SELECT Country,
           SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice) AS Revenue
    FROM dbo.online_retail
    WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
      AND Country IS NOT NULL
    GROUP BY Country
)
SELECT Country, ROUND(Revenue, 2) AS Revenue,
       ROUND(100.0 * Revenue / NULLIF(SUM(Revenue) OVER (), 0), 2) AS RevenuePct
FROM country_sales
ORDER BY Revenue DESC;

-- 18. Invoice-level order totals (for validation)
SELECT InvoiceNo, MIN(InvoiceDate) AS OrderDate,
       MAX(CustomerID) AS CustomerID,
       ROUND(SUM(CAST(Quantity AS DECIMAL(18,4)) * UnitPrice), 2) AS OrderValue
FROM dbo.online_retail
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
GROUP BY InvoiceNo
ORDER BY OrderValue DESC;
