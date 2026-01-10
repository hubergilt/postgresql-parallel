# PostgreSQL Parallel Stored Procedure Execution

Examples demonstrating multiple approaches for executing PostgreSQL stored procedures in parallel to overcome sequential execution limitations.

## 📋 Overview

This repository provides practical implementations for running PostgreSQL stored procedures in parallel using four different methods:

| Method            | Approach                      | Best Use Case                     |
| ----------------- | ----------------------------- | --------------------------------- |
| **dblink**        | Multiple database connections | Standard PostgreSQL environments  |
| **pg_background** | Background worker processes   | Lower overhead parallel tasks     |
| **Citus**         | Distributed PostgreSQL        | Large-scale distributed workloads |
| **TimescaleDB**   | Time-series optimization      | Parallel time-series operations   |

## 📂 Project Structure

```
postgresql-parallel/
├── dblink/ # Using dblink extension for parallel connections
│ ├── README.md # Dblink extension tutorial
│ └── primes.sql # Parallel execution script example to find prime numbers
├── pg_background/ # Using pg_background extension
│ ├── README.md # Background extension tutorial
│ └── primes.sql # Parallel execution script example to find prime numbers
├── citus/ # Using Citus distributed PostgreSQL
│ └── README.md # Citus extension tutorial
├── timescaledb/ # Using TimescaleDB capabilities
│ └── README.md # Timescaledb extension tutorial
└── README.md # This documentation
```
