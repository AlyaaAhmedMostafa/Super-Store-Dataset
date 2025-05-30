SELECT *
FROM [dbo].[Superstore Sales Dataset]

--  Detect and eliminate duplicate records within the Amazon sales dataset to ensure data integrity.
WITH Duplicate_Records AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name, Segment, Country, City, State, Postal_Code, Region, Product_ID, Category, Sub_Category, Product_Name, Sales, shipping_duration_in_days
                           ORDER BY (SELECT NULL)) AS RowNum
    FROM [dbo].[Superstore Sales Dataset]
)
DELETE FROM [dbo].[Superstore Sales Dataset]
WHERE Row_ID IN (
    SELECT Row_ID FROM Duplicate_Records WHERE RowNum > 1
);

-- This query analyzes the [Superstore Sales].[dbo].[Superstore Sales Dataset] table to identify missing values in key columns.
-- It returns the total number of records in the table, the count of records with NULL values in the 'Sales' column,
-- and the count of records with NULL values in the 'Order_Date' column.  This is useful for data quality assessment.

SELECT 
    COUNT(*) AS Total_Records,
    COUNT(CASE WHEN Sales IS NULL THEN 1 END) AS Missing_Sales,
    COUNT(CASE WHEN Order_Date IS NULL THEN 1 END) AS Missing_Order_Dates
FROM [dbo].[Superstore Sales Dataset]

--Adding missing postal codes to Burlington city records
UPDATE [dbo].[Superstore Sales Dataset]
SET Postal_Code ='05401'
Where City = 'Burlington' AND State ='Vermont'
And Postal_Code IS NULL;

-- This query identifies products with exceptionally high sales.
-- It selects products where the sales amount exceeds the average sales by more than three standard deviations.
-- The query calculates this threshold using a subquery, and then filters the products based on this threshold.
-- The results are ordered in descending order of sales, showing the highest sales first.

SELECT Product_ID, Product_Name, Sales
FROM [dbo].[Superstore Sales Dataset]
WHERE Sales > (SELECT AVG(Sales) + 3*STDEV(Sales) FROM [dbo].[Superstore Sales Dataset])
ORDER BY Sales DESC;

-- Adds a 'shipping_duration_in_days' column to store the calculated transit time
-- Computed as the difference in days between the order date and ship date for each record date.

ALTER TABLE [dbo].[Superstore Sales Dataset]
ADD shipping_duration_in_days INT;

UPDATE [dbo].[Superstore Sales Dataset]
SET shipping_duration_in_days = DATEDIFF(DAY, Order_Date, Ship_Date);

--calculating the total number of orders, unique customers, unique products, and total sales
SELECT COUNT(*) AS Total_Orders, 
       COUNT(DISTINCT Customer_ID) AS Unique_Customers, 
       COUNT(DISTINCT Product_ID) AS Unique_Products, 
       SUM(Sales) AS Total_Sales
FROM [dbo].[Superstore Sales Dataset];


-- This query analyzes sales performance and market penetration for each region.
-- It calculates total sales, order and customer counts, average order value, and average shipping days for each region.
-- Additionally, it calculates the number of states and cities covered within each region,
-- as well as sales per customer and sales per order.

WITH Region_Metrics AS (
    SELECT 
        Region,
        SUM(Sales) AS Total_Sales,
        COUNT(DISTINCT Order_ID) AS Order_Count,
        COUNT(DISTINCT Customer_ID) AS Customer_Count,
        AVG(Sales) AS Average_Order_Value,
        AVG(DATEDIFF(DAY, Order_Date, Ship_Date)) AS Avg_Shipping_Days,
        COUNT(DISTINCT State) AS State_Coverage,
        COUNT(DISTINCT City) AS City_Coverage
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Region
)
SELECT
    Region,
    Total_Sales,
    Order_Count,
    Customer_Count,
    Average_Order_Value,
    Avg_Shipping_Days,
    State_Coverage,
    City_Coverage,
    ROUND(Total_Sales / Customer_Count, 2) AS Sales_Per_Customer,
    ROUND(Total_Sales / Order_Count, 2) AS Sales_Per_Order
FROM Region_Metrics
ORDER BY Total_Sales DESC;


-- This query analyzes sales performance and shipping efficiency for each state.
-- It calculates total sales, order count, customer count, average order value, and average shipping days for each state.
-- It then ranks states based on these metrics: total sales, average order value, and shipping speed.

