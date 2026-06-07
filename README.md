# Datatel Pipeline

An Apache Airflow data pipeline for a fictional telecom company (Datatel). Ingests raw transactional data from PostgreSQL, applies data quality checks, transforms into analytics aggregates, and loads to BigQuery via GCS.

## Architecture

```
PostgreSQL (source) → Staging tables → Aggregates → GCS → BigQuery
```

**Source tables:** `src_customers`, `src_billing_transactions`, `src_network_sessions`

**Destinations:**
- PostgreSQL aggregates (intermediate)
- BigQuery `dw_user_analytics` (final warehouse table)

## DAGs

| DAG | Trigger | Purpose |
|---|---|---|
| `datatel_init` | Manual (once) | Creates all tables and seeds watermarks |
| `datatel_pipeline` | Daily | Runs the full pipeline |

## Pipeline Stages

1. **Freshness checks** — validates billing and session data is current
2. **Data quality** — completeness, uniqueness, referential integrity, validity checks
3. **Quarantine** — bad rows are written to a quarantine table; pipeline continues
4. **Staging** — loads billings and sessions incrementally; customers load incrementally on weekdays, full refresh on Sundays
5. **Watermarks** — updated after each successful staging load
6. **Aggregates** — user revenue, user usage, monthly revenue, session buckets, ARPU, session distribution
7. **Export → BQ** — Postgres → GCS (CSV) → BigQuery staging → MERGE into warehouse table
8. **Truncate staging** — staging tables cleared on successful completion

## Prerequisites

- Python 3.12
- Apache Airflow 2.10.4
- PostgreSQL
- GCP project with BigQuery and GCS enabled

## Setup

**1. Clone and install dependencies**

```bash
git clone <repo-url>
cd datatel_pipeline
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**2. Configure environment**

```bash
cp config/.env.example .env
# Fill in your values
```

**3. Set Airflow variables**

```
GCS_BUCKET
BQ_PROJECT
BQ_DATASET
BQ_TABLE
BQ_STAGING
```

**4. Set Airflow connections**

| Connection ID | Type |
|---|---|
| `postgres_conn_id` | PostgreSQL |
| `google_cloud_default` | Google Cloud |

**5. Initialize the schema**

Trigger `datatel_init` manually once from the Airflow UI. This creates all tables and seeds the watermark table.

**6. Run the pipeline**

`datatel_pipeline` runs on a daily schedule. You can also trigger it manually with optional params:

```json
{
  "run_date": "2025-01-15",
  "start_date": "2025-01-15",
  "end_date": "2025-01-15"
}
```

## Project Structure

```
dags/
  datatel_init.py       # One-time schema setup DAG
  datatel_pipeline.py   # Main pipeline DAG
sql/
  setup/                # CREATE TABLE statements
  staging/              # Load staging tables
  transforms/           # Build aggregates
  quality/              # Data quality checks and quarantine
  utils/                # Watermark updates, freshness checks, truncate
  warehouse/            # Postgres → GCS and BQ merge
data/
  src_*.csv             # Sample source data
config/
  .env.example
```

## Data Quality

Bad rows are routed to a `quarantine` table with an error reason and timestamp. The pipeline does not halt on quality failures — problematic rows are isolated and processing continues.
