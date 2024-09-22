/* 
1.Find the average monthly electricity consumption for participants who live in a 'House'
and have a home size greater than 1000 square feet.
*/

SELECT AVG(electricity_cons)
FROM eco_table
WHERE home_type = 'House' AND home_size > 1000;



/* 2. Correlated Subquery: List participants who have a higher environmental awareness than the average awareness of their location.*/

-- 2/1

SELECT * 
FROM 
(
	SELECT id_participant
		, age
		, location
		, env_aware
		, ROUND(AVG(env_aware) OVER(PARTITION BY location),2) as AV1
	FROM eco_table
)
WHERE env_aware > AV1
ORDER BY location;

-- 2/2
SELECT id_participant, Location, env_aware
FROM eco_table E1
WHERE env_aware > (SELECT AVG(env_aware) 
                                FROM eco_table E2 
                                WHERE E2.Location = E1.Location);
								
								
								
/* 
3. Calculate the cumulative total of monthly electricity consumption 
for each gender based on their ParticipantID.
*/

-- 3.1 
SELECT 
	id_participant
	, age
	, gender
	, SUM(electricity_cons) OVER (PARTITION BY gender) as SUM_gender
	, COUNT(gender) OVER (PARTITION BY gender) as COUNT_gender
FROM eco_table
ORDER BY gender;



/*
4. Self-Join:
Find pairs of participants with the same age who have different diet types.
*/

SELECT e.id_participant ID_1, f.id_participant AS ID_2, e.age, e.diet_type AS diet1, f.diet_type AS diet2, e.gender, f.gender
FROM eco_table e
JOIN eco_table f ON e.age = f.age
WHERE e.diet_type != f.diet_type AND e.gender = f.gender;



/*
5. Dynamic PIVOT Query:
Create a dynamic pivot table to show the count of participants by diet type and gender.
*/

SELECT Count(*), gender, diet_type
FROM eco_table
GROUP BY gender, diet_type
Order BY gender



SELECT 
	diet_type, 
	SUM(CASE gender WHEN 'Female' THEN 1 ELSE 0 END) AS FEMALE
	, SUM(CASE gender WHEN 'Male' THEN 1 ELSE 0 END) AS MALE
	, SUM(CASE gender WHEN 'Non-Binary' THEN 1 ELSE 0 END) AS NON_BINARY
	, SUM(CASE gender WHEN 'Prefer not to say' THEN 1 ELSE 0 END) AS PREFER_NOT_TO_SAY
	, COUNT(diet_type) As total
FROM eco_table e
GROUP BY diet_type;



/*
6. Using CASE with Aggregation:
Calculate the percentage of participants using renewable energy in different home types
*/

SELECT 
	home_type
	, ROUND (100.0 * SUM(CASE WHEN energy_source = 'Renewable' THEN 1 ELSE 0 END)/COUNT(*), 2) AS "% OF RENEW"
	, ROUND (100.0 * SUM(CASE energy_source WHEN 'Mixed' THEN 1 ELSE 0 END)/COUNT(*),2) as "% OF MIXED"
	, ROUND (100.0 * SUM(CASE energy_source WHEN 'Non-Renewable' THEN 1 ELSE 0 END)/COUNT(*), 2) AS "% OF NON-RENEW"
FROM eco_table
GROUP BY home_type
Order BY home_type



/*
7. Complex Subquery with GROUP BY:
Find the average monthly water consumption for each diet type, 
but only for participants who have a rating above the average rating.
*/

SELECT 
	diet_type
	, AVG(water_cons) AS water_with_high_rating
FROM eco_table
WHERE rating > (SELECT AVG(rating) FROM eco_table)
GROUP BY diet_type
Order BY diet_type;


-- 7/2 comparison with average water_cons without high rating
SELECT 
	e1.diet_type
	, AVG(e1.water_cons) AS water_with_high_rating
	, AVG(e2.water_cons) AS water_without_high_rating
FROM eco_table e1
JOIN eco_table e2 ON e1.diet_type = e2.diet_type
WHERE e1.rating > (SELECT AVG(rating) FROM eco_table)
GROUP BY e1.diet_type
Order BY e1.diet_type;


-- 7/3 comparison with average water_cons of the whole table
SELECT 
	diet_type
	, (SELECT AVG(water_cons) FROM eco_table WHERE rating > (SELECT AVG(rating) FROM eco_table ))AS water_with_high_rating
	, AVG(water_cons) AS water_without_high_rating
FROM eco_table 
GROUP BY diet_type
Order BY diet_type;


-- 7/2/1 comparison with average water_cons without high rating
SELECT 
    e1.diet_type,
    e1.water_with_high_rating,
    e2.water_without_high_rating
FROM 
    (
        SELECT 
            diet_type,
            AVG(water_cons) AS water_with_high_rating
        FROM eco_table
        WHERE rating > (SELECT AVG(rating) FROM eco_table)
        GROUP BY diet_type
    ) e1
FULL OUTER JOIN 
    (
        SELECT 
            diet_type,
            AVG(water_cons) AS water_without_high_rating
        FROM eco_table
        GROUP BY diet_type
    ) e2
ON e1.diet_type = e2.diet_type
ORDER BY e1.diet_type;



