--create a watermark table to track the last processed timestamp for each source table
CREATE TABLE IF NOT EXISTS pipeline_watermarks (
    source_table TEXT PRIMARY KEY,
    last_processed TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


