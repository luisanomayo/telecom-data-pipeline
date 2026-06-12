# DataTel Pipeline — Submission Write-Up

**AltSchool Data Engineering | Karatu 2025 | Third Semester Capstone**

---

## Stage 1 — Data Quality Checks

Four validation queries run against the source tables before any data moves. Bad rows are logged to the quarantine table; the pipeline always continues.

**Note on gating:** The original brief describes quality checks as pipeline gates. This was revised — stopping a pipeline because source data is imperfect means no analytics on the days quality degrades, which is when they matter most. The quarantine table is the investigation trail.

**Check 1 — NULL primary identifiers**
Detects NULL `transaction_id`, `session_id`, or `customer_id` in their respective source tables. Without a primary key, rows cannot be deduplicated or joined, and they inflate aggregation totals with unattributable records.

**Check 2 — Duplicate transaction and session IDs**
Detects `transaction_id` and `session_id` values appearing more than once — caused by retried API calls in the source systems. If both rows load, revenue and usage totals are inflated. Staging handles deduplication; these rows are still quarantined so retries are visible.

**Check 3 — Orphaned customer IDs**
Detects transactions and sessions with a `customer_id` that has no matching row in `src_customers`. Revenue from these rows cannot be assigned to a real customer, corrupting per-customer metrics and making reconciliation impossible.

**Check 4 — Invalid session times**
Detects rows where `end_time` precedes `start_time`, caused by clock sync errors in network equipment. Staging sets duration to zero for these rows; they are quarantined as a signal to the infrastructure team.

---

## Stage 2 — Deduplication in `stg_billing`

Duplicates in `src_billing_transactions` are handled with `ROW_NUMBER()` partitioned by `transaction_id`, ordered by `transaction_date DESC`, keeping only `row_num = 1`.

Two alternatives were rejected:

- `DISTINCT` only removes rows where every column matches. Two rows can share a `transaction_id` but differ on `amount` or `transaction_date`, so `DISTINCT` leaves the duplicate intact.
- `GROUP BY` with `MAX(transaction_date)` identifies the right date but loses the other columns, requiring a self-join to recover them. `ROW_NUMBER()` does it in a single pass.

---

## Stage 3 — Division Risk in `agg_arpu`

ARPU = total revenue ÷ distinct months with at least one transaction. A customer with no transactions produces a zero denominator.

```sql
CASE
    WHEN COUNT(DISTINCT month) = 0 THEN 0
    ELSE SUM(total_revenue) / COUNT(DISTINCT month)
END
```

Zero is returned rather than NULL — NULL forces every downstream consumer to add their own null-handling. Zero is unambiguous: the customer has no revenue history.

---

## Stage 4 — Join Strategy for `dw_user_analytics`

`stg_customers` is the driving table. `agg_user_revenue`, `agg_user_usage`, `agg_arpu`, and `agg_session_distribution` are LEFT JOINed onto it.

Every customer appears in the output regardless of activity. A customer with no sessions or billing still gets a row, with metrics defaulting to zero via `COALESCE`. This matters for churn detection — inactive customers are a key segment.

Transactions or sessions belonging to an orphaned `customer_id` do not appear in the warehouse; there is no customer row to join to. Those records exist in staging and quarantine for investigation.

---

## Stage 5 — Task Dependency Decisions

Tasks run in parallel where independent; they wait only when they consume an upstream output.

**Stage 1 — Quality and quarantine**
`check_freshness_billing` and `check_freshness_sessions` run in parallel at DAG start. All quality checks and `quarantine_insert` run in parallel after both freshness checks complete — freshness runs first because quality checks on an empty source table are meaningless. All Stage 1 tasks must finish before any staging load begins.

**Stage 2 — Staging loads**
`load_stg_billings` and `load_stg_sessions` run in parallel — different sources, different targets. The customer branch runs in parallel with both. A `BranchPythonOperator` triggers either `load_stg_customers_incremental` (Mon–Sat) or `load_stg_customers_full` (Sun); only one path executes.

**Watermark updates**
Each watermark update follows its own staging load. `update_watermark_customers` uses `TriggerRule.NONE_FAILED` so the skipped branch path does not block it.

**Stage 3 — Aggregations**
`load_agg_user_revenue`, `load_agg_user_usage`, `load_agg_monthly_revenue`, and `load_session_buckets` run in parallel after all watermarks update. `load_agg_arpu` waits for `load_agg_monthly_revenue` because it reads from it. `load_agg_session_distribution` waits for `load_session_buckets` for the same reason.

**Stage 4 — BigQuery**
`export_to_gcs` waits for all six aggregation tasks. The remaining steps are sequential: export → load to BQ staging → MERGE into `dw_user_analytics` → truncate PostgreSQL staging. Truncation is last — if any BigQuery step fails, staging is preserved for retry.