WITH State_Metrics AS (
    SELECT 
        State,
        SUM(Sales) AS Total_Sales,
        COUNT(DISTINCT Order_ID) AS Order_Count,
        COUNT(DISTINCT Customer_ID) AS Customer_Count,
        AVG(Sales) AS Average_Order_Value,
        AVG(DATEDIFF(DAY, Order_Date, Ship_Date)) AS Avg_Shipping_Days
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY State
),
State_Rankings AS (
    SELECT
        State,
        Total_Sales,
        Order_Count,
        Customer_Count,
        Average_Order_Value,
        Avg_Shipping_Days,
        RANK() OVER (ORDER BY Total_Sales DESC) AS Sales_Rank,
        RANK() OVER (ORDER BY Average_Order_Value DESC) AS AOV_Rank,
        RANK() OVER (ORDER BY Avg_Shipping_Days ASC) AS Shipping_Speed_Rank
    FROM State_Metrics
)
SELECT *
FROM State_Rankings
ORDER BY Sales_Rank;

-- This query analyzes sales performance and shipping efficiency for each city within each state.
-- It calculates key metrics including total sales, order count, customer count, average order value, and average shipping days for each city.
-- It then ranks each city within its state based on sales performance, and also provides an overall sales rank and average order value rank for all cities.

WITH City_Metrics AS (
    SELECT 
        City,
        State,
        SUM(Sales) AS Total_Sales,
        COUNT(DISTINCT Order_ID) AS Order_Count,
        COUNT(DISTINCT Customer_ID) AS Customer_Count,
        AVG(Sales) AS Average_Order_Value,
        AVG(DATEDIFF(DAY, Order_Date, Ship_Date)) AS Avg_Shipping_Days
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY City, State
),
City_Rankings AS (
    SELECT
        City,
        State,
        Total_Sales,
        Order_Count,
        Customer_Count,
        Average_Order_Value,
        Avg_Shipping_Days,
        RANK() OVER (ORDER BY Total_Sales DESC) AS Sales_Rank,
        RANK() OVER (PARTITION BY State ORDER BY Total_Sales DESC) AS State_Sales_Rank,
        RANK() OVER (ORDER BY Average_Order_Value DESC) AS AOV_Rank
    FROM City_Metrics
)
SELECT *
FROM City_Rankings
ORDER BY Sales_Rank;

-- This query identifies the top 10 customers based on total sales.
-- It calculates each customer's total sales and assigns a rank based on sales,
-- then selects the top 10 customers based on that rank.

WITH Customer_Totals AS (
    SELECT Customer_Name, SUM(Sales) AS Total_Sales,
           ROW_NUMBER() OVER (ORDER BY SUM(Sales) DESC) AS RowNum
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Customer_Name
)
SELECT *
FROM Customer_Totals
WHERE RowNum <= 10;

-- This query performs a segment-based analysis, calculating key sales, performance, time-based, and product engagement metrics.
-- It uses Common Table Expressions (CTEs) to organize the calculations.

WITH Segment_Analysis AS (
    SELECT 
        Segment,
        -- Basic sales metrics
        SUM(Sales) AS Total_Sales,
        COUNT(DISTINCT Order_ID) AS Order_Count,
        COUNT(DISTINCT Customer_ID) AS Customer_Count,
        
        -- Performance metrics
        SUM(Sales)/COUNT(DISTINCT Customer_ID) AS Sales_Per_Customer,
        SUM(Sales)/COUNT(DISTINCT Order_ID) AS Average_Order_Value,
        
        -- Time-based metrics
        AVG(DATEDIFF(DAY, Order_Date, Ship_Date)) AS Avg_Shipping_Days,
        
        -- Product engagement metrics
        COUNT(DISTINCT Product_ID) AS Unique_Products_Purchased
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Segment
),
Overall_Metrics AS (
    SELECT 
        SUM(Total_Sales) AS Grand_Total_Sales,
        SUM(Order_Count) AS Grand_Total_Orders
    FROM Segment_Analysis
)
SELECT 
    sa.Segment,
    sa.Total_Sales,
    ROUND(sa.Total_Sales * 100.0 / om.Grand_Total_Sales, 2) AS Sales_Percentage,
    sa.Order_Count,
    ROUND(sa.Order_Count * 100.0 / om.Grand_Total_Orders, 2) AS Order_Percentage,
    sa.Customer_Count,
    sa.Sales_Per_Customer,
    sa.Average_Order_Value,
    sa.Avg_Shipping_Days,
    sa.Unique_Products_Purchased,
    RANK() OVER (ORDER BY sa.Total_Sales DESC) AS Segment_Rank
FROM Segment_Analysis sa
CROSS JOIN Overall_Metrics om
ORDER BY sa.Total_Sales DESC;

-- Comprehensive category and subcategory sales performance analysis
-- Calculates total sales, percentage of overall sales, and average order value
-- Includes rank within each category for subcategory comparison

