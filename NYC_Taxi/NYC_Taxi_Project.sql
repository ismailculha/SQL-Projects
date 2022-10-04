SELECT TOP 100 *
FROM nyc_oct;

-- INFORMATIONS ABOUT DATASET

--VendorID A code indicating the LPEP provider that provided the record. // 1= Creative Mobile Technologies, LLC; 2= VeriFone Inc.
--lpep_pickup_datetime : The date and time when the meter was engaged.
--lpep_dropoff_datetime : The date and time when the meter was disengaged.
--Passenger_count : The number of passengers in the vehicle. This is a driver-entered value.
--Trip_distance : The elapsed trip distance in miles reported by the taximeter.
--Pickup_longitude : Longitude where the meter was engaged.
--Pickup_latitude : Latitude where the meter was engaged.
--RateCodeID : The final rate code in effect at the end of the trip. // 1= Standard rate, 2=JFK, 3=Newark, 4=Nassau or Westchester, 5=Negotiated fare, 6=Group ride
--Store_and_fwd_flag : This flag indicates whether the trip record was held in vehicle memory before sending to the vendor, aka “store and forward,” because the vehicle did not have a connection to the server.
--						Y= store and forward trip // N= not a store and forward trip
--Dropoff_longitude : Longitude where the meter was timed off.
--Dropoff_ latitude : Latitude where the meter was timed off.
--Payment_type : A numeric code signifying how the passenger paid for the trip.
--				1= Credit card, 2= Cash, 3= No charge, 4= Dispute, 5= Unknown, 6= Voided trip
--Fare_amount : The time-and-distance fare calculated by the meter.
--Extra : Miscellaneous extras and surcharges. Currently, this only includes the $0.50 and $1 rush hour and overnight charges.
--MTA_tax : $0.50 MTA tax that is automatically triggered based on the metered rate in use.
--Improvement_surcharge : $0.30 improvement surcharge assessed on hailed trips at the flag drop. The improvement surcharge began being levied in 2015.
--Tip_amount : Tip amount – This field is automatically populated for credit card tips. Cash tips are not included.
--Tolls_amount : Total amount of all tolls paid in trip.
--Total_amount : The total amount charged to passengers. Does not include cash tips.
--Trip_type : A code indicating whether the trip was a street-hail or a dispatch that is automatically assigned based on the metered rate in use but can be altered by the driver.
--			1= Street-hail, 2= Dispatch


-- 1. QUESTION
--		   1. Most expensive trip (total amount)?
SELECT TOP 1 *
FROM nyc_sep
ORDER BY Total_amount DESC;

SELECT MAX(Total_amount) FROM nyc_sep

-- 2. QUESTION
--			2. Most expensive trip per mile (total amount/mile).
SELECT *, (Total_amount / Trip_distance)
FROM nyc_sep
WHERE (Total_amount > 0) AND (Trip_distance > 0)
ORDER BY (Total_amount / Trip_distance) DESC;

SELECT MAX(Total_amount / Trip_distance) FROM nyc_sep WHERE (Total_amount > 0) AND (Trip_distance > 0)

-- 3. QUESTION
--			3. Most generous trip (highest tip).
SELECT TOP 1 *
FROM nyc_sep
ORDER BY Tip_amount DESC

SELECT MAX(Tip_amount) FROM nyc_sep

-- 4. QUESTION
--			4. Longest trip duration.
SELECT TOP 1 *, DATEDIFF(MINUTE,lpep_pickup_datetime,Lpep_dropoff_datetime ) AS diff_time
FROM nyc_sep
ORDER BY diff_time DESC

SELECT MAX(DATEDIFF(MINUTE,lpep_pickup_datetime,Lpep_dropoff_datetime )) FROM nyc_sep

-- 5. QUESTION
--			5. Mean tip by hour.
SELECT	DATEPART(HOUR,lpep_pickup_datetime), 
		AVG(Tip_amount)
FROM nyc_sep
GROUP BY DATEPART(HOUR,lpep_pickup_datetime)
ORDER BY DATEPART(HOUR,lpep_pickup_datetime)

SELECT DISTINCT	DATEPART(HH,lpep_pickup_datetime),
		AVG(Tip_amount) OVER (PARTITION BY DATEPART(HH,lpep_pickup_datetime))
FROM nyc_sep
ORDER BY DATEPART(HH,lpep_pickup_datetime)

