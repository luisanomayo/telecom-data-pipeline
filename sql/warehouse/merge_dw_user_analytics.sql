MERGE  `{{params.bq_project}}.{{params.bq_dataset}}.{{params.bq_table}}` AS target
USING `{}` AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN
  UPDATE SET
    customer_name = source.customer_name,
    email = source.email,
    country = source.country,
    customer_since = source.customer_since,
    total_revenue = source.total_revenue,
    total_transactions = source.total_transactions,
    total_data_used_mb = source.total_data_used_mb,
    total_sessions = source.total_sessions,
    avg_session_duration_sec = source.avg_session_duration_sec,
    arpu = source.arpu,
    short_sessions = source.short_sessions,
    medium_sessions = source.medium_sessions,
    long_sessions = source.long_sessions,
    avg_data_per_session_mb = source.avg_data_per_session_mb,
    last_updated_at = source.last_updated_at
WHEN NOT MATCHED THEN
  INSERT (
    customer_id,customer_name,email,country,
    customer_since,total_revenue,total_transactions,
    total_data_used_mb,total_sessions,
    avg_session_duration_sec,arpu,
    short_sessions,medium_sessions,long_sessions,
    avg_data_per_session_mb,last_updated_at
  )
    VALUES (
        source.customer_id,source.customer_name,source.email,source.country,
        source.customer_since,source.total_revenue,source.total_transactions,
        source.total_data_used_mb,source.total_sessions,
        source.avg_session_duration_sec,source.arpu,
        source.short_sessions,source.medium_sessions,source.long_sessions,
        source.avg_data_per_session_mb,source.last_updated_at
    );