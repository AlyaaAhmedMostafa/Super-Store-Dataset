select *
from [Superstore Sales ]..[Superstore Sales Dataset]

--Adding missing postal codes to Burlington city records
UPDATE [Superstore Sales ]..[Superstore Sales Dataset]
SET Postal_Code ='05401'
Where City = 'Burlington' AND State ='Vermont'
And Postal_Code IS NULL

-- Calculating shipping duration
SELECT Order_ID,Order_Date,Ship_Date,
DATEDIFF(DAY,Order_Date,Ship_Date) AS shipping_duration_in_days
from [Superstore Sales ]..[Superstore Sales Dataset]

--adding shipping duration in days column
ALTER TABLE [Superstore Sales]..[Superstore Sales Dataset]
ADD shipping_duration_in_days INT

UPDATE [Superstore Sales]..[Superstore Sales Dataset]
SET shipping_duration_in_days = DATEDIFF(DAY, Order_Date, Ship_Date)

--Exploring the data 

--calculating the total number of orders, unique customers, unique products, and total sales
SELECT COUNT(*) AS Total_Orders, 
       COUNT(DISTINCT Customer_ID) AS Unique_Customers, 
       COUNT(DISTINCT Product_ID) AS Unique_Products, 
       SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]

--calculating Average Sales
SELECT AVG(Sales) AS Average_Order_Value
FROM [Superstore Sales]..[Superstore Sales Dataset]

--Calculating Total Sales in each region
SELECT Region, SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY Region
ORDER BY Total_Sales DESC

--Top 10 Customers
WITH CustomerTotals AS (
    SELECT Customer_Name, SUM(Sales) AS Total_Sales,
           ROW_NUMBER() OVER (ORDER BY SUM(Sales) DESC) AS RowNum
    FROM [Superstore Sales]..[Superstore Sales Dataset]
    GROUP BY Customer_Name
)
SELECT *
FROM CustomerTotals
WHERE RowNum <= 10

-- Calculating total sales in each state
SELECT State ,SUM(Sales) AS Total_Sales_Per_State
FROM  [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY  State
ORDER BY Total_Sales_Per_State DESC

--Calculating total sales in each city
SELECT City ,SUM(Sales) AS Total_Sales_Per_City
FROM  [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY  City
ORDER BY Total_Sales_Per_City DESC

--Calculating total sales in each segment
SELECT Segment ,SUM(Sales) AS Total_Sales_Per_Segment
FROM  [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY  Segment
ORDER BY Total_Sales_Per_Segment DESC

--Calculating total sales in each category
SELECT Category ,SUM(Sales) AS Total_Sales_Per_Category
FROM  [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY  Category
ORDER BY Total_Sales_Per_Category DESC

-- Arranging categories by sales in each region
WITH RegionCategorySales AS (
    SELECT
        Region,Category, SUM(Sales) AS Total_Sales,
        RANK() OVER (PARTITION BY Region ORDER BY SUM(Sales) DESC) AS CategoryRank
    FROM [Superstore Sales]..[Superstore Sales Dataset]
    GROUP BY Region, Category
)
SELECT
    Region,Category,Total_Sales
FROM RegionCategorySales
WHERE CategoryRank <=3

-- Arranging categories by sales in each state
SELECT State,Category,SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY State, Category
ORDER BY  Total_Sales DESC

--Calculating total sales in each subcategory
SELECT Sub_Category, SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY Sub_Category

--Top 10 Products
SELECT Top 10 Product_Name,SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY Product_Name
ORDER BY Total_Sales DESC

--  calculating the total sales for each year 
SELECT YEAR(Order_Date) AS Year,  SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY YEAR(Order_Date)
ORDER BY Year

--calculating the total sales for each month  
SELECT Year(Order_Date) AS Year, Month(Order_Date) AS Month, SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY YEAR(Order_Date), MONTH(Order_Date)
ORDER BY  Year, Month

-- Measuring shipping duration in each region
SELECT  Region , AVG(shipping_duration_in_days) AS Avg_Shipping_Duration
FROM [Superstore Sales]..[Superstore Sales Dataset]
Group by   Region
ORDER BY  Avg_Shipping_Duration

--Measuring the shipping duration for each state
SELECT State ,AVG(shipping_duration_in_days) AS Avg_Shipping_Duration
FROM [Superstore Sales]..[Superstore Sales Dataset]
Group by  State
ORDER BY  Avg_Shipping_Duration

--Computing the duration of shipments for different shipping modes
SELECT Ship_Mode, AVG(shipping_duration_in_days) AS Average_Shipping_Time
FROM  [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY Ship_Mode
ORDER BY  Average_Shipping_Time

--Determining sales by ship method
SELECT Ship_Mode, SUM(Sales) AS Total_Sales
FROM [Superstore Sales]..[Superstore Sales Dataset]
GROUP BY Ship_Mode
ORDER BY Total_Sales DESC


