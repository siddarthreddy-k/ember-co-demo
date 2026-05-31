-- =============================================================
-- Ember & Co — Fact Layer (Kimball)
-- Model: fct_orders.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Orders fact table. One row per order.
--              References dim tables via surrogate keys.
--              Grain: one row per order.
-- =============================================================

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

customers AS (
    SELECT
        CUSTOMER_ID,
        CUSTOMER_KEY,
        ACQUISITION_COHORT,
        CHANNEL_TYPE,
        REGION
    FROM {{ ref('dim_customers') }}
),

dates AS (
    SELECT
        DATE_DAY,
        DATE_KEY,
        QUARTER_LABEL,
        MONTH_LABEL,
        IS_WEEKEND,
        IS_PEAK_SEASON
    FROM {{ ref('dim_dates') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['o.ORDER_ID']) }}
                                            AS ORDER_KEY,

        -- Natural key
        o.ORDER_ID,

        -- Foreign keys to dimensions
        c.CUSTOMER_KEY,
        d.DATE_KEY,

        -- Degenerate dimensions (kept on fact for convenience)
        o.CUSTOMER_ID,
        o.ORDER_DATE,
        o.CHANNEL,
        o.CATEGORY,
        o.COUNTRY,
        o.STATUS,

        -- Context from dims
        c.ACQUISITION_COHORT,
        c.CHANNEL_TYPE,
        c.REGION,
        d.MONTH_LABEL,
        d.QUARTER_LABEL,
        d.IS_WEEKEND,
        d.IS_PEAK_SEASON,

        -- Measures
        o.GROSS_REVENUE,
        o.DISCOUNT,
        o.NET_REVENUE,
        o.ADJUSTED_REVENUE,

        -- Flags
        o.IS_RETURNED,
        o.IS_DISCOUNTED,

        -- Metadata
        o.LOADED_AT

    FROM orders o
    LEFT JOIN customers c ON o.CUSTOMER_ID = c.CUSTOMER_ID
    LEFT JOIN dates d ON o.ORDER_DATE = d.DATE_DAY
)

SELECT * FROM final