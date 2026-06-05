-- update_watermark_billings.sql

INSERT INTO pipeline_watermarks (source_table, last_processed, updated_at)
VALUES (
    'src_billing_transactions',
    (SELECT MAX(transaction_date) FROM stg_billings),
    NOW()
)
ON CONFLICT (source_table)
DO UPDATE SET
    last_processed = EXCLUDED.last_processed,
    updated_at     = EXCLUDED.updated_at;