-- 6. QUESTION
--			6. Median trip cost.
SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Total_amount) OVER () AS Median_TripCost
FROM nyc_sep

-- 7. QUESTION
--			7. Average total trip by day of week 
SELECT DATEPART(WEEKDAY, day_ ) as week_day, lpep_pickup_day_of_week , AVG(total_trip) avg_trip
FROM (
SELECT DISTINCT CONVERT(DATE, lpep_pickup_datetime) day_,
	lpep_pickup_day_of_week,
	COUNT(*) OVER (PARTITION BY CONVERT(DATE, lpep_pickup_datetime)) total_trip
FROM nyc_sep ) as table_1
GROUP BY DATEPART(WEEKDAY, day_ ), lpep_pickup_day_of_week
ORDER BY week_day

-- 8. QUESTION
--			8. Count of trips by hour
SELECT	DISTINCT DATEPART(HOUR, lpep_pickup_datetime), 
		lpep_pickup_hour , 
		COUNT(*) OVER( PARTITION BY DATEPART(HOUR, lpep_pickup_datetime))
FROM nyc_sep

-- 9. QUESTION
--			9. Average passenger count per trip by hour
SELECT DISTINCT trip_hour, CONVERT(NUMERIC(8,2),(SUM(sum_passenger) OVER (PARTITION BY trip_hour) *1.0 / COUNT (*) OVER (PARTITION BY trip_hour)))
FROM (	SELECT DISTINCT	CONVERT(DATE, lpep_pickup_datetime) AS day_,
				DATEPART(HOUR, lpep_pickup_datetime) AS trip_hour, 
				SUM(Passenger_count) OVER(PARTITION BY CONVERT(DATE, lpep_pickup_datetime),DATEPART(HOUR, lpep_pickup_datetime) ) sum_passenger
		FROM nyc_sep) 
		AS table_1

-- 10. QUESTION
--			10. Which airport welcomes more passengers: JFK or EWR? 
SELECT TOP 1 RateCodeID, SUM(Passenger_count) AS passenger_count,
	CASE 
	WHEN RateCodeID = 2 THEN 'JFK'
	ELSE 'EWR'
	END airport_name
FROM nyc_sep
WHERE (RateCodeID = 2) OR (RateCodeID = 3)
GROUP BY RateCodeID
ORDER BY RateCodeID

-- 11. QUESTION
--			11. How many nulls are there in Total_amount?
SELECT SUM(CASE WHEN Total_amount  IS NULL THEN 1 ELSE 0 END)
FROM nyc_sep

-- 12. QUESTION
--			12. How many null values are there in Trip_distance? 
SELECT COUNT(*)
FROM nyc_sep
WHERE Trip_distance IS NULL

-- 13. QUESTION
--			13. Find the trips of which trip distance is greater than 15 miles (included) or less than 0.1 mile (included)?
SELECT *
FROM nyc_sep
WHERE (Trip_distance > 15) OR (Trip_distance < 0.1)

-- 14. QUESTION
--			14. We would like to see the distribution (not like histogram) of Total_amount. 
--			Could you create buckets, or price range, for Total_amount and find how many trips there are in each buckets?
SELECT payment_range ,COUNT(*) AS Trip_Count
FROM(
SELECT Total_amount,
	CASE
	WHEN Total_amount BETWEEN 0 AND 4.99 THEN '0-5'
	WHEN Total_amount BETWEEN 5 AND 9.99 THEN '5-10'
	WHEN Total_amount BETWEEN 10 AND 14.99 THEN '10-15'
	WHEN Total_amount BETWEEN 15 AND 19.99 THEN '15-20'
	WHEN Total_amount BETWEEN 20 AND 24.99 THEN '20-25'
	WHEN Total_amount BETWEEN 25 AND 29.99 THEN '25-30'
	WHEN Total_amount BETWEEN 30 AND 34.99 THEN '30-35'
	ELSE '35+'
	END payment_range
FROM nyc_sep) AS table1
GROUP BY payment_range
ORDER BY payment_range

-- 15. QUESTION
--			15. We also would like to analyze the performance of each driver’s earning. 
--			Could you add driver_id to payment distribution table?  


