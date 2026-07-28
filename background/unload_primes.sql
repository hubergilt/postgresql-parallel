-- ============================================================================
-- Unload all objects created by primes.sql
-- Run this before re-importing primes.sql for a clean slate
-- ============================================================================

DROP PROCEDURE IF EXISTS run_procedures_parallel();
DROP PROCEDURE IF EXISTS procedure1();
DROP PROCEDURE IF EXISTS procedure2();
DROP PROCEDURE IF EXISTS procedure3();
DROP PROCEDURE IF EXISTS procedure4();
DROP PROCEDURE IF EXISTS procedure5();
DROP PROCEDURE IF EXISTS procedure6();
DROP PROCEDURE IF EXISTS procedure7();
DROP PROCEDURE IF EXISTS procedure8();

DROP TABLE IF EXISTS processing_log;

-- Optional: also clear out any orphaned pg_background workers from failed
-- runs (2.0 API). Safe to skip if pg_background_list doesn't exist yet.
-- SELECT pg_background_purge();