/*
8.Advanced Filtering with Window Functions:
List participants who are within the top 10% in terms of monthly electricity consumption
in their respective home types.
*/

WITH a1 AS 
	(SELECT 
		id_participant
		, home_type
		, electricity_cons
		, ROUND(AVG(electricity_cons) OVER(PARTITION BY home_type ORDER BY home_type),2) AS e_e
		, PERCENT_RANK() OVER(PARTITION BY home_type ORDER BY electricity_cons ASC) AS e_rating
	FROM eco_table
	GROUP BY id_participant, home_type, electricity_cons
	ORDER BY  home_type, e_rating DESC, id_participant) 
SELECT *
FROM a1
WHERE e_rating > 0.9;



/*
9. Multi-Level Subqueries:
Find participants who are in the top 10% for both monthly electricity and water consumption.
*/

WITH a1 AS 
	(SELECT 
		id_participant
		, home_type
		, electricity_cons
		, PERCENT_RANK() OVER(ORDER BY electricity_cons ASC) AS e_rating
	FROM eco_table
	GROUP BY id_participant, home_type, electricity_cons
	ORDER BY  home_type, e_rating DESC, id_participant), 

	b1 AS 
	(SELECT 
		id_participant
		, home_type
		, water_cons
		, PERCENT_RANK() OVER(ORDER BY water_cons ASC) AS water_rating
	FROM eco_table
	GROUP BY id_participant, home_type, water_cons
	ORDER BY  home_type, water_rating DESC, id_participant)
		
SELECT *
FROM a1
JOIN b1 ON a1.id_participant = b1.id_participant
WHERE water_rating >=0.9 AND e_rating >=0.9
ORDER BY a1.id_participant;


--9/2 TRY number 2

SELECT 
	id_participant
	, home_type
	, electricity_cons
	, water_cons
FROM eco_table
WHERE electricity_cons >= (SELECT(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY electricity_cons)) FROM eco_table) AND
water_cons >= (SELECT(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY water_cons))FROM eco_table);



/*
10.Full Outer Join (Assume another table):
Join the '****' table with another table '*****' to find participants
who are involved in community activities but are not environmentally aware 
(EnvironmentalAwareness < 4), and participants who are environmentally aware but 
not involved in community activities.	
*/	

SELECT 
	c1.id_participant
	, c1.community_inv
	, c1.env_aware
FROM eco_table c1
FULL OUTER JOIN eco_table d1 ON c1.id_participant = d1.id_participant
WHERE (c1.community_inv = 'High' AND c1.env_aware <=3) OR 
((d1.community_inv in ('Low', 'None')) AND d1.env_aware <=3)



/*
11. Advanced ROLLUP with Grouping:
Generate a report showing the total, average, and count of monthly electricity and water consumption, 
grouped by 'HomeType', with a grand total at the end.
*/

SELECT home_type
       , SUM(electricity_cons) AS Total_electr 
       , AVG(electricity_cons) AS Avg_electr
       , SUM(water_cons) AS Total_water 
       , AVG(water_cons) AS Avg_water
       , COUNT(*) AS part_count
FROM eco_table
GROUP BY ROLLUP(home_type);

	
	
/*
12.Complex Case with Nested Subqueries:
Calculate the ratio of participants who prefer public transportation versus those 
who prefer private transportation for each home type.
*/
	
WITH f1 as
	(
		SELECT 
			home_type 
			, SUM(CASE WHEN transport = 'Public Transit' THEN 1 ELSE 0 END) AS public_tr
			, SUM(CASE WHEN transport = 'Car' THEN 1 ELSE 0 END) AS private
		FROM eco_table
		GROUP BY home_type
	)
SELECT 
	*
	, CONCAT('1:', ROUND(private*1.0/public_tr *1.0, 2))AS ratio_pr_to_publ
FROM f1
GROUP BY private, public_tr, f1.home_type
ORDER BY f1.home_type;


-- 12/2
SELECT home_type, 
       ROUND(SUM(CASE WHEN transport = 'Public Transit' THEN 1 ELSE 0 END) * 1.0 / 
       NULLIF(SUM(CASE WHEN transport = 'Car' THEN 1 ELSE 0 END), 0),3) AS public_to_private
FROM eco_table
GROUP BY home_type;



/*
13. Some stat info 
*/

SELECT 
	CASE
		WHEN age <=25 THEN '1. Generation <=25'
		WHEN age BETWEEN 26 AND 45 THEN '2. Generation 26-45'
		WHEN age >=46 AND age <=65 THEN '3. Generation 46-65'
		WHEN age >=66 AND age <=100 THEN '4. Generation 66-100'
		ELSE 'CHECK' END AS AGE_CATEGORY
	, COUNT(*)
	, home_type
	, MIN(electricity_cons) AS max_electricity
	, MAX(electricity_cons) AS min_electricity
	, ROUND(AVG(electricity_cons),1) AS avg_electricity
	, PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY electricity_cons) AS MED_ee
	, MIN(water_cons) AS min_water
	, MAX(water_cons) AS max_water
	, ROUND(AVG(water_cons), 1) AS avg_water
	, PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY water_cons) AS MED_water
FROM eco_table
GROUP BY AGE_CATEGORY, home_type
ORDER BY AGE_CATEGORY;