SELECT driver_id, payment_range , COUNT(*) AS Trip_Count
FROM(
SELECT Total_amount, driver_id,
	CASE
	WHEN Total_amount BETWEEN 0 AND 4.99 THEN '0-5'
	WHEN Total_amount BETWEEN 5 AND 9.99 THEN '5-10'
	WHEN Total_amount BETWEEN 10 AND 14.99 THEN '10-15'
	WHEN Total_amount BETWEEN 15 AND 19.99 THEN '15-20'
	WHEN Total_amount BETWEEN 20 AND 24.99 THEN '20-25'
	WHEN Total_amount BETWEEN 25 AND 29.99 THEN '25-30'
	WHEN Total_amount BETWEEN 30 AND 34.99 THEN '30-35'
	ELSE '35+'
	END payment_range
FROM nyc_sep) AS table1
GROUP BY  payment_range , driver_id
ORDER BY driver_id, payment_range

-- 16. QUESTION
--			16. Could you find the highest 3 Total_amount trips for each driver
SELECT DISTINCT driver_id, Total_amount
FROM(
	SELECT  *, DENSE_RANK () OVER (PARTITION BY driver_id ORDER BY Total_amount DESC ) row_num
	FROM nyc_sep) AS table1
WHERE row_num < 4
ORDER BY driver_id ASC, Total_amount DESC

-- 17. QUESTION
--			17. Could you find the lowest 3 Total_amount trips for each driver
SELECT driver_id, Total_amount
FROM(
	SELECT  *, ROW_NUMBER () OVER (PARTITION BY driver_id ORDER BY Total_amount ASC ) row_num
	FROM nyc_sep) AS table1
WHERE row_num < 4

-- 18. QUESTION
--			18. Could you find the lowest 10 Total_amount trips for driver_id 1?
SELECT DISTINCT driver_id, Total_amount
FROM(
	SELECT  *, DENSE_RANK () OVER (PARTITION BY driver_id ORDER BY Total_amount ASC ) row_num
	FROM nyc_sep) AS table1
WHERE row_num < 10 AND driver_id = 1

