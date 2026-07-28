-- Verify dblink extension is loaded
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'dblink') THEN
        -- Try to create the extension
        BEGIN
            CREATE EXTENSION dblink;
            RAISE NOTICE '✓ dblink extension created successfully!';
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'dblink extension is not available. Please install it: CREATE EXTENSION dblink;';
        END;
    ELSE
        RAISE NOTICE '✓ dblink extension loaded successfully!';
    END IF;
END
$$;

-- Create a table to log procedure execution results
CREATE TABLE IF NOT EXISTS processing_log (
    id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100),
    range_start BIGINT,
    range_end BIGINT,
    prime_count INTEGER,
    prime_sum BIGINT,
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
-- Each procedure calculates the sum of prime numbers in a specific range
-- Range 1: 1 - 1,000,000 (Procedure 1)
-- Range 2: 1,000,001 - 2,000,000 (Procedure 2)
-- Range 3: 2,000,001 - 3,000,000 (Procedure 3)
-- Range 4: 3,000,001 - 4,000,000 (Procedure 4)
-- Range 5: 4,000,001 - 5,000,000 (Procedure 5)
-- Range 6: 5,000,001 - 6,000,000 (Procedure 6)
-- Range 7: 6,000,001 - 7,000,000 (Procedure 7)
-- Range 8: 7,000,001 - 8,000,000 (Procedure 8)
-- ============================================================================

-- Procedure 1: Calculate primes from 1 to 1,000,000
CREATE OR REPLACE PROCEDURE procedure1()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 1;
    v_range_end BIGINT := 1000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 1: Computing primes in range % to %', v_range_start, v_range_end;
    
    -- Special case: add 2 if in range
    IF v_range_start <= 2 AND v_range_end >= 2 THEN
        v_sum := v_sum + 2;
        v_prime_count := v_prime_count + 1;
    END IF;
    
    -- Start from first odd number in range
    v_num := CASE WHEN v_range_start <= 3 THEN 3 
                  WHEN v_range_start % 2 = 0 THEN v_range_start + 1
                  ELSE v_range_start 
             END;
    
    -- Check odd numbers only
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        -- Check divisibility up to sqrt(v_num)
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2; -- Move to next odd number
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    -- Log the result
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure1', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 1 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 2: Calculate primes from 1,000,001 to 2,000,000
CREATE OR REPLACE PROCEDURE procedure2()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 1000001;
    v_range_end BIGINT := 2000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 2: Computing primes in range % to %', v_range_start, v_range_end;
    
    -- Start from first odd number in range
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure2', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 2 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 3: Calculate primes from 2,000,001 to 3,000,000
CREATE OR REPLACE PROCEDURE procedure3()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 2000001;
    v_range_end BIGINT := 3000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 3: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure3', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 3 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 4: Calculate primes from 3,000,001 to 4,000,000
CREATE OR REPLACE PROCEDURE procedure4()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 3000001;
    v_range_end BIGINT := 4000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 4: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure4', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 4 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 5: Calculate primes from 4,000,001 to 5,000,000
CREATE OR REPLACE PROCEDURE procedure5()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 4000001;
    v_range_end BIGINT := 5000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 5: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure5', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 5 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 6: Calculate primes from 5,000,001 to 6,000,000
CREATE OR REPLACE PROCEDURE procedure6()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 5000001;
    v_range_end BIGINT := 6000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 6: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure6', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 6 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 7: Calculate primes from 6,000,001 to 7,000,000
CREATE OR REPLACE PROCEDURE procedure7()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 6000001;
    v_range_end BIGINT := 7000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 7: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure7', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 7 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- Procedure 8: Calculate primes from 7,000,001 to 8,000,000
CREATE OR REPLACE PROCEDURE procedure8()
LANGUAGE plpgsql AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_range_start BIGINT := 7000001;
    v_range_end BIGINT := 8000000;
    v_prime_count INTEGER := 0;
    v_num BIGINT;
    v_sum BIGINT := 0;
    v_is_prime BOOLEAN;
    v_divisor BIGINT;
    v_sqrt BIGINT;
