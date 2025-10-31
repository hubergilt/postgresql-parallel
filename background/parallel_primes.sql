-- ============================================================================
-- Complete Script: PostgreSQL Parallel Stored Procedures with pg_background
-- ============================================================================
-- This script creates everything from database to execution
-- Run this as a PostgreSQL superuser (e.g., postgres user)
-- ============================================================================

-- ============================================================================
-- PART 1: DATABASE AND USER SETUP
-- ============================================================================

-- Drop existing database if it exists (CAUTION: This deletes all data!)
DROP DATABASE IF EXISTS parallel_demo;

-- Create the database
CREATE DATABASE parallel_demo
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create a user for the database (optional, or use existing user)
-- If you already have a user, skip these lines
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'huber') THEN
        CREATE USER huber WITH PASSWORD 'huber';
    END IF;
END
$$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE parallel_demo TO huber;

-- Connect to the new database
\c parallel_demo

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO huber;

-- ============================================================================
-- PART 2: EXTENSION SETUP
-- ============================================================================

-- Enable pg_background extension (required for parallel execution)
-- NOTE: This extension must be installed on your PostgreSQL server first
-- Installation: https://github.com/vibhorkum/pg_background
CREATE EXTENSION IF NOT EXISTS pg_background;

-- ============================================================================
-- PART 3: CREATE SAMPLE DATA TABLES (OPTIONAL)
-- ============================================================================

-- Create a sample table for demonstration purposes
CREATE TABLE IF NOT EXISTS processing_log (
    id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    duration INTERVAL,
    status VARCHAR(50),
    message TEXT
);

-- Grant privileges on the table
GRANT ALL PRIVILEGES ON TABLE processing_log TO huber;
GRANT USAGE, SELECT ON SEQUENCE processing_log_id_seq TO huber;

-- ============================================================================
-- PART 4: CREATE EXAMPLE STORED PROCEDURES
-- ============================================================================

-- Procedure 1: Compute sum of first 100 000 prime numbers
CREATE OR REPLACE PROCEDURE procedure1()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_count INTEGER := 0;
    v_num INTEGER := 2;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor INTEGER;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 1 starting at %', v_start_time;
    RAISE NOTICE 'Computing sum of first 100 prime numbers...';
    
    -- Find first 100 000 prime numbers and sum them
    WHILE v_count < 100000 LOOP
        v_is_prime := TRUE;
        
        -- Check if v_num is prime
        IF v_num > 2 THEN
            FOR v_divisor IN 2..floor(sqrt(v_num))::INTEGER LOOP
                IF v_num % v_divisor = 0 THEN
                    v_is_prime := FALSE;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        
        -- If prime, add to sum
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_count := v_count + 1;
        END IF;
        
        v_num := v_num + 1;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    RAISE NOTICE 'Sum of first 100000 prime numbers: %', v_sum;
    
    -- Log the result
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure1', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Sum of first 100000 primes: ' || v_sum);
    
    RAISE NOTICE 'Procedure 1 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 2: Process dataset B
CREATE OR REPLACE PROCEDURE procedure2()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 2 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure2', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset B');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 2 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 3: Process dataset C
CREATE OR REPLACE PROCEDURE procedure3()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 3 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure3', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset C');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 3 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 4: Process dataset D
CREATE OR REPLACE PROCEDURE procedure4()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 4 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure4', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset D');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 4 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 5: Process dataset E
CREATE OR REPLACE PROCEDURE procedure5()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 5 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure5', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset E');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 5 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 6: Process dataset F
CREATE OR REPLACE PROCEDURE procedure6()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 6 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure6', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset F');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 6 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 7: Process dataset G
CREATE OR REPLACE PROCEDURE procedure7()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 7 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure7', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset G');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 7 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- Procedure 8: Process dataset H
CREATE OR REPLACE PROCEDURE procedure8()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 8 starting at %', v_start_time;
    
    PERFORM pg_sleep(2);
    
    INSERT INTO processing_log (procedure_name, start_time, end_time, duration, status, message)
    VALUES ('procedure8', v_start_time, clock_timestamp(), 
            clock_timestamp() - v_start_time, 'SUCCESS', 
            'Processed dataset H');
    
    v_end_time := clock_timestamp();
    RAISE NOTICE 'Procedure 8 completed at % (duration: %)', v_end_time, v_end_time - v_start_time;
END;
$$;

-- ============================================================================
-- PART 5: CREATE MASTER PROCEDURE FOR PARALLEL EXECUTION
-- ============================================================================

CREATE OR REPLACE PROCEDURE run_procedures_parallel()
LANGUAGE plpgsql AS $$
DECLARE
    -- Procedure names to execute in parallel
    proc_names TEXT[] := ARRAY['procedure1', 'procedure2', 'procedure3', 'procedure4', 
                                'procedure5', 'procedure6', 'procedure7', 'procedure8'];
    
    -- Array to store background worker PIDs
    worker_pids INTEGER[];
    
    i INTEGER;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    error_count INTEGER := 0;
