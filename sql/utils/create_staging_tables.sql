--staging table for billing transactions with basic transformations and quality checks applied
CREATE TABLE IF NOT EXISTS stg_billing (
    transaction_id   BIGINT    PRIMARY KEY,
    customer_id      BIGINT    NOT NULL,
    amount           NUMERIC   NOT NULL DEFAULT 0,
    currency         VARCHAR(10),
    transaction_date TIMESTAMP NOT NULL,
    loaded_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

--staging table for network_sessions with basic transformations and quality checks applied

CREATE TABLE IF NOT EXISTS stg_sessions (
    session_id           BIGINT    PRIMARY KEY,
    customer_id          BIGINT    NOT NULL,
    start_time           TIMESTAMP NOT NULL,
    end_time             TIMESTAMP,
    data_used_mb         NUMERIC   NOT NULL DEFAULT 0,
    session_duration_sec NUMERIC   NOT NULL DEFAULT 0,
    loaded_at            TIMESTAMP NOT NULL DEFAULT NOW()
);

--staging table for customers with basic transformations and quality checks applied
CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id BIGINT    PRIMARY KEY,
    name        TEXT,
    email       TEXT,
    country     TEXT,
    created_at  TIMESTAMP,
    row_hash    TEXT      NOT NULL,
    loaded_at   TIMESTAMP NOT NULL DEFAULT NOW()
);
