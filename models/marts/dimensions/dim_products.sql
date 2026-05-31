-- =============================================================
-- Ember & Co — Dimension Layer (Kimball)
-- Model: dim_products.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Product category dimension derived from orders.
--              One row per product category.
-- =============================================================

WITH categories AS (
    SELECT DISTINCT
        CATEGORY
    FROM {{ ref('stg_orders') }}
    WHERE CATEGORY IS NOT NULL
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['CATEGORY']) }}
                                        AS PRODUCT_KEY,

        -- Natural key
        CATEGORY                        AS CATEGORY,

        -- Display name
        INITCAP(CATEGORY)               AS DISPLAY_NAME,

        -- Average order value benchmark by category
        CASE CATEGORY
            WHEN 'tops'         THEN 45
            WHEN 'bottoms'      THEN 65
            WHEN 'outerwear'    THEN 120
            WHEN 'accessories'  THEN 35
            WHEN 'footwear'     THEN 90
            ELSE NULL
        END                             AS BENCHMARK_AOV_GBP,

        -- Return risk — higher AOV categories tend to have higher returns
        CASE CATEGORY
            WHEN 'outerwear'    THEN 'High'
            WHEN 'footwear'     THEN 'High'
            WHEN 'bottoms'      THEN 'Medium'
            WHEN 'tops'         THEN 'Medium'
            WHEN 'accessories'  THEN 'Low'
            ELSE 'Unknown'
        END                             AS RETURN_RISK

    FROM categories
)

SELECT * FROM final