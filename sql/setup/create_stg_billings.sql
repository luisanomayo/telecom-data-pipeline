--staging table for billing transactions with basic transformations and quality checks applied
CREATE TABLE IF NOT EXISTS stg_billing (
    transaction_id   BIGINT    PRIMARY KEY,
    customer_id      BIGINT    NOT NULL,
    amount           NUMERIC   NOT NULL DEFAULT 0,
    currency         VARCHAR(10),
    transaction_date TIMESTAMP NOT NULL,
    loaded_at        TIMESTAMP NOT NULL DEFAULT NOW()
);