
INSERT INTO agg_arpu(
    customer_id,
    arpu,
    last_updated_at
) SELECT 
    customer_id,
    CASE WHEN COUNT (DISTINCT month) = 0 THEN 0 
    ELSE SUM(total_revenue) / COUNT(DISTINCT month) END AS arpu,
    NOW () AS last_updated_at
FROM agg_monthly_revenue
GROUP BY customer_id
ON CONFLICT (customer_id)
DO UPDATE SET
    arpu = EXCLUDED.arpu,
    last_updated_at = EXCLUDED.last_updated_at;