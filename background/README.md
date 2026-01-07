# Background Tutorial

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

# Now build pg_background
git clone https://github.com/vibhorkum/pg_background.git
cd pg_background
make clean
make
sudo make install

# Restart PostgreSQL
module load postgresql/16.11
pgrestart
```

- **Configure PostgreSQL**
  Switch to the postgres user and edit the configuracion file:
  - **Edit** postgresql.conf:

    ```bash
    $ sudo su - postgres
    postgres@pop-os:~$ nvim 16/main/postgresql.conf
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

- **Call the storeprocedure**

```sql
psql -d bgdb
psql (16.11 (Ubuntu 16.11-1.pgdg22.04+1))
Type "help" for help.

bgdb=# call run_procedures_parallel();
NOTICE:  ========================================
NOTICE:  STARTING PARALLEL PRIME CALCULATION
NOTICE:  Time: 2026-01-06 22:01:38.138289
NOTICE:  Task: Calculate prime sums from 1 to 8,000,000
NOTICE:  ========================================
NOTICE:
NOTICE:  Phase 1: Launching all procedures...
NOTICE:    [1/8] Launched procedure1 (Worker PID: 38159)
NOTICE:    [2/8] Launched procedure2 (Worker PID: 38160)
NOTICE:    [3/8] Launched procedure3 (Worker PID: 38161)
NOTICE:    [4/8] Launched procedure4 (Worker PID: 38162)
NOTICE:    [5/8] Launched procedure5 (Worker PID: 38163)
NOTICE:    [6/8] Launched procedure6 (Worker PID: 38164)
NOTICE:    [7/8] Launched procedure7 (Worker PID: 38165)
NOTICE:    [8/8] Launched procedure8 (Worker PID: 38166)
NOTICE:
NOTICE:  All procedures launched. Now waiting for completion...
NOTICE:
NOTICE:  Phase 2: Collecting results...
NOTICE:  Procedure 1: Computing primes in range 1 to 1000000
NOTICE:  Procedure 1 completed: 78498 primes found, sum = 37550402023 (duration: 00:00:01.412481)
NOTICE:    [1/8] procedure1 completed successfully
NOTICE:  Procedure 2: Computing primes in range 1000001 to 2000000
NOTICE:  Procedure 2 completed: 70435 primes found, sum = 105363426899 (duration: 00:00:02.217521)
NOTICE:    [2/8] procedure2 completed successfully
NOTICE:  Procedure 3: Computing primes in range 2000001 to 3000000
NOTICE:  Procedure 3 completed: 67883 primes found, sum = 169557243343 (duration: 00:00:02.699601)
NOTICE:    [3/8] procedure3 completed successfully
NOTICE:  Procedure 4: Computing primes in range 3000001 to 4000000
NOTICE:  Procedure 4 completed: 66330 primes found, sum = 232030571996 (duration: 00:00:03.039604)
NOTICE:    [4/8] procedure4 completed successfully
NOTICE:  Procedure 5: Computing primes in range 4000001 to 5000000
NOTICE:  Procedure 5 completed: 65367 primes found, sum = 294095048847 (duration: 00:00:03.441357)
NOTICE:    [5/8] procedure5 completed successfully
NOTICE:  Procedure 6: Computing primes in range 5000001 to 6000000
NOTICE:  Procedure 6 completed: 64336 primes found, sum = 353794274146 (duration: 00:00:03.63494)
NOTICE:    [6/8] procedure6 completed successfully
NOTICE:  Procedure 7: Computing primes in range 6000001 to 7000000
NOTICE:  Procedure 7 completed: 63799 primes found, sum = 414670457917 (duration: 00:00:03.907713)
NOTICE:    [7/8] procedure7 completed successfully
NOTICE:  Procedure 8: Computing primes in range 7000001 to 8000000
NOTICE:  Procedure 8 completed: 63129 primes found, sum = 473422077077 (duration: 00:00:04.080201)
NOTICE:    [8/8] procedure8 completed successfully
NOTICE:
NOTICE:  ========================================
NOTICE:  PARALLEL EXECUTION COMPLETED
NOTICE:  Start time:  2026-01-06 22:01:38.138289
NOTICE:  End time:    2026-01-06 22:01:42.229175
NOTICE:  Duration:    00:00:04.090886
NOTICE:  Errors:      0
NOTICE:  ========================================
CALL
```
