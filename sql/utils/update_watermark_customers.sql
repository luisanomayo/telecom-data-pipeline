-- update_watermark_customers.sql

INSERT INTO pipeline_watermarks (source_table, last_processed, updated_at)
VALUES (
    'src_customers',
    (SELECT MAX(created_at) FROM stg_customers),
    NOW()
)
ON CONFLICT (source_table)
DO UPDATE SET
    last_processed = EXCLUDED.last_processed,
    updated_at     = EXCLUDED.updated_at;