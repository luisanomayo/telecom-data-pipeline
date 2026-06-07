from datetime import datetime, timedelta
from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import BranchPythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.google.cloud.transfers.postgres_to_gcs import PostgresToGCSOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.models.param import Param


GCS_BUCKET = Variable.get("GCS_BUCKET")
BQ_PROJECT = Variable.get("BQ_PROJECT")
BQ_DATASET = Variable.get("BQ_DATASET")
BQ_TABLE = Variable.get("BQ_TABLE")
BQ_STAGING = Variable.get("BQ_STAGING")

default_args = {
    'owner': 'airflow',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': False
}


def branch_customer_load(**context):
    run_date = context['params']['run_date']
    weekday = datetime.strptime(run_date, '%Y-%m-%d').weekday()

    if weekday == 6:
        return 'load_stg_customers_full'
    return 'load_stg_customers_incremental'


with DAG(
    dag_id='datatel_pipeline',
    default_args=default_args,
    schedule_interval='@daily',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    params={
        'run_date': Param(default='{{ds}}', type='string'),
        'start_date': Param(default='{{ds}}', type='string'),
        'end_date': Param(default='{{ds}}', type='string')
    },
    tags=['datatel', 'pipeline']
) as dag:

    check_freshness_billings = PostgresOperator(
        task_id='check_freshness_billing',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/check_freshness_billing.sql',
        parameters={'run_date': '{{params.run_date}}'},
    )

    check_freshness_sessions = PostgresOperator(
        task_id='check_freshness_sessions',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/check_freshness_sessions.sql',
        parameters={'run_date': '{{params.run_date}}'},
    )

    check_completeness = PostgresOperator(
        task_id='check_completeness',
        postgres_conn_id='postgres_conn_id',
        sql='sql/quality/completeness.sql',
    )

    check_uniqueness = PostgresOperator(
        task_id='check_uniqueness',
        postgres_conn_id='postgres_conn_id',
        sql='sql/quality/uniqueness_check.sql'
    )

    check_referential_integrity = PostgresOperator(
        task_id='check_referential_integrity',
        postgres_conn_id='postgres_conn_id',
        sql='sql/quality/referential_integrity_check.sql',
    )

    check_validity = PostgresOperator(
        task_id='check_validity',
        postgres_conn_id='postgres_conn_id',
        sql='sql/quality/validity_check.sql',
    )

    quarantine_insert = PostgresOperator(
        task_id='quarantine_insert',
        postgres_conn_id='postgres_conn_id',
        sql='sql/quality/quarantine_insert.sql',
    )

    load_stg_billings = PostgresOperator(
        task_id='load_stg_billings',
        postgres_conn_id='postgres_conn_id',
        sql='sql/staging/load_stg_billings.sql',
        parameters={'run_date': '{{params.run_date}}'},
    )

    load_stg_sessions = PostgresOperator(
        task_id='load_stg_sessions',
        postgres_conn_id='postgres_conn_id',
        sql='sql/staging/load_stg_sessions.sql',
        parameters={'run_date': '{{params.run_date}}'},
    )

    branch_customers = BranchPythonOperator(
        task_id='branch_customers',
        python_callable=branch_customer_load,
        provide_context=True,
    )

    load_stg_customers_incremental = PostgresOperator(
        task_id='load_stg_customers_incremental',
        postgres_conn_id='postgres_conn_id',
        sql='sql/staging/load_stg_customers_incremental.sql',
        parameters={'run_date': '{{params.run_date}}'},
    )

    load_stg_customers_full = PostgresOperator(
        task_id='load_stg_customers_full',
        postgres_conn_id='postgres_conn_id',
        sql='sql/staging/load_stg_customers_full.sql',
    )

    update_watermark_billing = PostgresOperator(
        task_id='update_watermark_billing',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/update_watermark_billings.sql',
    )

    update_watermark_sessions = PostgresOperator(
        task_id='update_watermark_sessions',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/update_watermark_sessions.sql',
    )

    update_watermark_customers = PostgresOperator(
        task_id='update_watermark_customers',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/update_watermark_customers.sql',
        trigger_rule=TriggerRule.NONE_FAILED,
    )

    load_agg_user_revenue = PostgresOperator(
        task_id='load_agg_user_revenue',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_agg_user_revenue.sql',
    )

    load_agg_user_usage = PostgresOperator(
        task_id='load_agg_user_usage',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_agg_user_usage.sql',
    )

    load_agg_monthly_revenue = PostgresOperator(
        task_id='load_agg_monthly_revenue',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_agg_monthly_revenue.sql',
    )

    load_session_buckets = PostgresOperator(
        task_id='load_session_buckets',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_session_buckets.sql',
    )

    load_agg_arpu = PostgresOperator(
        task_id='load_agg_arpu',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_agg_arpu.sql',
    )

    load_agg_session_distribution = PostgresOperator(
        task_id='load_agg_session_distribution',
        postgres_conn_id='postgres_conn_id',
        sql='sql/transforms/load_agg_session_distribution.sql',
    )

    export_to_gcs = PostgresToGCSOperator(
        task_id='export_to_gcs',
        postgres_conn_id='postgres_conn_id',
        gcp_conn_id='google_cloud_default',
        sql='sql/warehouse/postgres_to_gcs.sql',
        bucket=GCS_BUCKET,
        filename='exports/dw_user_analytics_{{ds}}.csv',
        export_format='csv',
        gzip=False,
    )

    load_to_bq_staging = GCSToBigQueryOperator(
        task_id='load_to_bq_staging',
        gcp_conn_id='google_cloud_default',
        bucket=GCS_BUCKET,
        source_objects=['exports/dw_user_analytics_{{ds}}.csv'],
        destination_project_dataset_table=f'{BQ_PROJECT}:{BQ_DATASET}.{BQ_STAGING}',
        source_format='CSV',
        skip_leading_rows=1,
        write_disposition='WRITE_TRUNCATE',
    )

    merge_dw_user_analytics = BigQueryInsertJobOperator(
        task_id='merge_dw_user_analytics',
        gcp_conn_id='google_cloud_default',
        configuration={
            'query': {
                'query': '{% include "sql/warehouse/merge_dw_user_analytics.sql" %}',
                'useLegacySql': False,
                'queryParameters': [
                    {'name': 'bq_project', 'parameterType': {'type': 'STRING'}, 'parameterValue': {'value': BQ_PROJECT}},
                    {'name': 'bq_dataset', 'parameterType': {'type': 'STRING'}, 'parameterValue': {'value': BQ_DATASET}},
                    {'name': 'bq_table',   'parameterType': {'type': 'STRING'}, 'parameterValue': {'value': BQ_TABLE}},
                    {'name': 'bq_staging', 'parameterType': {'type': 'STRING'}, 'parameterValue': {'value': BQ_STAGING}},
                ]
            }
        },
    )

    truncate_staging = PostgresOperator(
        task_id='truncate_staging',
        postgres_conn_id='postgres_conn_id',
        sql='sql/utils/truncate_staging.sql',
    )

    [check_freshness_billings, check_freshness_sessions] >> check_completeness
    [check_freshness_billings, check_freshness_sessions] >> check_uniqueness
    [check_freshness_billings, check_freshness_sessions] >> check_referential_integrity
    [check_freshness_billings, check_freshness_sessions] >> check_validity
    [check_freshness_billings, check_freshness_sessions] >> quarantine_insert

    [check_completeness, check_uniqueness,
     check_referential_integrity, check_validity, quarantine_insert] >> load_stg_billings

    [check_completeness, check_uniqueness,
     check_referential_integrity, check_validity, quarantine_insert] >> load_stg_sessions

    [check_completeness, check_uniqueness,
     check_referential_integrity, check_validity, quarantine_insert] >> branch_customers

    branch_customers >> [load_stg_customers_incremental, load_stg_customers_full]

    load_stg_billings >> update_watermark_billing
    load_stg_sessions >> update_watermark_sessions
    [load_stg_customers_incremental, load_stg_customers_full] >> update_watermark_customers

    [update_watermark_billing, update_watermark_sessions,
     update_watermark_customers] >> load_agg_user_revenue

    [update_watermark_billing, update_watermark_sessions,
     update_watermark_customers] >> load_agg_user_usage

    [update_watermark_billing, update_watermark_sessions,
     update_watermark_customers] >> load_agg_monthly_revenue

    [update_watermark_billing, update_watermark_sessions,
     update_watermark_customers] >> load_session_buckets

    load_agg_monthly_revenue >> load_agg_arpu
    load_session_buckets >> load_agg_session_distribution

    [load_agg_user_revenue, load_agg_user_usage,
     load_agg_arpu, load_agg_session_distribution] >> export_to_gcs

    export_to_gcs >> load_to_bq_staging >> merge_dw_user_analytics >> truncate_staging
