-- Translating business questionsn to SQL Syntax - (Data Lemur Questions)

--1. Count the user activation Rate
-- Postgres 14 Syntax 

WITH CTE AS (
    SELECT 
      COUNT(user_id) FILTER(WHERE signup_action = 'Confirmed') AS count_confirmed,
      COUNT(user_id) FILTER(WHERE signup_action = 'Not Confirmed') AS count_not_confirmed
    FROM emails as e
    LEFT JOIN texts as t
        ON e.email_id = t.email_id
            )
SELECT ROUND((count_confirmed / SUM(count_confirmed + count_not_confirmed)),2) AS confirm_rate
FROM CTE
GROUP BY count_confirmed,count_not_confirmed

--2. How well do credit cards typically do first month of launch (question derived by a companies need to launch a new credit card)
    -- we are analysing the number of requested credit cards upon first month the cards were launched.

WITH CTE AS (
      SELECT 
      card_name, 
      issued_amount,
      MAKE_DATE(issue_year,issue_month,1) as issue_date, 
      MIN(MAKE_DATE(issue_year,issue_month,1)) OVER(PARTITION BY card_name) min_issue_date
      FROM monthly_cards_issued
      ORDER BY issued_amount DESC
            )

SELECT card_name, issued_amount
FROM CTE
WHERE issue_date = min_issue_date
ORDER BY issued_amount DESC


--3. Calculate the proportion of international calls made 
 -- The table structure is such that a caller has a receiver, this requires a 2 left joins or self joins to resolve

SELECT 
ROUND(100.0 * SUM(CASE WHEN caller.country_id <> receiver.country_id THEN 1 ELSE NULL END)/ COUNT(*),1) AS international_call_pct
FROM phone_calls as calls
LEFT JOIN phone_info as caller 
  ON calls.caller_id = caller.caller_id 
LEFT JOIN phone_info as receiver
  ON calls.receiver_id = receiver.caller_id
  

--4. count duplicate transactions that occured in the within 10 minutes of a user completing a transaction at a merchant
WITH transaction_time_diff as (
  
  SELECT transaction_id,
       merchant_id,
       credit_card_id,
       amount,
       transaction_timestamp,
       EXTRACT(EPOCH from transaction_timestamp -   LAG(transaction_timestamp) OVER( 
                            PARTITION BY 
                              merchant_id,
                              credit_card_id,
                              amount
                            ORDER BY transaction_timestamp)) / 60 as minute_diff
  FROM transactions
)
SELECT COUNT(merchant_id)
FROM transaction_time_diff
WHERE minute_diff <= 10
;

--5. Calculate Month-on-Month change where call durations exceed 5 minutes (300 seconds)

WITH count_monthly_change AS (
      SELECT 
        EXTRACT(YEAR FROM call_received) AS yr,
        EXTRACT(MONTH FROM call_received) AS mth,
        COUNT(case_id) AS curr_mth_call,
        LAG(COUNT(case_id)) OVER(ORDER BY EXTRACT(MONTH FROM call_received)) as previous_month_count --window function 
      FROM callers
      WHERE call_duration_secs > 300
      GROUP BY yr, mth
  )
  SELECT
    yr,
    mth,
    ROUND((100.0 * (curr_mth_call - previous_month_count )/previous_month_count),1) AS growth_pct
  FROM count_monthly_change
  ORDER BY yr, mth ASC


-- 6. count distinct monthly users in that were active in june that are active in july 
-- business questions finding the number of active users that were active in the previous month
-- SQL Techniques: Correlated Sub-queries


SELECT 
  EXTRACT(MONTH FROM event_date) AS mth,
  COUNT(DISTINCT user_id) AS monthly_active_users
FROM user_actions AS curr_month
WHERE EXISTS (
   SELECT last_month.user_id
   FROM user_actions AS last_month
   WHERE last_month.user_id = curr_month.user_id -- self join query that links 
   AND EXTRACT(MONTH FROM last_month.event_date) =  EXTRACT(MONTH FROM curr_month.event_date - interval '1 month') -- correlated subquery to extract the previous month
            )
AND EXTRACT(MONTH FROM event_date) = 7
AND EXTRACT(YEAR FROM event_date) = 2022
GROUP BY mth


-- 7. using a cross join to link pizza toppings (many-to-many) combinations in a table
-- the goal is to find the highest grossing pizza combination 
with cte as (
      SELECT  
      p1.topping_name first_top, 
      p2.topping_name second_top,
      p3.topping_name third_top,
      p1.ingredient_cost first_cost, 
      p2.ingredient_cost second_cost,
      p3.ingredient_cost third_cost
      FROM 
      pizza_toppings AS p1 
      CROSS JOIN -- using cross join to horizontal join the table to itself
        pizza_toppings AS p2,
        pizza_toppings as p3
      WHERE p1.topping_name < p2.topping_name -- "break ties by listing the ingredients in alphabetical order"
        AND p2.topping_name < p3.topping_name
)

SELECT
      concat(first_top,',' ,second_top,',', third_top) as pizza,
      (first_cost + second_cost + third_cost) as total_cost
  from cte
  order by total_cost desc,  pizza asc

