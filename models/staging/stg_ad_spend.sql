-- =============================================================
-- Ember & Co — Staging Layer
-- Model: stg_ad_spend.sql
-- Schema: EMBER_CO_DW.STAGING
-- Description: Cleans RAW.AD_SPEND and derives performance
--              metrics — CPM, CPC, CTR — per channel per day.
-- =============================================================

WITH base AS (
    SELECT
        TRY_TO_DATE(DATE)           AS SPEND_DATE,
        LOWER(TRIM(CHANNEL))        AS CHANNEL,
        COALESCE(SPEND_GBP, 0)      AS SPEND_GBP,
        COALESCE(IMPRESSIONS, 0)    AS IMPRESSIONS,
        COALESCE(CLICKS, 0)         AS CLICKS,
        LOADED_AT
    FROM {{ source('raw', 'ad_spend') }}
    WHERE DATE IS NOT NULL
),

enriched AS (
    SELECT
        b.*,

        -- Time dimensions
        DATE_TRUNC('week',  b.SPEND_DATE)   AS SPEND_WEEK,
        DATE_TRUNC('month', b.SPEND_DATE)   AS SPEND_MONTH,
        DATE_PART('quarter', b.SPEND_DATE)  AS SPEND_QUARTER,

        -- Derived performance metrics
        CASE
            WHEN b.IMPRESSIONS > 0
            THEN ROUND((b.SPEND_GBP / b.IMPRESSIONS) * 1000, 2)
            ELSE NULL
        END AS CPM,

        CASE
            WHEN b.CLICKS > 0
            THEN ROUND(b.SPEND_GBP / b.CLICKS, 2)
            ELSE NULL
        END AS CPC,

        CASE
            WHEN b.IMPRESSIONS > 0
            THEN ROUND(b.CLICKS / b.IMPRESSIONS, 4)
            ELSE NULL
        END AS CTR

    FROM base b
)

SELECT * FROM enriched