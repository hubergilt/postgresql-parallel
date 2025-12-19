# Timescaledb Tutorial

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

- **Configure PostgreSQL Settings** Switch to the postgres user and edit the configuracion file and load the timescaledb library:
  - **Edit** postgresql.conf:

    ```bash
    $ sudo su - postgres
    postgres@pop-os:~$ nvim 16/main/postgresql.conf
    #Add or modify these lines:
    shared_preload_libraries = 'timescaledb'
    ```

    _Nota: Restart after configuration changes_

  - **User Setup** Create a user (`huber`):

    ```bash
    $ sudo -u postgres createuser -P -s -d huber
    ```

  - **Database Setup** Create the database (`tsdb`):

    ```bash
    $ createdb tsdb
    ```

- **Create the Extension** Connect to the database and run:

  ```sql
  tsdb=# create extension timescaledb;
  CREATE EXTENSION
  tsdb=# create extension timescaledb_toolkit;
  CREATE EXTENSION
  tsdb=# \dx
                                                    List of installed extensions
        Name         | Version |   Schema   |                                      Description
  ---------------------+---------+------------+---------------------------------------------------------------------------------------
  plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
  timescaledb         | 2.24.0  | public     | Enables scalable inserts and complex queries for time-series data (Community Edition)
  timescaledb_toolkit | 1.22.0  | public     | Library of analytical hyperfunctions, time-series pipelining, and other SQL utilities
  (3 rows)
  ```

## 2. Loading the NYC Taxi Dataset

- **Download** the Dataset

```bash
mkdir nyc_taxi_data && cd nyc_taxi_data
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-01.parquet
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-02.parquet
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-03.parquet
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-04.parquet
```

- **Create Both Normal and Hypertable Versions**

```sql
-- Create normal PostgreSQL table
CREATE TABLE rides_normal (
    vendor_id              INTEGER,
    tpep_pickup_datetime   TIMESTAMPTZ NOT NULL,
    tpep_dropoff_datetime  TIMESTAMPTZ NOT NULL,

    passenger_count        NUMERIC,
    trip_distance          DOUBLE PRECISION,
    ratecode_id            NUMERIC,

    store_and_fwd_flag     TEXT,
    pu_location_id         INTEGER,
    do_location_id         INTEGER,
    payment_type           INTEGER,

    fare_amount            NUMERIC,
    extra                  NUMERIC,
    mta_tax                NUMERIC,
    tip_amount             NUMERIC,
    tolls_amount           NUMERIC,
    improvement_surcharge  NUMERIC,
    total_amount           NUMERIC,
    congestion_surcharge   NUMERIC,
    airport_fee            NUMERIC,
    cbd_congestion_fee     NUMERIC
);

-- Create index on normal table for fair comparison
CREATE INDEX idx_rides_normal_pickup ON rides_normal (tpep_pickup_datetime DESC);

-- Create TimescaleDB hypertable
CREATE TABLE rides (
    vendor_id              INTEGER,
    tpep_pickup_datetime   TIMESTAMPTZ NOT NULL,
    tpep_dropoff_datetime  TIMESTAMPTZ NOT NULL,

    passenger_count        NUMERIC,
    trip_distance          DOUBLE PRECISION,
    ratecode_id            NUMERIC,

    store_and_fwd_flag     TEXT,
    pu_location_id         INTEGER,
    do_location_id         INTEGER,
    payment_type           INTEGER,

    fare_amount            NUMERIC,
    extra                  NUMERIC,
    mta_tax                NUMERIC,
    tip_amount             NUMERIC,
    tolls_amount           NUMERIC,
    improvement_surcharge  NUMERIC,
    total_amount           NUMERIC,
    congestion_surcharge   NUMERIC,
    airport_fee            NUMERIC,
    cbd_congestion_fee     NUMERIC
);

-- Convert to hypertable
SELECT create_hypertable('rides', 'tpep_pickup_datetime');
```

- **Convert** Parquet to CSV (Recommended for Efficient Loading)
  The NYC Taxi data is provided in Parquet format, but timescaledb-parallel-copy works with CSV. Convert it first using Python (requires pandas and pyarrow or fastparquet):

```bash
pip install pandas pyarrow # Or fastparquet if preferred
```

Create a script convert_parquet_to_csv.py:

```python
# convert_parquet_to_csv.py
import glob

import pandas as pd

for parquet_file in glob.glob("*.parquet"):
    csv_file = parquet_file.replace(".parquet", ".csv")
    df = pd.read_parquet(parquet_file)
    df.to_csv(csv_file, index=False, header=False)
```

Run it:

```bash
python convert_parquet_to_csv.py
```

- **Load the Data into Hypertable**

```bash
for f in yellow_tripdata_2025-0*.csv; do
timescaledb-parallel-copy \
 --connection "host=localhost user=huber dbname=tsdb sslmode=disable" \
 --table rides \
 --file "$f" \
 --columns vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,ratecode_id,store_and_fwd_flag,pu_location_id,do_location_id,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge,airport_fee,cbd_congestion_fee \
 --workers 4 \
 --copy-options "CSV" \
 --reporting-period 30s
done
```

- **Load the Data into Normal Table**

```bash
for f in yellow_tripdata_2025-0*.csv; do
timescaledb-parallel-copy \
 --connection "host=localhost user=huber dbname=tsdb sslmode=disable" \
 --table rides_normal \
 --file "$f" \
 --columns vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,ratecode_id,store_and_fwd_flag,pu_location_id,do_location_id,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge,airport_fee,cbd_congestion_fee \
 --workers 4 \
 --copy-options "CSV" \
 --reporting-period 30s
done
```

