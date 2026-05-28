-- Billing: negative or zero amounts
SELECT
    'src_billing_transactions'  AS source_table,
    'invalid_amount'            AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_billing_transactions
WHERE amount IS NOT NULL
  AND amount::NUMERIC < 0

UNION ALL

-- Billing: unparseable transaction_date
SELECT
    'src_billing_transactions'  AS source_table,
    'unparseable_date'          AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_billing_transactions
WHERE transaction_date IS NOT NULL
  AND transaction_date::TIMESTAMP IS NULL

UNION ALL

-- Sessions: end_time before or equal to start_time
SELECT
    'src_network_sessions'      AS source_table,
    'invalid_session_times'     AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_network_sessions
WHERE end_time IS NOT NULL
  AND start_time IS NOT NULL
  AND end_time::TIMESTAMP < start_time::TIMESTAMP

UNION ALL

-- Sessions: unparseable start_time or end_time
SELECT
    'src_network_sessions'      AS source_table,
    'unparseable_timestamp'     AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_network_sessions
WHERE start_time IS NOT NULL
  AND start_time::TIMESTAMP IS NULL;





