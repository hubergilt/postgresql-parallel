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

    _Nota: If there are multiple shared libraries use citus as first one_

  - **User Setup** Create a user (`huber`):

    ```bash
    sudo -u postgres createuser -P -s -d huber
    ```

  - **Database Setup** Create the database (`tsdb`):

    ```bash
    sudo -u postgres createuser -P -s -d huber
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
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet
```

- **Convert** Parquet to CSV (Recommended for Efficient Loading)
  The NYC Taxi data is provided in Parquet format, but timescaledb-parallel-copy works with CSV. Convert it first using Python (requires pandas and pyarrow or fastparquet):

```bash
pip install pandas pyarrow # Or fastparquet if preferred
```

Create a script convert_parquet_to_csv.py:

```python
import pandas as pd

# Read Parquet file

df = pd.read_parquet('yellow_tripdata_2023-01.parquet')

# Write to CSV without index and without header (we'll handle header separately if needed)

df.to_csv('yellow_tripdata_2023-01.csv', index=False, header=False)
```

Run it:

```bash
python convert_parquet_to_csv.py
```

This produces a headerless CSV file (~300-400 MB) suitable for fast loading.

- **Load the Data with timescaledb-parallel-copy (CSV Version)**

Now use the command:

```bash
timescaledb-parallel-copy \
 --connection "host=localhost user=huber dbname=tsdb sslmode=disable" \
 --table rides \
 --file yellow_tripdata_2023-01.csv \
 --columns VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,congestion_surcharge,airport_fee \
 --workers 4 \
 --copy-options "CSV" \
 --reporting-period 30s # Optional: reports progress every 30 seconds
```
## 3. Testing

```sql
tsdb=# SELECT COUNT(\*) FROM rides;
count

---

3066766
(1 row)

tsdb=# SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime) FROM rides;
min | max
------------------------+------------------------
2008-12-31 23:01:42-05 | 2023-02-01 00:56:53-05
(1 row)
```
