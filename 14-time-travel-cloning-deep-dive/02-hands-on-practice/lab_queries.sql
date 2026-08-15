-- ============================================================================
-- LAB: Time Travel, Fail-safe & Cloning Deep Dive
-- ============================================================================
-- Run each step sequentially in Snowsight. Pause between steps to observe
-- results and let timestamps differentiate between operations.
-- ============================================================================


-- ============================================================================
-- STEP 1: Setup Environment
-- ============================================================================
-- Establish the session context. We use DATA_ENGINEER role and TASK_WH warehouse.

USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;

-- Create a dedicated schema for this lab
CREATE OR REPLACE SCHEMA TIME_TRAVEL_LAB;
USE SCHEMA TIME_TRAVEL_LAB;


-- ============================================================================
-- STEP 2: Create Sample Table with Data
-- ============================================================================
-- We create a table with enough rows to make time travel queries meaningful.

CREATE OR REPLACE TABLE employees (
    emp_id      INT,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    department  VARCHAR(50),
    salary      NUMBER(10,2),
    hire_date   DATE
);

INSERT INTO employees VALUES
    (1, 'Alice',   'Johnson',  'Engineering', 95000.00, '2021-03-15'),
    (2, 'Bob',     'Smith',    'Marketing',   72000.00, '2020-07-01'),
    (3, 'Charlie', 'Brown',    'Engineering', 88000.00, '2022-01-10'),
    (4, 'Diana',   'Prince',   'Sales',       67000.00, '2021-11-20'),
    (5, 'Eve',     'Davis',    'Engineering', 102000.00, '2019-05-08'),
    (6, 'Frank',   'Miller',   'Marketing',   69000.00, '2023-02-14'),
    (7, 'Grace',   'Lee',      'Sales',       71000.00, '2022-08-30'),
    (8, 'Henry',   'Wilson',   'Engineering', 91000.00, '2020-12-01');

-- Verify the data
SELECT * FROM employees ORDER BY emp_id;

-- Record the current timestamp for later use
-- OBSERVE: Note this timestamp — we will reference it in Step 5
SELECT CURRENT_TIMESTAMP() AS baseline_timestamp;


-- ============================================================================
-- STEP 3: Make Changes (UPDATE, DELETE) and Note Timestamps
-- ============================================================================
-- IMPORTANT: Wait at least 5-10 seconds between this step and Step 2
-- so that the time travel offset works reliably.

-- Give Engineering a 10% raise
UPDATE employees
SET salary = salary * 1.10
WHERE department = 'Engineering';

-- OBSERVE: 4 rows should be updated
-- Note the query ID for this update — we'll use it in Step 6
SELECT LAST_QUERY_ID() AS update_query_id;

-- Record timestamp after the update
SELECT CURRENT_TIMESTAMP() AS post_update_timestamp;

-- Now delete some rows
DELETE FROM employees
WHERE department = 'Marketing';

-- OBSERVE: 2 rows deleted (Bob and Frank)
SELECT LAST_QUERY_ID() AS delete_query_id;

-- Current state: Engineering salaries increased, Marketing rows gone
SELECT * FROM employees ORDER BY emp_id;


-- ============================================================================
-- STEP 4: Query Historical Data with AT(OFFSET => -60)
-- ============================================================================
-- OFFSET is in seconds. -60 means "the state 60 seconds ago."
-- If you ran Step 3 less than 60 seconds ago, increase the offset or wait.

-- This should show the ORIGINAL data before any updates or deletes
SELECT * FROM employees AT(OFFSET => -60) ORDER BY emp_id;

-- OBSERVE: You should see:
--   - All 8 rows (including Marketing employees)
--   - Original salary values (no 10% raise applied)
-- If you still see modified data, increase the offset (e.g., -120).


-- ============================================================================
-- STEP 5: Query with AT(TIMESTAMP => ...)
-- ============================================================================
-- Replace the timestamp below with the one you noted in Step 2.
-- This lets you travel to an exact point in time.

-- Option A: Use a variable (run these two lines together)
SET baseline_ts = (SELECT CURRENT_TIMESTAMP() - INTERVAL '2 minutes');
SELECT * FROM employees AT(TIMESTAMP => $baseline_ts) ORDER BY emp_id;

-- Option B: Hardcode a timestamp (replace with your actual value from Step 2)
-- SELECT * FROM employees AT(TIMESTAMP => '2025-01-15 10:30:00.000'::TIMESTAMP_LTZ)
-- ORDER BY emp_id;

