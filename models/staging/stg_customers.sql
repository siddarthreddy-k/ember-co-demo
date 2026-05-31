-- =============================================================
-- Ember & Co — Staging Layer
-- Model: stg_customers.sql
-- Schema: EMBER_CO_DW.STAGING
-- Description: Cleans RAW.CUSTOMERS and adds derived fields
--              for cohort analysis and segmentation.
-- =============================================================

WITH base AS (
    SELECT
        CUSTOMER_ID,
        LOWER(TRIM(ACQUISITION_CHANNEL))    AS ACQUISITION_CHANNEL,
        TRY_TO_DATE(ACQUISITION_DATE)       AS ACQUISITION_DATE,
        UPPER(TRIM(COUNTRY))                AS COUNTRY,
        EMAIL_SUBSCRIBED,
        LOADED_AT
    FROM {{ source('raw', 'customers') }}
    WHERE CUSTOMER_ID IS NOT NULL
),

enriched AS (
    SELECT
        b.*,

        -- Cohort key — month of acquisition (used in LTV cohort mart)
        DATE_TRUNC('month', b.ACQUISITION_DATE)     AS ACQUISITION_COHORT,

        -- Quarter of acquisition
        DATE_TRUNC('quarter', b.ACQUISITION_DATE)   AS ACQUISITION_QUARTER,

        -- Channel grouping — paid vs organic
        CASE
            WHEN b.ACQUISITION_CHANNEL IN ('meta', 'google', 'tiktok') THEN 'paid'
            WHEN b.ACQUISITION_CHANNEL IN ('organic', 'email', 'referral') THEN 'organic'
            ELSE 'unknown'
        END AS CHANNEL_TYPE,

        -- Region grouping
        CASE
            WHEN b.COUNTRY IN ('GB', 'DE', 'FR', 'NL') THEN 'Europe'
            WHEN b.COUNTRY = 'US' THEN 'North America'
            WHEN b.COUNTRY = 'CA' THEN 'North America'
            WHEN b.COUNTRY = 'AU' THEN 'APAC'
            ELSE 'Other'
        END AS REGION

    FROM base b
)

SELECT * FROM enriched