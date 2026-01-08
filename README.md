# PostgreSQL Parallel Stored Procedure Execution

Examples demonstrating multiple approaches for executing PostgreSQL stored procedures in parallel to overcome sequential execution limitations.

## 📋 Overview

This repository provides practical implementations for running PostgreSQL stored procedures in parallel using four different methods:

| Method | Approach | Best Use Case |
|--------|----------|---------------|
| **dblink** | Multiple database connections | Standard PostgreSQL environments |
| **pg_background** | Background worker processes | Lower overhead parallel tasks |
| **Citus** | Distributed PostgreSQL | Large-scale distributed workloads |
| **TimescaleDB** | Time-series optimization | Parallel time-series operations |

## 📂 Project Structure
```
postgresql-parallel/
├── dblink/ # Using dblink extension for parallel connections
│ ├── setup.sql # Database setup
│ ├── procedures.sql # Example stored procedures
│ └── parallel.sql # Parallel execution logic
├── pg_background/ # Using pg_background extension
│ ├── setup.sql
│ ├── procedures.sql
│ └── parallel.sql
├── citus/ # Using Citus distributed PostgreSQL
│ ├── setup.sql # Citus cluster configuration
│ ├── sharding.sql # Table sharding for distribution
│ ├── procedures.sql # Distributed procedures
│ └── parallel.sql # Parallel execution across nodes
├── timescaledb/ # Using TimescaleDB capabilities
│ ├── setup.sql # TimescaleDB installation & setup
│ ├── hypertables.sql # Time-series table creation
│ ├── procedures.sql # Time-aware parallel procedures
│ └── parallel.sql # Parallel time-series operations
└── README.md # This documentation
```