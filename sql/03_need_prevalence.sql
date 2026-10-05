-- ============================================================================
-- 03_need_prevalence.sql   
-- ============================================================================
--Query to determine the percent positive for each need domain, as well as distinguish between urban and rural
--needed to unpivot in sqlite to accomplish this as each domain was its own column
-- ============================================================================
--I use sqlite not sql server so i have to do this the crappy way
WITH domain_cte AS (
SELECT screening_id, v.member_id, county, 'housing' AS domain, housing_positive AS positive
FROM v_screenings v JOIN members m ON v.member_id = m.member_id
UNION ALL
SELECT screening_id, v.member_id, county, 'food' AS domain, food_positive AS positive
FROM v_screenings v JOIN members m ON v.member_id = m.member_id
UNION ALL
SELECT screening_id, v.member_id, county, 'transportation' AS domain, transportation_positive AS positive
FROM v_screenings v JOIN members m ON v.member_id = m.member_id
UNION ALL
SELECT screening_id, v.member_id, county, 'utilities' AS domain, utilities_positive AS positive
FROM v_screenings v JOIN members m ON v.member_id = m.member_id
UNION ALL
SELECT screening_id, v.member_id, county, 'safety' AS domain, safety_positive AS positive
FROM v_screenings v JOIN members m ON v.member_id = m.member_id
)
SELECT domain, ROUND(100 * AVG (CASE WHEN county = 'Broome' OR county = 'Tompkins' THEN positive END), 1) AS pct_positive_urban, ROUND(100 * AVG(CASE WHEN county != 'Broome' AND county != 'Tompkins' THEN positive END), 1) AS pct_positive_rural, ROUND(100 * AVG(positive), 1) AS pct_positive_all
--domain, average of urban population using case in aggregate (no reason to add else as i want it to be null), --same for this column but rural
FROM domain_cte
GROUP BY domain
ORDER BY pct_positive_all DESC;


