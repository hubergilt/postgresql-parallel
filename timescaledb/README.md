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


## 2. Clone repository

- **Clone** the repository

```bash
git clone https://github.com/dreamsofcode-io/timescaledb-taxidata.git
```
- **Modify** numpy version
```bash
nvim requirements.txt
#Add the line:
numpy<2
```
- **Install** requirements
```bash
pip install -r requirements.txt
```
- **Install** migrate tool
```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```
*Note: add /home/huber/go/bin to path*

## 3. Loading the NYC Taxi Dataset

- **Modify** .env file 

```bash
nvim .env
#Add or modify the line
DATABASE_URL=postgres://huber:huber@popos.lan:5432/tsdb
```
- **Create** initial tables
```bash
psql -d tsdb -h popos.lan < migrations/000_initial.up.sql 
Password for user huber: 
BEGIN
CREATE TABLE
CREATE TABLE
INSERT 0 2
COMMIT

- **Modify** download file
```bash
nvim src/download.py
# modify the following lines:
years = range(2020, 2023)
table = (
    ("green", (2020, 1), (2024, 4)),
    ("yellow", (2020, 1), (2024, 4)),
)
```
- **Download** data file
```bash
python src/download.py
```

- **Load** data file
```bash
python src/load.py
```

- **Create Both Normal and Hypertable Versions**

```bash
make migrate-hypertable
```

## 3. Performance Comparison Tests

### Basic Count Query

```sql

-- Database size

tsdb=# select pg_size_pretty(pg_database_size('tsdb'));
 pg_size_pretty 
----------------
 16 GB
(1 row)

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

### Continuous agregation

```bash
make migrate-aggregate
```

```sql
-- 
tsdb=# select view_name from timescaledb_information.continuous_aggregates;
      view_name      
---------------------
 total_summary_daily
(1 row)

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

- **Load** 2023 data

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
- **Refresh** 2023 data

```sql
tsdb=# call refresh_continuous_aggregate ( 'total_summary_daily', '2022-12-31', '2024-01-01');
CALL
```

--**Query** 2023 data

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