-- 19. QUESTION
--			19.  Our friend, driver_id 1, is very happy to see what we have done for her.
--			Could you do her a favor and track her earning after each trip? 
SELECT	lpep_pickup_datetime, Total_amount, Passenger_count, 
		SUM(Total_amount) OVER(ORDER BY lpep_pickup_datetime ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Sum
FROM nyc_sep
WHERE driver_id = 1

-- 20. QUESTION
--			20.  Driver_id 1, is fascinated by your work and would like you to find max and min Total_amount.
SELECT lpep_pickup_datetime, Total_amount, Passenger_count 
FROM nyc_sep
WHERE driver_id = 1 AND 
		Total_amount = (SELECT MIN(Total_amount) FROM nyc_sep WHERE driver_id = 1) OR
		Total_amount = (SELECT MAX(Total_amount) FROM nyc_sep WHERE driver_id = 1)
ORDER BY Total_amount

-- 21. QUESTION
--			21.  Is there any new driver in October? Hint: Drivers existing in one table but not in another table.
SELECT DISTINCT driver_id
FROM nyc_oct NYO
WHERE NOT EXISTS (	SELECT DISTINCT driver_id
					FROM nyc_sep NYS
					WHERE NYS.driver_id = NYO.driver_id)

-- 22. QUESTION
--			22.  Total amount difference between October and September.
SELECT SUM(Total_amount) - (SELECT SUM (Total_amount) FROM nyc_sep) AS diff_of_two_months
FROM nyc_oct

-- 23. QUESTION
--			23.  Revenue of drivers each month.
SELECT *, (total_amount_oct - total_amount_sep) AS oct_sep_revenue_difference
FROM(
	SELECT	DISTINCT NYO.driver_id , SUM(NYO.Total_amount) OVER (PARTITION BY NYO.driver_id ) AS total_amount_oct,
			(SELECT DISTINCT SUM(NYS.Total_amount) OVER (PARTITION BY NYS.driver_id)
			FROM nyc_sep NYS
			WHERE NYS.driver_id = NYO.driver_id) AS total_amount_sep
	FROM nyc_oct NYO
	WHERE EXISTS (	SELECT DISTINCT NYS.driver_id 
					FROM nyc_sep NYS
					WHERE NYS.driver_id = NYO.driver_id) ) AS table1
ORDER BY driver_id

-- 24. QUESTION
--			24.  Trip count of drivers each month.
SELECT *, (trip_count_oct - trip_count_sep) AS oct_sep_revenue_difference
FROM(
	SELECT	DISTINCT NYS.driver_id ,
			(SELECT DISTINCT COUNT(*) OVER (PARTITION BY NYO.driver_id)
			FROM nyc_oct NYO
			WHERE NYS.driver_id = NYO.driver_id) AS trip_count_oct,
			COUNT(*) OVER (PARTITION BY NYS.driver_id ) AS trip_count_sep
	FROM nyc_sep NYS ) AS table1
ORDER BY driver_id

-- 25. QUESTION
--			25.  Revenue_per-trip of drivers each month.
SELECT *, (revenue_per_trip_oct - revenue_per_trip_sep) AS revenue_difference
FROM(
	SELECT	DISTINCT NYS.driver_id,
			(	SELECT	DISTINCT AVG(NYO.Total_amount) OVER(PARTITION BY NYO.driver_id)
				FROM nyc_oct NYO
				WHERE NYS.driver_id = NYO.driver_id) AS revenue_per_trip_oct,
			AVG(NYS.Total_amount) OVER(PARTITION BY NYS.driver_id) AS revenue_per_trip_sep
	FROM nyc_sep NYS ) AS table1
ORDER BY driver_id

-- 26. QUESTION
--			26.  Revenue per day of week for each driver comparison
SELECT *, (total_amount_oct - total_amount_sep) AS total_amount_diff
FROM(
SELECT	DISTINCT NYS.driver_id, NYS.lpep_pickup_day_of_week,
		(SELECT DISTINCT SUM(NYO.Total_amount) OVER (PARTITION BY  NYO.driver_id, NYO.lpep_pickup_day_of_week)
		FROM nyc_oct NYO
		WHERE NYO.driver_id = NYS.driver_id  AND NYO.lpep_pickup_day_of_week = NYS.lpep_pickup_day_of_week
		) AS total_amount_oct,
		SUM(NYS.Total_amount) OVER (PARTITION BY  NYS.driver_id, NYS.lpep_pickup_day_of_week) AS total_amount_sep
FROM nyc_sep NYS) AS table1

-- 27. QUESTION
--			27.  Revenue and trip count comparison of VendorID

WITH NYC_CTE AS(
SELECT VendorID, SUM(Total_amount) total_oct, COUNT(*) count_oct
FROM nyc_oct
GROUP BY VendorID),
NYO_CTE AS(
SELECT VendorID, SUM(Total_amount) total_sep, COUNT(*) count_sep
FROM nyc_sep
GROUP BY VendorID
)
SELECT NYO_CTE.VendorID, total_oct, total_sep, (total_oct-total_sep) AS diff_total, count_oct, count_sep, (count_oct-count_sep) diff_count
FROM NYC_CTE, NYO_CTE
WHERE NYC_CTE.VendorID = NYO_CTE.VendorID

-- 28. QUESTION
--			28.  Find the trips that are longer than previous trip
WITH CTE AS(
SELECT	trip_id ,driver_id, lpep_pickup_datetime, Lpep_dropoff_datetime, 
		DATEDIFF(MINUTE, lpep_pickup_datetime, Lpep_dropoff_datetime) AS diff_minute,
		LAG(DATEDIFF(MINUTE, lpep_pickup_datetime, Lpep_dropoff_datetime)) OVER (PARTITION BY driver_id ORDER BY lpep_pickup_datetime) AS previous_trip
FROM nyc_sep),
CTE2 AS(
SELECT *,IIF(diff_minute > previous_trip,1,0) AS compare
FROM CTE)
SELECT trip_id, driver_id, lpep_pickup_datetime, Lpep_dropoff_datetime
FROM CTE2
WHERE compare = 1

-- 29. QUESTION
--			29.  Which drivers are having good days?These are the drivers whose next revenue is more than previous revenue.
--			In other words, revenue would increase by every trip for the driver
WITH CTE AS(
SELECT	trip_id ,driver_id, lpep_pickup_datetime, Total_amount, 
		LAG(Total_amount) OVER (PARTITION BY driver_id, DATEPART(DAY, lpep_pickup_datetime) ORDER BY lpep_pickup_datetime) AS previous_amount
FROM nyc_sep),
CTE2 AS(
SELECT *, CONVERT(DATE, lpep_pickup_datetime) AS day_,IIF(Total_amount > previous_amount,1,0) AS compare
FROM CTE)
SELECT driver_id, day_,
	CASE
	WHEN (SUM(compare)*1.0/COUNT(*)) > 0.5 THEN 'GOOD'
	ELSE 'BAD'
	END day_situation
FROM CTE2
GROUP BY driver_id, day_
ORDER BY 1,2









 
 









