# DataTel Pipeline — Submission Write-Up

**AltSchool Data Engineering | Karatu 2025 | Third Semester Capstone**

---

## Stage 1 — Data Quality Checks

Four validation queries run against the source tables before any data is moved. They do not modify data — they surface problems so that bad rows can be logged to the quarantine table while the pipeline continues.

**Note on gating:** The original brief describes quality checks as pipeline gates that block downstream loads on failure. This requirement was revised during the project — the pipeline always continues regardless of what the checks find. Stopping a pipeline because source data is imperfect means the business has no analytics on the days data quality degrades, which is exactly when they need it most. The quarantine table is the paper trail; the team investigates there rather than through pipeline failure logs.

**Check 1 — NULL primary identifiers**
Detects rows in `src_billing_transactions`, `src_network_sessions`, and `src_customers` where the primary key column is NULL. A transaction with no `transaction_id` cannot be deduplicated — if two rows both have a NULL ID, there is no way to know whether they represent the same event or two separate ones. A session with no `session_id` has the same problem. A customer with no `customer_id` cannot be joined to any other table. If these rows are loaded without detection, they create ghost records in aggregation tables that inflate totals and cannot be attributed to any real customer or event.

**Check 2 — Duplicate transaction and session IDs**
Detects `transaction_id` values in `src_billing_transactions` that appear more than once, and `session_id` values in `src_network_sessions` that appear more than once. Duplicates are caused by retry events in the source systems — a failed API call that gets retried produces two rows with the same ID. If both rows are loaded into staging and counted in aggregations, revenue totals and usage metrics are inflated. The staging layer handles deduplication, but these rows are still logged to the quarantine table so the team knows retries are occurring.

**Check 3 — Orphaned customer IDs**
Detects rows in `src_billing_transactions` and `src_network_sessions` where `customer_id` is not NULL but has no matching row in `src_customers`. This means the transaction or session is attributed to a customer that does not exist in the master register. Revenue from these rows cannot be assigned to a real customer profile. If they flow into aggregations unchecked, a single NULL or phantom customer bucket accumulates unattributable revenue, corrupting per-customer metrics and making reconciliation against the source system impossible.

**Check 4 — Invalid session times**
Detects rows in `src_network_sessions` where `end_time` precedes `start_time`. This is caused by clock synchronisation errors in the network equipment. If these rows are loaded with a negative duration calculated from the timestamps, every downstream average of `session_duration_sec` is corrupted. The staging layer sets duration to zero for these rows, but they are still quarantined as a signal to the infrastructure team that clock drift is occurring.

---

## Stage 2 — Deduplication Approach for `stg_billing`

`src_billing_transactions` contains duplicate `transaction_id` values caused by retry events. The instruction is to keep the most recent record where duplicates exist.

The approach used is `ROW_NUMBER()` partitioned by `transaction_id` and ordered by `transaction_date DESC`, keeping only the row where `row_num = 1`.

Two alternatives were considered and rejected.

`DISTINCT` removes exact duplicates only — every column in the row must match. In this dataset two rows can share a `transaction_id` but differ on `amount` or `transaction_date`, which means they are not exact duplicates. `DISTINCT` would keep both, and the duplicate problem remains unsolved.

`GROUP BY transaction_id` with `MAX(transaction_date)` identifies which date to keep but loses the rest of the columns. To recover `amount` and `customer_id` for that row requires a self-join back to the source table, which adds complexity and a second scan. The `ROW_NUMBER()` approach does it in a single pass and keeps the full row without any additional joins.

---

## Stage 3 — Division Risk in `agg_arpu`

ARPU is defined as total revenue divided by the number of distinct calendar months in which the customer had at least one transaction.

The division risk is a customer with no transactions — their month count is zero, and dividing by zero raises a runtime error.

This is handled with a CASE expression:

```sql
CASE
    WHEN COUNT(DISTINCT month) = 0 THEN 0
    ELSE SUM(total_revenue) / COUNT(DISTINCT month)
END
```

Zero is returned rather than NULL because the warehouse requires all metrics to have a default numeric value. A NULL ARPU forces every downstream analyst to write their own NULL-handling logic before they can use the column. A zero is unambiguous — it means the customer has no revenue history — and requires no defensive coding from the consumer side.

---

## Stage 4 — Join Strategy for `dw_user_analytics`

`stg_customers` is the driving table. All other tables — `agg_user_revenue`, `agg_user_usage`, `agg_arpu`, `agg_session_distribution` — are LEFT JOINed onto it.

This ensures every customer appears in the output regardless of whether they have billing or session activity. A customer who registered but never used the service still gets a row, with all metrics defaulting to zero via `COALESCE`. This matters for churn detection — a customer with no activity is one of the most important segments to surface, not a row to drop.

