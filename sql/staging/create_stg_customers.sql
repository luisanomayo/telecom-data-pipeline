CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id BIGINT    PRIMARY KEY,
    name        TEXT,
    email       TEXT,
    country     TEXT,
    created_at  TIMESTAMP,
    row_hash    TEXT      NOT NULL,
    loaded_at   TIMESTAMP NOT NULL DEFAULT NOW()
);