WITH Category_Sales AS (
    SELECT 
        Category,
        Sub_Category AS Subcategory,
        SUM(Sales) AS Total_Sales,
        COUNT(DISTINCT Order_ID) AS Order_Count,
        SUM(Sales) / COUNT(DISTINCT Order_ID) AS Avg_Order_Value
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Category, Sub_Category
),
TotalSales AS (
    SELECT SUM(Total_Sales) AS Grand_Total
    FROM Category_Sales
)
SELECT 
    cs.Category,
    cs.Subcategory,
    cs.Total_Sales,
    ROUND((cs.Total_Sales * 100.0 / ts.Grand_Total), 2) AS Percent_of_Total_Sales,
    cs.Order_Count,
    cs.Avg_Order_Value,
    RANK() OVER (PARTITION BY cs.Category ORDER BY cs.Total_Sales DESC) AS Subcategory_Rank
FROM Category_Sales cs
CROSS JOIN TotalSales ts
ORDER BY 
    cs.Category,
    cs.Total_Sales DESC;


-- This query identifies the top 10 best-selling products.
SELECT Top 10 Product_Name,
              SUM(Sales) AS Total_Sales
FROM [dbo].[Superstore Sales Dataset]
GROUP BY Product_Name
ORDER BY Total_Sales DESC;


-- Computing the duration of shipments for different shipping modes
SELECT Ship_Mode, AVG(shipping_duration_in_days) AS Average_Shipping_Time
FROM  [dbo].[Superstore Sales Dataset]
GROUP BY Ship_Mode
ORDER BY  Average_Shipping_Time;

--Determining sales by ship method
SELECT Ship_Mode, SUM(Sales) AS Total_Sales
FROM [dbo].[Superstore Sales Dataset]
GROUP BY Ship_Mode
ORDER BY Total_Sales DESC;

-- This query calculates the total sales for each year.
SELECT YEAR(Order_Date) AS Year,  SUM(Sales) AS Total_Sales
FROM [dbo].[Superstore Sales Dataset]
GROUP BY YEAR(Order_Date)
ORDER BY Year;

-- This query retrieves monthly sales data from the Monthly_Sales_Summary_View.
-- The Monthly_Sales_Summary_View calculates the total sales for each month and year.
-- This query formats the year and month into a 'YYYY-MM' format and orders the results chronologically.

CREATE VIEW Monthly_Sales_Summary_View AS
SELECT
    YEAR(Order_Date) AS Sales_Year,
    MONTH(Order_Date) AS Sales_Month,
    SUM(Sales) AS Total_Sales
FROM [dbo].[Superstore Sales Dataset]
GROUP BY YEAR(Order_Date), MONTH(Order_Date);

SELECT 
    CONCAT(Sales_Year, '-', FORMAT(Sales_Month, '00')) AS Month,
    Total_Sales
FROM Monthly_Sales_Summary_View
ORDER BY  Sales_Year, Sales_Month;


-- This query calculates the rolling total sales for each month.
-- It uses a Common Table Expression (CTE) "ROLLING_TOTAL" to first calculate the total sales for each month,
-- formatting the Order_Date to get the full month name (e.g., 'January 2025').
-- The query then calculates the cumulative sum of sales up to and including each month, using a window function.

WITH Sales AS (
    SELECT
        Order_Date,
        SUM(Sales) AS Total_Sales
    FROM [dbo].[Superstore Sales Dataset]
    WHERE Order_Date IS NOT NULL
    GROUP BY
        Order_Date
),
ROLLING_TOTAL AS (
    SELECT
        Order_Date,
        Total_Sales,  
        SUM(Total_Sales) OVER (ORDER BY Order_Date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Rolling_Total
    FROM Sales
)
SELECT
    Order_Date,
    Total_Sales,
    Rolling_Total
FROM ROLLING_TOTAL
ORDER BY Order_Date;


-- Stored procedure: sp_SalesByDateRange
-- Description: This stored procedure calculates the total sales for each category within a specified date range.
-- Parameters:
--     @StartDate DATE: The starting date for the sales period.
--     @EndDate DATE: The ending date for the sales period.
-- Returns:
--     A result set containing the Category and the corresponding Total_Sales, ordered by Total_Sales in descending order.

CREATE PROCEDURE sp_SalesByDateRange
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        Category,
        SUM(Sales) AS Total_Sales
    FROM [dbo].[Superstore Sales Dataset]
    WHERE Order_Date BETWEEN @StartDate AND @EndDate
    GROUP BY Category
    ORDER BY Total_Sales DESC;
END;

EXEC sp_SalesByDateRange '2015-01-05', '2017-07-05';


-- This query performs an RFM (Recency, Frequency, Monetary) analysis to segment customers.
-- It calculates RFM metrics, assigns scores, and categorizes customers into segments.

WITH Customer_Metrics AS (
    SELECT
        Customer_Name,
        DATEDIFF(day, MAX(Order_Date), GETDATE()) AS Recency,
        COUNT(DISTINCT Order_ID) AS Frequency,
        SUM(Sales) AS Monetary
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Customer_Name
),
RFM_Scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary DESC) AS M_Score
    FROM Customer_Metrics
),
Customer_Segments AS ( -- Added this CTE for clarity and maintainability
    SELECT
        Customer_Name,
        Recency,
        Frequency,
        Monetary,
        R_Score,
        F_Score,
        M_Score,
        CONCAT(R_Score, F_Score, M_Score) AS RFM_Combined,
        CASE
            WHEN (R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4) THEN 'VIP Customers'
            WHEN (R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3) THEN 'Loyal Customers'
            WHEN (R_Score >= 3 AND F_Score >= 1 AND M_Score >= 2) THEN 'Potential Loyalists'
            WHEN (R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2) THEN 'At Risk'
            WHEN (R_Score = 1 AND F_Score = 1 AND M_Score >= 1) THEN 'Lost Customers'
            ELSE 'Others'
        END AS Customer_Segment
    FROM RFM_Scores
)
SELECT
    Customer_Name,
    Recency,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    RFM_Combined,
    Customer_Segment