-- OBSERVE: Results should match the original 8 rows with original salaries.
-- AT(TIMESTAMP) is precise — useful for recovering data at a known point.


-- ============================================================================
-- STEP 6: Query with BEFORE(STATEMENT => last_query_id)
-- ============================================================================
-- BEFORE(STATEMENT => ...) shows data as it was immediately BEFORE a statement ran.
-- This is the most precise method — no guessing about timestamps.

-- First, let's get the query ID of our UPDATE statement
-- (If you saved it from Step 3, use that. Otherwise, find it in query history.)

-- Show data as it was BEFORE the most recent DELETE
SELECT * FROM employees BEFORE(STATEMENT => LAST_QUERY_ID()) ORDER BY emp_id;

-- OBSERVE: This won't work as expected because LAST_QUERY_ID() now points to
-- a SELECT. Let's use the saved query IDs instead.

-- To use a specific query ID, replace 'your_query_id_here':
-- SELECT * FROM employees BEFORE(STATEMENT => '01b2c3d4-0000-abcd-0000-000000000000')
-- ORDER BY emp_id;

-- Practical approach: use a variable
-- SET my_delete_id = 'paste-your-delete-query-id-here';
-- SELECT * FROM employees BEFORE(STATEMENT => $my_delete_id) ORDER BY emp_id;

-- OBSERVE: BEFORE the DELETE, you'd see 8 rows with updated salaries (post-UPDATE).
-- BEFORE the UPDATE, you'd see 8 rows with original salaries.


-- ============================================================================
-- STEP 7: Compare Current vs Historical (Side by Side)
-- ============================================================================
-- Use time travel to detect exactly what changed. This is powerful for auditing.

-- Compare current salaries vs 2-minute-ago salaries for Engineering
SELECT
    curr.emp_id,
    curr.first_name,
    curr.last_name,
    hist.salary AS old_salary,
    curr.salary AS new_salary,
    curr.salary - hist.salary AS salary_change
FROM employees curr
JOIN employees AT(OFFSET => -120) hist
    ON curr.emp_id = hist.emp_id
WHERE curr.department = 'Engineering'
ORDER BY curr.emp_id;

-- OBSERVE: Each Engineering employee shows a ~10% increase.
-- This pattern is invaluable for change detection and auditing.

-- Find deleted rows (rows that existed before but not now)
SELECT hist.*
FROM employees AT(OFFSET => -120) hist
LEFT JOIN employees curr ON hist.emp_id = curr.emp_id
WHERE curr.emp_id IS NULL;

-- OBSERVE: Shows the Marketing employees (Bob, Frank) that were deleted.


-- ============================================================================
-- STEP 8: UNDROP Table
-- ============================================================================
-- Drop a table, then recover it using UNDROP. Simulates accidental deletion.

