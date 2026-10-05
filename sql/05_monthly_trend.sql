-- ============================================================================
-- 05_monthly_trend.sql       
-- ============================================================================
--Query to count screenings each month, and if that count is going up or down
--month - text string of year-month
--screenings - count of screenings that month
--change vs prior month - this month minus last month
--rolling 3mo avg - average of this month and two before it
--pct any positive - percent of that month's screenings positive in at least one domain
-- ============================================================================
--initial thoughts, going to use LAG for the change v prior and rolling 3mo avg (actually i dont, initial thoughts wrong
--for pct_any_positive im guessing something like a WHERE with a bunch of OR's
WITH month_convert AS (
--use a CTE here to i can pass the count of each month to use in window functions, big case statement is simple sum the 1's if any positive
SELECT strftime('%Y-%m', screening_date) AS month, COUNT(*) AS 'screenings',  SUM(CASE WHEN housing_positive = 1 THEN 1
																					   WHEN food_positive = 1 THEN 1
																					   WHEN transportation_positive = 1 THEN 1
																					   WHEN utilities_positive = 1 THEN 1
																					   WHEN safety_positive = 1 THEN 1
																					   ELSE 0 END) AS any_positive
FROM v_screenings
GROUP BY month
)
SELECT month, screenings, screenings - LAG(screenings, 1, NULL) OVER (ORDER BY month) AS change_vs_prior_month, --set NULL for first value 
ROUND(AVG(screenings) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1) as rolling_3mo_avg, --window fram moving averages
ROUND(100.0 * any_positive / screenings, 1) AS pct_any_positive
FROM month_convert
GROUP BY month;

