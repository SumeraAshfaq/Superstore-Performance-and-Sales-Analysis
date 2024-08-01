-- Create the table
CREATE TABLE SalesData (
    City VARCHAR(50),  --Name of the city where the sales data is recorded.
    Year INT,  --Year associated with the sales data.
    Month INT,  --Month associated with the sales data.
    Sales INT   --Sales: Sales amount for a specific city, year, and month.
);

-- Insert data
INSERT INTO SalesData (City, Year, Month, Sales)
VALUES
    ('Delhi', 2020, 5, 4300),
    ('Delhi', 2020, 6, 2000),
    ('Delhi', 2020, 7, 2100),
    ('Delhi', 2020, 8, 2200),
    ('Delhi', 2020, 9, 1900),
    ('Delhi', 2020, 10, 200),
    ('Mumbai', 2020, 5, 4400),
    ('Mumbai', 2020, 6, 2800),
    ('Mumbai', 2020, 7, 6000),
    ('Mumbai', 2020, 8, 9300),
    ('Mumbai', 2020, 9, 4200),
    ('Mumbai', 2020, 10, 9700),
    ('Bangalore', 2020, 5, 1000),
    ('Bangalore', 2020, 6, 2300),
    ('Bangalore', 2020, 7, 6800),
    ('Bangalore', 2020, 8, 7000),
    ('Bangalore', 2020, 9, 2300),
    ('Bangalore', 2020, 10, 8400);

-- Verify data
SELECT * FROM SalesData;

--utilize window functions to compute the "Previous Month Sales," "Next Month Sales," and "YTD Sales" (Year-To-Date Sales)
WITH SalesWithPrevNext AS (
    SELECT
        City,
        Year,
        Month,
        Sales,
        LAG(Sales) OVER (PARTITION BY City ORDER BY Year, Month) AS PreviousMonthSales,
        LEAD(Sales) OVER (PARTITION BY City ORDER BY Year, Month) AS NextMonthSales
    FROM SalesData
),   --Computes the previous month's sales and the next month's sales for each row.
SalesWithYTD AS (
    SELECT
        City,
        Year,
        Month,
        Sales,
        PreviousMonthSales,
        NextMonthSales,
        SUM(Sales) OVER (PARTITION BY City ORDER BY Year, Month) AS YTDSales
    FROM SalesWithPrevNext
)   --Computes the Year-To-Date (YTD) sales using the SUM window function.
SELECT
    City,
    Year,
    Month,
    Sales,
    CASE    ----Uses CASE statements to conditionally display the "Previous Month Sales," "Next Month Sales," and "YTD Sales" only for Delhi, converting numeric values to VARCHAR before applying the CASE statement.
        WHEN City = 'Delhi' THEN CAST(PreviousMonthSales AS VARCHAR(50))
        ELSE ''   --For cities other than Delhi, these fields are displayed as empty strings.
    END AS "Previous Month Sales",
    CASE 
        WHEN City = 'Delhi' THEN CAST(NextMonthSales AS VARCHAR(50))
        ELSE ''
    END AS "Next Month Sales",
    CASE 
        WHEN City = 'Delhi' THEN CAST(YTDSales AS VARCHAR(50))
        ELSE ''
    END AS "YTD Sales"
FROM SalesWithYTD
ORDER BY 
    CASE City
        WHEN 'Delhi' THEN 1
        WHEN 'Mumbai' THEN 2
        WHEN 'Bangalore' THEN 3
        ELSE 4   --Custom sorting logic to ensure Delhi appears first, followed by Mumbai and then Bangalore.
    END,
    Year,
    Month;   --Additionally sorts by Year and Month within each city.


--Summary:
--SalesWithPrevNext CTE: Calculates the previous and next month's sales for each row using window functions.
--SalesWithYTD CTE: Computes the YTD sales for each row using a cumulative sum window function.
--Final SELECT: Formats the output to include the computed values only for Delhi and sorts the results by city and then by year and month.
