--seed initial watermarks for each source table
INSERT INTO pipeline_watermarks (source_table, last_processed)
VALUES
    ('src_billing_transactions', '1970-01-01 00:00:00'),
    ('src_network_sessions', '1970-01-01 00:00:00'),
    ('src_customers', '1970-01-01 00:00:00')
ON CONFLICT (source_table) DO NOTHING;
