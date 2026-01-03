# Timescaledb Tutorial

This tutorial provides a comprehensive guide to installing, configuring, and using TimescaleDB—a PostgreSQL extension optimized for time-series data. Using the NYC taxi dataset as an example, it walks through the complete process from installation to performance comparison.

## 1. Installation and Configuration

- **Installation the Repository and Package**

```bash
# Add TimescaleDB APT repository
sudo apt install gnupg postgresql-common apt-transport-https lsb-release wget
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg

# Add repository for your distribution
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list

# Update and install
sudo apt update
sudo apt install timescaledb-2-postgresql-16  # For PostgreSQL 16
```

_Note: The above commands are for Ubuntu/Debian systems. For other systems, refer to the TimescaleDB official installation guide._

- **Configure PostgreSQL**
  Switch to the postgres user and edit the configuracion file:
  - **Edit** postgresql.conf:

    ```bash
    $ sudo su - postgres
    postgres@pop-os:~$ nvim 16/main/postgresql.conf
    ```

    Add or modify the following line in the configuration file to preload the TimescaleDB extension:

    ```bash
    shared_preload_libraries = 'timescaledb'
    ```

    _Important: Restart the PostgreSQL service after modifying the configuration._

- **Creating Database User and Database**
  Create a user with appropriate privileges (example username: `huber`):

  ```bash
  $ sudo -u postgres createuser -P -s -d huber
  ```

- **Database Setup** Create the database (`tsdb`):

  ```bash
  $ createdb tsdb
  ```

- **Enabling TimescaleDB Extensions**
  Connect to the database and create the extensions:

  ```sql
  -- Connect to the tsdb database
  psql -d tsdb

  -- Create the core TimescaleDB extension
  tsdb=# create extension timescaledb;
  CREATE EXTENSION

  -- Create the TimescaleDB toolkit extension (provides analytical functions, etc.)
  tsdb=# create extension timescaledb_toolkit;
  CREATE EXTENSION

  -- Verify installed extensions
  tsdb=# \dx
                                                        List of installed extensions
            Name         | Version |   Schema   |                                      Description
      ---------------------+---------+------------+---------------------------------------------------------------------------------------
      plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
      timescaledb         | 2.24.0  | public     | Enables scalable inserts and complex queries for time-series data (Community Edition)
      timescaledb_toolkit | 1.22.0  | public     | Library of analytical hyperfunctions, time-series pipelining, and other SQL utilities
      (3 rows)
  ```

  The output should include both timescaledb and timescaledb_toolkit.

## 2. Cloning Repository and Environment Setup

- **Cloning the Example Repository**

```bash
git clone https://github.com/dreamsofcode-io/timescaledb-taxidata.git
```

- **Configuring Python Environment**

Edit the ```requirements.txt``` file to ensure ```numpy``` version compatibility:

```bash
nvim requirements.txt
#Add the line:
numpy<2
```

- Install Python dependencies:

```bash
pip install -r requirements.txt
```

- **Installing Database Migration Tool**

Install the Go-based database migration tool (for managing database schema changes):

```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

*Tip: After installation, add $HOME/go/bin to your PATH environment variable to use the migrate command directly.*

## 3. Loading the NYC Taxi Dataset

- **Configuring Database Connection**
Edit the .env file to set the database connection string:

```bash
nvim .env
#Add or modify the line
DATABASE_URL=postgres://huber:huber@popos.lan:5432/tsdb
```

- **Creating Initial Table Structure**

Execute the initial migration script to create the base tables:

````bash
psql -d tsdb -h popos.lan < migrations/000_initial.up.sql
Password for user huber:
BEGIN
CREATE TABLE
CREATE TABLE
INSERT 0 2
COMMIT

- **Modifying Data Download Range**

Edit ```src/download.py``` to adjust the download year and month ranges:

```bash
nvim src/download.py
# modify the following lines:
years = range(2020, 2023)
table = (
    ("green", (2020, 1), (2024, 4)),
    ("yellow", (2020, 1), (2024, 4)),
)
````

- **Downloading and Loading Data**

Download the NYC taxi dataset:

```bash
python src/download.py
```

Load the downloaded data into the database:

```bash
python src/load.py
```

- **Creating Regular Table and Hypertable**

Use the Make command to create a hypertable—TimescaleDB's core data structure optimized for time-series:

```bash
make migrate-hypertable
```
Explanation: A hypertable is TimescaleDB's specialized table structure for time-series data, supporting automatic partitioning, efficient compression, and fast queries.

## 4. Performance Comparison Tests

