--1. Looking at datasets to understand
SELECT  * FROM cust
SELECT * FROM market
SELECT * FROM orders
SELECT * FROM prod
SELECT * FROM shipping

--2. Id columns were reorganized. Their names and data types were changed according to normalization.
UPDATE shipping SET Ship_id = SUBSTRING(Ship_id,5,10)
UPDATE cust SET Cust_id = SUBSTRING(Cust_id,6,15)
UPDATE orders SET Ord_id = SUBSTRING(Ord_id,5,15)
UPDATE prod SET Prod_id = SUBSTRING(Prod_id,6,15) 
UPDATE market SET Ship_id = SUBSTRING(Ship_id,5,10)
UPDATE market SET Cust_id = SUBSTRING(Cust_id,6,15)
UPDATE market SET Ord_id = SUBSTRING(Ord_id,5,15)
UPDATE market SET Prod_id = SUBSTRING(Prod_id,6,15) 

--3.Id columns were controlled to be unique and add constraint to tables to get primary key.
ALTER TABLE prod  ALTER COLUMN Prod_id SMALLINT NOT NULL;
ALTER TABLE prod ADD PRIMARY KEY (Prod_id);

ALTER TABLE cust  ALTER COLUMN Cust_id SMALLINT NOT NULL;
ALTER TABLE cust ADD PRIMARY KEY (Cust_id);

ALTER TABLE orders  ALTER COLUMN Ord_id SMALLINT NOT NULL;
ALTER TABLE orders ADD PRIMARY KEY (Ord_id);

ALTER TABLE shipping  ALTER COLUMN Ship_id SMALLINT NOT NULL;
ALTER TABLE shipping ADD PRIMARY KEY (Ship_id);

--4.On market table, columns data types were changed according to normalization and 
--		add foreign key to table to get relationship with other tables.

ALTER TABLE market  ALTER COLUMN Ship_id SMALLINT NOT NULL;
ALTER TABLE market  ALTER COLUMN Ord_id SMALLINT NOT NULL;
ALTER TABLE market  ALTER COLUMN Cust_id SMALLINT NOT NULL;
ALTER TABLE market  ALTER COLUMN Prod_id SMALLINT NOT NULL;


ALTER TABLE market ADD FOREIGN KEY (Prod_id) REFERENCES prod;
ALTER TABLE market ADD FOREIGN KEY (Cust_id) REFERENCES cust;
ALTER TABLE market ADD FOREIGN KEY (Ord_id) REFERENCES orders;
ALTER TABLE market ADD FOREIGN KEY (Ship_id) REFERENCES shipping;


--1. Create new table named combined_table
SELECT	prod.Prod_id, prod.Product_Category, prod.Product_Sub_Category,
		Cust.Cust_id, cust.Customer_Name, cust.Customer_Segment, cust.Province, cust.Region,
		orders.Ord_id, orders.Order_Date, orders.Order_Priority,
		shipping.Ship_id, shipping.Ship_Date, shipping.Ship_Mode, shipping.Order_ID as internal_ship_id,
		market.Sales, market.Order_Quantity, market.Discount, market.Product_Base_Margin
INTO combined_table
FROM market FULL OUTER JOIN cust ON cust.Cust_id = market.Cust_id
FULL OUTER JOIN orders ON orders.Ord_id = market.Ord_id
FULL OUTER JOIN prod ON prod.Prod_id = market.Prod_id
FULL OUTER JOIN shipping ON shipping.Ship_id = market.Ship_id


--2. Find the top 3 customers who have the maximum count of orders.
 SELECT  TOP 3  Cust_id, Customer_Name, COUNT(DISTINCT Ord_id) count_of_orders
 FROM combined_table
 GROUP BY Cust_id,Customer_Name
 ORDER BY 3 DESC

--3. Create a new column at combined_table as DaysTakenForDelivery 
--		that contains the date difference of Order_Date and Ship_Date.
ALTER TABLE combined_table ADD DaysTakenForDelivery SMALLINT
UPDATE combined_table SET DaysTakenForDelivery = DATEDIFF(DAY, Order_Date, Ship_Date) 


--4. Find the customer whose order took the maximum time to get delivered.
SELECT TOP 1 Cust_id, Customer_Name, Order_Date, Ship_Date,DaysTakenForDelivery
FROM combined_table
ORDER BY DaysTakenForDelivery DESC


--5. Count the total number of unique customers in January and 
--		how many of them came back every month over the entire year in 2011
SELECT  MONTH(Order_Date) AS month_id, COUNT(DISTINCT Cust_id) AS count_of_customer
FROM combined_table
WHERE YEAR(Order_Date) = 2011 AND Cust_id IN (
SELECT DISTINCT Cust_id
FROM combined_table
WHERE YEAR(Order_Date) = 2011 AND  MONTH(Order_Date) = 1)
GROUP  BY MONTH(Order_Date)

