CREATE TABLE IF NOT EXISTS agg_session_distribution(
    customer_id BIGINT PRIMARY KEY,
    short_sessions INT NOT NULL DEFAULT 0,
    medium_sessions INT NOT NULL DEFAULT 0,
    long_sessions INT NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);