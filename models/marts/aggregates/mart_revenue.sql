-- =============================================================
-- Ember & Co — Mart Layer
-- Model: mart_revenue.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Gross vs net revenue by channel and week.
--              Surfaces return rate impact on real revenue.
--              Key story: Meta gross looks strong but net
--              revenue is eroded by 31% return rate.
-- =============================================================

WITH orders AS (
    SELECT
        ORDER_WEEK,
        ORDER_MONTH,
        ORDER_QUARTER,
        ORDER_YEAR,
        CHANNEL,
        COUNTRY,
        CATEGORY,
        GROSS_REVENUE,
        DISCOUNT,
        NET_REVENUE,
        ADJUSTED_REVENUE,
        IS_RETURNED,
        IS_DISCOUNTED
    FROM {{ ref('stg_orders') }}
),

weekly_revenue AS (
    SELECT
        ORDER_WEEK                          AS WEEK,
        ORDER_MONTH                         AS MONTH,
        ORDER_QUARTER                       AS QUARTER,
        ORDER_YEAR                          AS YEAR,
        CHANNEL,
        COUNTRY,
        CATEGORY,

        -- Volume
        COUNT(*)                            AS TOTAL_ORDERS,
        SUM(IS_RETURNED)                    AS RETURNED_ORDERS,

        -- Revenue
        ROUND(SUM(GROSS_REVENUE), 2)        AS GROSS_REVENUE,
        ROUND(SUM(DISCOUNT), 2)             AS TOTAL_DISCOUNTS,
        ROUND(SUM(NET_REVENUE), 2)          AS NET_REVENUE,
        ROUND(SUM(ADJUSTED_REVENUE), 2)     AS ADJUSTED_REVENUE,

        -- Rates
        ROUND(SUM(IS_RETURNED) / COUNT(*) * 100, 1)     AS RETURN_RATE_PCT,
        ROUND(SUM(IS_DISCOUNTED) / COUNT(*) * 100, 1)   AS DISCOUNT_RATE_PCT,

        -- Average order values
        ROUND(AVG(GROSS_REVENUE), 2)        AS AVG_ORDER_VALUE,
        ROUND(AVG(NET_REVENUE), 2)          AS AVG_NET_ORDER_VALUE

    FROM orders
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT * FROM weekly_revenue
ORDER BY WEEK, CHANNEL