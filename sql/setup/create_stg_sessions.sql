CREATE TABLE IF NOT EXISTS stg_sessions (
    session_id           BIGINT    PRIMARY KEY,
    customer_id          BIGINT    NOT NULL,
    start_time           TIMESTAMP NOT NULL,
    end_time             TIMESTAMP,
    data_used_mb         NUMERIC   NOT NULL DEFAULT 0,
    session_duration_sec NUMERIC   NOT NULL DEFAULT 0,
    loaded_at            TIMESTAMP NOT NULL DEFAULT NOW()
);