The inverse is also true: transactions or sessions belonging to a `customer_id` that has no row in `stg_customers` do not appear in the warehouse. Their data exists in the aggregation tables but has no customer anchor to join to. This is acceptable — those records are orphaned and their `customer_id` values are logged in the quarantine table. The warehouse correctly excludes data whose identity cannot be verified.

All metric columns use `COALESCE(..., 0)` so that no analyst ever receives a NULL from this table for a numeric field.

---

## Stage 5 — Task Dependency Decisions

The dependency graph is designed so that tasks run in parallel wherever they are independent, and wait only when they genuinely consume an upstream output.

**Stage 1 — Quality and quarantine tasks**
The two freshness checks (`check_freshness_billing`, `check_freshness_sessions`) run in parallel at DAG start — they are independent reads on separate source tables. All quality check tasks and the `quarantine_insert` task run in parallel after both freshness checks complete. They are grouped after freshness checks because a source table with no data for the run date makes quality checks meaningless. All Stage 1 tasks must complete before any staging load begins, since staging depends on knowing what is in the source.

**Stage 2 — Staging loads**
`load_stg_billings` and `load_stg_sessions` run in parallel — they read from different source tables and write to different staging tables. The customer branch runs in parallel with both. The `BranchPythonOperator` checks the day of the week and triggers either `load_stg_customers_incremental` (Monday–Saturday) or `load_stg_customers_full` (Sunday). Only one path executes; the other is skipped.

**Watermark updates**
Each watermark update runs immediately after its own staging load — `update_watermark_billing` after `load_stg_billings`, `update_watermark_sessions` after `load_stg_sessions`. `update_watermark_customers` runs after whichever customer load path executed, using `TriggerRule.NONE_FAILED` so that the skipped branch path does not block it.

**Stage 3 — Aggregations**
All four first-level aggregation tasks (`load_agg_user_revenue`, `load_agg_user_usage`, `load_agg_monthly_revenue`, `load_session_buckets`) run in parallel after all three watermarks are updated. They each read from different staging tables and write to different aggregation tables. `load_agg_arpu` waits for `load_agg_monthly_revenue` because it reads from that table directly. `load_agg_session_distribution` waits for `load_session_buckets` for the same reason.

**Stage 4 — BigQuery**
`export_to_gcs` waits for all six aggregation tasks. The three BigQuery steps are sequential: export → load to BQ staging → MERGE into `dw_user_analytics` → truncate PostgreSQL staging. The truncation is last deliberately — if any BigQuery step fails, the staging tables are preserved so the run can be retried without data loss.

---

## Discussion Questions

### Q1 — Incremental boundary and late records

The boundary is a watermark — the maximum `transaction_date` (or `start_time` for sessions) already present in the staging table, stored in the `pipeline_watermarks` table under `last_processed`. On each run, the staging load pulls records from the source where the date is greater than `last_processed - 3 days`.

The three-day lookback is the late arrival tolerance. A record that arrives two days late in the source system will be caught on the next run because the load window always extends three days back from the watermark. Because staging uses upsert (`ON CONFLICT DO UPDATE`), re-scanning already-loaded records is safe — they update in place and no duplicates are created.

A record arriving more than three days late would be missed by this window. That is a known limitation and a business decision — the three-day window covers the vast majority of late arrivals for most operational systems. If the source is known to delay longer, the window should be extended.

---

### Q2 — Keeping aggregations correct without full rebuilds

Staging tables are ephemeral. They are truncated at the end of each successful run and repopulated with only the fresh delta on the next run. This means when an aggregation task runs, the entire staging table is the delta — there is no historical data mixed in.

Aggregations use an additive upsert pattern: if the customer already has a row in the aggregation table, today's delta is added to the existing total. If the customer is new, a new row is inserted with the delta as the starting value. Because each record enters staging exactly once per run (upsert prevents duplicates), and staging is cleared between runs, each record's value is counted in an aggregation exactly once across the pipeline's lifetime.

`agg_arpu` is the exception — it uses replace semantics rather than additive, recalculating from the current state of `agg_monthly_revenue` each run. This is correct because ARPU is a ratio, not a sum, and cannot be updated incrementally by addition.

---

### Q3 — `stg_customers` has no activity timestamp

`src_customers` has no `updated_at` column, so there is no cheap signal indicating which rows changed since the last run.

A daily full scan of all customers would solve the problem but does not scale — reading and hashing every customer row every day is expensive when the table is large.

