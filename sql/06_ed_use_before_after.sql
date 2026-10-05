-- ============================================================================
-- 06_ed_use_before_after.sql     
-- ============================================================================
--Query to count each member with a need met and count ed visits before and after the need being met
--ed visits before - count of visits to emergency department BEFORE a referral was met
--ed visits after - count of visits to emergency department AFTER a referral was met
--ed per 1000 before - ED rate before per 1000 members
--ed per 1000 after - ED rate after per 1000 members
-- ============================================================================
WITH referral_cte AS (
SELECT *, row_number() OVER (PARTITION BY member_id ORDER BY referral_date) AS referral_row
FROM v_referrals 
WHERE status = 'closed_met'
),
referral_cte_2 AS (
SELECT COUNT(DISTINCT r.member_id) AS members_count, SUM(CASE 
								  WHEN julianday(e.encounter_date) >= (julianday(r.referral_date) - 180) 
								  AND julianday(e.encounter_date) < julianday(r.referral_date) THEN 1
								  ELSE 0 END) AS ed_before,
							  SUM(CASE
							      WHEN julianday(e.encounter_date) > julianday(r.closed_date)
								  AND julianday(e.encounter_date) <= (julianday(r.closed_date) + 180) THEN 1
								  ELSE 0 END) AS ed_after --convert date into a running number and apply the math formula for if its between the two dates, aggregate it in sum to count each column
FROM referral_cte r LEFT JOIN encounters e ON r.member_id = e.member_id AND encounter_type = 'ED' --left join with encounter type to keep members with 0 ED visits, ED condition in ON so it limits encounters without dropping members
WHERE referral_row = 1
AND referral_date >= '2025-07-01' 
AND closed_date <= '2026-01-01' --date filter after picking row 1, so we only keep member if their first referral is in window;
)
SELECT members_count AS 'members', ed_before AS ed_visits_before, ed_after AS ed_visits_after, ROUND((1000.0/members_count) * ed_before,0) AS ed_per_1000_before, ROUND((1000.0/members_count) * ed_after,0) AS ed_per_1000_after
FROM referral_cte_2;

--for members whose needs were met the data shows no change in emergency visits before and visits after. This analysis cannot prove that the needs being met had no effect, as it's possible ED visits could've gotten worse without intervention.
--there is no control group for this data as well there is no way to draw a conclusion that the referrals are helping either
--467 members, 180 days before and after it closed, 315 ED visits per 1000 members in both periods.