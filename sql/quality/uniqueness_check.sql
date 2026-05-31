-- Billing: duplicate transaction_ids
SELECT
    'src_billing_transactions'  AS source_table,
    'duplicate_identifier'      AS check_type,
    COUNT(*)                    AS faulty_rows
FROM (
    SELECT transaction_id
    FROM src_billing_transactions
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

-- Sessions: duplicate session_ids
SELECT
    'src_network_sessions'      AS source_table,
    'duplicate_identifier'      AS check_type,
    COUNT(*)                    AS faulty_rows
FROM (
    SELECT session_id
    FROM src_network_sessions
    GROUP BY session_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

-- Customers: duplicate customer_ids
SELECT
    'src_customers'      AS source_table,
    'duplicate_identifier'      AS check_type,
    COUNT(*)                    AS faulty_rows
FROM (
    SELECT customer_id
    FROM src_customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) duplicates;
