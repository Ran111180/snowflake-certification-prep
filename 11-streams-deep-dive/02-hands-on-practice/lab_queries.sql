-- =============================================================================
-- STREAMS HANDS-ON LAB - COMPLETE QUERY REFERENCE
-- =============================================================================
-- Database: TASK_PRACTICE_DB | Schema: STREAMS_LAB
-- Role: DATA_ENGINEER | Warehouse: TASK_WH
-- Run each section one by one in Snowsight (select statement → Run)
-- =============================================================================

-- ============================================
-- STEP 1: SETUP
-- ============================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;
CREATE SCHEMA IF NOT EXISTS STREAMS_LAB COMMENT = 'Streams hands-on practice';
USE SCHEMA STREAMS_LAB;

-- ============================================
-- STEP 2: CREATE SOURCE TABLE
-- ============================================
CREATE OR REPLACE TABLE employees (
  emp_id       INT,
  name         VARCHAR(100),
  department   VARCHAR(50),
  salary       DECIMAL(10,2),
  status       VARCHAR(20) DEFAULT 'active',
  updated_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO employees (emp_id, name, department, salary) VALUES
  (1, 'Ravi Kumar', 'Engineering', 85000),
  (2, 'Priya Sharma', 'Marketing', 72000),
  (3, 'Amit Patel', 'Engineering', 90000),
  (4, 'Sneha Reddy', 'Sales', 68000),
  (5, 'Vikram Singh', 'HR', 75000);

SELECT * FROM employees ORDER BY emp_id;

-- ============================================
-- STEP 3: CREATE STANDARD STREAM
-- ============================================
CREATE OR REPLACE STREAM employees_stream
  ON TABLE employees
  COMMENT = 'Tracks all changes to employees table';

-- Check stream metadata
SHOW STREAMS LIKE 'employees_stream';

-- ============================================
-- STEP 4: VERIFY STREAM IS EMPTY (no changes since creation)
-- ============================================
SELECT * FROM employees_stream;
-- Expected: EMPTY (inserts happened BEFORE stream was created)

SELECT SYSTEM$STREAM_HAS_DATA('STREAMS_LAB.EMPLOYEES_STREAM') AS has_data;
-- Expected: FALSE

-- ============================================
-- STEP 5: MAKE DML CHANGES (INSERT, UPDATE, DELETE)
-- ============================================

-- INSERT: New employee
INSERT INTO employees (emp_id, name, department, salary) VALUES
  (6, 'Deepa Nair', 'Engineering', 92000);

-- UPDATE: Ravi got a raise
UPDATE employees SET salary = 95000, updated_at = CURRENT_TIMESTAMP()
WHERE emp_id = 1;

-- UPDATE: Sneha moved departments
UPDATE employees SET department = 'Marketing', updated_at = CURRENT_TIMESTAMP()
WHERE emp_id = 4;

-- DELETE: Vikram left
DELETE FROM employees WHERE emp_id = 5;

-- ============================================
-- STEP 6: QUERY THE STREAM - SEE CDC DATA!
-- ============================================
SELECT
  METADATA$ACTION AS action,
  METADATA$ISUPDATE AS is_update,
  METADATA$ROW_ID AS row_id,
  emp_id, name, department, salary
FROM employees_stream
ORDER BY emp_id, action;
-- Expected: 6 rows (updates = DELETE old + INSERT new with same ROW_ID)

-- ============================================
-- STEP 7: PROVE SELECT DOES NOT ADVANCE OFFSET
-- ============================================
SELECT COUNT(*) AS rows_still_in_stream FROM employees_stream;
-- Expected: Still 6 rows! SELECT doesn't consume.

-- ============================================
-- STEP 8: CONSUME THE STREAM (DML advances offset)
-- ============================================
CREATE OR REPLACE TABLE employees_changelog (
  change_id     INT AUTOINCREMENT,
  action        VARCHAR(10),
  is_update     BOOLEAN,
  emp_id        INT,
  name          VARCHAR(100),
  department    VARCHAR(50),
  salary        DECIMAL(10,2),
  captured_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- This INSERT INTO consumes the stream (offset advances!)
INSERT INTO employees_changelog (action, is_update, emp_id, name, department, salary)
SELECT
  METADATA$ACTION,
  METADATA$ISUPDATE,
  emp_id, name, department, salary
FROM employees_stream;

-- ============================================
-- STEP 9: VERIFY STREAM IS NOW EMPTY
-- ============================================
SELECT COUNT(*) AS stream_rows FROM employees_stream;
-- Expected: 0 (offset advanced, changes consumed)

-- Changelog has our audit trail
SELECT * FROM employees_changelog ORDER BY change_id;

-- ============================================
-- STEP 10: NEW CHANGES APPEAR IN STREAM
-- ============================================
INSERT INTO employees (emp_id, name, department, salary) VALUES
  (7, 'Kavita Joshi', 'Sales', 71000);
UPDATE employees SET salary = 98000 WHERE emp_id = 3;

-- Only NEW changes since last consumption
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, salary
FROM employees_stream ORDER BY emp_id;

-- ============================================
-- STEP 11: CREATE APPEND-ONLY STREAM (comparison)
-- ============================================

-- First consume standard stream to reset
INSERT INTO employees_changelog (action, is_update, emp_id, name, department, salary)
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, department, salary
FROM employees_stream;

-- Create append-only stream
CREATE OR REPLACE STREAM employees_append_stream
  ON TABLE employees
  APPEND_ONLY = TRUE
  COMMENT = 'Tracks only INSERTs - ignores updates and deletes';

-- Make all types of changes
INSERT INTO employees (emp_id, name, department, salary) VALUES
  (8, 'Rajesh Gupta', 'Finance', 82000);
UPDATE employees SET salary = 100000 WHERE emp_id = 6;
DELETE FROM employees WHERE emp_id = 2;

-- APPEND-ONLY: Shows only INSERT
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, salary
FROM employees_append_stream;
-- Expected: 1 row (only Rajesh INSERT)

-- STANDARD: Shows all changes
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, salary
FROM employees_stream ORDER BY emp_id, METADATA$ACTION;
-- Expected: Multiple rows (insert + update + delete)

-- ============================================
-- STEP 12: NET CHANGE DEMO (Standard Stream Magic)
-- ============================================

-- Consume both streams to reset
INSERT INTO employees_changelog (action, is_update, emp_id, name, department, salary)
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, department, salary
FROM employees_stream;

INSERT INTO employees_changelog (action, is_update, emp_id, name, department, salary)
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, department, salary
FROM employees_append_stream;

-- INSERT then DELETE before consuming = NET ZERO in Standard stream!
INSERT INTO employees (emp_id, name, department, salary) VALUES
  (99, 'Temporary Person', 'Temp', 50000);
DELETE FROM employees WHERE emp_id = 99;

-- Standard stream: EMPTY (insert + delete cancel out)
SELECT * FROM employees_stream;
-- Expected: EMPTY!

-- Append-only stream: Still shows the INSERT
SELECT METADATA$ACTION, emp_id, name FROM employees_append_stream;
-- Expected: 1 row (the INSERT, even though row was deleted)

-- ============================================
-- STEP 13: STREAMS + TASKS (Automated Pipeline)
-- ============================================

-- Consume remaining streams
INSERT INTO employees_changelog (action, is_update, emp_id, name, department, salary)
SELECT METADATA$ACTION, METADATA$ISUPDATE, emp_id, name, department, salary
FROM employees_append_stream;

-- Target dimension table
CREATE OR REPLACE TABLE dim_employees (
  emp_id       INT PRIMARY KEY,
  name         VARCHAR(100),
  department   VARCHAR(50),
  salary       DECIMAL(10,2),
  status       VARCHAR(20),
  last_synced  TIMESTAMP_NTZ
);

-- Task that auto-processes changes
CREATE OR REPLACE TASK sync_employees_task
  WAREHOUSE = TASK_WH
  SCHEDULE = '1 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('STREAMS_LAB.EMPLOYEES_STREAM')
AS
  MERGE INTO dim_employees t
  USING (
    SELECT emp_id, name, department, salary, status
    FROM employees_stream
    WHERE METADATA$ACTION = 'INSERT'
  ) s ON t.emp_id = s.emp_id
  WHEN MATCHED THEN
    UPDATE SET t.name = s.name, t.department = s.department,
              t.salary = s.salary, t.status = s.status,
              t.last_synced = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN
    INSERT (emp_id, name, department, salary, status, last_synced)
    VALUES (s.emp_id, s.name, s.department, s.salary, s.status, CURRENT_TIMESTAMP());

-- Resume task (IMPORTANT: tasks are created in suspended state)
ALTER TASK sync_employees_task RESUME;

-- ============================================
-- STEP 14: TRIGGER THE PIPELINE
-- ============================================

-- Insert data to trigger the task
INSERT INTO employees (emp_id, name, department, salary) VALUES
  (9, 'Meena Iyer', 'Engineering', 88000),
  (10, 'Suresh Menon', 'Marketing', 76000);
UPDATE employees SET salary = 105000 WHERE emp_id = 3;

-- Verify stream has data (task should fire within 1 minute)
SELECT SYSTEM$STREAM_HAS_DATA('STREAMS_LAB.EMPLOYEES_STREAM') AS has_data;
-- Expected: TRUE (will become FALSE after task runs)

-- ============================================
-- STEP 15: VERIFY TASK RAN SUCCESSFULLY
-- Wait 1-2 minutes then run these
-- ============================================

-- Check task history
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'SYNC_EMPLOYEES_TASK',
  SCHEDULED_TIME_RANGE_START => DATEADD(MINUTES, -5, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;

-- Check dim_employees got populated
SELECT * FROM dim_employees ORDER BY emp_id;

-- Verify stream was consumed
SELECT SYSTEM$STREAM_HAS_DATA('STREAMS_LAB.EMPLOYEES_STREAM') AS has_data;
-- Expected: FALSE (consumed by task)

-- ============================================
-- STEP 16: CLEANUP (Suspend task to save credits)
-- ============================================
ALTER TASK sync_employees_task SUSPEND;

-- To fully clean up (optional):
-- DROP TASK sync_employees_task;
-- DROP STREAM employees_stream;
-- DROP STREAM employees_append_stream;
-- DROP TABLE dim_employees;
-- DROP TABLE employees_changelog;
-- DROP TABLE employees;
-- DROP SCHEMA STREAMS_LAB;
