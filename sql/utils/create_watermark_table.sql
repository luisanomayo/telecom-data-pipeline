--create a watermark table to track the last processed timestamp for each source table
CREATE TABLE IF NOT EXISTS pipeline_watermark (
    source_table TEXT PRIMARY KEY,
    last_processed TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


--seed initial watermarks for each source table
INSERT INTO pipeline_watermark (source_table, last_processed)
VALUES
    ('src_billing_transactions', '1970-01-01 00:00:00'),
    ('src_network_sessions', '1970-01-01 00:00:00'),
    ('src_customers', '1970-01-01 00:00:00')
ON CONFLICT (source_table) DO NOTHING;
