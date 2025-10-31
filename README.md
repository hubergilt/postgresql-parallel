# Ejemplos para ejecutar procedimientos almacenados en paralelo con postgresql

## Usando la extension dblink

- Ejemplo ejecucion en paralello de 8 procedimientos alamacenados ( con sleep de 3 segundos )
- Ejemplo ejecution en parallello de 1 Procedimiento almacenado ( calcula la suma de los 100000 numeros primos ) y 7 procedimientos almacenado (con sleep de 2 segundos)

## Usando la extension pg_background

- Ejemplo ejecucion en paralello de 8 procedimientos alamacenados ( con sleep de 3 segundos )
- Ejemplo de 1 Procedimiento almacenado ( calcula la suma de los 100000 numeros primos ) y 7 procedimientos almacenado (con sleep de 2 segundos)

```sql
parallel_demo=# call run_procedures_parallel();
NOTICE:  ========================================
NOTICE:  STARTING PARALLEL EXECUTION
NOTICE:  Time: 2025-10-30 22:05:11.113583
NOTICE:  ========================================
NOTICE:
NOTICE:  Phase 1: Launching all procedures...
NOTICE:    [1/8] Launched procedure1 (PID: 110200)
NOTICE:    [2/8] Launched procedure2 (PID: 110201)
NOTICE:    [3/8] Launched procedure3 (PID: 110202)
NOTICE:    [4/8] Launched procedure4 (PID: 110203)
NOTICE:    [5/8] Launched procedure5 (PID: 110204)
NOTICE:    [6/8] Launched procedure6 (PID: 110205)
NOTICE:    [7/8] Launched procedure7 (PID: 110206)
NOTICE:    [8/8] Launched procedure8 (PID: 110207)
NOTICE:
NOTICE:  All procedures launched. Now waiting for completion...
NOTICE:
NOTICE:  Phase 2: Collecting results...
NOTICE:  Procedure 1 starting at 2025-10-30 22:05:11.117518
NOTICE:  Computing sum of first 100 prime numbers...
NOTICE:  Sum of first 100 prime numbers: 24133
NOTICE:  Procedure 1 completed at 2025-10-30 22:05:11.117987 (duration: 00:00:00.000469)
NOTICE:    [1/8] procedure1 completed successfully
NOTICE:  Procedure 2 starting at 2025-10-30 22:05:11.117448
NOTICE:  Procedure 2 completed at 2025-10-30 22:05:14.134108 (duration: 00:00:03.01666)
NOTICE:    [2/8] procedure2 completed successfully
NOTICE:  Procedure 3 starting at 2025-10-30 22:05:11.11818
NOTICE:  Procedure 3 completed at 2025-10-30 22:05:14.134496 (duration: 00:00:03.016316)
NOTICE:    [3/8] procedure3 completed successfully
NOTICE:  Procedure 4 starting at 2025-10-30 22:05:11.118306
NOTICE:  Procedure 4 completed at 2025-10-30 22:05:14.134698 (duration: 00:00:03.016392)
NOTICE:    [4/8] procedure4 completed successfully
NOTICE:  Procedure 5 starting at 2025-10-30 22:05:11.118552
NOTICE:  Procedure 5 completed at 2025-10-30 22:05:14.123052 (duration: 00:00:03.0045)
NOTICE:    [5/8] procedure5 completed successfully
NOTICE:  Procedure 6 starting at 2025-10-30 22:05:11.11948
NOTICE:  Procedure 6 completed at 2025-10-30 22:05:14.135369 (duration: 00:00:03.015889)
NOTICE:    [6/8] procedure6 completed successfully
NOTICE:  Procedure 7 starting at 2025-10-30 22:05:11.119354
NOTICE:  Procedure 7 completed at 2025-10-30 22:05:14.135077 (duration: 00:00:03.015723)
NOTICE:    [7/8] procedure7 completed successfully
NOTICE:  Procedure 8 starting at 2025-10-30 22:05:11.119752
NOTICE:  Procedure 8 completed at 2025-10-30 22:05:14.135753 (duration: 00:00:03.016001)
NOTICE:    [8/8] procedure8 completed successfully
NOTICE:
NOTICE:  ========================================
NOTICE:  PARALLEL EXECUTION COMPLETED
NOTICE:  Start time:  2025-10-30 22:05:11.113583
NOTICE:  End time:    2025-10-30 22:05:14.136896
NOTICE:  Duration:    00:00:03.023313
NOTICE:  Errors:      0
NOTICE:  ========================================
CALL
parallel_demo=# SELECT * FROM processing_log ORDER BY start_time;
 id | procedure_name |         start_time         |          end_time          |    duration     | status  |            message
----+----------------+----------------------------+----------------------------+-----------------+---------+--------------------------------
 18 | procedure2     | 2025-10-30 22:05:11.117448 | 2025-10-30 22:05:14.133866 | 00:00:03.01642  | SUCCESS | Processed dataset B
 16 | procedure1     | 2025-10-30 22:05:11.117518 | 2025-10-30 22:05:11.11835  | 00:00:00.000832 | SUCCESS | Sum of first 100 primes: 24133
 19 | procedure3     | 2025-10-30 22:05:11.11818  | 2025-10-30 22:05:14.134321 | 00:00:03.016143 | SUCCESS | Processed dataset C
 20 | procedure4     | 2025-10-30 22:05:11.118306 | 2025-10-30 22:05:14.134521 | 00:00:03.016216 | SUCCESS | Processed dataset D
 17 | procedure5     | 2025-10-30 22:05:11.118552 | 2025-10-30 22:05:14.122907 | 00:00:03.004357 | SUCCESS | Processed dataset E
 21 | procedure7     | 2025-10-30 22:05:11.119354 | 2025-10-30 22:05:14.134938 | 00:00:03.015585 | SUCCESS | Processed dataset G
 22 | procedure6     | 2025-10-30 22:05:11.11948  | 2025-10-30 22:05:14.13528  | 00:00:03.015801 | SUCCESS | Processed dataset F
 23 | procedure8     | 2025-10-30 22:05:11.119752 | 2025-10-30 22:05:14.135604 | 00:00:03.015853 | SUCCESS | Processed dataset H
(8 rows)
```
