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

- Docker Desktop
- PostgreSQL (local instance)
- GCP project with BigQuery and GCS enabled
- Service account with BigQuery Job User and BigQuery Data Editor roles

## Running Airflow

**Docker is the recommended way to run this project**, especially on macOS. Running Airflow directly on macOS Apple Silicon (M1/M2) causes crashes due to a known incompatibility between grpcio and Python's fork model.

The included `docker-compose.yaml` uses **LocalExecutor** — a lightweight configuration that runs tasks directly in the scheduler process without Redis or Celery workers. This keeps memory usage low enough to run comfortably on an 8GB MacBook Air.

It runs three containers: `postgres` (Airflow metadata), `airflow-webserver`, and `airflow-scheduler`.

**Start Airflow**

```bash
docker compose up -d
```

Then open `http://localhost:8080` (default credentials: `airflow` / `airflow`).

**Stop Airflow**

```bash
docker compose down
```

## Setup

**1. Clone the repo**

```bash
git clone <repo-url>
cd datatel_pipeline
```

**2. Start Airflow (see above)**

**3. Set Airflow variables**

In the UI: Admin → Variables. Add:

```
GCS_BUCKET
BQ_PROJECT
BQ_DATASET
BQ_TABLE
BQ_STAGING
```

**4. Set Airflow connections**

In the UI: Admin → Connections. Add:

| Connection ID | Type | Notes |
|---|---|---|
| `postgres_conn_id` | PostgreSQL | Host: `host.docker.internal`, Port: `5432` |
| `google_cloud_default` | Google Cloud | Keyfile JSON from your GCP service account |

**5. Initialize the schema**

Trigger `datatel_init` manually once from the Airflow UI. This creates all Postgres and BigQuery tables and seeds the watermark table. Run it only once — it uses `CREATE TABLE IF NOT EXISTS` so re-running is safe but unnecessary.

**6. Run the pipeline**

`datatel_pipeline` runs on a daily schedule. Pause it from the DAGs list (toggle next to the DAG name) if you don't want it running automatically.

You can also trigger it manually with a specific date:

```json
{
  "run_date": "2025-01-15",
  "start_date": "2025-01-15",
  "end_date": "2025-01-15"
}
```

The `run_date` must match a date that exists in your source tables (`src_billing_transactions`, `src_network_sessions`). The freshness check at the start of the pipeline will fail if no data is found for that date. To find a valid date range:

```sql
SELECT MIN(transaction_date), MAX(transaction_date) FROM src_billing_transactions;
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
