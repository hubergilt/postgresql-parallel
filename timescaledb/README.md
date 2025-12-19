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

tsdb=# \timing on
Timing is on.
tsdb=# SELECT COUNT(*) FROM rides_normal;
  count   
----------
 15168579
(1 row)

Time: 436.686 ms
tsdb=# \timing off
Timing is off.
-- Hypertable

tsdb=# \timing on
Timing is on.
tsdb=# SELECT COUNT(*) FROM rides;
  count   
----------
 15168579
(1 row)

Time: 360.122 ms
tsdb=# \timing off
Timing is off.

```

### Time Range Query

```sql
-- Normal table
tsdb=# \timing on
Timing is on.
tsdb=# SELECT COUNT(*) FROM rides;
  count   
----------
 15168579
(1 row)

Time: 360.122 ms
tsdb=# \timing off
Timing is off.
tsdb=# EXPLAIN ANALYZE
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime)
FROM rides_normal;
                                                                                     QUERY PLAN                                                                                     
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Result  (cost=0.93..0.94 rows=1 width=16) (actual time=0.481..0.481 rows=1 loops=1)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=0.43..0.47 rows=1 width=8) (actual time=0.440..0.440 rows=1 loops=1)
           ->  Index Only Scan Backward using idx_rides_normal_pickup on rides_normal  (cost=0.43..465341.26 rows=15164694 width=8) (actual time=0.439..0.439 rows=1 loops=1)
                 Index Cond: (tpep_pickup_datetime IS NOT NULL)
                 Heap Fetches: 0
   InitPlan 2 (returns $1)
     ->  Limit  (cost=0.43..0.47 rows=1 width=8) (actual time=0.036..0.036 rows=1 loops=1)
           ->  Index Only Scan using idx_rides_normal_pickup on rides_normal rides_normal_1  (cost=0.43..465341.26 rows=15164694 width=8) (actual time=0.036..0.036 rows=1 loops=1)
                 Index Cond: (tpep_pickup_datetime IS NOT NULL)
                 Heap Fetches: 1
 Planning Time: 0.606 ms
 Execution Time: 0.528 ms
(13 rows)

