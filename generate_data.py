"""
Generate a synthetic Social Care Network (SCN) dataset and load it into SQLite.

All data is fake. Nothing here comes from real Medicaid members or real
community-based organizations. The structure is modeled on how a New York
SCN works: members are screened for health-related social needs (HRSN)
with the AHC screening tool, positive screens are navigated and referred
to community-based organizations (CBOs), and referrals are tracked until
they close.

A small number of data-quality problems are planted on purpose so the
checks in sql/01_data_quality.sql have something to find.

Usage:
    python generate_data.py
"""

import csv
import random
import sqlite3
from datetime import date, timedelta
from pathlib import Path

random.seed(42)

ROOT = Path(__file__).parent
DATA = ROOT / "data"
DB_PATH = ROOT / "scn.db"
DATA.mkdir(exist_ok=True)

START = date(2025, 1, 1)
END = date(2026, 6, 30)

COUNTIES = {
    # county: (relative population weight, rural flag)
    "Broome": (0.38, 0),
    "Tompkins": (0.18, 0),
    "Otsego": (0.12, 1),
    "Chenango": (0.12, 1),
    "Tioga": (0.11, 1),
    "Delaware": (0.09, 1),
}

DOMAINS = ["housing", "food", "transportation", "utilities", "safety"]

# Base probability that a screened member is positive in each domain
DOMAIN_POS_RATE = {
    "housing": 0.22,
    "food": 0.31,
    "transportation": 0.18,
    "utilities": 0.15,
    "safety": 0.05,
}

CBOS = [
    # cbo_id, name, county, domain served, typical days to close, close rate
    (1, "Food Partner A", "Broome", "food", 9, 0.82),
    (2, "Housing Partner A", "Broome", "housing", 34, 0.55),
    (3, "Transportation Partner A", "Broome", "transportation", 6, 0.88),
    (4, "Food Partner B", "Tompkins", "food", 11, 0.79),
    (5, "Housing Partner B", "Tompkins", "housing", 29, 0.61),
    (6, "Utilities Partner A", "Otsego", "utilities", 18, 0.70),
    (7, "Food Partner C", "Chenango", "food", 14, 0.74),
    (8, "Transportation Partner B", "Tioga", "transportation", 10, 0.66),
    (9, "Safety Partner A", "Delaware", "safety", 21, 0.72),
    (10, "Utilities Partner B", "Broome", "utilities", 16, 0.77),
    (11, "Safety Partner B", "Broome", "safety", 19, 0.75),
    (12, "Housing Partner C", "Otsego", "housing", 41, 0.48),
]

N_MEMBERS = 4000


def rand_date(start, end):
    return start + timedelta(days=random.randint(0, (end - start).days))


def pick_county():
    names = list(COUNTIES)
    weights = [COUNTIES[c][0] for c in names]
    return random.choices(names, weights)[0]


