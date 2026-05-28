CREATE TABLE IF NOT EXISTS quarantine_records (
    id           SERIAL       PRIMARY KEY,
    record       JSONB        NOT NULL,
    source       VARCHAR(50)  NOT NULL,
    check_type   VARCHAR(50)  NOT NULL,
    record_hash  TEXT         NOT NULL,
    detected_at  TIMESTAMP    DEFAULT NOW(),

    UNIQUE (record_hash)
);