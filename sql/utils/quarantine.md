--quarantine table creation and logic
Utility Table: quarantine_records
-- Stores bad rows detected during quality checks.
--
-- Idempotency: record_hash is computed from the source, check_type, and record content only -- not the run date. This means the same bad row is quarantined exactly once, ever, regardless of how many pipeline runs detect it. The detected_at timestamp captures when it was first found.


Quarantine Insert
-- For each data quality problem, if failing rows exist, insert the full record as JSON into quarantine_records. If no failing rows exist, the block exits silently. If a bad row was already quarantined on a previous run, it is skipped, no duplicates ever created.

-- Idempotency note: record_hash excludes run_date intentionally. The same bad row produces the same hash on every run. 
ON CONFLICT DO NOTHING ensures it is quarantined exactly once, ever. detected_at captures when it was first found.