def main():
    members, screenings, referrals, encounters = [], [], [], []

    # ---- members -----------------------------------------------------------
    for mid in range(1, N_MEMBERS + 1):
        county = pick_county()
        age_group = random.choices(
            ["0-17", "18-34", "35-49", "50-64", "65+"], [22, 28, 22, 19, 9]
        )[0]
        enroll = rand_date(date(2023, 1, 1), date(2026, 3, 1))
        members.append(
            {
                "member_id": mid,
                "county": county,
                "age_group": age_group,
                "medicaid_enroll_date": enroll.isoformat(),
            }
        )

    # ---- screenings, referrals ---------------------------------------------
    screening_id = 0
    referral_id = 0
    cbo_by_domain = {}
    for c in CBOS:
        cbo_by_domain.setdefault(c[3], []).append(c)

    for m in members:
        rural = COUNTIES[m["county"]][1]
        # Rural members are a bit less likely to get screened at all
        p_screened = 0.62 if rural else 0.74
        if random.random() > p_screened:
            continue

        n_screens = random.choices([1, 2, 3], [70, 24, 6])[0]
        for _ in range(n_screens):
            screening_id += 1
            s_date = rand_date(START, END)
            # Rural members have somewhat higher transportation need
            flags = {}
            for d in DOMAINS:
                p = DOMAIN_POS_RATE[d]
                if d == "transportation" and rural:
                    p += 0.12
                flags[d] = 1 if random.random() < p else 0

            screenings.append(
                {
                    "screening_id": screening_id,
                    "member_id": m["member_id"],
                    "screening_date": s_date.isoformat(),
                    "screen_setting": random.choice(
                        ["primary_care", "ED", "CBO", "care_manager", "phone"]
                    ),
                    **{f"{d}_positive": flags[d] for d in DOMAINS},
                }
            )

            # Each positive domain may get a referral
            for d in DOMAINS:
                if not flags[d] or random.random() > 0.81:
                    continue
                options = cbo_by_domain[d]
                local = [c for c in options if c[2] == m["county"]]
                cbo = random.choice(local or options)
                referral_id += 1
                r_date = s_date + timedelta(days=random.randint(0, 6))
                _, _, _, _, typical_days, close_rate = cbo
                roll = random.random()
                if roll < close_rate:
                    status = "closed_met"
                    closed = r_date + timedelta(
                        days=max(1, int(random.gauss(typical_days, typical_days * 0.4)))
                    )
                elif roll < close_rate + 0.12:
                    status = "closed_unmet"
                    closed = r_date + timedelta(days=random.randint(10, 60))
                else:
                    status = "open"
                    closed = None
                if closed and closed > END:
                    status, closed = "open", None
                referrals.append(
                    {
                        "referral_id": referral_id,
                        "screening_id": screening_id,
                        "member_id": m["member_id"],
                        "cbo_id": cbo[0],
                        "need_domain": d,
                        "referral_date": r_date.isoformat(),
                        "status": status,
                        "closed_date": closed.isoformat() if closed else None,
                    }
                )

    # ---- ED / inpatient encounters -----------------------------------------
    enc_id = 0
    for m in members:
        n = random.choices([0, 1, 2, 3, 4, 6], [45, 25, 14, 8, 5, 3])[0]
        for _ in range(n):
            enc_id += 1
            encounters.append(
                {
                    "encounter_id": enc_id,
                    "member_id": m["member_id"],
                    "encounter_date": rand_date(START, END).isoformat(),
                    "encounter_type": random.choices(["ED", "inpatient"], [82, 18])[0],
                }
            )

    # ---- plant a few data-quality issues on purpose ------------------------
    # 1. Referrals closed before they were opened
    for r in random.sample([r for r in referrals if r["closed_date"]], 7):
        r["closed_date"] = (
            date.fromisoformat(r["referral_date"]) - timedelta(days=random.randint(1, 5))
        ).isoformat()
    # 2. Referrals pointing to a screening that does not exist
    for r in random.sample(referrals, 4):
        r["screening_id"] = 999000 + r["referral_id"]
    # 3. Exact duplicate screening rows (double submission)
    for s in random.sample(screenings, 12):
        screening_id += 1
        screenings.append({**s, "screening_id": screening_id})
    # 4. "Closed" status with no closed_date
    for r in random.sample([r for r in referrals if r["status"] == "closed_met"], 5):
        r["closed_date"] = None

    # ---- write CSVs and SQLite ---------------------------------------------
    cbos = [
        {"cbo_id": c[0], "cbo_name": c[1], "county": c[2], "domain": c[3]} for c in CBOS
    ]
    tables = {
        "members": members,
        "cbos": cbos,
        "screenings": screenings,
        "referrals": referrals,
        "encounters": encounters,
    }
    for name, rows in tables.items():
        with open(DATA / f"{name}.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)

    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.executescript((ROOT / "sql" / "00_schema.sql").read_text())
    for name, rows in tables.items():
        cols = list(rows[0])
        con.executemany(
            f"INSERT INTO {name} ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
            [tuple(r[c] for c in cols) for r in rows],
        )
    con.commit()
    con.close()

    for name, rows in tables.items():
        print(f"{name:<11} {len(rows):>6} rows")
    print(f"Loaded into {DB_PATH.name}")


if __name__ == "__main__":
    main()