BEGIN
    v_start_time := clock_timestamp();
    RAISE NOTICE 'Procedure 8: Computing primes in range % to %', v_range_start, v_range_end;
    
    v_num := CASE WHEN v_range_start % 2 = 0 THEN v_range_start + 1 ELSE v_range_start END;
    
    WHILE v_num <= v_range_end LOOP
        v_is_prime := TRUE;
        v_sqrt := floor(sqrt(v_num))::BIGINT;
        
        FOR v_divisor IN 3..v_sqrt BY 2 LOOP
            IF v_num % v_divisor = 0 THEN
                v_is_prime := FALSE;
                EXIT;
            END IF;
        END LOOP;
        
        IF v_is_prime THEN
            v_sum := v_sum + v_num;
            v_prime_count := v_prime_count + 1;
        END IF;
        
        v_num := v_num + 2;
    END LOOP;
    
    v_end_time := clock_timestamp();
    
    INSERT INTO processing_log (procedure_name, range_start, range_end, prime_count, prime_sum, 
                                start_time, end_time, duration, status, message)
    VALUES ('procedure8', v_range_start, v_range_end, v_prime_count, v_sum,
            v_start_time, v_end_time, v_end_time - v_start_time, 'SUCCESS', 
            format('Found %s primes, sum: %s', v_prime_count, v_sum));
    
    RAISE NOTICE 'Procedure 8 completed: % primes found, sum = % (duration: %)', 
                 v_prime_count, v_sum, v_end_time - v_start_time;
END;
$$;

-- ============================================================================
-- DBLink-based Parallel Execution
-- ============================================================================

/*
This master procedure launches all 8 procedures in parallel using dblink.
Each procedure runs as a separate asynchronous connection, allowing them to
execute simultaneously.

How it works:
1. Creates asynchronous connections for each procedure using dblink_connect()
2. Executes procedures asynchronously using dblink_send_query()
3. Waits for all procedures to complete using dblink_get_result()
4. Collects results and logs the total execution time
*/

-- First, drop any existing version
DROP PROCEDURE IF EXISTS run_procedures_parallel();

-- Create the corrected parallel procedure
CREATE OR REPLACE PROCEDURE run_procedures_parallel()
LANGUAGE plpgsql AS $$
DECLARE
    proc_names TEXT[] := ARRAY['procedure1', 'procedure2', 'procedure3', 'procedure4', 
                                'procedure5', 'procedure6', 'procedure7', 'procedure8'];
    conn_names TEXT[] := ARRAY['conn1', 'conn2', 'conn3', 'conn4', 
                               'conn5', 'conn6', 'conn7', 'conn8'];
    i INTEGER;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    error_count INTEGER := 0;
    sql TEXT;
    conn_exists BOOLEAN;
    current_primes INTEGER;
    current_sum BIGINT;
    current_duration INTERVAL;
    total_primes BIGINT := 0;
    total_sum BIGINT := 0;
