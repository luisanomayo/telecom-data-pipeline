
INSERT INTO agg_user_revenue (
    customer_id,
    total_revenue,
    total_transactions,
    last_updated_at
)SELECT
    stg_b.customer_id,
    SUM(stg_b.amount)       AS total_revenue,
    COUNT(*)            AS total_transactions,
    NOW()               AS last_updated_at
FROM stg_billings stg_b
-- Only include customer_ids that exist in stg_customers
-- Orphaned transactions have no customer anchor — exclude them
INNER JOIN stg_customers stg_c
    ON stg_b.customer_id = stg_c.customer_id
GROUP BY stg_b.customer_id

ON CONFLICT (customer_id)
DO UPDATE SET
    total_revenue      = agg_user_revenue.total_revenue      + EXCLUDED.total_revenue,
    total_transactions = agg_user_revenue.total_transactions + EXCLUDED.total_transactions,
    last_updated_at    = EXCLUDED.last_updated_at;