FROM Customer_Segments
ORDER BY
    CASE  
        WHEN Customer_Segment = 'VIP Customers' THEN 1
        WHEN Customer_Segment = 'Loyal Customers' THEN 2
        ELSE 3
    END;

-- This query calculates the year-over-year (YoY) sales growth.
-- It uses a Common Table Expression (CTE) "YearlySales" to calculate the total sales for each year.
-- It then joins this CTE with itself to compare sales between consecutive years.
-- The final SELECT statement calculates the YoY growth percentage and orders the result by year.

WITH Yearly_Sales AS (
    SELECT 
        YEAR(Order_Date) AS Year,
        SUM(Sales) AS Total_Sales
    FROM [Superstore Sales Dataset]
    GROUP BY YEAR(Order_Date)
)
SELECT 
    a.Year,
    a.Total_Sales,
    b.Total_Sales AS Previous_Year_Sales,
    (a.Total_Sales - b.Total_Sales) / b.Total_Sales * 100 AS YoY_Growth_Percentage
FROM Yearly_Sales a
LEFT JOIN Yearly_Sales b ON a.Year = b.Year + 1
ORDER BY a.Year;

-- This query analyzes product lifecycle stages based on year-over-year sales growth.
-- It uses CTEs to calculate annual sales and orders for each product, then determines the sales growth rate.
-- Finally, it categorizes each product-year into a lifecycle stage (Growth, Maturity, Decline, Introduction)
-- based on the sales growth rate.

WITH Product_Sales_By_Year AS (
    SELECT
        Product_ID,
        YEAR(Order_Date) AS Year,
        SUM(Sales) AS Annual_Sales,
        COUNT(DISTINCT Order_ID) AS Annual_Orders
    FROM [dbo].[Superstore Sales Dataset]
    GROUP BY Product_ID, YEAR(Order_Date)
),
ProductGrowth AS (
    SELECT
        p1.Product_ID,
        p1.Year,
        p1.Annual_Sales,
        p1.Annual_Orders,
        (p1.Annual_Sales - p2.Annual_Sales) / NULLIF(p2.Annual_Sales, 0) * 100 AS Sales_Growth_Rate
    FROM Product_Sales_By_Year p1
    LEFT JOIN Product_Sales_By_Year p2 ON p1.Product_ID = p2.Product_ID AND p1.Year = p2.Year + 1
)
SELECT
    p.Product_ID,
    p.Product_Name,
    pg.Year,
    pg.Annual_Sales,
    pg.Sales_Growth_Rate,
    CASE
        WHEN pg.Sales_Growth_Rate > 20 THEN 'Growth'
        WHEN pg.Sales_Growth_Rate BETWEEN -5 AND 20 THEN 'Maturity'
        WHEN pg.Sales_Growth_Rate < -5 THEN 'Decline'
        ELSE 'Introduction'
    END AS Lifecycle_Stage
FROM ProductGrowth pg
JOIN [dbo].[Superstore Sales Dataset] p ON pg.Product_ID = p.Product_ID
WHERE pg.Sales_Growth_Rate IS NOT NULL
ORDER BY p.Product_ID, pg.Year;

-- This query creates a view called vw_SalesDashboardKPIs that summarizes key monthly performance indicators.
-- The view calculates total orders, unique customers, total sales, and average shipping duration for each month.
-- The Order_Date is formatted as 'yyyy-MM' to group the data by month.

CREATE VIEW vw_Sales_Dashboard_KPIs AS
SELECT
    FORMAT(Order_Date, 'yyyy-MM') AS Month,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers,
    SUM(Sales) AS Total_Sales,
    AVG(shipping_duration_in_days) AS Avg_Shipping_Days
FROM [dbo].[Superstore Sales Dataset]
GROUP BY FORMAT(Order_Date, 'yyyy-MM');


