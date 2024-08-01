--Import the Dataset into SQL Server

--Rename column names:

--Declare Variables
--@table_name is a variable that stores the name of the table whose columns will be renamed. In this case, the table is 'Orders'.
DECLARE @table_name NVARCHAR(255) = 'Orders';
--@sql is a variable that will hold the dynamically constructed SQL statement.
DECLARE @sql NVARCHAR(MAX) = '';

--Build SQL Statement
--The STRING_AGG function concatenates the rename commands for each column, separated by spaces.
--sp_rename takes three arguments: the current column name (@table_name + '.[' + COLUMN_NAME + ']'), the new column name (REPLACE(COLUMN_NAME, ' ', '_')), and the type of object being renamed ('COLUMN').
SELECT @sql = STRING_AGG('EXEC sp_rename ''' + @table_name + '.[' + COLUMN_NAME + ']'', ''' + REPLACE(COLUMN_NAME, ' ', '_') + ''', ''COLUMN'';', ' ')
FROM INFORMATION_SCHEMA.COLUMNS   --The INFORMATION_SCHEMA.COLUMNS system view is queried to get the names of columns in the specified table.
WHERE TABLE_NAME = @table_name AND COLUMN_NAME LIKE '% %';   --The WHERE clause filters the columns to include only those whose names contain spaces.

--sp_executesql is used to execute the dynamically constructed SQL statement stored in @sql.
EXEC sp_executesql @sql;   --For each column that meets the criteria, an EXEC sp_rename statement is generated.

--verify data
SELECT * FROM Orders;

--Check the column names in each table
SELECT name FROM sys.columns
WHERE object_id = OBJECT_ID('Orders');
SELECT name FROM sys.columns
WHERE object_id = OBJECT_ID('People');
SELECT name FROM sys.columns
WHERE object_id = OBJECT_ID('Returns');

--Check the missing values in the tables
SELECT * FROM orders
WHERE ROW_ID IS NULL OR Order_ID IS NULL OR Order_Date IS NULL OR Ship_Date IS NULL OR Sales IS NULL;

--Check for duplicate rows
SELECT Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name, Segment, Country, City, State, Postal_Code, Region, Product_ID, Category, Sub_Category, Product_Name, Sales, Quantity, Discount, Profit,
COUNT(*) 
AS Duplicate_Count
FROM Orders
Group by Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name, Segment, Country, City, State, Postal_Code, Region, Product_ID, Category, Sub_Category, Product_Name, Sales, Quantity, Discount, Profit
HAVING COUNT(*) > 1;  --One duplicate row found

--Remove the Duplicate values
WITH DuplicateRows AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name, Segment, Country, City, State, Postal_Code, Region, Product_ID, Category, Sub_Category, Product_Name, Sales, Quantity, Discount, Profit ORDER BY (SELECT NULL)) AS RowNum
    FROM Orders
)
DELETE FROM DuplicateRows WHERE RowNum > 1;

--Verify data
SELECT * FROM Orders;

--Calculate LTV, Find the Top 5 Customers and rank customers
--Calculate Years Correctly: Use DATEDIFF(YEAR, MIN(o.Order_Date), GETDATE()) to calculate the number of years correctly.
--Rank Customers by LTV: Use ROW_NUMBER() to rank customers based on their calculated LTV.
WITH CustomerLTV AS (
    SELECT 
        o.Customer_ID,
        SUM(o.Profit) / DATEDIFF(YEAR, MIN(o.Order_Date), GETDATE()) AS LTV,
        ROW_NUMBER() OVER (ORDER BY SUM(o.Profit) / DATEDIFF(YEAR, MIN(o.Order_Date), GETDATE()) DESC) AS Rank
    FROM 
        dbo.orders o
    INNER JOIN    --Ensure the INNER JOIN uses Customer_ID to match customers accurately.
        dbo.people p ON o.Region = p.Region
    LEFT JOIN 
        dbo.returns r ON o.Order_ID = r.Order_ID
	 WHERE
        r.Order_ID IS NULL    --Ensure that the LEFT JOIN and WHERE clause correctly exclude returned orders from the LTV calculation.
    GROUP BY 
        o.Customer_ID
)
-- Retrieve the top 5 customers by LTV
SELECT TOP 5
    cl.Customer_ID,
    cl.LTV
FROM 
    CustomerLTV cl
WHERE 
    cl.Rank <= 5
ORDER BY 
    cl.LTV DESC;

--Create a pivot table to show total sales by product category and sub-category:
--The PIVOT function requires sub-categories to be explicitly listed. This method is less flexible and more complex than simple aggregation for this type of problem.
--SELECT Category, SubCategory, SUM(Sales) AS TotalSales: Selects the category, sub-category, and sums the sales.
SELECT 
    Category,
    Sub_Category,
    SUM(Sales) AS TotalSales
FROM 
    Orders
GROUP BY   --GROUP BY Category, SubCategory: Groups the results by category and sub-category.
    Category,
    Sub_Category
ORDER BY   --ORDER BY Category, SubCategory: Orders the results by category and sub-category for better readability.
    Category,
    Sub_Category;

--Find the customer who has made the maximum number of orders in each category:
--Aggregate Orders by Customer and Category: Count the number of orders for each customer within each category.
WITH CustomerOrderCount AS (
    SELECT 
        Customer_ID,
        Category,
        COUNT(Order_ID) AS OrderCount
    FROM 
        Orders
    GROUP BY 
        Customer_ID, Category
), 
--Identify the Maximum Orders by Category: Use a subquery or a Common Table Expression (CTE) to find the maximum order count for each category.
MaxOrderCountByCategory AS (
    SELECT 
        Category,
        MAX(OrderCount) AS MaxOrderCount
    FROM 
        CustomerOrderCount
    GROUP BY 
        Category
) 
--Join to Get Customer Details: Join back to the main table to get the customer details for the maximum counts.
SELECT 
    coc.Customer_ID,
    coc.Category,
    coc.OrderCount AS MaxOrderCount
FROM 
    CustomerOrderCount coc
JOIN 
    MaxOrderCountByCategory moc
ON 
    coc.Category = moc.Category AND coc.OrderCount = moc.MaxOrderCount
ORDER BY 
    coc.Category, coc.OrderCount DESC; 

--Find the top 3 products in each category based on their sales:
--Aggregate Sales by Product and Category: Calculate the total sales for each product within each category.
WITH ProductSales AS (
    SELECT 
        Category,
        Product_ID,
        Product_Name,
        SUM(Sales) AS TotalSales
    FROM 
        Orders
    GROUP BY 
        Category, Product_ID, Product_Name
), 
--Rank Products within Each Category: Use the ROW_NUMBER() function to rank the products by their sales within each category.
RankedProductSales AS (
    SELECT 
        Category,
        Product_ID,
        Product_Name,
        TotalSales,
        ROW_NUMBER() OVER (PARTITION BY Category ORDER BY TotalSales DESC) AS SalesRank
    FROM 
        ProductSales
) 
--Filter the Top 3 Products for Each Category: Select only the top 3 products for each category based on the ranking.
SELECT 
    Category,
    Product_ID,
    Product_Name,
    TotalSales
FROM 
    RankedProductSales
WHERE 
    SalesRank <= 3
ORDER BY 
    Category, SalesRank; 

--Create the Function to Calculate Days Between Two Dates
CREATE FUNCTION dbo.DaysBetween (@startDate DATE, @endDate DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @startDate, @endDate);
END;

--Create the Stored Procedure Get_Customer_Orders
CREATE PROCEDURE Get_Customer_Orders
    @CustomerID NVARCHAR(50)
AS
BEGIN
    DECLARE @TotalOrders INT,
            @AvgAmount DECIMAL(10, 2),
            @TotalAmount DECIMAL(10, 2),
            @LastOrderDate DATE,
            @DaysSinceLastOrder INT;

    -- Calculate aggregate data
    SELECT 
        @TotalOrders = COUNT(Order_ID),
        @AvgAmount = AVG(Sales),
        @TotalAmount = SUM(Sales),
        @LastOrderDate = MAX(Order_Date)
    FROM 
        Orders
    WHERE 
        Customer_ID = @CustomerID;

    -- Calculate days since the last order
    SET @DaysSinceLastOrder = dbo.DaysBetween(@LastOrderDate, GETDATE());

    -- Return the results as a table
    SELECT 
        Order_Date,
        @TotalAmount AS TotalAmount,
        @TotalOrders AS TotalOrders,
        @AvgAmount AS AvgAmount,
        @LastOrderDate AS LastOrderDate,
        @DaysSinceLastOrder AS DaysSinceLastOrder
    FROM 
        Orders
    WHERE 
        Customer_ID = @CustomerID
    ORDER BY 
        Order_Date;
END;

--Execute the stored procedure
EXEC Get_Customer_Orders @CustomerID = 'LB-16795';

--Improvised stored procedure Get_Customer_Orders 
CREATE PROCEDURE Get_Customer_Orders_Improvised
    @CustomerID NVARCHAR(50)
AS
BEGIN
    DECLARE @TotalOrders INT,
            @AvgAmount DECIMAL(10, 2),
            @TotalAmount DECIMAL(10, 2),
            @LastOrderDate DATE,
            @DaysSinceLastOrder INT;

    -- Calculate aggregate data
    SELECT 
        @TotalOrders = COUNT(Order_ID),
        @AvgAmount = AVG(Sales),
        @TotalAmount = SUM(Sales),
        @LastOrderDate = MAX(Order_Date)
    FROM 
        Orders
    WHERE 
        Customer_ID = @CustomerID;

    -- Calculate days since the last order
    SET @DaysSinceLastOrder = dbo.DaysBetween(@LastOrderDate, GETDATE());

    -- Return the results as a table
    SELECT DISTINCT
        @CustomerID AS CustomerID,
        @TotalAmount AS TotalAmount,
        @TotalOrders AS TotalOrders,
        @AvgAmount AS AvgAmount,
        @LastOrderDate AS LastOrderDate,
        @DaysSinceLastOrder AS DaysSinceLastOrder
    FROM 
        Orders
    WHERE 
        Customer_ID = @CustomerID;
    --ORDER BY 
        --Order_Date;
END;

--Execute the stored procedure
EXEC Get_Customer_Orders_Improvised @CustomerID = 'LB-16735';
--DROP PROCEDURE Get_Customer_Orders_Improvised;