-- First, create a table we can safely drop
CREATE OR REPLACE TABLE temp_reports (
    report_id INT,
    report_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO temp_reports VALUES (1, 'Q1 Revenue', DEFAULT), (2, 'Q2 Forecast', DEFAULT);
SELECT * FROM temp_reports;

-- Now "accidentally" drop it
DROP TABLE temp_reports;

-- Verify it's gone
-- SELECT * FROM temp_reports;  -- This would error: object does not exist

-- Recover it!
UNDROP TABLE temp_reports;

-- Verify recovery
SELECT * FROM temp_reports;

-- OBSERVE: The table is fully restored with all its data intact.
-- UNDROP works within the Time Travel retention period (default 1 day).
-- After retention expires, data moves to Fail-safe (7 days, Snowflake-managed, no self-service).


-- ============================================================================
-- STEP 9: UNDROP Schema Demo
-- ============================================================================
-- UNDROP also works at the schema level, recovering all objects within.

-- Create a temporary schema with objects
CREATE OR REPLACE SCHEMA undrop_demo;
USE SCHEMA undrop_demo;

CREATE TABLE demo_table_a (id INT, value VARCHAR(20));
INSERT INTO demo_table_a VALUES (1, 'alpha'), (2, 'beta');

CREATE TABLE demo_table_b (id INT, score FLOAT);
INSERT INTO demo_table_b VALUES (1, 99.5), (2, 87.3);

-- Verify objects exist
SHOW TABLES IN SCHEMA undrop_demo;

-- Drop the entire schema
DROP SCHEMA undrop_demo;

-- Verify it's gone
-- SHOW TABLES IN SCHEMA undrop_demo;  -- Would error

-- Recover the schema and ALL its objects
UNDROP SCHEMA undrop_demo;

-- Verify everything is back
USE SCHEMA undrop_demo;
SHOW TABLES IN SCHEMA undrop_demo;
SELECT * FROM demo_table_a;
SELECT * FROM demo_table_b;

-- OBSERVE: Both tables and their data are fully recovered.
-- Switch back to our main lab schema
USE SCHEMA TIME_TRAVEL_LAB;


-- ============================================================================
-- STEP 10: Zero-Copy Clone a Table (CLONE Keyword)
-- ============================================================================
-- Cloning creates an instant copy that shares storage with the source
-- until either object is modified. No data is physically copied at creation.

-- Clone the employees table
CREATE TABLE employees_clone CLONE employees;

-- Verify the clone has the same data
SELECT * FROM employees_clone ORDER BY emp_id;

-- OBSERVE: The clone is instant regardless of table size.
-- Both tables point to the same underlying micro-partitions.
-- Storage cost at this point: essentially zero additional storage.


-- ============================================================================
-- STEP 11: Verify Clone is Independent (Modify Clone, Check Original)
-- ============================================================================
-- Changes to the clone do NOT affect the original (and vice versa).

-- Modify the clone
UPDATE employees_clone SET salary = 0 WHERE department = 'Sales';
DELETE FROM employees_clone WHERE emp_id = 1;

-- Check the clone (modified)
SELECT * FROM employees_clone ORDER BY emp_id;

-- Check the original (should be unchanged)
SELECT * FROM employees ORDER BY emp_id;

-- OBSERVE: The original table is completely unaffected by clone modifications.
-- After modification, only the changed micro-partitions consume new storage.
-- This is "zero-copy" — storage is shared until divergence occurs.


-- ============================================================================
-- STEP 12: Clone Entire Schema
-- ============================================================================
-- You can clone entire schemas (and databases) — all objects are cloned.

CREATE SCHEMA TIME_TRAVEL_LAB_BACKUP CLONE TIME_TRAVEL_LAB;

-- Verify the cloned schema has all objects
SHOW TABLES IN SCHEMA TIME_TRAVEL_LAB_BACKUP;

-- Spot-check data in the cloned schema
SELECT * FROM TIME_TRAVEL_LAB_BACKUP.employees ORDER BY emp_id;

-- OBSERVE: All tables, views, and other objects are cloned.
-- Schema/database cloning is powerful for creating dev/test environments instantly.
-- Grants (privileges) are NOT cloned by default (use COPY GRANTS option if needed).


-- ============================================================================
-- STEP 13: Check Storage with TABLE_STORAGE_METRICS
-- ============================================================================
-- This view shows active, time travel, and fail-safe bytes for each table.

SELECT
    table_catalog,
    table_schema,
    table_name,
    active_bytes,
    time_travel_bytes,
    failsafe_bytes,
    retained_for_clone_bytes,
    is_transient
FROM TASK_PRACTICE_DB.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE table_schema = 'TIME_TRAVEL_LAB'
  AND table_catalog = 'TASK_PRACTICE_DB'
ORDER BY table_name;

-- OBSERVE:
--   - ACTIVE_BYTES: current storage for live data
--   - TIME_TRAVEL_BYTES: storage for historical versions (increases after DML)
--   - FAILSAFE_BYTES: data in 7-day fail-safe (Snowflake-managed, Enterprise+)
--   - RETAINED_FOR_CLONE_BYTES: data kept because a clone still references it
--   - Tables we modified (employees, employees_clone) will show time_travel_bytes > 0


-- ============================================================================
-- STEP 14: Retention Settings (ALTER TABLE SET DATA_RETENTION_TIME_IN_DAYS)
-- ============================================================================
-- Time Travel retention can be 0-1 days (Standard) or 0-90 days (Enterprise+).
-- Default is 1 day. Longer retention = more storage cost but longer recovery window.

-- Check current retention setting
SHOW TABLES LIKE 'employees' IN SCHEMA TIME_TRAVEL_LAB;
-- Look for the "retention_time" column in the output

-- Increase retention to 5 days (requires Enterprise edition or higher)
ALTER TABLE employees SET DATA_RETENTION_TIME_IN_DAYS = 5;

-- Verify the change
SHOW TABLES LIKE 'employees' IN SCHEMA TIME_TRAVEL_LAB;

-- OBSERVE: The retention_time column now shows 5.
-- This means you can query up to 5 days of history for this table.
-- After 5 days, data moves to Fail-safe for 7 more days (not user-accessible).

-- Set retention to 0 (disables Time Travel — use cautiously!)
-- ALTER TABLE employees SET DATA_RETENTION_TIME_IN_DAYS = 0;
-- With 0 days: no UNDROP, no AT/BEFORE queries, no recovery. Data goes straight
-- to Fail-safe (if permanent table) or is purged immediately (if transient).

-- Reset to a reasonable value
ALTER TABLE employees SET DATA_RETENTION_TIME_IN_DAYS = 1;


-- ============================================================================
-- STEP 15: Transient Table Behavior
-- ============================================================================
-- Transient tables have Time Travel (0 or 1 day max) but NO Fail-safe.
-- Use them for staging/ETL data where loss is acceptable.

CREATE OR REPLACE TRANSIENT TABLE staging_orders (
    order_id    INT,
    customer_id INT,
    amount      NUMBER(10,2),
    order_date  DATE
);

INSERT INTO staging_orders VALUES
    (101, 1, 250.00, '2024-01-15'),
    (102, 2, 180.00, '2024-01-16'),
    (103, 1, 320.00, '2024-01-17');

-- Verify it's transient
SHOW TABLES LIKE 'staging_orders' IN SCHEMA TIME_TRAVEL_LAB;
-- Look for "is_transient" = Y and "retention_time" column

-- Transient tables max out at 1 day of retention
-- This will FAIL if you try more than 1 day:
-- ALTER TABLE staging_orders SET DATA_RETENTION_TIME_IN_DAYS = 2;  -- ERROR!

-- Set to 1 day (the maximum for transient)
ALTER TABLE staging_orders SET DATA_RETENTION_TIME_IN_DAYS = 1;

-- Check storage — notice failsafe_bytes will always be 0 for transient tables
SELECT
    table_name,
    active_bytes,
    time_travel_bytes,
    failsafe_bytes,
    is_transient
FROM TASK_PRACTICE_DB.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE table_schema = 'TIME_TRAVEL_LAB'
  AND table_name = 'STAGING_ORDERS';

-- OBSERVE:
--   - is_transient = 'YES'
--   - failsafe_bytes = 0 (transient tables skip fail-safe entirely)
--   - Temporary tables behave similarly but are also session-scoped
--   - Cost savings: no 7-day fail-safe storage overhead

-- Summary of table types and data protection:
-- +-------------+-------------------+-----------+
-- | Table Type  | Time Travel (max) | Fail-safe |
-- +-------------+-------------------+-----------+
-- | Permanent   | 90 days (Ent+)    | 7 days    |
-- | Transient   | 1 day             | 0 days    |
-- | Temporary   | 1 day             | 0 days    |
-- +-------------+-------------------+-----------+


-- ============================================================================
-- STEP 16: Cleanup
-- ============================================================================
-- Remove all lab objects to free storage and keep the account tidy.

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS employees_clone;
DROP TABLE IF EXISTS temp_reports;
DROP TABLE IF EXISTS staging_orders;
DROP SCHEMA IF EXISTS TIME_TRAVEL_LAB_BACKUP;
DROP SCHEMA IF EXISTS undrop_demo;
DROP SCHEMA IF EXISTS TIME_TRAVEL_LAB;

-- OBSERVE: All objects removed. In a real scenario, dropped objects enter
-- Time Travel (and then Fail-safe for permanent objects) before storage is freed.
-- You could UNDROP any of these within the retention period if needed.

-- ============================================================================
-- END OF LAB
-- ============================================================================
-- Key Takeaways:
--   1. Time Travel enables querying historical data via AT/BEFORE clauses
--   2. UNDROP recovers accidentally dropped tables, schemas, and databases
--   3. Zero-copy cloning creates instant copies with no initial storage cost
--   4. Clones are fully independent — changes don't propagate
--   5. DATA_RETENTION_TIME_IN_DAYS controls the Time Travel window
--   6. Transient/temporary tables sacrifice Fail-safe for lower storage costs
--   7. TABLE_STORAGE_METRICS reveals the true storage breakdown
-- ============================================================================
