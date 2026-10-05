"""
Export Power BI-ready tables from scn.db into powerbi/.

Uses the cleaned views from sql/01_data_quality.sql so the dashboard shows
the same numbers as the SQL results. Run generate_data.py and
run_queries.py first.

Usage:
    python export_for_powerbi.py
"""

import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).parent
OUT = ROOT / "powerbi"
OUT.mkdir(exist_ok=True)
con = sqlite3.connect(ROOT / "scn.db")

# Rebuild the clean views from YOUR sql/01_data_quality.sql so the export
# reflects your own work.
con.executescript((ROOT / "sql" / "01_data_quality.sql").read_text())

QUERIES = {
    # Dimension tables
    "dim_members": """
        SELECT member_id, county,
               CASE WHEN county IN ('Broome','Tompkins') THEN 'Urban' ELSE 'Rural' END AS urban_rural,
               age_group, medicaid_enroll_date
        FROM members""",
    "dim_cbos": "SELECT cbo_id, cbo_name, county AS cbo_county, domain AS cbo_domain FROM cbos",

    # Fact tables (cleaned)
    "fact_screenings": """
        SELECT screening_id, member_id, screening_date, screen_setting,
               housing_positive, food_positive, transportation_positive,
               utilities_positive, safety_positive,
               MAX(housing_positive, food_positive, transportation_positive,
                   utilities_positive, safety_positive) AS any_positive
        FROM v_screenings""",
    # Same screenings, one row per domain: easier to chart need prevalence
    "fact_screening_domains": """
        SELECT screening_id, member_id, screening_date, 'Housing' AS domain, housing_positive AS positive FROM v_screenings
        UNION ALL SELECT screening_id, member_id, screening_date, 'Food', food_positive FROM v_screenings
        UNION ALL SELECT screening_id, member_id, screening_date, 'Transportation', transportation_positive FROM v_screenings
        UNION ALL SELECT screening_id, member_id, screening_date, 'Utilities', utilities_positive FROM v_screenings
        UNION ALL SELECT screening_id, member_id, screening_date, 'Safety', safety_positive FROM v_screenings""",
    "fact_referrals": """
        SELECT referral_id, screening_id, member_id, cbo_id,
               UPPER(SUBSTR(need_domain,1,1)) || SUBSTR(need_domain,2) AS need_domain,
               referral_date, status, closed_date,
               CASE WHEN status = 'closed_met'
                    THEN CAST(julianday(closed_date) - julianday(referral_date) AS INTEGER) END AS days_to_close,
               CASE WHEN referral_date <= date('2026-06-30','-60 days') THEN 1 ELSE 0 END AS eligible_60d
        FROM v_referrals""",
    "fact_encounters": "SELECT encounter_id, member_id, encounter_date, encounter_type FROM encounters",
}

for name, sql in QUERIES.items():
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    with open(OUT / f"{name}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)
    print(f"{name:<24} {len(rows):>6} rows")

con.close()
