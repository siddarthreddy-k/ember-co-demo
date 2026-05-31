-- =============================================================
-- Ember & Co — Staging Layer
-- Model: stg_fulfilment.sql
-- Schema: EMBER_CO_DW.STAGING
-- Description: Cleans RAW.FULFILMENT and calculates fulfilment
--              durations and return processing times.
-- =============================================================

WITH base AS (
    SELECT
        ORDER_ID,
        TRY_TO_DATE(SHIPPED_AT)             AS SHIPPED_AT,
        TRY_TO_DATE(DELIVERED_AT)           AS DELIVERED_AT,
        TRY_TO_DATE(RETURN_REQUESTED_AT)    AS RETURN_REQUESTED_AT,
        TRY_TO_DATE(RETURN_COMPLETED_AT)    AS RETURN_COMPLETED_AT,
        LOWER(TRIM(FULFILMENT_STATUS))      AS FULFILMENT_STATUS,
        LOADED_AT
    FROM {{ source('raw', 'fulfilment') }}
    WHERE ORDER_ID IS NOT NULL
),

enriched AS (
    SELECT
        b.*,

        -- Fulfilment durations (days)
        DATEDIFF('day', b.SHIPPED_AT, b.DELIVERED_AT)              AS DAYS_TO_DELIVER,

        CASE
            WHEN b.RETURN_REQUESTED_AT IS NOT NULL
            THEN DATEDIFF('day', b.DELIVERED_AT, b.RETURN_REQUESTED_AT)
            ELSE NULL
        END AS DAYS_TO_RETURN_REQUEST,

        CASE
            WHEN b.RETURN_COMPLETED_AT IS NOT NULL
            AND b.RETURN_REQUESTED_AT IS NOT NULL
            THEN DATEDIFF('day', b.RETURN_REQUESTED_AT, b.RETURN_COMPLETED_AT)
            ELSE NULL
        END AS DAYS_TO_PROCESS_RETURN,

        -- Flags
        CASE WHEN b.RETURN_REQUESTED_AT IS NOT NULL THEN 1 ELSE 0 END  AS IS_RETURNED,
        CASE WHEN b.RETURN_COMPLETED_AT IS NOT NULL THEN 1 ELSE 0 END  AS IS_RETURN_COMPLETED

    FROM base b
)

SELECT * FROM enriched