-- Hypertable
EXPLAIN ANALYZE
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime)
FROM rides;
                                                                                                       QUERY PLAN                                                                                                       
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Result  (cost=0.44..0.45 rows=1 width=16) (actual time=0.024..0.025 rows=1 loops=1)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=0.14..0.15 rows=1 width=8) (actual time=0.008..0.009 rows=1 loops=1)
           ->  Custom Scan (ChunkAppend) on rides  (cost=0.14..50.93 rows=159 width=8) (actual time=0.007..0.008 rows=1 loops=1)
                 Order: rides.tpep_pickup_datetime
                 ->  Index Only Scan Backward using _hyper_1_13_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_13_chunk  (cost=0.14..50.93 rows=159 width=8) (actual time=0.006..0.006 rows=1 loops=1)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 1
                 ->  Index Only Scan Backward using _hyper_1_11_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_11_chunk  (cost=0.14..50.93 rows=159 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_1_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_1_chunk  (cost=0.29..2364.84 rows=75425 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_2_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_2_chunk  (cost=0.42..18411.99 rows=632313 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_3_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_3_chunk  (cost=0.42..22853.16 rows=798611 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_4_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_4_chunk  (cost=0.42..23611.59 rows=831031 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_5_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_5_chunk  (cost=0.42..23726.32 rows=833401 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_6_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_6_chunk  (cost=0.42..24959.90 rows=884824 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_7_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_7_chunk  (cost=0.42..25322.59 rows=895643 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_8_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_8_chunk  (cost=0.42..25409.34 rows=903634 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_9_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_9_chunk  (cost=0.42..24541.83 rows=864540 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_10_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_10_chunk  (cost=0.42..27105.13 rows=965388 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_12_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_12_chunk  (cost=0.42..26089.60 rows=921222 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_14_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_14_chunk  (cost=0.42..26655.15 rows=943346 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_15_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_15_chunk  (cost=0.42..25811.73 rows=912943 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_16_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_16_chunk  (cost=0.42..26954.85 rows=961266 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_17_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_17_chunk  (cost=0.42..26440.14 rows=935920 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_18_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_18_chunk  (cost=0.42..25893.45 rows=918708 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_19_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_19_chunk  (cost=0.42..24895.83 rows=877312 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_20_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_20_chunk  (cost=0.42..27296.34 rows=971642 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan Backward using _hyper_1_21_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_21_chunk  (cost=0.29..1202.02 rows=41408 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
   InitPlan 2 (returns $1)
     ->  Limit  (cost=0.29..0.29 rows=1 width=8) (actual time=0.011..0.012 rows=1 loops=1)
           ->  Custom Scan (ChunkAppend) on rides rides_1  (cost=0.29..1202.02 rows=41408 width=8) (actual time=0.011..0.012 rows=1 loops=1)
                 Order: rides_1.tpep_pickup_datetime DESC
                 ->  Index Only Scan using _hyper_1_21_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_21_chunk _hyper_1_21_chunk_1  (cost=0.29..1202.02 rows=41408 width=8) (actual time=0.011..0.011 rows=1 loops=1)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_20_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_20_chunk _hyper_1_20_chunk_1  (cost=0.42..27296.34 rows=971642 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_19_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_19_chunk _hyper_1_19_chunk_1  (cost=0.42..24895.83 rows=877312 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_18_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_18_chunk _hyper_1_18_chunk_1  (cost=0.42..25893.45 rows=918708 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_17_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_17_chunk _hyper_1_17_chunk_1  (cost=0.42..26440.14 rows=935920 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_16_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_16_chunk _hyper_1_16_chunk_1  (cost=0.42..26954.85 rows=961266 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_15_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_15_chunk _hyper_1_15_chunk_1  (cost=0.42..25811.73 rows=912943 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_14_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_14_chunk _hyper_1_14_chunk_1  (cost=0.42..26655.15 rows=943346 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_12_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_12_chunk _hyper_1_12_chunk_1  (cost=0.42..26089.60 rows=921222 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_10_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_10_chunk _hyper_1_10_chunk_1  (cost=0.42..27105.13 rows=965388 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_9_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_9_chunk _hyper_1_9_chunk_1  (cost=0.42..24541.83 rows=864540 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_8_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_8_chunk _hyper_1_8_chunk_1  (cost=0.42..25409.34 rows=903634 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_7_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_7_chunk _hyper_1_7_chunk_1  (cost=0.42..25322.59 rows=895643 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_6_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_6_chunk _hyper_1_6_chunk_1  (cost=0.42..24959.90 rows=884824 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_5_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_5_chunk _hyper_1_5_chunk_1  (cost=0.42..23726.32 rows=833401 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_4_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_4_chunk _hyper_1_4_chunk_1  (cost=0.42..23611.59 rows=831031 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_3_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_3_chunk _hyper_1_3_chunk_1  (cost=0.42..22853.16 rows=798611 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_2_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_2_chunk _hyper_1_2_chunk_1  (cost=0.42..18411.99 rows=632313 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_1_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_1_chunk _hyper_1_1_chunk_1  (cost=0.29..2364.84 rows=75425 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_11_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_11_chunk _hyper_1_11_chunk_1  (cost=0.14..50.93 rows=159 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
                 ->  Index Only Scan using _hyper_1_13_chunk_rides_tpep_pickup_datetime_idx on _hyper_1_13_chunk _hyper_1_13_chunk_1  (cost=0.14..50.93 rows=159 width=8) (never executed)
                       Index Cond: (tpep_pickup_datetime IS NOT NULL)
                       Heap Fetches: 0
 Planning Time: 1.165 ms
 Execution Time: 0.101 ms
(137 rows)
```

### Time Bucket Aggregation (Daily)

```sql
-- Normal table
tsdb=# EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('day', tpep_pickup_datetime) AS day,
    COUNT(*) AS trips,
    AVG(total_amount) AS avg_fare,
    SUM(trip_distance) AS total_distance
FROM rides_normal
GROUP BY day
ORDER BY day;
tsdb=# EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('day', tpep_pickup_datetime) AS day,
    COUNT(*) AS trips,
    AVG(total_amount) AS avg_fare,
    SUM(trip_distance) AS total_distance
FROM rides_normal
GROUP BY day
ORDER BY day;
                                                                QUERY PLAN                                                                
------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=2791942.49..2804766.06 rows=5129429 width=56) (actual time=3278.574..3278.579 rows=124 loops=1)
   Sort Key: (date_trunc('day'::text, tpep_pickup_datetime))
   Sort Method: quicksort  Memory: 32kB
   ->  HashAggregate  (cost=1614954.53..1869607.22 rows=5129429 width=56) (actual time=3278.500..3278.557 rows=124 loops=1)
         Group Key: date_trunc('day'::text, tpep_pickup_datetime)
         Planned Partitions: 256  Batches: 1  Memory Usage: 465kB
         ->  Seq Scan on rides_normal  (cost=0.00..449168.67 rows=15164694 width=22) (actual time=57.755..2103.143 rows=15168579 loops=1)
 Planning Time: 0.263 ms
 JIT:
   Functions: 6
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.752 ms, Inlining 13.805 ms, Optimization 26.272 ms, Emission 17.662 ms, Total 58.490 ms
 Execution Time: 3279.459 ms
(13 rows)


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
                                                                             QUERY PLAN                                                                             
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=404745.97..404746.47 rows=200 width=56) (actual time=2321.918..2326.617 rows=123 loops=1)
   Sort Key: (time_bucket('1 day'::interval, rides.tpep_pickup_datetime))
   Sort Method: quicksort  Memory: 32kB
   ->  Finalize HashAggregate  (cost=404735.33..404738.33 rows=200 width=56) (actual time=2321.821..2326.567 rows=123 loops=1)
         Group Key: (time_bucket('1 day'::interval, rides.tpep_pickup_datetime))
         Batches: 1  Memory Usage: 96kB
         ->  Gather  (cost=26598.51..404636.13 rows=7936 width=56) (actual time=59.716..2326.382 rows=136 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               ->  Parallel Append  (cost=25598.51..402842.53 rows=3968 width=56) (actual time=311.460..2302.546 rows=45 loops=3)
                     ->  Partial HashAggregate  (cost=25770.15..25773.15 rows=200 width=56) (actual time=246.141..246.144 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_20_chunk.tpep_pickup_datetime)
                           Worker 1:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_20_chunk  (cost=0.00..21721.64 rows=404851 width=22) (actual time=52.239..158.323 rows=971642 loops=1)
                     ->  Partial HashAggregate  (cost=25598.51..25601.51 rows=200 width=56) (actual time=629.133..629.136 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_10_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_10_chunk  (cost=0.00..21576.06 rows=402245 width=22) (actual time=52.962..525.802 rows=965388 loops=1)
                     ->  Partial HashAggregate  (cost=25422.88..25425.88 rows=200 width=56) (actual time=572.794..572.798 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_16_chunk.tpep_pickup_datetime)
                           Worker 1:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_16_chunk  (cost=0.00..21417.60 rows=400528 width=22) (actual time=0.503..478.768 rows=961266 loops=1)
                     ->  Partial HashAggregate  (cost=24991.87..24994.87 rows=200 width=56) (actual time=178.734..178.737 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_14_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_14_chunk  (cost=0.00..21061.26 rows=393061 width=22) (actual time=0.536..97.783 rows=943346 loops=1)
                     ->  Partial HashAggregate  (cost=24880.25..24883.25 rows=200 width=56) (actual time=176.795..176.797 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_17_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_17_chunk  (cost=0.00..20980.58 rows=389967 width=22) (actual time=0.023..94.321 rows=935920 loops=1)
                     ->  Partial HashAggregate  (cost=24436.45..24439.45 rows=200 width=56) (actual time=438.003..438.006 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_12_chunk.tpep_pickup_datetime)
                           Worker 1:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_12_chunk  (cost=0.00..20598.03 rows=383842 width=22) (actual time=0.670..347.070 rows=921222 loops=1)
                     ->  Partial HashAggregate  (cost=24354.89..24357.89 rows=200 width=56) (actual time=172.854..172.857 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_18_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_18_chunk  (cost=0.00..20526.94 rows=382795 width=22) (actual time=0.026..92.610 rows=918708 loops=1)
                     ->  Partial HashAggregate  (cost=24166.84..24169.84 rows=200 width=56) (actual time=173.867..173.869 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_15_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_15_chunk  (cost=0.00..20362.91 rows=380393 width=22) (actual time=0.033..93.019 rows=912943 loops=1)
                     ->  Partial HashAggregate  (cost=23805.57..23808.57 rows=200 width=56) (actual time=560.483..560.485 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_8_chunk.tpep_pickup_datetime)
                           Worker 1:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_8_chunk  (cost=0.00..20040.43 rows=376514 width=22) (actual time=0.450..475.173 rows=903634 loops=1)
                     ->  Partial HashAggregate  (cost=23693.66..23696.66 rows=200 width=56) (actual time=617.145..617.148 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_7_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_7_chunk  (cost=0.00..19961.81 rows=373185 width=22) (actual time=2.333..530.124 rows=895643 loops=1)
                     ->  Partial HashAggregate  (cost=23470.23..23473.23 rows=200 width=56) (actual time=166.986..166.988 rows=4 loops=3)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_6_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           Worker 1:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_6_chunk  (cost=0.00..19783.46 rows=368677 width=22) (actual time=0.378..137.754 rows=294941 loops=3)
                     ->  Partial HashAggregate  (cost=23287.80..23290.80 rows=200 width=56) (actual time=163.060..163.065 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_19_chunk.tpep_pickup_datetime)
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_19_chunk  (cost=0.00..19632.33 rows=365547 width=22) (actual time=0.026..87.422 rows=877312 loops=1)
                     ->  Partial HashAggregate  (cost=22918.06..22921.06 rows=200 width=56) (actual time=319.280..319.283 rows=7 loops=2)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_9_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           Worker 0:  Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_9_chunk  (cost=0.00..19315.81 rows=360225 width=22) (actual time=0.686..277.580 rows=432270 loops=2)
                     ->  Partial HashAggregate  (cost=22152.13..22155.13 rows=200 width=56) (actual time=547.340..547.342 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_5_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_5_chunk  (cost=0.00..18679.63 rows=347250 width=22) (actual time=0.300..459.977 rows=833401 loops=1)
                     ->  Partial HashAggregate  (cost=22007.92..22010.92 rows=200 width=56) (actual time=394.164..394.166 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_4_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_4_chunk  (cost=0.00..18545.29 rows=346263 width=22) (actual time=0.310..311.195 rows=831031 loops=1)
                     ->  Partial HashAggregate  (cost=21290.98..21293.98 rows=200 width=56) (actual time=433.040..433.043 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_3_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_3_chunk  (cost=0.00..17963.43 rows=332755 width=22) (actual time=1.292..355.566 rows=798611 loops=1)
                     ->  Partial HashAggregate  (cost=16901.94..16904.94 rows=200 width=56) (actual time=361.363..361.367 rows=7 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_2_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_2_chunk  (cost=0.00..14267.30 rows=263464 width=22) (actual time=0.747..299.341 rows=632313 loops=1)
                     ->  Partial HashAggregate  (cost=2300.28..2303.28 rows=200 width=56) (actual time=35.059..35.060 rows=1 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_1_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_1_chunk  (cost=0.00..1856.60 rows=44368 width=22) (actual time=0.994..27.347 rows=75425 loops=1)
                     ->  Partial HashAggregate  (cost=1285.05..1288.05 rows=200 width=56) (actual time=8.910..8.911 rows=1 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_21_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_21_chunk  (cost=0.00..1041.47 rows=24358 width=22) (actual time=0.010..5.154 rows=41408 loops=1)
                     ->  Partial HashAggregate  (cost=12.12..15.12 rows=200 width=56) (actual time=0.010..0.011 rows=1 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_13_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_13_chunk  (cost=0.00..11.18 rows=94 width=22) (actual time=0.006..0.006 rows=1 loops=1)
                     ->  Partial HashAggregate  (cost=12.12..15.12 rows=200 width=56) (actual time=59.104..59.105 rows=1 loops=1)
                           Group Key: time_bucket('1 day'::interval, _hyper_1_11_chunk.tpep_pickup_datetime)
                           Batches: 1  Memory Usage: 40kB
                           ->  Parallel Seq Scan on _hyper_1_11_chunk  (cost=0.00..11.18 rows=94 width=22) (actual time=59.075..59.082 rows=1 loops=1)
 Planning Time: 2.499 ms
 JIT:
   Functions: 382
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 16.170 ms, Inlining 0.000 ms, Optimization 11.841 ms, Emission 151.875 ms, Total 179.886 ms
 Execution Time: 2333.259 ms
(103 rows)
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