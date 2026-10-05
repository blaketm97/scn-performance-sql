-- ============================================================================
-- 01_data_quality.sql 
-- ============================================================================
--Before reporting anything, we need to find the 'bad' rows.
--We want to build two views that can be queried from later
-- ============================================================================


-- ---------------------------------------------------------------------------
--Write each check seperately before combining
-- ---------------------------------------------------------------------------
WITH duplicates AS (
SELECT COUNT(*) as n
FROM screenings
GROUP BY member_id, screening_date, screen_setting, housing_positive, food_positive, transportation_positive, utilities_positive, safety_positive
HAVING COUNT(*) > 1
) -- this is a CTE for A4
-- A1. closed_before_opened
--     Referrals where closed_date is earlier than referral_date.
SELECT 'closed_before_opened' AS check_name, COUNT(*) AS problem_rows
FROM referrals
WHERE closed_date < referral_date

-- A2. closed_status_no_date
--     Referrals whose status starts with 'closed' but closed_date is NULL.
UNION ALL
SELECT 'closed_status_no_date' ,COUNT(*)
FROM referrals
WHERE closed_date IS NULL
AND status LIKE 'closed%'

-- A3. orphan_referrals
--     Referrals whose screening_id doesn't exist in the screenings table.
UNION ALL
SELECT 'orphan_referrals', COUNT(*)
FROM referrals r LEFT JOIN screenings s ON r.screening_id = s.screening_id
WHERE s.screening_id IS NULL --left join check for null on right side, i was tripped up for a whilst

-- A4. duplicate_screenings
--     Screenings that are exact copies of another screening (same member_id,
--     screening_date, screen_setting, and all five *_positive columns) but a
--     different screening_id. Count the EXTRA copies only: if a screening
--     appears twice, that's 1 extra.
UNION ALL
SELECT 'duplicate_screenings', SUM(n-1) --sum -1 because we only want to count the extra copies
FROM duplicates

-- A5. domain_mismatch
--     Referrals sent to a CBO that doesn't serve that need
UNION ALL
SELECT 'domain_mismatch', COUNT(*)
FROM referrals r JOIN cbos c ON r.cbo_id = c.cbo_id
WHERE r.need_domain != c.domain;



-- ---------------------------------------------------------------------------
--Two cleaned views. Queries 02 through 06 use these.
-- ---------------------------------------------------------------------------

-- B1. v_screenings: every screening, but only ONE copy of each duplicate
--     (keep the copy with the lowest screening_id).
--     Expected: 3,815 rows
--     Just have to put the A answers into these views
DROP VIEW IF EXISTS v_screenings;
CREATE VIEW v_screenings AS
WITH screening_cte AS(
SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, screening_date, screen_setting, housing_positive, food_positive, transportation_positive, utilities_positive, safety_positive ORDER BY screening_id) AS duplicates
--use rownumber instead of ranks incase of a tie. there can be two rank 2's and so on, so this way we only drop 1
FROM screenings
)
SELECT *
FROM screening_cte
WHERE duplicates = 1
;


-- B2. v_referrals: referrals WITHOUT the problems from checks A1, A2, and A3.
--     Expected: 2,883 rows
DROP VIEW IF EXISTS v_referrals;
CREATE VIEW v_referrals AS
WITH closed_before_opened AS (
SELECT referral_id
FROM referrals
WHERE closed_date < referral_date
),
closed_status_no_date AS (
SELECT referral_id
FROM referrals
WHERE closed_date IS NULL
AND status LIKE 'closed%'
),
orphan_referrals AS (
SELECT referral_id
FROM referrals r LEFT JOIN screenings s ON r.screening_id = s.screening_id
WHERE s.screening_id IS NULL --left join check for null on right side, i was tripped up for a whilst
)
SELECT *
FROM referrals r LEFT JOIN closed_before_opened c1 ON r.referral_id = c1.referral_id
				 LEFT JOIN closed_status_no_date c2 ON r.referral_id = c2.referral_id
				 LEFT JOIN orphan_referrals o ON r.referral_id = o.referral_id
WHERE c1.referral_id IS NULL
AND c2.referral_id IS NULL
AND o.referral_id IS NULL
;
