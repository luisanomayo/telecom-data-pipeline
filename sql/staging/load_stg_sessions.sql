-- load_stg_sessions.sql

INSERT INTO stg_sessions (
    session_id,
    customer_id,
    start_time,
    end_time,
    data_used_mb,
    session_duration_sec,
    loaded_at
)
SELECT
    session_id,
    customer_id,
    start_time::TIMESTAMP                                AS start_time,
    end_time::TIMESTAMP                                  AS end_time,
    COALESCE(data_used_mb, 0)                            AS data_used_mb,
    CASE
        WHEN end_time IS NOT NULL
         AND start_time IS NOT NULL
         AND end_time::TIMESTAMP > start_time::TIMESTAMP
        THEN EXTRACT(EPOCH FROM (
                end_time::TIMESTAMP - start_time::TIMESTAMP
             ))
        ELSE 0
    END                                                  AS session_duration_sec,
    NOW()                                                AS loaded_at
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY session_id
            ORDER BY start_time::TIMESTAMP DESC
        ) AS row_num
    FROM src_network_sessions
    WHERE session_id  IS NOT NULL
      AND customer_id IS NOT NULL
      AND start_time::TIMESTAMP > (
            SELECT last_processed - INTERVAL '3 days'
            FROM pipeline_watermarks
            WHERE source_table = 'src_network_sessions'
      )
) deduped
WHERE row_num = 1
ON CONFLICT (session_id)
DO UPDATE SET
    customer_id          = EXCLUDED.customer_id,
    start_time           = EXCLUDED.start_time,
    end_time             = EXCLUDED.end_time,
    data_used_mb         = EXCLUDED.data_used_mb,
    session_duration_sec = EXCLUDED.session_duration_sec,
    loaded_at            = EXCLUDED.loaded_at;