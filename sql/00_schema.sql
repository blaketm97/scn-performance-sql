-- Schema for the synthetic Social Care Network dataset.
-- Foreign keys are declared to document the relationships, but SQLite does
-- not enforce them unless PRAGMA foreign_keys = ON. They are left unenforced
-- on purpose, the way raw data often lands from a partner platform, so the
-- data-quality checks in 01_data_quality.sql can catch problems.

CREATE TABLE members (
    member_id            INTEGER PRIMARY KEY,
    county               TEXT NOT NULL,
    age_group            TEXT NOT NULL,
    medicaid_enroll_date TEXT NOT NULL
);

CREATE TABLE cbos (
    cbo_id   INTEGER PRIMARY KEY,
    cbo_name TEXT NOT NULL,
    county   TEXT NOT NULL,
    domain   TEXT NOT NULL      -- housing, food, transportation, utilities, safety
);

-- One row per AHC HRSN screening. Each domain is 1 (positive) or 0.
CREATE TABLE screenings (
    screening_id            INTEGER PRIMARY KEY,
    member_id               INTEGER NOT NULL REFERENCES members(member_id),
    screening_date          TEXT NOT NULL,
    screen_setting          TEXT NOT NULL,
    housing_positive        INTEGER NOT NULL,
    food_positive           INTEGER NOT NULL,
    transportation_positive INTEGER NOT NULL,
    utilities_positive      INTEGER NOT NULL,
    safety_positive         INTEGER NOT NULL
);

CREATE TABLE referrals (
    referral_id   INTEGER PRIMARY KEY,
    screening_id  INTEGER NOT NULL REFERENCES screenings(screening_id),
    member_id     INTEGER NOT NULL REFERENCES members(member_id),
    cbo_id        INTEGER NOT NULL REFERENCES cbos(cbo_id),
    need_domain   TEXT NOT NULL,
    referral_date TEXT NOT NULL,
    status        TEXT NOT NULL,    -- open, closed_met, closed_unmet
    closed_date   TEXT
);

CREATE TABLE encounters (
    encounter_id   INTEGER PRIMARY KEY,
    member_id      INTEGER NOT NULL REFERENCES members(member_id),
    encounter_date TEXT NOT NULL,
    encounter_type TEXT NOT NULL    -- ED, inpatient
);

CREATE INDEX idx_screenings_member ON screenings(member_id);
CREATE INDEX idx_referrals_member  ON referrals(member_id);
CREATE INDEX idx_referrals_cbo     ON referrals(cbo_id);
CREATE INDEX idx_encounters_member ON encounters(member_id);
