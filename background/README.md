# Background Extension Tutorial

This tutorial provides a comprehensive guide to installing, configuring, and using background extension.

## 1. Installation and Configuration

- **Installation the Repository and Package**

```bash
# Install all required dependencies
sudo apt install -y \
    postgresql-server-dev-16 \
    build-essential \
    libkrb5-dev \
    libgssapi-krb5-2 \
    libssl-dev \
    libpam0g-dev \
    libreadline-dev \
    zlib1g-dev \
    git

# Load postgresql module
module load db/postgresql
pgstart

# Now build pg_background
git clone https://github.com/vibhorkum/pg_background.git
cd pg_background
make clean
make
sudo make install PG_CONFIG=$PGHOME/bin/pg_config

# Restart PostgreSQL
pgrestart
```

- **Configure PostgreSQL**
  - **Edit** postgresql.conf:

    ```bash
    $ sudo nvim /etc/postgresql/16/main/postgresql.conf
    ```

    Add or modify the following line in the configuration file to preload the pg_background extension:

    ```bash
    shared_preload_libraries = 'pg_background'
    ```

    Add or modify the following line in the configuration file to preload the pg_background extension:

    ```bash
    max_worker_processes = 16
    max_parallel_workers = 12
    max_parallel_workers_per_gather = 4
    ```

    _Important: Restart the PostgreSQL service after modifying the configuration._

- **Creating Database User and Database**
  Create a user with appropriate privileges (example username: `huber`):

  ```bash
  $ sudo -u postgres createuser -P -s -d huber
  ```

- **Database Setup** Create the database (`bgdb`):

  ```bash
  $ createdb bgdb
  ```

- **Enabling pg_background Extension**
  Connect to the database and create the extension:

  ```sql
  -- Connect to the bgdb database
  psql -d bgdb

  -- Create the core pg_background extension
  tsdb=# create extension pg_background;
  CREATE EXTENSION

  -- Verify installed extensions
  tsdb=# \dx
                        List of installed extensions
      Name      | Version |   Schema   |            Description
  ---------------+---------+------------+-----------------------------------
  pg_background | 1.4     | public     | Run SQL queries in the background
  plpgsql       | 1.0     | pg_catalog | PL/pgSQL procedural language
  (2 rows)
  ```

  The output should include pg_background.

## 2. Run store procedure

- **Load the store procedure**

```sql
psql -d bgdb -f primes.sql
psql:primes.sql:16: NOTICE:  ✓ dblink extension created successfully!
DO
psql:primes.sql:31: NOTICE:  relation "processing_log" already exists, skipping
CREATE TABLE
GRANT
GRANT
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
CREATE PROCEDURE
DROP PROCEDURE
CREATE PROCEDURE
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
TRUNCATE TABLE
psql:primes.sql:685: NOTICE:
psql:primes.sql:685: NOTICE:  ========================================
psql:primes.sql:685: NOTICE:  SETUP COMPLETED SUCCESSFULLY!
psql:primes.sql:685: NOTICE:  ========================================
psql:primes.sql:685: NOTICE:
psql:primes.sql:685: NOTICE:  Available procedures:
psql:primes.sql:685: NOTICE:    1. procedure1() to procedure8() - Individual range calculations
psql:primes.sql:685: NOTICE:    2. run_procedures_parallel() - Parallel execution using dblink
psql:primes.sql:685: NOTICE:
psql:primes.sql:685: NOTICE:  To run parallel execution:
psql:primes.sql:685: NOTICE:    CALL run_procedures_parallel();
psql:primes.sql:685: NOTICE:
psql:primes.sql:685: NOTICE:  To view results:
psql:primes.sql:685: NOTICE:    SELECT * FROM processing_log ORDER BY range_start;
psql:primes.sql:685: NOTICE:    SELECT SUM(prime_count) as total_primes, SUM(prime_sum) as total_sum FROM processing_log;
psql:primes.sql:685: NOTICE:
psql:primes.sql:685: NOTICE:  ========================================
DO
```

- **Run the store procedure**