BEGIN
    start_time := clock_timestamp();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STARTING PARALLEL PRIME CALCULATION (DBLINK)';
    RAISE NOTICE 'Time: %', start_time;
    RAISE NOTICE 'Task: Calculate prime sums from 1 to 8,000,000';
    RAISE NOTICE '========================================';
    
    -- Phase 1: Establish connections and send queries asynchronously
    RAISE NOTICE '';
    RAISE NOTICE 'Phase 1: Establishing connections and sending queries...';
    
    FOR i IN 1..8 LOOP
        BEGIN
            -- Establish a connection to the same database
            -- Uses host=localhost (TCP) + password so dblink authenticates via
            -- md5/scram instead of Unix-socket peer auth (which would check the
            -- OS user of the *server* backend process, not the client session).
            sql := 'host=localhost port=5432 dbname=' || current_database() || 
                   ' user=' || current_user || ' password=huber';
            
            PERFORM dblink_connect(conn_names[i], sql);
            
            -- Send the query asynchronously
            sql := 'CALL ' || proc_names[i] || '()';
            PERFORM dblink_send_query(conn_names[i], sql);
            
            RAISE NOTICE '  [%/8] Launched % (Connection: %)', i, proc_names[i], conn_names[i];
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '  [%/8] Failed to launch %: %', i, proc_names[i], SQLERRM;
            error_count := error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'All queries sent. Now waiting for completion...';
    RAISE NOTICE '';
    
    -- Phase 2: Wait for all queries to complete and get results
    RAISE NOTICE 'Phase 2: Collecting results...';
    
    FOR i IN 1..8 LOOP
        BEGIN
            -- Get the result (this will wait if not ready)
            -- Note: dblink_get_result doesn't need column specification in PERFORM
            PERFORM dblink_get_result(conn_names[i]);
            RAISE NOTICE '  [%/8] % completed successfully', i, proc_names[i];
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '  [%/8] Error collecting result for %: %', i, proc_names[i], SQLERRM;
            error_count := error_count + 1;
        END;
    END LOOP;
    
    -- Phase 3: Clean up connections
    RAISE NOTICE '';
    RAISE NOTICE 'Phase 3: Cleaning up connections...';
    
    FOR i IN 1..8 LOOP
        BEGIN
            PERFORM dblink_disconnect(conn_names[i]);
            RAISE NOTICE '  [%/8] Closed connection %', i, conn_names[i];
        EXCEPTION WHEN OTHERS THEN
            -- Connection might already be closed
            NULL;
        END;
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
    
    -- Display summary from log table
    RAISE NOTICE '';
    RAISE NOTICE 'Results Summary:';
    RAISE NOTICE '----------------';
    
    -- Reset totals
    total_primes := 0;
    total_sum := 0;
    
    FOR i IN 1..8 LOOP
        BEGIN
            -- Get the latest result for this procedure
            SELECT prime_count, prime_sum, duration 
            INTO current_primes, current_sum, current_duration
            FROM processing_log 
            WHERE procedure_name = proc_names[i]
            ORDER BY id DESC 
            LIMIT 1;
            
            IF FOUND THEN
                RAISE NOTICE '  %: % primes, sum: %, duration: %', 
                             proc_names[i], current_primes, current_sum, current_duration;
                total_primes := total_primes + current_primes;
                total_sum := total_sum + current_sum;
            ELSE
                RAISE NOTICE '  %: No result found in log', proc_names[i];
            END IF;
            
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE NOTICE '  %: No result found in log', proc_names[i];
        END;
    END LOOP;
    
    -- Display totals
    RAISE NOTICE '';
    RAISE NOTICE 'TOTALS:';
    RAISE NOTICE '  Total primes: %', total_primes;
    RAISE NOTICE '  Total sum:    %', total_sum;
    RAISE NOTICE '========================================';
    
    IF error_count > 0 THEN
        RAISE WARNING 'Completed with % error(s). Check logs above.', error_count;
    END IF;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
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

-- Also grant dblink usage permissions
GRANT USAGE ON FOREIGN DATA WRAPPER dblink_fdw TO huber;

-- ============================================================================
-- SETUP COMPLETION AND INSTRUCTIONS
-- ============================================================================

-- Clear any existing log data
TRUNCATE TABLE processing_log;

-- Display instructions
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SETUP COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Available procedures:';
    RAISE NOTICE '  1. procedure1() to procedure8() - Individual range calculations';
    RAISE NOTICE '  2. run_procedures_parallel() - Parallel execution using dblink';
    RAISE NOTICE '';
    RAISE NOTICE 'To run parallel execution:';
    RAISE NOTICE '  CALL run_procedures_parallel();';
    RAISE NOTICE '';
    RAISE NOTICE 'To view results:';
    RAISE NOTICE '  SELECT * FROM processing_log ORDER BY range_start;';
    RAISE NOTICE '  SELECT SUM(prime_count) as total_primes, SUM(prime_sum) as total_sum FROM processing_log;';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
