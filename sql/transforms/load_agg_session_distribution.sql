INSERT INTO agg_session_distribution (
    customer_id,
    short_sessions,
    medium_sessions,
    long_sessions,
    last_updated_at
) SELECT
    customer_id,
    COUNT(*) FILTER (WHERE bucket = 'short') AS short_sessions,
    COUNT(*) FILTER (WHERE bucket = 'medium') AS medium_sessions,
    COUNT(*) FILTER (WHERE bucket = 'long') AS long_sessions,
    NOW() AS last_updated_at
FROM session_buckets
GROUP BY customer_id
ON CONFLICT (customer_id)
DO UPDATE SET
    short_sessions = agg_session_distribution.short_sessions + EXCLUDED.short_sessions,
    medium_sessions = agg_session_distribution.medium_sessions + EXCLUDED.medium_sessions,
    long_sessions = agg_session_distribution.long_sessions + EXCLUDED.long_sessions,
    last_updated_at = EXCLUDED.last_updated_at;
