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
WHERE customer_id IS NOT NULL
ON CONFLICT (customer_id)
DO UPDATE SET
    name       = EXCLUDED.name,
    email      = EXCLUDED.email,
    country    = EXCLUDED.country,
    created_at = EXCLUDED.created_at,
    row_hash   = EXCLUDED.row_hash,
    loaded_at  = EXCLUDED.loaded_at;