## 3. Performance Comparison Tests

### Basic Count Query

```sql
-- Normal table
\timing on
SELECT COUNT(*) FROM rides_normal;
\timing off

-- Hypertable
\timing on
SELECT COUNT(*) FROM rides;
\timing off
```

### Time Range Query

```sql
-- Normal table
EXPLAIN ANALYZE
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime)
FROM rides_normal;

-- Hypertable
EXPLAIN ANALYZE
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime)
FROM rides;
```

### Time Bucket Aggregation (Daily)

```sql
-- Normal table
EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('day', tpep_pickup_datetime) AS day,
    COUNT(*) AS trips,
    AVG(total_amount) AS avg_fare,
    SUM(trip_distance) AS total_distance
FROM rides_normal
GROUP BY day
ORDER BY day;

-- Hypertable with time_bucket
EXPLAIN ANALYZE
SELECT
    time_bucket('1 day', tpep_pickup_datetime) AS day,
    COUNT(*) AS trips,
    AVG(total_amount) AS avg_fare,
    SUM(trip_distance) AS total_distance
FROM rides
GROUP BY day
ORDER BY day;
```

### Recent Data Query (Last 7 Days)

```sql
-- Normal table
EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('hour', tpep_pickup_datetime) AS hour,
    COUNT(*) AS trips,
    AVG(fare_amount) AS avg_fare
FROM rides_normal
WHERE tpep_pickup_datetime >= NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;

-- Hypertable
EXPLAIN ANALYZE
SELECT
    time_bucket('1 hour', tpep_pickup_datetime) AS hour,
    COUNT(*) AS trips,
    AVG(fare_amount) AS avg_fare
FROM rides
WHERE tpep_pickup_datetime >= NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;
```

### Complex Aggregation Query

```sql
-- Normal table
EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('hour', tpep_pickup_datetime) AS hour,
    payment_type,
    COUNT(*) AS trip_count,
    AVG(trip_distance) AS avg_distance,
    AVG(total_amount) AS avg_total,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) AS median_total
FROM rides_normal
WHERE tpep_pickup_datetime BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY hour, payment_type
ORDER BY hour, payment_type;

-- Hypertable
EXPLAIN ANALYZE
SELECT
    time_bucket('1 hour', tpep_pickup_datetime) AS hour,
    payment_type,
    COUNT(*) AS trip_count,
    AVG(trip_distance) AS avg_distance,
    AVG(total_amount) AS avg_total,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) AS median_total
FROM rides
WHERE tpep_pickup_datetime BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY hour, payment_type
ORDER BY hour, payment_type;
```

### Table Size Comparison

```sql
-- Check table sizes
SELECT
    'rides_normal' AS table_name,
    pg_size_pretty(pg_total_relation_size('rides_normal')) AS total_size,
    pg_size_pretty(pg_relation_size('rides_normal')) AS table_size,
    pg_size_pretty(pg_indexes_size('rides_normal')) AS indexes_size
UNION ALL
SELECT
    'rides' AS table_name,
    pg_size_pretty(pg_total_relation_size('rides')) AS total_size,
    pg_size_pretty(pg_relation_size('rides')) AS table_size,
    pg_size_pretty(pg_indexes_size('rides')) AS indexes_size;

-- Check hypertable chunks
SELECT
    chunk_name,
    range_start,
    range_end,
    pg_size_pretty(total_bytes) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'rides'
ORDER BY range_start;
```

## 4. Advanced TimescaleDB Features

### Continuous Aggregates (Pre-computed Results)

```sql
-- Create a continuous aggregate for hourly statistics
CREATE MATERIALIZED VIEW rides_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', tpep_pickup_datetime) AS hour,
    COUNT(*) AS trip_count,
    AVG(fare_amount) AS avg_fare,
    AVG(trip_distance) AS avg_distance,
    SUM(total_amount) AS total_revenue
FROM rides
GROUP BY hour;

-- Add refresh policy (auto-update)
SELECT add_continuous_aggregate_policy('rides_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Query the continuous aggregate (much faster!)
SELECT * FROM rides_hourly
WHERE hour >= NOW() - INTERVAL '7 days'
ORDER BY hour DESC;
```

### Compression Policy

```sql
-- Enable compression on older data
ALTER TABLE rides SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'tpep_pickup_datetime DESC'
);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('rides', INTERVAL '7 days');

-- Check compression stats
SELECT
    pg_size_pretty(before_compression_total_bytes) AS before,
    pg_size_pretty(after_compression_total_bytes) AS after,
    ROUND(100 - (after_compression_total_bytes::float / before_compression_total_bytes::float * 100), 2) AS compression_ratio
FROM timescaledb_information.compression_settings
WHERE hypertable_name = 'rides';
```

## 5. Key Takeaways

**When to use TimescaleDB Hypertables:**
- Large time-series datasets (millions of rows)
- Frequent time-based queries and aggregations
- Need for automatic data retention/compression
- Real-time analytics requirements

**Performance Benefits:**
- Faster time-range queries through chunk exclusion
- Efficient time-based aggregations with `time_bucket()`
- Reduced storage with compression
- Pre-computed results with continuous aggregates

**Normal PostgreSQL Tables are fine for:**
- Small datasets (< 1M rows)
- Non-time-series data
- Simple queries without time-based patterns