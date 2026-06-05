INSERT INTO agg_monthly_revenue (
    customer_id,
    month,
    total_revenue,
    last_updated_at
)
SELECT
    stg_b.customer_id,
    DATE_TRUNC('month', stg_b.transaction_date)::DATE   AS month,
    SUM(stg_b.amount)                                   AS total_revenue,
    NOW()                                               AS last_updated_at
FROM stg_billings stg_b
INNER JOIN stg_customers stg_c
    ON stg_b.customer_id = stg_c.customer_id
WHERE stg_b.transaction_date IS NOT NULL  -- exclude transactions with no date (can't assign to a month)
GROUP BY stg_b.customer_id, DATE_TRUNC('month', stg_b.transaction_date)

ON CONFLICT (customer_id, month)
DO UPDATE SET
    total_revenue   = agg_monthly_revenue.total_revenue + EXCLUDED.total_revenue,
    last_updated_at = EXCLUDED.last_updated_at;