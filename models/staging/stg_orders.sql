-- =============================================================
-- Ember & Co — Staging Layer
-- Model: stg_orders.sql
-- Schema: EMBER_CO_DW.STAGING
-- Description: Cleans and casts RAW.ORDERS, derives time
--              dimensions, revenue flags and adjusted revenue.
-- =============================================================

WITH base AS (
    SELECT
        ORDER_ID,
        CUSTOMER_ID,
        TRY_TO_DATE(ORDER_DATE)         AS ORDER_DATE,
        LOWER(TRIM(CHANNEL))            AS CHANNEL,
        LOWER(TRIM(CATEGORY))           AS CATEGORY,
        UPPER(TRIM(COUNTRY))            AS COUNTRY,
        COALESCE(GROSS_REVENUE, 0)      AS GROSS_REVENUE,
        COALESCE(DISCOUNT, 0)           AS DISCOUNT,
        COALESCE(NET_REVENUE, 0)        AS NET_REVENUE,
        RETURNED,
        LOWER(TRIM(STATUS))             AS STATUS,
        LOADED_AT
    FROM {{ source('raw', 'orders') }}
    WHERE ORDER_ID IS NOT NULL
),

enriched AS (
    SELECT
        b.*,

        -- Time dimensions
        DATE_TRUNC('week',  b.ORDER_DATE)   AS ORDER_WEEK,
        DATE_TRUNC('month', b.ORDER_DATE)   AS ORDER_MONTH,
        DATE_PART('quarter', b.ORDER_DATE)  AS ORDER_QUARTER,
        DATE_PART('year',    b.ORDER_DATE)  AS ORDER_YEAR,

        -- Revenue flags
        CASE WHEN b.RETURNED = TRUE THEN 1 ELSE 0 END  AS IS_RETURNED,
        CASE WHEN b.DISCOUNT > 0    THEN 1 ELSE 0 END  AS IS_DISCOUNTED,

        -- Adjusted revenue after discount
        ROUND(b.NET_REVENUE - b.DISCOUNT, 2)            AS ADJUSTED_REVENUE

    FROM base b
)

SELECT * FROM enriched