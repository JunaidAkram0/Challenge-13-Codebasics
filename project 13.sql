select * from dim_city;
select * from dim_date;
select * from dim_repeat_trip_distribution;
select * from fact_passenger_summary;
select * from fact_trips;
------------------------------------------------------------------------------------
     ----- Bussiness Request 1 ------
-- CityLevel Fare and Trip Summary Report --

Select tA.city_name , 
	COALESCE(tc.total_trip_count, 0) AS 'Total Trips' ,
	Round(sum(tg.fare_amount) / sum(tg.distance_travelled_km),2) as 'Average Fare Per KM',
	Round(sum(tg.fare_amount) / tc.total_trip_count, 2) as ' Average Fare Per Trip',
	(tc.total_trip_count) / (SELECT SUM(trip_count) FROM dim_repeat_trip_distribution) * 100
	AS 'City Contribution to Total Trip Count (%)'
from fact_trips tg

Join dim_city tA on tA.city_id = tg.city_id
LEFT JOIN (
    SELECT 
        city_id, 
        SUM(trip_count) AS total_trip_count
    FROM dim_repeat_trip_distribution
    GROUP BY city_id
) tc ON tc.city_id = tg.city_id
GROUP BY tA.city_id, tA.city_name, tc.total_trip_count
ORDER BY tA.city_name;

-----------------------------------------------------------------
    ----- Bussiness Request 2 ------
-- Monthly City level Target Trip Performance --

Select  ta.city_name as 'City Name', 
		tb.month_name as 'Month',
		count(Distinct tg.trip_id) as 'Total Actual Trip', 
        t1.total_target_trips as 'Total Target Trips',
Case When count(Distinct tg.trip_id) > t1.total_target_trips then 'Above Target' Else 'Below Target' END AS 'Performance Status',
Round((COUNT(DISTINCT tg.trip_id) - t1.total_target_trips) / (t1.total_target_trips) * 100, 2) AS '% Difference'
 from trips_db.fact_trips tg
 

	join trips_db.dim_date tb on tg.date = tb.start_of_month
	join trips_db.dim_city ta on tg.city_id = ta.city_id
    
Left 
	Join targets_db.monthly_target_trips t1 on 
    t1.city_id = tg.city_id and t1.month = tb.start_of_month
    Group by ta.city_name, tb.month_name,
        t1.total_target_trips
        order by tb.month_name;

------------------------------------------------------------------
----- Bussiness Request 3 ------
-- Monthly Repeat Passenger Count By Month & City --

select tA.city_name as 'City Name' , 
Round(sum(case when tc.trip_count = '2-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "2-Trip" , 
Round(sum(case when tc.trip_count = '3-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "3-Trip" , 
Round(sum(case when tc.trip_count = '4-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "4-Trip" , 
Round(sum(case when tc.trip_count = '5-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "5-Trip" , 
Round(sum(case when tc.trip_count = '6-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "6-Trip" , 
Round(sum(case when tc.trip_count = '7-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "7-Trip" , 
Round(sum(case when tc.trip_count = '8-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "8-Trip" , 
Round(sum(case when tc.trip_count = '9-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "9-Trip" , 
Round(sum(case when tc.trip_count = '10-Trips' then tc.repeat_passenger_count else 0 end) * 100.0 / sum(tc.repeat_passenger_count),2 ) as "10-Trip" 
from dim_repeat_trip_distribution tc
Join dim_city tA on tA.city_id = tc.city_id
Group by tA.city_name;

------------------------------------------------------------------------
----- Bussiness Request 4 ------
----- City with Highest & lowest new Passengers -----

select 		tA.city_name  	as ' City Name',
			sum(td.new_passengers) as 'Total New Passengers',
Case 
	When Rank() over (Order by sum(td.new_passengers) DESC) <= 3 Then "Top 3"
    when Rank() over (Order by sum(td.new_passengers) ASC)  <= 3 Then "Bottom 3"
end as 'City Category'

from fact_passenger_summary td
Join dim_city tA on td.city_id = tA.city_id

Group by tA.city_name
order by sum(td.new_passengers)  DESC;

--------------------------------------------------------------
----- Bussiness Request 5 ------
-- Month with Highest Revenue for each city -- 

With Revenue_Rank As (
select 
		tB.month_name as 'Month' ,
	    tA.city_name 	as 'City_Name',
		Sum(tg.fare_amount) as 'Revenue',
		Sum(Sum(tg.fare_amount)) OVER (PARTITION BY tA.city_name) AS TotalCityRevenue,
		Rank() over(Partition by tA.city_name order by  sum(tg.fare_amount) Desc) As RevenueRank
 from fact_trips tg
 
 join dim_city tA on tA.city_id = tg.city_id
 join dim_date tB on tB.start_of_month = tg.date
 Group by tB.month_name ,tA.city_name
 )
 Select City_Name as 'City' , month as 'Month',  Revenue , TotalCityRevenue,
 Round(Revenue * 100.0 /  TotalCityRevenue ,2) as 'Percentage_Contribution %'
 From   Revenue_Rank
 where RevenueRank = 1
Order by City_Name;

------------------------------------------------------------------------------------------
----- Bussiness Request 6------
-- Repeat Passenger Rate Analysis --

Select 
		td.month As 'Month' , 
        tA.city_name as 'City' , 
        td.total_passengers as 'Total Passengers' , 
        td.repeat_passengers as 'Repeat Passengers' ,
        ROUND((td.repeat_passengers * 100.0) / td.total_passengers, 2) 
        AS 'Monthly Repeat Passenger Rate %' ,
		Round(Sum(td.repeat_passengers) over (Partition by tA.city_name) * 100.0 / 
		sum(td.total_passengers) Over(Partition by tA.city_name) ,2) 
        As 'City Repeat Passenger Rate %' 
		
from fact_passenger_summary	td

Join dim_city tA on tA.city_id = td.city_id 

Group by td.month,tA.city_name,td.total_passengers,td.repeat_passengers
Order by td.month;



        