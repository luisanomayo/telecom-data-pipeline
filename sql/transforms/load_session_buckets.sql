INSERT INTO session_buckets(
    session_id,
    customer_id,
    bucket,
    last_updated_at
) SELECT
    stg_s.session_id,
    stg_s.customer_id,
    CASE 
        WHEN stg_s.session_duration_sec < 60 THEN 'short' 
        WHEN stg_s.session_duration_sec < 300 THEN 'medium'
        ELSE 'long' 
    END AS bucket,
    NOW() AS last_updated_at
FROM stg_sessions stg_s
INNER JOIN stg_customers stg_c
    ON stg_s.customer_id = stg_c.customer_id

ON CONFLICT (session_id)
DO UPDATE SET
    bucket = EXCLUDED.bucket,
    last_updated_at = EXCLUDED.last_updated_at;