BEGIN
    start_time := clock_timestamp();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STARTING PARALLEL EXECUTION';
    RAISE NOTICE 'Time: %', start_time;
    RAISE NOTICE '========================================';
    
    -- Phase 1: Launch all procedures as background workers
    RAISE NOTICE '';
    RAISE NOTICE 'Phase 1: Launching all procedures...';
    
    FOR i IN 1..8 LOOP
        BEGIN
            -- Launch procedure in background worker
            worker_pids[i] := pg_background_launch('CALL ' || proc_names[i] || '()');
            
            RAISE NOTICE '  [%/8] Launched % (PID: %)', i, proc_names[i], worker_pids[i];
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '  [%/8] Failed to launch %: %', i, proc_names[i], SQLERRM;
            error_count := error_count + 1;
            worker_pids[i] := NULL;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'All procedures launched. Now waiting for completion...';
    RAISE NOTICE '';
    
    -- Phase 2: Wait for all background workers to complete
    RAISE NOTICE 'Phase 2: Collecting results...';
    
    FOR i IN 1..8 LOOP
        IF worker_pids[i] IS NOT NULL THEN
            BEGIN
                -- Wait for background worker to complete
                -- pg_background_result returns a record, so we use a simple query
                PERFORM * FROM pg_background_result(worker_pids[i]) AS (result TEXT);
                RAISE NOTICE '  [%/8] % completed successfully', i, proc_names[i];
                
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '  [%/8] % failed: %', i, proc_names[i], SQLERRM;
                error_count := error_count + 1;
            END;
            
            -- Detach from background worker
            BEGIN
                PERFORM pg_background_detach(worker_pids[i]);
            EXCEPTION WHEN OTHERS THEN
                -- Ignore detach errors
            END;
        END IF;
    END LOOP;
    
    end_time := clock_timestamp();
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PARALLEL EXECUTION COMPLETED';
    RAISE NOTICE 'Start time:  %', start_time;
    RAISE NOTICE 'End time:    %', end_time;
    RAISE NOTICE 'Duration:    %', end_time - start_time;
    RAISE NOTICE 'Errors:      %', error_count;
    RAISE NOTICE '========================================';
    
    IF error_count > 0 THEN
        RAISE WARNING 'Completed with % error(s). Check logs above.', error_count;
    END IF;
END;
$$;

-- ============================================================================
-- PART 6: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON PROCEDURE procedure1() TO huber;
GRANT EXECUTE ON PROCEDURE procedure2() TO huber;
GRANT EXECUTE ON PROCEDURE procedure3() TO huber;
GRANT EXECUTE ON PROCEDURE procedure4() TO huber;
GRANT EXECUTE ON PROCEDURE procedure5() TO huber;
GRANT EXECUTE ON PROCEDURE procedure6() TO huber;
GRANT EXECUTE ON PROCEDURE procedure7() TO huber;
GRANT EXECUTE ON PROCEDURE procedure8() TO huber;
GRANT EXECUTE ON PROCEDURE run_procedures_parallel() TO huber;

-- ============================================================================
-- PART 7: EXECUTION AND VERIFICATION
-- ============================================================================

-- Clear any existing log data
TRUNCATE TABLE processing_log;

-- Display instructions
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔════════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║              SETUP COMPLETED SUCCESSFULLY!                     ║';
    RAISE NOTICE '╚════════════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE 'Database: parallel_demo';
    RAISE NOTICE 'User: huber';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: This script uses pg_background extension.';
    RAISE NOTICE 'Make sure pg_background is installed on your PostgreSQL server.';
    RAISE NOTICE '';
    RAISE NOTICE 'Installation instructions:';
    RAISE NOTICE '  - GitHub: https://github.com/vibhorkum/pg_background';
    RAISE NOTICE '  - Or use: apt install postgresql-XX-pg-background (Debian/Ubuntu)';
    RAISE NOTICE '';
    RAISE NOTICE 'TO RUN THE PARALLEL PROCEDURES, EXECUTE:';
    RAISE NOTICE '    CALL run_procedures_parallel();';
    RAISE NOTICE '';
    RAISE NOTICE 'TO VIEW RESULTS AFTER EXECUTION:';
    RAISE NOTICE '    SELECT * FROM processing_log ORDER BY start_time;';
    RAISE NOTICE '';
    RAISE NOTICE 'NOTE: Each procedure runs for 2 seconds. Running sequentially';
    RAISE NOTICE '      would take 16 seconds, but in parallel should take ~2 seconds!';
    RAISE NOTICE '';
END;
$$;

-- ============================================================================
-- READY TO EXECUTE!
-- ============================================================================
-- Uncomment the line below to run immediately after setup:
-- CALL run_procedures_parallel();

-- To view the results:
-- SELECT * FROM processing_log ORDER BY start_time;
