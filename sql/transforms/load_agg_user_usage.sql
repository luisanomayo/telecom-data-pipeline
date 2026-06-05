
INSERT INTO agg_user_usage (
    customer_id,
    total_data_used_mb,
    total_session_duration,
    total_sessions,
    last_updated_at
)SELECT
    stg_s.customer_id,
    SUM(stg_s.data_used_mb)          AS total_data_used_mb,
    SUM(stg_s.session_duration_sec)  AS total_session_duration,
    COUNT(*)                         AS total_sessions,
    NOW()                            AS last_updated_at
FROM stg_sessions stg_s
INNER JOIN stg_customers stg_c
    ON stg_s.customer_id = stg_c.customer_id
GROUP BY stg_s.customer_id

ON CONFLICT (customer_id)
DO UPDATE SET
    total_data_used_mb     = agg_user_usage.total_data_used_mb     + EXCLUDED.total_data_used_mb,
    total_session_duration = agg_user_usage.total_session_duration + EXCLUDED.total_session_duration,
    total_sessions         = agg_user_usage.total_sessions         + EXCLUDED.total_sessions,
    last_updated_at        = EXCLUDED.last_updated_at;