-- check_freshness_sessions.sql
DO $$
BEGIN
    IF (
        SELECT COUNT(*)
        FROM src_network_sessions
        WHERE transaction_date::TIMESTAMP::DATE = '{{ params.run_date }}'::DATE
    ) = 0 THEN
        RAISE EXCEPTION 'No network sessions data found for run date %', '{{ params.run_date }}';
    END IF;
END $$;