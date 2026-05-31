
--TRUNCATE TABLE quarantine_records RESTART IDENTITY;

-- COMPLETENESS: NULL transaction_id in billing
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'billing_transactions',
    'null_identifier',
    MD5('billing_transactions' ||
     'null_identifier' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_billing_transactions t
WHERE transaction_id IS NULL
ON CONFLICT (record_hash) DO NOTHING;


-- COMPLETENESS: NULL session_id in sessions
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at
    )
SELECT
    row_to_json(t)::JSONB,
    'network_sessions',
    'null_identifier',
    MD5('network_sessions' ||
     'null_identifier' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_network_sessions t
WHERE session_id IS NULL
ON CONFLICT (record_hash) DO NOTHING;


-- COMPLETENESS: NULL customer_id in customers
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'customers',
    'null_identifier',
    MD5('customers' || 
    'null_identifier' || 
    row_to_json(t)::TEXT),
    NOW()
FROM src_customers t
WHERE customer_id IS NULL
ON CONFLICT (record_hash) DO NOTHING;


-- UNIQUENESS: duplicate transaction_ids in billing
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'billing_transactions',
    'duplicate_identifier',
    MD5('billing_transactions' ||
     'duplicate_identifier' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_billing_transactions t
WHERE transaction_id IN (
    SELECT transaction_id
    FROM src_billing_transactions
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
)
ON CONFLICT (record_hash) DO NOTHING;


-- UNIQUENESS: duplicate session_ids in sessions
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'network_sessions',
    'duplicate_identifier',
    MD5('network_sessions' ||
     'duplicate_identifier' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_network_sessions t
WHERE session_id IN (
    SELECT session_id
    FROM src_network_sessions
    GROUP BY session_id
    HAVING COUNT(*) > 1
)
ON CONFLICT (record_hash) DO NOTHING;


-- UNIQUENESS: duplicate customer_ids in customers
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'customers',
    'duplicate_identifier',
    MD5('customers' ||
     'duplicate_identifier' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_customers t
WHERE customer_id IN (
    SELECT customer_id
    FROM src_customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
ON CONFLICT (record_hash) DO NOTHING;


-- REFERENTIAL INTEGRITY: orphaned customer_ids in billing
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'billing_transactions',
    'orphaned_customer_id',
    MD5('billing_transactions' || 
    'orphaned_customer_id' || 
    row_to_json(t)::TEXT),
    NOW()
FROM src_billing_transactions t
WHERE t.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM src_customers c
      WHERE c.customer_id = t.customer_id
  )
ON CONFLICT (record_hash) DO NOTHING;


-- REFERENTIAL INTEGRITY: orphaned customer_ids in sessions
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'network_sessions',
    'orphaned_customer_id',
    MD5('network_sessions' ||
     'orphaned_customer_id' ||
    row_to_json(t)::TEXT),
    NOW()
FROM src_network_sessions t
WHERE t.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM src_customers c
      WHERE c.customer_id = t.customer_id
  )
ON CONFLICT (record_hash) DO NOTHING;


-- VALIDITY: negative amounts in billing
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'billing_transactions',
    'invalid_amount',
    MD5('billing_transactions' ||
     'invalid_amount' ||
      row_to_json(t)::TEXT),
    NOW()
FROM src_billing_transactions t
WHERE amount IS NOT NULL
  AND amount < 0
ON CONFLICT (record_hash) DO NOTHING;


-- VALIDITY: end_time before start_time in sessions
INSERT INTO quarantine_records (
    record, 
    source, 
    check_type, 
    record_hash, 
    detected_at)
SELECT
    row_to_json(t)::JSONB,
    'network_sessions',
    'invalid_session_times',
    MD5('network_sessions' ||
     'invalid_session_times' || 
     row_to_json(t)::TEXT),
    NOW()
FROM src_network_sessions t
WHERE end_time IS NOT NULL
  AND start_time IS NOT NULL
  AND end_time::TIMESTAMP < start_time::TIMESTAMP
ON CONFLICT (record_hash) DO NOTHING;