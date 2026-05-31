-- =============================================================
-- Ember & Co — Mart Layer
-- Model: mart_ltv_cohorts.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Customer LTV cohort analysis.
--              Groups customers by acquisition month and tracks
--              cumulative net revenue at 30, 60, 90, 180 days.
--              Key story: Top cohort by order volume is least
--              profitable once returns are factored in.
-- =============================================================

WITH customers AS (
    SELECT
        CUSTOMER_ID,
        ACQUISITION_CHANNEL,
        ACQUISITION_DATE,
        ACQUISITION_COHORT,
        CHANNEL_TYPE,
        REGION
    FROM {{ ref('stg_customers') }}
),

orders AS (
    SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_DATE,
        NET_REVENUE,
        IS_RETURNED,
        GROSS_REVENUE,
        DISCOUNT
    FROM {{ ref('stg_orders') }}
),

customer_orders AS (
    SELECT
        c.CUSTOMER_ID,
        c.ACQUISITION_CHANNEL,
        c.ACQUISITION_DATE,
        c.ACQUISITION_COHORT,
        c.CHANNEL_TYPE,
        c.REGION,
        o.ORDER_DATE,
        o.NET_REVENUE,
        o.GROSS_REVENUE,
        o.IS_RETURNED,

        -- Days since acquisition
        DATEDIFF('day', c.ACQUISITION_DATE, o.ORDER_DATE) AS DAYS_SINCE_ACQ

    FROM customers c
    LEFT JOIN orders o ON c.CUSTOMER_ID = o.CUSTOMER_ID
),

cohort_ltv AS (
    SELECT
        ACQUISITION_COHORT,
        ACQUISITION_CHANNEL,
        CHANNEL_TYPE,
        REGION,

        -- Cohort size
        COUNT(DISTINCT CUSTOMER_ID)                         AS COHORT_SIZE,

        -- Total orders and returns
        COUNT(ORDER_DATE)                                   AS TOTAL_ORDERS,
        SUM(IS_RETURNED)                                    AS TOTAL_RETURNS,

        -- Return rate
        ROUND(SUM(IS_RETURNED) / NULLIF(COUNT(ORDER_DATE), 0) * 100, 1)
                                                            AS RETURN_RATE_PCT,

        -- Cumulative revenue at 30 days
        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 30
            THEN NET_REVENUE ELSE 0 END), 2)                AS LTV_30D,

        -- Cumulative revenue at 60 days
        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 60
            THEN NET_REVENUE ELSE 0 END), 2)                AS LTV_60D,

        -- Cumulative revenue at 90 days
        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 90
            THEN NET_REVENUE ELSE 0 END), 2)                AS LTV_90D,

        -- Cumulative revenue at 180 days
        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 180
            THEN NET_REVENUE ELSE 0 END), 2)                AS LTV_180D,

        -- LTV per customer at each interval
        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 30
            THEN NET_REVENUE ELSE 0 END)
            / NULLIF(COUNT(DISTINCT CUSTOMER_ID), 0), 2)   AS LTV_30D_PER_CUSTOMER,

        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 60
            THEN NET_REVENUE ELSE 0 END)
            / NULLIF(COUNT(DISTINCT CUSTOMER_ID), 0), 2)   AS LTV_60D_PER_CUSTOMER,

        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 90
            THEN NET_REVENUE ELSE 0 END)
            / NULLIF(COUNT(DISTINCT CUSTOMER_ID), 0), 2)   AS LTV_90D_PER_CUSTOMER,

        ROUND(SUM(CASE WHEN DAYS_SINCE_ACQ <= 180
            THEN NET_REVENUE ELSE 0 END)
            / NULLIF(COUNT(DISTINCT CUSTOMER_ID), 0), 2)   AS LTV_180D_PER_CUSTOMER

    FROM customer_orders
    GROUP BY 1, 2, 3, 4
)

SELECT * FROM cohort_ltv
ORDER BY ACQUISITION_COHORT, ACQUISITION_CHANNEL