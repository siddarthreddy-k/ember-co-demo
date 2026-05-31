-- =============================================================
-- Ember & Co — Dimension Layer (Kimball)
-- Model: dim_channels.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Channel dimension — one row per channel.
--              Provides display labels and groupings for BI tools.
--              Joined to fct_orders and fct_ad_spend on CHANNEL.
-- =============================================================

WITH channel_mapping AS (
    SELECT * FROM {{ ref('seed_channel_mapping') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['channel']) }}
                                    AS CHANNEL_KEY,

        -- Natural key
        UPPER(channel)              AS CHANNEL,

        -- Attributes
        display_name                AS DISPLAY_NAME,
        channel_type                AS CHANNEL_TYPE,
        colour                      AS COLOUR_HEX,

        -- Flags
        CASE WHEN channel_type = 'Paid' THEN TRUE ELSE FALSE END
                                    AS IS_PAID

    FROM channel_mapping
)

SELECT * FROM final