CREATE TABLE IF NOT EXISTS session_buckets (
    session_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    bucket VARCHAR(10) NOT NULL, -- 'short', 'medium', 'long'
    last_updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);