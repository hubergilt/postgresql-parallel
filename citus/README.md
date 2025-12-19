# Citus Distributed Database Tutorial

This tutorial covers the installation of Citus 13.2 on PostgreSQL 16, configuring the coordinator node, distributing tables, and scaling out to worker nodes.

## 1. Installation and Configuration for Coordinator and Worker nodes.

First, install the Citus extension and configure the PostgreSQL server to handle distributed connections.

- **Install the Repository and Package** Run the installation script and install the PostgreSQL 16 Citus extension on coordinator node and worker nodes:

```bash
$ curl https://install.citusdata.com/community/deb.sh | sudo bash
$ sudo apt install postgresql-16-citus-13.2
```

- **Configure PostgreSQL Settings** Switch to the postgres user and edit the configuracion files to allow network connection and load the Citus library:
  - **Edit** postgresql.conf:

    ```bash
    $ sudo su - postgres
    postgres@pop-os:~$ nvim 16/main/postgresql.conf
    #Add or modify these lines:
    listen_addresses = '*'
    shared_preload_libraries = 'citus'
    wal_level = 'logical'
    ```

    _Note: If there are multiple shared libraries use citus as first one_

  - **Edit** pg_hba.conf: Allow the local network (192.168.0.0/24) to connect via SCRAM-SHA-256:

    ```bash
    postgres@pop-os:~$ nvim 16/main/pg_hba.conf
    #Add or modify this line:
    host    all             all             192.168.0.0/24            scram-sha-256
    ```

  - **User Setup** Create a user (`huber`):

    ```bash
    $ sudo -u postgres createuser -P -s -d huber
    ```

    _Note: Restart PostgreSQL service_

  - **Configure Passwordless Access** (.pgpass) To ensure nodes can communicate without manual password entry, add credentials to ~/.pgpass and set permissions:

    ```bash
    $ nvim ~/.pgpass
    #Add or modify this line:
    popos.lan:5432:citusdb:huber:huber
    citus01.lan:5432:citusdb:huber:huber
    cutus02.lan:5432:citusdb:huber:huber
    $ chmod 600 ~/.pgpass
    ```

    _Note: Before configure proper IPs for popos (coordinator), citus01 and citus02 (workers)_

- **Create the Extension** Connect to the database and run:

  ```sql
  citusdb=# create extension citus;
  CREATE EXTENSION
  citusdb=# \dx
                   List of installed extensions
    Name   | Version |   Schema   |         Description
  ---------+---------+------------+------------------------------
   citus   | 13.2-1  | pg_catalog | Citus distributed database
   plpgsql | 1.0     | pg_catalog | PL/pgSQL procedural language
  (2 rows)
  ```

## 2. Preparing Database and Tables

Once the service database is running, and enabled the extension then preparate the existing `pgbench` tables for distribution only on coordinator node.

- **Database Setup** Create the database (`citusdb`), and generate sample data using pgbench:

  ```bash
  $ sudo -u postgres createuser -P -s -d huber
  $ createdb citusdb
  $ pgbench -i -s 64 citusdb
  ```

- **Modify Primary Keys** Citus requires the distribution column to be part of the Primary Key. Modify `pgbench_accounts` to include `bid`:

```sql
citusdb=# alter table pgbench_accounts drop constraint pgbench_accounts_pkey;
ALTER TABLE

citusdb=# alter table pgbench_accounts add primary key (aid, bid);
ALTER TABLE

```

- **Distribute the Tables** Convert the standard local tables into distributed tables sharded by `bid`:

```sql
citusdb=# select create_distributed_table('pgbench_accounts', 'bid');
NOTICE:  Copying data from local table...
NOTICE:  copying the data has completed
DETAIL:  The local data in the table is no longer visible, but is still on disk.
HINT:  To remove the local data, run: SELECT truncate_local_data_after_distributing_table($$public.pgbench_accounts$$)
 create_distributed_table
--------------------------

(1 row)

citusdb=# select create_distributed_table('pgbench_branches', 'bid');
NOTICE:  Copying data from local table...
NOTICE:  copying the data has completed
DETAIL:  The local data in the table is no longer visible, but is still on disk.
HINT:  To remove the local data, run: SELECT truncate_local_data_after_distributing_table($$public.pgbench_branches$$)
 create_distributed_table
--------------------------

(1 row)
```

- **Verify Distribution** Check the table metadata to confirm they are distributed with a shard count of 32:

```sql
citusdb=# select * from citus_tables limit 2 \gx
-[ RECORD 1 ]-------+-----------------
table_name          | pgbench_accounts
citus_table_type    | distributed
distribution_column | bid
colocation_id       | 1
table_size          | 967 MB
shard_count         | 32
table_owner         | huber
access_method       | heap
-[ RECORD 2 ]-------+-----------------
table_name          | pgbench_branches
citus_table_type    | distributed
distribution_column | bid
colocation_id       | 1
table_size          | 736 kB
shard_count         | 32
table_owner         | huber
access_method       | heap

```

- **Query Before Rebalancing** show that only localhost node is schedule to execute the task.

```sql
citusdb=# explain (analyze) select count(*) from pgbench_branches;
                                                                         QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=250.00..250.02 rows=1 width=8) (actual time=6.999..6.999 rows=1 loops=1)
   ->  Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=100000 width=8) (actual time=6.990..6.992 rows=32 loops=1)
         Task Count: 32
         Tuple data received from nodes: 256 bytes
         Tasks Shown: One of 32
         ->  Task
               Tuple data received from node: 8 bytes
               Node: host=localhost port=5432 dbname=citusdb
               ->  Aggregate  (cost=12.50..12.51 rows=1 width=8) (actual time=0.013..0.014 rows=1 loops=1)
                     ->  Seq Scan on pgbench_branches_102040 pgbench_branches  (cost=0.00..12.00 rows=200 width=0) (actual time=0.008..0.009 rows=3 loops=1)
                   Planning Time: 0.042 ms
                   Execution Time: 0.034 ms
 Planning Time: 0.668 ms
 Execution Time: 7.031 ms
(14 rows)
```

