-- Active: 1749329170628@@127.0.0.1@5432@datatel


-- Billing: NULL transaction_id or customer_id
SELECT
    'src_billing_transactions'  AS source_table,
    'null_identifier'           AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_billing_transactions
WHERE transaction_id IS NULL
   --OR customer_id IS NULL

UNION ALL

-- Sessions: NULL session_id or customer_id
SELECT
    'src_network_sessions'      AS source_table,
    'null_identifier'           AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_network_sessions
WHERE session_id IS NULL
   --OR customer_id IS NULL

UNION ALL

-- Customers: NULL customer_id
SELECT
    'src_customers'             AS source_table,
    'null_identifier'           AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_customers
WHERE customer_id IS NULL

UNION ALL

--transaction_date with NULL value
SELECT
    'src_billing_transactions'  AS source_table,
    'null_transaction_date'     AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_billing_transactions
WHERE transaction_date IS NULL

UNION ALL

--created at with NULL value
SELECT
    'src_customers'             AS source_table,
    'null_created_at'           AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_customers
WHERE created_at IS NULL

UNION ALL

--start_time or end_time with NULL value
SELECT
    'src_network_sessions'      AS source_table,
    'null_start_or_end_time'    AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_network_sessions
WHERE start_time IS NULL
   OR end_time IS NULL;