**Checking Database Size**

```sql

-- Database size

tsdb=# select pg_size_pretty(pg_database_size('tsdb'));
 pg_size_pretty
----------------
 16 GB
(1 row)

**Regular Table Query Performance**

-- Normal table

tsdb=# \timing
Timing is on.
tsdb=# SELECT time_bucket(INTERVAL '1 month', started_at) AS bucket,
       AVG(total_amount),
       MIN(total_amount)
FROM trips
WHERE started_at >= '2022-01-01'
  AND started_at < '2023-01-01'
  AND total_amount > 0
GROUP BY bucket;
         bucket         |        avg         | min
------------------------+--------------------+------
 2021-12-31 19:00:00-05 |  2.916830191358083 | 0.15
 2022-01-31 19:00:00-05 |  2.889386516874528 |  0.3
 2022-02-28 19:00:00-05 |  2.874196115454305 |  0.3
 2022-03-31 19:00:00-05 | 2.8769253081561046 | 0.31
 2022-04-30 19:00:00-05 | 2.9062023583378505 |  0.3
 2022-05-31 19:00:00-05 |  2.897284148694031 | 0.31
 2022-06-30 19:00:00-05 |  2.883385194035209 | 0.31
 2022-07-31 19:00:00-05 | 2.9051512623051488 |  0.1
 2022-08-31 19:00:00-05 | 2.9431251570644616 |  0.3
 2022-09-30 19:00:00-05 |  2.856818736438773 | 0.31
 2022-10-31 19:00:00-05 | 2.8504129311834503 | 0.31
 2022-11-30 19:00:00-05 | 2.9351285808441254 | 0.31
 2022-12-31 19:00:00-05 | 3.1644700159042007 | 1.01
(13 rows)

Time: 9474.453 ms (00:09.474)

Timing is off.

Result: Query took approximately 9.47 seconds.

### Hypertable Query Performance

-- Hypertable

tsdb=# \timing
Timing is on.
tsdb=# SELECT time_bucket(INTERVAL '1 month', started_at) AS bucket,
       AVG(total_amount),
       MIN(total_amount)
FROM trips_hyper
WHERE started_at >= '2022-01-01'
  AND started_at < '2023-01-01'
  AND total_amount > 0
GROUP BY bucket;
         bucket         |        avg         | min
------------------------+--------------------+------
 2022-11-30 19:00:00-05 | 2.9351285808450087 | 0.31
 2022-10-31 19:00:00-05 | 2.8504129311838127 | 0.31
 2022-01-31 19:00:00-05 |  2.889386516875081 |  0.3
 2022-03-31 19:00:00-05 | 2.8769253081571513 | 0.31
 2022-12-31 19:00:00-05 |  3.164470015904203 | 1.01
 2022-09-30 19:00:00-05 |  2.856818736439836 | 0.31
 2022-02-28 19:00:00-05 | 2.8741961154551827 |  0.3
 2022-04-30 19:00:00-05 |  2.906202358338388 |  0.3
 2022-08-31 19:00:00-05 |  2.943125157065067 |  0.3
 2022-05-31 19:00:00-05 |  2.897284148694234 | 0.31
 2022-07-31 19:00:00-05 |  2.905151262305845 |  0.1
 2021-12-31 19:00:00-05 | 2.9168301913583354 | 0.15
 2022-06-30 19:00:00-05 | 2.8833851940358874 | 0.31
(13 rows)

Time: 2945.699 ms (00:02.946)

tsdb=# \timing off
Timing is off.

```
Result: Query took approximately 2.95 seconds.

### 5. Continuous Aggregates and Data Refresh


**Creating Continuous Aggregates**

Continuous Aggregates are another key TimescaleDB feature that automatically maintains pre-aggregated results:

```bash
make migrate-aggregate
```

View created continuous aggregate views:

