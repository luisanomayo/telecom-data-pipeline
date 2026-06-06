CREATE TABLE IF NOT EXISTS agg_monthly_revenue (
    customer_id BIGINT NOT NULL,
    month DATE NOT NULL,
    total_revenue NUMERIC NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (customer_id, month)
);