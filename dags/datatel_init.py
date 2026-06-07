from datetime import datetime
from airflow import DAG
from airflow.models import Variable
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator


BQ_PROJECT = Variable.get("BQ_PROJECT")
BQ_DATASET = Variable.get("BQ_DATASET")

with DAG(
    dag_id='datatel_init',
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['datatel', 'init']
) as dag:

    create_quarantine_table = PostgresOperator(
        task_id='create_quarantine_table',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_quarantine_table.sql',
    )

    create_watermark_table = PostgresOperator(
        task_id='create_watermark_table',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_watermark_table.sql',
    )

    seed_watermarks = PostgresOperator(
        task_id='seed_watermarks',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/watermark_initial_insert.sql',
    )

    create_stg_billings = PostgresOperator(
        task_id='create_stg_billings',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_stg_billings.sql',
    )

    create_stg_sessions = PostgresOperator(
        task_id='create_stg_sessions',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_stg_sessions.sql',
    )

    create_stg_customers = PostgresOperator(
        task_id='create_stg_customers',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_stg_customers.sql',
    )

    create_agg_user_revenue = PostgresOperator(
        task_id='create_agg_user_revenue',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_agg_user_revenue.sql',
    )

    create_agg_user_usage = PostgresOperator(
        task_id='create_agg_user_usage',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_agg_user_usage.sql',
    )

    create_agg_monthly_revenue = PostgresOperator(
        task_id='create_agg_monthly_revenue',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_agg_monthly_revenue.sql',
    )

    create_agg_arpu = PostgresOperator(
        task_id='create_agg_arpu',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_agg_arpu.sql',
    )

    create_session_buckets = PostgresOperator(
        task_id='create_session_buckets',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_session_buckets.sql',
    )

    create_agg_session_distribution = PostgresOperator(
        task_id='create_agg_session_distribution',
        postgres_conn_id='postgres_conn_id',
        sql='sql/setup/create_agg_session_distribution.sql',
    )

    create_bq_stg_user_analytics = BigQueryInsertJobOperator(
        task_id='create_bq_stg_user_analytics',
        gcp_conn_id='google_cloud_default',
        configuration={
            'query': {
                'query': '{% include "sql/setup/create_stg_user_analytics.sql" %}',
                'useLegacySql': False,
            }
        },
    )

    create_bq_dw_user_analytics = BigQueryInsertJobOperator(
        task_id='create_bq_dw_user_analytics',
        gcp_conn_id='google_cloud_default',
        configuration={
            'query': {
                'query': '{% include "sql/setup/create_dw_user_analytics.sql" %}',
                'useLegacySql': False,
            }
        },
    )

    create_watermark_table >> seed_watermarks

    [
        create_quarantine_table,
        create_watermark_table,
        create_stg_billings,
        create_stg_sessions,
        create_stg_customers,
        create_agg_user_revenue,
        create_agg_user_usage,
        create_agg_monthly_revenue,
        create_agg_arpu,
        create_session_buckets,
        create_agg_session_distribution,
        create_bq_stg_user_analytics,
        create_bq_dw_user_analytics,
    ]
