-- Billing: customer_ids with no matching customer record
SELECT
    'src_billing_transactions'  AS source_table,
    'orphaned_customer_id'      AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_billing_transactions b
WHERE b.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM src_customers c
    WHERE c.customer_id = b.customer_id
)

UNION ALL

-- Sessions: customer_ids with no matching customer record
SELECT
    'src_network_sessions'      AS source_table,
    'orphaned_customer_id'      AS check_type,
    COUNT(*)                    AS faulty_rows
FROM src_network_sessions s
WHERE s.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM src_customers c
    WHERE c.customer_id = s.customer_id
);


