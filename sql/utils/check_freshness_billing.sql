-- check_freshness_billing.sql
DO $$
BEGIN
    IF (
        SELECT COUNT(*)
        FROM src_billing_transactions
        WHERE transaction_date::TIMESTAMP::DATE = '{{ params.run_date }}'::DATE
    ) = 0 THEN
        RAISE EXCEPTION 'No billing data found for run date %', '{{ params.run_date }}';
    END IF;
END $$;