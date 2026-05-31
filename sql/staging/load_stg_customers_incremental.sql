INSERT INTO stg_customers (
    customer_id,
    name,
    email,
    country,
    created_at,
    row_hash,
    loaded_at
)
SELECT
    customer_id,
    INITCAP(name)                                     AS name,
    LOWER(email)                                      AS email,
    COALESCE(country, 'Nigeria')                      AS country,
    created_at::TIMESTAMP                             AS created_at,
    MD5(
        COALESCE(customer_id::TEXT, '') ||
        COALESCE(name,              '') ||
        COALESCE(email,             '') ||
        COALESCE(country,           '') ||
        COALESCE(created_at,        '')
    )                                                 AS row_hash,
    NOW()                                             AS loaded_at
FROM src_customers
WHERE customer_id  IS NOT NULL
  AND created_at::TIMESTAMP > (
        SELECT last_processed
        FROM pipeline_watermarks
        WHERE source_table = 'src_customers'
  )
ON CONFLICT (customer_id)
DO NOTHING;