The approach used is a hybrid: on weekdays, the load filters by `created_at > last_processed`, picking up only new customers registered since the last run. On Sundays, a `BranchPythonOperator` triggers a full scan that loads all customers regardless of `created_at`. Change detection for existing customers happens at the BigQuery MERGE layer — the pipeline computes an MD5 hash of each customer row's content columns and carries it forward to `dw_user_analytics`. The MERGE only updates a matched customer when the incoming `row_hash` differs from the stored one, meaning no write happens if nothing changed.

This keeps weekday runs fast and reserves the expensive full scan for once a week. The correct long-term fix is to request an `updated_at` column from the team that owns `src_customers` — without it, no incremental strategy can detect changes cheaply on a daily basis.

---

### Q4 — BigQuery write pattern

The write pattern is MERGE (upsert) on `customer_id`, with an additional condition that the update only fires when `target.row_hash != source.row_hash`.

This handles three cases: a new customer gets inserted, an existing customer whose data changed gets updated, and an existing customer whose data has not changed is left untouched — no write occurs at all.

A simple overwrite would replace the entire table with only the customers present in the current run's export. Customers with no activity on a given day would be deleted from the warehouse. Analysts would see customers disappearing and reappearing based on whether they had transactions that day. Historical `last_updated_at` values would be lost on every run. Any downstream report referencing a specific `customer_id` would break intermittently. The MERGE pattern ensures every customer that has ever existed in the warehouse continues to exist, and their metrics are only updated when new data is available.

---

### Q5 — Billing data arrives six hours late

The pipeline runs at its scheduled time. The watermark-based load scans the source from `last_processed - 3 days` and finds no new billing records for the run date. Nothing is loaded, no data is corrupted, and the pipeline exits cleanly. No error is raised by the pipeline itself — from its perspective, there was simply nothing new.

When the billing data arrives six hours later, the next scheduled run catches it automatically. The 3-day late arrival window means the records are within the scan range, and the upsert pattern loads them without duplicates.

The problem is that between the scheduled run and when the data arrives, the business is looking at stale metrics and has no way to know why. The fix is the freshness check — a task that runs before the staging load and asserts the source table contains records for the expected run date. If it finds nothing, it raises an exception and triggers the `on_failure_callback`, which in production would send an alert via Slack, email, or PagerDuty. The team is notified before the business notices the stale dashboards.

To be precise: the watermark and late arrival window are the answer to how the pipeline handles late data. The freshness check is the answer to how the team detects and is alerted to it.

---

### Q6 — Customer in billing but not in customers

**Stage 1:** The referential integrity check in `quarantine_insert.sql` detects the orphaned `customer_id` — it finds a `customer_id` in `src_billing_transactions` with no matching row in `src_customers` and writes the entire billing row as JSON to `quarantine_records` with `check_type = 'orphaned_customer_id'`. The pipeline continues.

**Stage 2:** `load_stg_billings.sql` loads the transaction into `stg_billings`. The staging load does not enforce referential integrity — it excludes NULL `customer_id` rows, but a non-NULL orphaned ID passes through.

**Stage 3:** The aggregation loads use `INNER JOIN stg_customers` when computing `agg_user_revenue`, `agg_user_usage`, and `agg_monthly_revenue`. The orphaned `customer_id` has no row in `stg_customers`, so the join excludes it. The transaction's revenue is not counted in any aggregation.

**Stage 4:** `dw_user_analytics` is built from `stg_customers` as the driving table. The orphaned `customer_id` has no anchor row there, so it does not appear in the warehouse.

The outcome is acceptable. The transaction is not lost — it exists in `stg_billings` and in the quarantine table with enough context for investigation. The warehouse correctly excludes data whose customer identity cannot be verified. Any analyst investigating revenue discrepancies should check the quarantine table for orphaned records, which is where the pipeline has deliberately directed them.

---

### Q7 — Churn flag incorrectly flags new customers

The data needed to fix this is already in the pipeline. `dw_user_analytics` contains `customer_since`, derived from `created_at` in `stg_customers`. The current churn rule has no awareness of how long a customer has been registered.

The fix is a query-level change — add a minimum observation window to the churn condition:

```sql
WHERE total_sessions  < 5
  AND total_revenue   < 1000
  AND customer_since <= CURRENT_DATE - INTERVAL '30 days'
```

This excludes customers registered in the last 30 days. A customer registered yesterday has not had enough time to accumulate sessions and revenue, so flagging them as churned is a false positive by definition.

The pipeline itself does not need to change. The `customer_since` column was always being captured and loaded correctly — the churn rule simply needed a more precise definition of what "at risk" means. The 30-day threshold is a business decision, not a technical one, and should be agreed with stakeholders.
