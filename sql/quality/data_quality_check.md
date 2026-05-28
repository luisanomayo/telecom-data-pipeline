
Data Quality Check: Completeness
-- Detects NULL values in primary identifier columns across all three source tables.

-- Problem: Records with NULL identifiers cannot be deduplicated, joined, or tracked through the pipeline.

-- Risk: 
1. NULL transaction_ids or session_ids would cause legitimate records to be grouped together or dropped during deduplication. 
2. NULL customer_ids means revenue and usage cannot be attributed to any customer, corrupting every customer-level aggregation downstream.

Data Quality Check: Uniqueness
-- Detects duplicate primary identifiers in source tables.

-- Problem: Source systems generate duplicates through retry logic, network timeouts, and system errors. The same transaction or session can be submitted more than once.

-- Risk: 
1. Duplicate transaction_ids inflate revenue totals.
2. Duplicate session_ids inflate usage metrics. Both corrupt every customer-level aggregation downstream.

Data Quality Check: Referential Integrity
-- Detects customer_ids in billing and sessions that have no matching record in the customers table.

-- Problem: Transactions and sessions belong to customers. If a customer_id exists in billing or sessions but not in the customer register, we cannot attribute that activity to a known customer.

-- Risk: 
1. Revenue and usage for these orphaned records will exist in aggregation tables but will be invisible in the warehouse, since the warehouse drives from stg_customers. This creates silent discrepancies between aggregations and the final analytics table.

Data Quality Check: Validity
-- Detects values that are present but invalid, wrong type, impossible value, or unparseable format.

-- Problem: Invalid values pass completeness checks because they are not NULL, but they will either cause errors during staging casts or silently corrupt aggregations.

-- Risk: 
1. Negative amounts corrupt revenue totals. 
2. Invalid timestamps cause staging load failures. 
3. Negative session durations corrupt usage averages.