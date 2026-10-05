-- ============================================================================
-- 02_screening_reach.sql   
-- ============================================================================

--Queries the share of members in each county that has been screened AT LEAST once.
--Purpose is to find counties with low screening rate as that's where resources should be sent

-- ============================================================================
--SELECT ROW_NUMBER() OVER (PARTITION BY m.county ORDER BY m.member_id) AS number, * --first iteration, this is dumb
WITH unscreened_count AS (
SELECT m.county, COUNT(*) AS unscreened
FROM members m LEFT JOIN v_screenings v ON m.member_id = v.member_id
WHERE v.screening_date IS NULL
GROUP BY m.county
),
total_count AS (
SELECT county, COUNT(*) AS population
FROM members
GROUP BY county
)
SELECT u.county, t.population AS 'members', (t.population - u.unscreened) AS members_screened, ROUND(100.0 * (t.population - u.unscreened) / t.population, 1) AS pct_screened
FROM unscreened_count u JOIN total_count t ON u.county = t.county
ORDER BY pct_screened DESC, members_screened;