## 3. Scaling Out (Adding Nodes)

Initially, all shards reside on the coordinator. You must reguister the worker nodes to scale the cluster.

- **Set the coordinator** Designate the current host `popos.lan` as the coordinator.

```sql
select citus_set_coordinator_host('popos.lan', 5432);
 citus_set_coordinator_host
----------------------------
(1 row)
```

- **Add Worker Nodes** Add the worker nodes (`citus01.lan` and `citus02.lan`) to the cluster:

```sql
(1 row)
citusdb=# select * from citus_add_node('citus01.lan', 5432);
NOTICE:  shards are still on the coordinator after adding the new node
HINT:  Use SELECT rebalance_table_shards(); to balance shards data between workers and coordinator or SELECT citus_drain_node('popos.lan',5432); to permanently move shards away from the coordinator.
 citus_add_node
----------------
              3
(1 row)

citusdb=# select * from citus_add_node('citus02.lan', 5432);
 citus_add_node
----------------
              4
(1 row)
```

_Note: At this stage, shards are still on the coordinator_

- **Verify Active Workers** Ensure the nodes are recognized.

```sql
citusdb=# select * from citus_get_active_worker_nodes();
  node_name  | node_port
-------------+-----------
 citus01.lan |      5432
 citus02.lan |      5432
(2 rows)

citusdb=#

```

## 4. Rebalancing and Verification

Move data to the new nodes and verify that queries are routing correctly.

- **Rebalance Shards** Run the rebalancer to move shards from the coordinator t othe new workers:

```sql
citusdb=# select rebalance_table_shards();
NOTICE:  Moving shard 102016 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102009 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102008 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102011 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102021 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102022 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102031 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102032 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102036 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102038 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102012 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102014 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102017 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102024 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102027 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102028 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102029 from popos.lan:5432 to citus02.lan:5432 ...
NOTICE:  Moving shard 102030 from popos.lan:5432 to citus01.lan:5432 ...
NOTICE:  Moving shard 102035 from popos.lan:5432 to citus02.lan:5432 ...
 rebalance_table_shards
------------------------

(1 row)
```

- **Verify Shard Placement** Check `pg_disk_shard_placement` to see where shards are located. You will see a mix of `popos.lan` and other nodes depending on the rebalance status:

```sql
citusdb=# select * from pg_dist_shard_placement limit 10;
 shardid | shardstate | shardlength | nodename  | nodeport | placementid
---------+------------+-------------+-----------+----------+-------------
  102010 |          1 |           0 | popos.lan |     5432 |           3
  102013 |          1 |           0 | popos.lan |     5432 |           6
  102015 |          1 |           0 | popos.lan |     5432 |           8
  102018 |          1 |           0 | popos.lan |     5432 |          11
  102019 |          1 |           0 | popos.lan |     5432 |          12
  102020 |          1 |           0 | popos.lan |     5432 |          13
  102023 |          1 |           0 | popos.lan |     5432 |          16
  102025 |          1 |           0 | popos.lan |     5432 |          18
  102026 |          1 |           0 | popos.lan |     5432 |          19
  102033 |          1 |           0 | popos.lan |     5432 |          26
(10 rows)
```

- **Test Distributed Queries** Run `explain (analyze)` to confirm that queries are routing to specific worker nodes based on the distribution column (`bid`).
  - **Query routing to Node 1** (`citus01.lan`):

  ```sql
  citusdb=# explain(analyze) select * from pgbench_accounts where bid=5;
                                                                           QUERY PLAN
  ------------------------------------------------------------------------------------------------------------------------------------------------------------
   Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=0 width=0) (actual time=1004.129..1013.223 rows=100000 loops=1)
     Task Count: 1
     Tuple data received from nodes: 9375 kB
     Tasks Shown: All
     ->  Task
           Tuple data received from node: 9375 kB
           Node: host=citus01.lan port=5432 dbname=citusdb
           ->  Seq Scan on pgbench_accounts_102014 pgbench_accounts  (cost=0.00..5832.00 rows=99873 width=97) (actual time=0.007..13.018 rows=100000 loops=1)
                 Filter: (bid = 5)
                 Rows Removed by Filter: 100000
               Planning Time: 0.031 ms
               Execution Time: 25.675 ms
   Planning Time: 0.089 ms
   Execution Time: 1018.872 ms
  (14 rows)
  ```

  - **Query routing to Node 2** (`citus02.lan`):

  ```sql
  citusdb=# explain(analyze) select * from pgbench_accounts where bid=56;
                                                                            QUERY PLAN
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------
   Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=0 width=0) (actual time=1767.131..1773.156 rows=100000 loops=1)
     Task Count: 1
     Tuple data received from nodes: 9375 kB
     Tasks Shown: All
     ->  Task
           Tuple data received from node: 9375 kB
           Node: host=citus02.lan port=5432 dbname=citusdb
           ->  Seq Scan on pgbench_accounts_102031 pgbench_accounts  (cost=0.00..8682.00 rows=99400 width=97) (actual time=418.063..536.884 rows=100000 loops=1)
                 Filter: (bid = 56)
                 Rows Removed by Filter: 200000
               Planning Time: 0.255 ms
               Execution Time: 558.302 ms
   Planning Time: 0.076 ms
   Execution Time: 1777.002 ms
  (14 rows)

  ```