```sql
--
tsdb=# select view_name from timescaledb_information.continuous_aggregates;
      view_name
---------------------
 total_summary_daily
(1 row)

***Querying Continuous Aggregate Data***

Use continuous aggregates to query monthly statistics:

tsdb=# SELECT time_bucket(INTERVAL '1 month', bucket) AS month,
       AVG(avg), MAX(max),
       MIN(min)
FROM total_summary_daily
WHERE bucket >= '2022-01-01'
  AND bucket < '2023-01-01'
GROUP BY month;
         month          |        avg         |  max   | min
------------------------+--------------------+--------+------
 2022-11-30 19:00:00-05 |  2.951589614710395 | 597.65 | 0.31
 2022-10-31 19:00:00-05 | 2.8543183899138906 |   2021 | 0.31
 2022-01-31 19:00:00-05 | 2.8918014014926814 |  421.3 |  0.3
 2022-03-31 19:00:00-05 | 2.8778998134524643 |  521.3 | 0.31
 2022-09-30 19:00:00-05 |  2.858335961752192 |  488.3 | 0.31
 2022-02-28 19:00:00-05 | 2.8755083629953537 |    500 |  0.3
 2022-04-30 19:00:00-05 | 2.9065982665507173 |  596.3 |  0.3
 2022-08-31 19:00:00-05 | 3.5494977582708804 | 544.35 |  0.3
 2022-05-31 19:00:00-05 |  2.898257898505066 |  400.3 | 0.31
 2022-07-31 19:00:00-05 |  2.906969715147334 |  542.3 |  0.1
 2021-12-31 19:00:00-05 |  2.916614071492035 |  605.3 | 0.15
 2022-06-30 19:00:00-05 | 2.8854899127753773 |  522.3 | 0.31
(12 rows)

```
*Advantage*: Continuous aggregate queries are typically faster than raw table queries since data is pre-computed and stored.

- **Loading and Refreshing New Data**

 Load 2023 data:

```bash
python3 src/load-2023.py
Processing ./data/yellow_tripdata_2023-04.parquet at 1767413040.5200367
Processing ./data/yellow_tripdata_2023-03.parquet at 1767413040.5200346
File ./data/yellow_tripdata_2023-04.parquet converted to csv at 1767413048.0183482
File ./data/yellow_tripdata_2023-03.parquet converted to csv at 1767413048.261182
File ./data/yellow_tripdata_2023-04.parquet loaded to db at 1767413057.3109279
Processing ./data/yellow_tripdata_2023-01.parquet at 1767413057.3171778
File ./data/yellow_tripdata_2023-01.parquet converted to csv at 1767413064.8558462
File ./data/yellow_tripdata_2023-03.parquet loaded to db at 1767413074.870518
Processing ./data/yellow_tripdata_2023-02.parquet at 1767413074.8764715
File ./data/yellow_tripdata_2023-02.parquet converted to csv at 1767413081.1646533
File ./data/yellow_tripdata_2023-01.parquet loaded to db at 1767413088.8295724
File ./data/yellow_tripdata_2023-02.parquet loaded to db at 1767413107.9962893
Processing ./data/green_tripdata_2023-01.parquet at 1767413108.00282
Processing ./data/green_tripdata_2023-03.parquet at 1767413108.00282
File ./data/green_tripdata_2023-01.parquet converted to csv at 1767413108.161891
File ./data/green_tripdata_2023-03.parquet converted to csv at 1767413108.170231
File ./data/green_tripdata_2023-01.parquet loaded to db at 1767413116.7125154
Processing ./data/green_tripdata_2023-04.parquet at 1767413116.7200866
File ./data/green_tripdata_2023-03.parquet loaded to db at 1767413116.7362845
Processing ./data/green_tripdata_2023-02.parquet at 1767413116.741042
File ./data/green_tripdata_2023-04.parquet converted to csv at 1767413116.8696618
File ./data/green_tripdata_2023-02.parquet converted to csv at 1767413116.8872678
File ./data/green_tripdata_2023-04.parquet loaded to db at 1767413119.4063764
File ./data/green_tripdata_2023-02.parquet loaded to db at 1767413119.4082282
Done!
```

Refresh continuous aggregates to include new data:

```sql
tsdb=# call refresh_continuous_aggregate ( 'total_summary_daily', '2022-12-31', '2024-01-01');
CALL
```

Query 2023 aggregated data:

```sql
tsdb=# SELECT time_bucket(INTERVAL '1 month', bucket) AS month,
       AVG(avg), MAX(max),
       MIN(min)
FROM total_summary_daily
WHERE bucket >= '2023-01-01'
  AND bucket < '2024-01-01'
GROUP BY month;
         month          |        avg         |  max  | min
------------------------+--------------------+-------+------
 2023-03-31 19:00:00-05 |  2.951823493701453 | 542.1 | 1.01
 2023-04-30 19:00:00-05 | 2.6097750034535157 |   300 |    1
 2022-12-31 19:00:00-05 | 2.9744563355797875 |   491 |  0.8
 2023-01-31 19:00:00-05 |  2.971060633216708 |   441 | 0.35
 2023-02-28 19:00:00-05 | 2.9621309024604447 |   478 |  0.5
(5 rows)
```
