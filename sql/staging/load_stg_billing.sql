-- load_stg_billings.sql

INSERT INTO stg_billings (
    transaction_id,
    customer_id,
    amount,
    currency,
    transaction_date,
    loaded_at
)
SELECT
    transaction_id,
    customer_id,
    COALESCE(amount, 0)                                AS amount,
    CASE
        WHEN UPPER(TRIM(currency)) IN ('NGN', 'NAIRA') THEN 'NGN'
        ELSE 'NGN'
    END                                                AS currency,
    transaction_date::TIMESTAMP                        AS transaction_date,
    NOW()                                              AS loaded_at
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY transaction_date::TIMESTAMP DESC
        ) AS row_num
    FROM src_billing_transactions
    WHERE transaction_id  IS NOT NULL
      AND customer_id     IS NOT NULL
      AND transaction_date::TIMESTAMP > (
            SELECT last_processed - INTERVAL '3 days'
            FROM pipeline_watermarks
            WHERE source_table = 'src_billing_transactions'
      )
) deduped
WHERE row_num = 1
ON CONFLICT (transaction_id)
DO UPDATE SET
    customer_id      = EXCLUDED.customer_id,
    amount           = EXCLUDED.amount,
    currency         = EXCLUDED.currency,
    transaction_date = EXCLUDED.transaction_date,
    loaded_at        = EXCLUDED.loaded_at;