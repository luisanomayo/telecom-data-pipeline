SELECT
    stg_c.customer_id,
    stg_c.name AS customer_name,
    stg_c.email,
    stg_c.country,
    stg_c.created_at::DATE AS customer_since,
    COALESCE(agg_r.total_revenue, 0) AS total_revenue,
    COALESCE(agg_r.total_transactions, 0) AS total_transactions,
    COALESCE(agg_us.total_data_used_mb, 0) AS total_data_used_mb,
    COALESCE(agg_us.total_sessions, 0) AS total_sessions,
    CASE
        WHEN COALESCE(agg_us.total_sessions, 0) = 0 THEN 0
        ELSE agg_us.total_session_duration / agg_us.total_sessions
    END AS avg_session_duration_sec,
    COALESCE(agg_ar.arpu, 0) AS arpu,
    COALESCE(agg_sd.short_sessions, 0) AS short_sessions,
    COALESCE(agg_sd.medium_sessions, 0) AS medium_sessions,
    COALESCE(agg_sd.long_sessions, 0) AS long_sessions,
    CASE
        WHEN COALESCE(agg_us.total_sessions, 0) = 0 THEN 0
        ELSE agg_us.total_data_used_mb / agg_us.total_sessions
    END AS avg_data_per_session_mb,
    stg_c.row_hash,
    NOW() AS last_updated_at
FROM stg_customers stg_c
LEFT JOIN agg_user_revenue agg_r ON stg_c.customer_id = agg_r.customer_id
LEFT JOIN agg_user_usage agg_us ON stg_c.customer_id = agg_us.customer_id
LEFT JOIN agg_arpu agg_ar ON stg_c.customer_id = agg_ar.customer_id
LEFT JOIN agg_session_distribution agg_sd ON stg_c.customer_id = agg_sd.customer_id;