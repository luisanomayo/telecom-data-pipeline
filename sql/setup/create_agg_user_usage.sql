CREATE TABLE IF NOT EXISTS agg_user_usage (
    customer_id BIGINT PRIMARY KEY,
    total_data_used_mb NUMERIC NOT NULL DEFAULT 0,
    total_session_duration NUMERIC NOT NULL DEFAULT 0,
    total_sessions INT NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);