---

## Discussion Questions

### Q1 — Incremental boundary and late records

The watermark is the maximum `transaction_date` (or `start_time`) already in staging, stored in `pipeline_watermarks.last_processed`. Each run loads records where the date is greater than `last_processed - 3 days`.

The 3-day lookback covers late arrivals. Staging uses upsert (`ON CONFLICT DO UPDATE`), so re-scanning already-loaded records is safe — they update in place with no duplicates.

Records arriving more than 3 days late are missed. This is a known trade-off — the window covers the vast majority of late arrivals for typical operational systems. If the source is known to delay longer, the window should be extended.

---

### Q2 — Keeping aggregations correct without full rebuilds

Staging is ephemeral — truncated after each successful run and repopulated with only the fresh delta on the next run. When an aggregation task runs, the entire staging table is the delta; no historical data is mixed in.

Aggregations use additive upsert: if the customer already has a row, today's delta is added to the existing total. If the customer is new, a row is inserted with the delta as the starting value. Because each record enters staging exactly once per run, each value is counted in an aggregation exactly once across the pipeline's lifetime.

`agg_arpu` is the exception — it uses replace semantics, recalculating from the current state of `agg_monthly_revenue` each run. ARPU is a ratio, not a sum, and cannot be updated by addition.

---

### Q3 — `stg_customers` has no activity timestamp

`src_customers` has no `updated_at` column, so there is no cheap signal for which rows changed.

The approach is a hybrid: on weekdays, the load filters by `created_at > last_processed`, picking up only new customers. On Sundays, a `BranchPythonOperator` triggers a full scan of all customers. Change detection for existing customers happens at the BigQuery MERGE layer — an MD5 hash of each row's content columns is computed and carried to `dw_user_analytics`. The MERGE only updates a customer when the incoming `row_hash` differs from the stored one.

Weekday runs stay fast; the expensive full scan runs once a week. The correct long-term fix is an `updated_at` column on `src_customers` — without it, no incremental strategy can detect row changes cheaply.

---

### Q4 — BigQuery write pattern

The write is a MERGE on `customer_id`, with an update guard: the update only fires when `target.row_hash != source.row_hash`.

Three cases are handled: new customer → insert, changed customer → update, unchanged customer → no write.

A simple overwrite would replace the entire table with only customers active during the current run. Customers with no activity that day would be deleted, causing analysts to see customers disappearing and reappearing. Historical `last_updated_at` values would be lost on every run. The MERGE ensures every customer persists and metrics update only when new data is available.

---

### Q5 — Billing data arrives six hours late

The pipeline runs on schedule. The watermark-based load finds no new billing records for the run date, loads nothing, and exits cleanly. No error is raised — from the pipeline's perspective, there was nothing new.

When data arrives six hours later, the next scheduled run catches it. The 3-day window covers it; the upsert loads without duplicates.

The gap is that the business sees stale metrics with no indication why. The freshness check addresses this — it runs before staging and asserts the source contains records for the expected run date. If not, it raises an exception and triggers `on_failure_callback`, alerting the team before the business notices.

The watermark and late arrival window handle how the pipeline processes late data. The freshness check handles how the team detects it.

---

### Q6 — Customer in billing but not in customers

**Stage 1:** The referential integrity check in `quarantine_insert.sql` detects the orphaned `customer_id` and writes the billing row as JSON to `quarantine_records` with `check_type = 'orphaned_customer_id'`. Pipeline continues.

**Stage 2:** `load_stg_billings.sql` loads the transaction. The staging load excludes NULL `customer_id` rows, but a non-NULL orphaned ID passes through.

**Stage 3:** Aggregation loads use `INNER JOIN stg_customers`. The orphaned ID has no row there, so the join excludes it. The transaction's revenue is not counted.

**Stage 4:** `dw_user_analytics` is built from `stg_customers` as the driving table. No anchor row exists for the orphaned ID, so it does not appear in the warehouse.

The transaction is not lost — it exists in `stg_billings` and quarantine. The warehouse correctly excludes data whose customer identity cannot be verified.

---

### Q7 — Churn flag incorrectly flags new customers

`dw_user_analytics` already contains `customer_since` from `stg_customers`. The fix is a query-level change:

```sql
WHERE total_sessions  < 5
  AND total_revenue   < 1000
  AND customer_since <= CURRENT_DATE - INTERVAL '30 days'
```

This excludes customers registered in the last 30 days. The pipeline does not change — `customer_since` was always captured correctly. The 30-day threshold is a business decision and should be confirmed with stakeholders.
