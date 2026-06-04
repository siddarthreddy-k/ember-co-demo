-- =============================================================
-- Ember & Co — Mart Layer
-- Model: mart_cac.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Blended CAC per channel per month.
--              Joins ad spend to new customers acquired.
--              Key story: Meta CAC inflates ~40% Jan to Dec.
-- =============================================================

WITH monthly_spend AS (
    SELECT
        SPEND_MONTH                         AS MONTH,
        CHANNEL,
        SUM(SPEND_GBP)                      AS TOTAL_SPEND
    FROM {{ ref('stg_ad_spend') }}
    GROUP BY 1, 2
),

new_customers AS (
    SELECT
        DATE_TRUNC('month', ACQUISITION_DATE)   AS MONTH,
        ACQUISITION_CHANNEL                     AS CHANNEL,
        COUNT(DISTINCT CUSTOMER_ID)             AS NEW_CUSTOMERS
    FROM {{ ref('stg_customers') }}
    WHERE ACQUISITION_CHANNEL IN ('meta', 'google', 'tiktok')
    GROUP BY 1, 2
),

joined AS (
    SELECT
        s.MONTH,
        s.CHANNEL,
        s.TOTAL_SPEND,
        COALESCE(c.NEW_CUSTOMERS, 0)        AS NEW_CUSTOMERS,
        CASE
            WHEN COALESCE(c.NEW_CUSTOMERS, 0) > 0
            THEN ROUND(s.TOTAL_SPEND / c.NEW_CUSTOMERS, 2)
            ELSE NULL
        END                                 AS CAC_GBP
    FROM monthly_spend s
    LEFT JOIN new_customers c
        ON s.MONTH = c.MONTH
        AND s.CHANNEL = c.CHANNEL
)

SELECT
    MONTH,
    CHANNEL,
    TOTAL_SPEND,
    NEW_CUSTOMERS,
    CAC_GBP,

    -- Month over month CAC change (absolute)
    CAC_GBP - LAG(CAC_GBP) OVER (
        PARTITION BY CHANNEL ORDER BY MONTH
    )                                       AS CAC_MOM_CHANGE,

    -- % change as decimal (e.g. 0.102 = 10.2%) — format as % in Looker
    CASE
        WHEN LAG(CAC_GBP) OVER (PARTITION BY CHANNEL ORDER BY MONTH) > 0
        THEN ROUND(
            (CAC_GBP - LAG(CAC_GBP) OVER (PARTITION BY CHANNEL ORDER BY MONTH))
            / LAG(CAC_GBP) OVER (PARTITION BY CHANNEL ORDER BY MONTH), 4)
        ELSE NULL
    END                                     AS CAC_MOM_PCT_CHANGE

FROM joined
ORDER BY MONTH, CHANNEL