-- update_watermark_sessions.sql

INSERT INTO pipeline_watermarks (source_table, last_processed, updated_at)
VALUES (
    'src_network_sessions',
    (SELECT MAX(start_time) FROM stg_sessions),
    NOW()
)
ON CONFLICT (source_table)
DO UPDATE SET
    last_processed = EXCLUDED.last_processed,
    updated_at     = EXCLUDED.updated_at;