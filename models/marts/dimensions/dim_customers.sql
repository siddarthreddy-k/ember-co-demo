-- =============================================================
-- Ember & Co — Dimension Layer (Kimball)
-- Model: dim_customers.sql
-- Schema: EMBER_CO_DW.MARTS
-- Description: Customer dimension table. One row per customer.
--              Contains all customer attributes for slicing
--              fact tables in BI tools.
-- =============================================================

WITH source AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['CUSTOMER_ID']) }}
                                            AS CUSTOMER_KEY,

        -- Natural key
        CUSTOMER_ID,

        -- Attributes
        ACQUISITION_CHANNEL,
        ACQUISITION_DATE,
        ACQUISITION_COHORT,
        ACQUISITION_QUARTER,
        CHANNEL_TYPE,
        COUNTRY,
        REGION,
        EMAIL_SUBSCRIBED,

        -- Metadata
        LOADED_AT
    FROM source
)

SELECT * FROM final