CREATE TABLE IF NOT EXISTS agg_user_revenue (
    customer_id BIGINT PRIMARY KEY,
    total_revenue NUMERIC NOT NULL DEFAULT 0,
    total_transactions INT NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

--ALTER TABLE agg_user_revenue
--ALTER COLUMN total_revenue SET DATA TYPE NUMERIC;