```sql
bgdb=# call run_procedures_parallel();
NOTICE:  ========================================
NOTICE:  STARTING PARALLEL PRIME CALCULATION (DBLINK)
NOTICE:  Time: 2026-01-07 22:00:59.56284
NOTICE:  Task: Calculate prime sums from 1 to 8,000,000
NOTICE:  ========================================
NOTICE:
NOTICE:  Phase 1: Establishing connections and sending queries...
NOTICE:    [1/8] Launched procedure1 (Connection: conn1)
NOTICE:    [2/8] Launched procedure2 (Connection: conn2)
NOTICE:    [3/8] Launched procedure3 (Connection: conn3)
NOTICE:    [4/8] Launched procedure4 (Connection: conn4)
NOTICE:    [5/8] Launched procedure5 (Connection: conn5)
NOTICE:    [6/8] Launched procedure6 (Connection: conn6)
NOTICE:    [7/8] Launched procedure7 (Connection: conn7)
NOTICE:    [8/8] Launched procedure8 (Connection: conn8)
NOTICE:
NOTICE:  All queries sent. Now waiting for completion...
NOTICE:
NOTICE:  Phase 2: Collecting results...
NOTICE:    [1/8] procedure1 completed successfully
NOTICE:    [2/8] procedure2 completed successfully
NOTICE:    [3/8] procedure3 completed successfully
NOTICE:    [4/8] procedure4 completed successfully
NOTICE:    [5/8] procedure5 completed successfully
NOTICE:    [6/8] procedure6 completed successfully
NOTICE:    [7/8] procedure7 completed successfully
NOTICE:    [8/8] procedure8 completed successfully
NOTICE:
NOTICE:  Phase 3: Cleaning up connections...
NOTICE:    [1/8] Closed connection conn1
NOTICE:    [2/8] Closed connection conn2
NOTICE:    [3/8] Closed connection conn3
NOTICE:    [4/8] Closed connection conn4
NOTICE:    [5/8] Closed connection conn5
NOTICE:    [6/8] Closed connection conn6
NOTICE:    [7/8] Closed connection conn7
NOTICE:    [8/8] Closed connection conn8
NOTICE:
NOTICE:  ========================================
NOTICE:  PARALLEL EXECUTION COMPLETED
NOTICE:  Start time:  2026-01-07 22:00:59.56284
NOTICE:  End time:    2026-01-07 22:01:05.790532
NOTICE:  Duration:    00:00:06.227692
NOTICE:  Errors:      0
NOTICE:  ========================================
NOTICE:
NOTICE:  Results Summary:
NOTICE:  ----------------
NOTICE:    procedure1: 78498 primes, sum: 37550402023, duration: 00:00:02.321429
NOTICE:    procedure2: 70435 primes, sum: 105363426899, duration: 00:00:03.695219
NOTICE:    procedure3: 67883 primes, sum: 169557243343, duration: 00:00:04.437
NOTICE:    procedure4: 66330 primes, sum: 232030571996, duration: 00:00:04.867695
NOTICE:    procedure5: 65367 primes, sum: 294095048847, duration: 00:00:05.322463
NOTICE:    procedure6: 64336 primes, sum: 353794274146, duration: 00:00:05.738695
NOTICE:    procedure7: 63799 primes, sum: 414670457917, duration: 00:00:05.969168
NOTICE:    procedure8: 63129 primes, sum: 473422077077, duration: 00:00:06.193063
NOTICE:
NOTICE:  TOTALS:
NOTICE:    Total primes: 539777
NOTICE:    Total sum:    2080483502248
NOTICE:  ========================================
CALL
```

- **View results**

```sql
bgdb=# SELECT * FROM processing_log ORDER BY range_start;
 id | procedure_name | range_start | range_end | prime_count |  prime_sum   |         start_time         |          end_time          |    duration     | status  |                message
----+----------------+-------------+-----------+-------------+--------------+----------------------------+----------------------------+-----------------+---------+---------------------------------------
 45 | procedure1     |           1 |   1000000 |       78498 |  37550402023 | 2026-01-07 22:00:59.571163 | 2026-01-07 22:01:01.892592 | 00:00:02.321429 | SUCCESS | Found 78498 primes, sum: 37550402023
 46 | procedure2     |     1000001 |   2000000 |       70435 | 105363426899 | 2026-01-07 22:00:59.575334 | 2026-01-07 22:01:03.270553 | 00:00:03.695219 | SUCCESS | Found 70435 primes, sum: 105363426899
 47 | procedure3     |     2000001 |   3000000 |       67883 | 169557243343 | 2026-01-07 22:00:59.578972 | 2026-01-07 22:01:04.015972 | 00:00:04.437    | SUCCESS | Found 67883 primes, sum: 169557243343
 48 | procedure4     |     3000001 |   4000000 |       66330 | 232030571996 | 2026-01-07 22:00:59.583722 | 2026-01-07 22:01:04.451417 | 00:00:04.867695 | SUCCESS | Found 66330 primes, sum: 232030571996
 49 | procedure5     |     4000001 |   5000000 |       65367 | 294095048847 | 2026-01-07 22:00:59.586421 | 2026-01-07 22:01:04.908884 | 00:00:05.322463 | SUCCESS | Found 65367 primes, sum: 294095048847
 50 | procedure6     |     5000001 |   6000000 |       64336 | 353794274146 | 2026-01-07 22:00:59.589832 | 2026-01-07 22:01:05.328527 | 00:00:05.738695 | SUCCESS | Found 64336 primes, sum: 353794274146
 51 | procedure7     |     6000001 |   7000000 |       63799 | 414670457917 | 2026-01-07 22:00:59.592983 | 2026-01-07 22:01:05.562151 | 00:00:05.969168 | SUCCESS | Found 63799 primes, sum: 414670457917
 52 | procedure8     |     7000001 |   8000000 |       63129 | 473422077077 | 2026-01-07 22:00:59.595365 | 2026-01-07 22:01:05.788428 | 00:00:06.193063 | SUCCESS | Found 63129 primes, sum: 473422077077
(8 rows)

bgdb=# SELECT SUM(prime_count) as total_primes, SUM(prime_sum) as total_sum FROM processing_log;
 total_primes |   total_sum
--------------+---------------
       539777 | 2080483502248
(1 row)
```
