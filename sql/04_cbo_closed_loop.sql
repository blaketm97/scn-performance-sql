-- ============================================================================
-- 04_cbo_closed_loop.sql    
-- ============================================================================
--Query to determine how well each CBO closes refferals and the time it takes to do so.
--Determines closed loop rate (referrals with status closed met)
--median days - median days to close a refferal
--still open - referrals still opened
--flag - flags review if closed loop rate under 60
--only counts referrals 60 days out from data end
-- ============================================================================
WITH flag_cte AS (
SELECT cbo_name, domain, COUNT(*) AS 'referrals', ROUND(100 * AVG (CASE WHEN v.status = 'closed_met' THEN 1 ELSE 0 END), 1) AS closed_loop_rate, --if status is closed 1, else  0
SUM(CASE WHEN v.status = 'open' THEN 1 ELSE 0 END) AS still_open --same as average but just a sum for the total count
FROM v_referrals v JOIN cbos c ON v.cbo_id = c.cbo_id
WHERE strftime('%Y%m%d',v.referral_date) <= strftime('%Y%m%d','2026-05-01') --only withing last 60 days
GROUP BY cbo_name
),
median_cte AS (
--AVG(CASE WHEN v.status = 'closed_met' THEN (strftime('%Y%m%d', closed_date) - (strftime('%Y%m%d', referral_date)))END) AS median_days,
--need to use julian day for this
--list of each cbos refereals and days to close
--sort smallest to largest
--ROWNUMBER them
--find the middle
SELECT c2.cbo_name, julianday(v2.closed_date) - julianday(v2.referral_date) AS count_of_days, --count of days it took referral to close
ROW_NUMBER() OVER (PARTITION BY c2.cbo_name ORDER BY (julianday(v2.closed_date) - julianday(v2.referral_date))) AS rank_of_days, --rank of the referrals based on how long it took to close
COUNT(*) OVER (PARTITION BY c2.cbo_name) AS n --passing the highest rank for use in median
FROM v_referrals v2 JOIN cbos c2 ON v2.cbo_id = c2.cbo_id
WHERE (strftime('%Y%m%d',v2.referral_date) <= strftime('%Y%m%d','2026-05-01'))
AND v2.status = 'closed_met'
),
median_cte_2 AS (
--our problem here is we cant just do where n/2 for the rank as that rank does not exist for the odd numbers so it rounds down, so we need the average
--we need to use another cte for this
SELECT * , ROUND(AVG(count_of_days),0) AS median_days
FROM median_cte
WHERE rank_of_days IN ((n+1) / 2, (n + 2) / 2) -- integer division finds the middle position when n is even and odd
GROUP BY cbo_name
)
--SELECT *, CASE WHEN closed_loop_rate < 60 THEN 'review' ELSE '' END AS flag
--FROM flag_cte;
SELECT f.cbo_name, f.domain, f.referrals, f.closed_loop_rate, m.median_days, f.still_open, CASE WHEN closed_loop_rate < 60 THEN 'review' ELSE '' END AS flag
FROM median_cte_2 m JOIN flag_cte f ON m.cbo_name = f.cbo_name
ORDER BY closed_loop_rate;