--6. Write a query to return for each user the time elapsed between the first
--		purchasing and the third purchasing, in ascending order by Customer ID.
--1st Step
SELECT *, ROW_NUMBER()OVER(PARTITION BY Cust_id ORDER BY Order_Date ) AS row_num
INTO #temp1
FROM(
SELECT DISTINCT Cust_id, Ord_id, Order_Date
FROM combined_table
WHERE Cust_id IN(
SELECT DISTINCT Cust_id
FROM combined_table
GROUP BY Cust_id
HAVING COUNT(DISTINCT Ord_id ) > 2)) AS table1
--2nd step
WITH CTE1 AS(
SELECT Cust_id, (SELECT Order_Date FROM #temp1 WHERE row_num = 1  AND B.Cust_id = Cust_id ) as first_order,
	(SELECT Order_Date FROM #temp1 WHERE row_num = 3  AND B.Cust_id = Cust_id ) as third_order
FROM  #temp1 B)
SELECT DISTINCT Cust_id, DATEDIFF(DAY, first_order, third_order ) AS diff_of_order
FROM CTE1
ORDER BY 1


--2nd Method
WITH CTE1 AS (
SELECT DISTINCT Cust_id, Ord_id, Order_Date
FROM combined_table
WHERE Cust_id IN(
SELECT DISTINCT Cust_id
FROM combined_table
GROUP BY Cust_id
HAVING COUNT(DISTINCT Ord_id ) > 2)),
CTE2 AS(
SELECT *, DATEDIFF(DAY,Order_Date,LEAD(Order_Date,2) OVER(PARTITION BY Cust_id ORDER BY Order_date)) AS diff_day
FROM CTE1)
SELECT DISTINCT Cust_id, FIRST_VALUE(diff_day) OVER(PARTITION BY Cust_id ORDER BY Order_date)
FROM CTE2
ORDER BY 1




--6. Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of 
--		these products to the total number of products purchased by the customer.

WITH CTE1 AS(
SELECT Cust_id,  SUM(Order_Quantity) as total_sum
FROM combined_table
GROUP BY Cust_id),
CTE2 AS(
SELECT Cust_id, SUM(Order_Quantity) AS prod11
FROM combined_table
WHERE Prod_id =  11
GROUP BY Cust_id
),
CTE3 AS(
SELECT Cust_id, SUM(Order_Quantity) AS prod14
FROM combined_table
WHERE Prod_id =  14
GROUP BY Cust_id
)
SELECT	A.Cust_id, 
		prod11  ,CONVERT(NUMERIC(5,2),prod11 *1.0 / total_sum) percentage_of_prod11,
		prod14 ,CONVERT(NUMERIC(5,2),prod14 *1.0 / total_sum) percentage_of_prod14
FROM CTE1 A, CTE2 B, CTE3 C
WHERE A.Cust_id = B.Cust_id AND B.Cust_id = C.Cust_id;


--Customer Segmentation

--1. Create a “view” that keeps visit logs of customers on a monthly basis. (For
--		each log, three field is kept: Cust_id, Year, Month)
CREATE VIEW  vw_VisitingByCustomer AS
SELECT DISTINCT Cust_id, YEAR(Order_Date) year_of_sale, MONTH(Order_Date) month_of_sale, COUNT(DISTINCT Ord_id) count_of_orders
FROM combined_table
GROUP BY Cust_id, YEAR(Order_Date), MONTH(Order_Date);


SELECT *
FROM vw_VisitingByCustomer
ORDER BY 1;

--2. Create a “view” that keeps the number of monthly visits by users. (Show
--		separately all months from the beginning business)
CREATE VIEW vw_VisitingByMonth AS 
SELECT *
FROM(
SELECT month_of_sale,year_of_sale,count_of_orders  FROM vw_VisitingByCustomer) as table1
PIVOT(
SUM(count_of_orders)
FOR year_of_sale IN ([2009],[2010],[2011],[2012])) AS pivot1

SELECT * 
FROM vw_VisitingByMonth
ORDER BY 1


--3. For each visit of customers, create the next month of the visit as a separate column.
CREATE VIEW vw_NextYearAndMonth AS
SELECT *, LEAD(year_of_sale) OVER (PARTITION BY Cust_id  ORDER BY year_of_sale , month_of_sale ) AS next_year ,
	LEAD(month_of_sale) OVER (PARTITION BY Cust_id ORDER BY year_of_sale , month_of_sale ) AS next_month
FROM vw_VisitingByCustomer

SELECT *
FROM vw_NextYearAndMonth


--4. Calculate the monthly time gap between two consecutive visits by each customer.
SELECT DISTINCT Cust_id, 
	(next_year - year_of_sale)*12+(next_month - month_of_sale)
FROM vw_NextYearAndMonth
ORDER BY 1;



--5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.

--1st Step
SELECT  Cust_id,  SUM(count_of_orders) sum_of_orders,
		AVG((next_year - year_of_sale)*12+(next_month - month_of_sale)) avg_gap_between_orders,
		COUNT(*) count_of_diff_months
INTO #temp2
FROM vw_NextYearAndMonth
GROUP BY Cust_id
ORDER BY 1;

SELECT AVG(avg_gap_between_orders), AVG(count_of_diff_months) 
FROM #temp2

--2nd and last Step
DECLARE @AVG_GAP TINYINT, @AVG_COUNT TINYINT
SELECT  @AVG_GAP=AVG(avg_gap_between_orders), @AVG_COUNT=AVG(count_of_diff_months) 
FROM #temp2
SELECT  Cust_id,
CASE
	WHEN count_of_diff_months > @AVG_COUNT  AND  avg_gap_between_orders <=  @AVG_GAP/2 THEN 'Regular'
	WHEN count_of_diff_months > @AVG_COUNT  AND avg_gap_between_orders >  @AVG_GAP/2 THEN 'Average'
	WHEN sum_of_orders = 1  THEN 'One Time'
	ELSE 'Rare'
	END customer_classification
FROM #temp2

--one time customer : sum of orders = 1 
--regular customer	: count_of_different_months > 3, avg_gap_between_orders <= 5
--average customer	: count_of_different_months > 3, avg_gap_between_orders > 5
--rare customer		: count_of_different_months <4







--Month-Wise Retention Rate
--Find month-by-month customer retention ratei since the start of the business.


--1st Step
CREATE TABLE #temp3 (
MONTH_ INT NULL,
YEAR_ INT NULL,
COUNT1 INT NULL,
COUNT2 INT NULL,
);

--2nd Step
DECLARE @YEAR INT = 2009
DECLARE @MONTH INT = 1
DECLARE @MONTH2 INT = 2
DECLARE @COUNT1 INT
DECLARE @COUNT2 INT
WHILE @YEAR < 2013
BEGIN
	SET @MONTH  = 1
	SET @MONTH2 = 2
	WHILE @MONTH2 < 13
	BEGIN
	
		SELECT @COUNT1 = COUNT(*)
		FROM(
		SELECT DISTINCT Cust_id
		FROM combined_table
		WHERE YEAR(Order_Date) = @YEAR AND MONTH(Order_Date) = @MONTH
		INTERSECT
		SELECT DISTINCT Cust_id
		FROM combined_table
		WHERE YEAR(Order_Date) = @YEAR AND MONTH(Order_Date) = @MONTH2) AS table1
		
		SELECT @COUNT2 = COUNT(DISTINCT Cust_id)
		FROM combined_table
		WHERE YEAR(Order_Date) = @YEAR AND MONTH(Order_Date) = @MONTH2
		
		
		INSERT INTO #temp3 VALUES (@MONTH2,@YEAR,@COUNT1,@COUNT2)
		
		IF @MONTH2 = 12
			BEGIN
				SELECT @COUNT1 =COUNT(*)
				FROM(
				SELECT DISTINCT Cust_id
				FROM combined_table
				WHERE YEAR(Order_Date) = @YEAR AND MONTH(Order_Date) = @MONTH2
				INTERSECT
				SELECT DISTINCT Cust_id
				FROM combined_table
				WHERE YEAR(Order_Date) = @YEAR+1 AND MONTH(Order_Date) = 1) AS table1
		
				SELECT @COUNT2 = COUNT(DISTINCT Cust_id)
				FROM combined_table
				WHERE YEAR(Order_Date) = @YEAR+1 AND MONTH(Order_Date) = 1
		

				INSERT INTO #temp3 VALUES (1,@YEAR+1,@COUNT1, @COUNT2)
			END
		SET @MONTH = @MONTH+1
		SET @MONTH2 = @MONTH2+1
	END
	SET @YEAR = @YEAR+1
END

--3rd and last Step
SELECT *
FROM(
SELECT MONTH_, YEAR_, CONVERT( NUMERIC(10,2), COUNT1*1.0 / COUNT2)  AS percentage_
FROM #temp3
WHERE NOT COUNT1 = 0) AS table1
PIVOT(
MAX(percentage_)
FOR YEAR_ IN ([2009],[2010],[2011],[2012]) ) AS pivot1












