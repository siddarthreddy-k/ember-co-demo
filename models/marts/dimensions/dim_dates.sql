-- =============================================================
-- Ember & Co — Dimension Layer (Kimball)
-- Model: dim_dates.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Date dimension — one row per calendar day
--              covering the full range of the dataset (2024).
--              Standard Kimball date dim for time intelligence
--              in Looker Studio and SQL analysis.
-- =============================================================

WITH date_spine AS (
    SELECT
        DATEADD('day', SEQ4(), '2024-01-01'::DATE) AS DATE_DAY
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD('day', SEQ4(), '2024-01-01'::DATE) <= '2024-12-31'::DATE
),

final AS (
    SELECT
        -- Surrogate key
        TO_NUMBER(TO_CHAR(DATE_DAY, 'YYYYMMDD'))    AS DATE_KEY,

        -- Natural key
        DATE_DAY,

        -- Day attributes
        DATE_PART('year',       DATE_DAY)           AS YEAR,
        DATE_PART('quarter',    DATE_DAY)           AS QUARTER,
        DATE_PART('month',      DATE_DAY)           AS MONTH_NUMBER,
        MONTHNAME(DATE_DAY)                         AS MONTH_NAME,
        DATE_PART('week',       DATE_DAY)           AS WEEK_NUMBER,
        DATE_PART('dayofweek',  DATE_DAY)           AS DAY_OF_WEEK,
        DAYNAME(DATE_DAY)                           AS DAY_NAME,
        DATE_PART('dayofyear',  DATE_DAY)           AS DAY_OF_YEAR,

        -- Truncated periods
        DATE_TRUNC('week',      DATE_DAY)           AS WEEK_START,
        DATE_TRUNC('month',     DATE_DAY)           AS MONTH_START,
        DATE_TRUNC('quarter',   DATE_DAY)           AS QUARTER_START,

        -- Display labels
        'Q' || DATE_PART('quarter', DATE_DAY) || ' '
            || DATE_PART('year', DATE_DAY)          AS QUARTER_LABEL,
        MONTHNAME(DATE_DAY) || ' '
            || DATE_PART('year', DATE_DAY)          AS MONTH_LABEL,

        -- Flags
        CASE WHEN DAYNAME(DATE_DAY) IN ('Sat', 'Sun')
            THEN TRUE ELSE FALSE END                AS IS_WEEKEND,

        CASE WHEN DATE_PART('month', DATE_DAY) IN (11, 12)
            THEN TRUE ELSE FALSE END                AS IS_PEAK_SEASON

    FROM date_spine
)

SELECT * FROM final
ORDER BY DATE_DAY