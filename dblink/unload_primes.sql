-- ============================================================================
-- UNLOAD_PRIMES.SQL
-- Reverses everything created by primes.sql (dblink version).
-- Run this before re-running primes.sql if you want a clean slate without
-- dropping/recreating the whole database.
-- ============================================================================

-- Drop procedures (drop the orchestrator first, then the workers)
DROP PROCEDURE IF EXISTS run_procedures_parallel();
DROP PROCEDURE IF EXISTS procedure1();
DROP PROCEDURE IF EXISTS procedure2();
DROP PROCEDURE IF EXISTS procedure3();
DROP PROCEDURE IF EXISTS procedure4();
DROP PROCEDURE IF EXISTS procedure5();
DROP PROCEDURE IF EXISTS procedure6();
DROP PROCEDURE IF EXISTS procedure7();
DROP PROCEDURE IF EXISTS procedure8();

-- Drop the logging table (CASCADE clears its sequence + any dependent objects too)
DROP TABLE IF EXISTS processing_log CASCADE;

-- Revoke the FDW usage grant given to huber
REVOKE USAGE ON FOREIGN DATA WRAPPER dblink_fdw FROM huber;

-- Optional: drop the dblink extension itself.
-- Commented out by default since other scripts/sessions on this database
-- may still depend on it. Uncomment only if you're sure nothing else needs it.
-- DROP EXTENSION IF EXISTS dblink;

-- Confirm cleanup
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CLEANUP COMPLETE';
    RAISE NOTICE 'All procedures and processing_log table dropped.';
    RAISE NOTICE 'dblink extension left in place (uncomment DROP EXTENSION line to remove).';
    RAISE NOTICE '========================================';
END $$;
