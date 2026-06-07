CREATE TABLE IF NOT EXISTS `altschool-projects-495218.datatel.dw_user_analytics` (
    customer_id              INT64,
    customer_name            STRING,
    email                    STRING,
    country                  STRING,
    customer_since           DATE,
    total_revenue            FLOAT64,
    total_transactions       INT64,
    total_data_used_mb       FLOAT64,
    total_sessions           INT64,
    avg_session_duration_sec FLOAT64,
    arpu                     FLOAT64,
    short_sessions           INT64,
    medium_sessions          INT64,
    long_sessions            INT64,
    avg_data_per_session_mb  FLOAT64,
    row_hash                 STRING,
    last_updated_at          TIMESTAMP
);
