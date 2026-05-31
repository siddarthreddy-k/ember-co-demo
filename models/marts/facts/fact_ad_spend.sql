-- =============================================================
-- Ember & Co — Fact Layer (Kimball)
-- Model: fct_ad_spend.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Ad spend fact table. One row per channel per day.
--              References dim_dates and dim_channels.
--              Grain: one row per channel per day.
-- =============================================================

WITH ad_spend AS (
    SELECT * FROM {{ ref('stg_ad_spend') }}
),

dates AS (
    SELECT
        DATE_DAY,
        DATE_KEY,
        MONTH_LABEL,
        QUARTER_LABEL,
        IS_WEEKEND,
        IS_PEAK_SEASON
    FROM {{ ref('dim_dates') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['a.SPEND_DATE', 'a.CHANNEL']) }}
                                            AS AD_SPEND_KEY,

        -- Foreign keys
        d.DATE_KEY,

        -- Degenerate dimensions
        a.SPEND_DATE,
        a.CHANNEL,

        -- Context from dims
        d.MONTH_LABEL,
        d.QUARTER_LABEL,
        d.IS_WEEKEND,
        d.IS_PEAK_SEASON,

        -- Measures
        a.SPEND_GBP,
        a.IMPRESSIONS,
        a.CLICKS,

        -- Derived metrics
        a.CPM,
        a.CPC,
        a.CTR,

        -- Metadata
        a.LOADED_AT

    FROM ad_spend a
    LEFT JOIN dates d ON a.SPEND_DATE = d.DATE_DAY
)

SELECT * FROM final