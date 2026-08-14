-- =============================================================================
-- SNOWPIPE HANDS-ON LAB - COMPLETE QUERY REFERENCE
-- =============================================================================
-- Database: TASK_PRACTICE_DB | Schema: SNOWPIPE_LAB
-- Role: DATA_ENGINEER | Warehouse: TASK_WH
-- Executed: August 14, 2026
-- =============================================================================

-- ============================================
-- SECTION 1: SETUP (Role, Database, Schema)
-- ============================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;

-- Create dedicated schema for Snowpipe practice
CREATE SCHEMA IF NOT EXISTS SNOWPIPE_LAB COMMENT = 'Snowpipe hands-on practice';
USE SCHEMA SNOWPIPE_LAB;

-- ============================================
-- SECTION 2: FILE FORMAT & STAGE
-- ============================================

-- Create a file format (tells Snowflake how to parse CSV files)
CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('NULL', 'null', '')
  COMMENT = 'Standard CSV with header';

-- Create an internal named stage
CREATE OR REPLACE STAGE raw_data_stage
  FILE_FORMAT = csv_format
  COMMENT = 'Internal stage for Snowpipe practice';

-- ============================================
-- SECTION 3: TARGET TABLE
-- ============================================

CREATE OR REPLACE TABLE customer_orders (
  order_id       INT,
  customer_name  VARCHAR(100),
  product        VARCHAR(100),
  quantity       INT,
  order_amount   DECIMAL(10,2),
  order_date     DATE,
  region         VARCHAR(50),
  loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================
-- SECTION 4: UPLOAD DATA TO STAGE
-- ============================================

-- Batch 1: Create temp table and unload to stage
CREATE OR REPLACE TEMPORARY TABLE temp_orders AS
SELECT * FROM VALUES
  (1001, 'Ravi Kumar', 'Laptop', 2, 1500.00, '2026-08-01'::DATE, 'South'),
  (1002, 'Priya Sharma', 'Mouse', 10, 250.00, '2026-08-02'::DATE, 'North'),
  (1003, 'Amit Patel', 'Keyboard', 5, 375.00, '2026-08-03'::DATE, 'West'),
  (1004, 'Sneha Reddy', 'Monitor', 3, 2100.00, '2026-08-04'::DATE, 'South'),
  (1005, 'Vikram Singh', 'Headphones', 20, 600.00, '2026-08-05'::DATE, 'East'),
  (1006, 'Deepa Nair', 'Webcam', 8, 480.00, '2026-08-06'::DATE, 'West'),
  (1007, 'Rajesh Gupta', 'SSD Drive', 4, 520.00, '2026-08-07'::DATE, 'North'),
  (1008, 'Meena Iyer', 'Tablet', 1, 899.00, '2026-08-08'::DATE, 'East')
  AS t(order_id, customer_name, product, quantity, order_amount, order_date, region);

COPY INTO @raw_data_stage/batch_01/orders_aug_week1.csv
FROM temp_orders
FILE_FORMAT = (TYPE='CSV')
OVERWRITE = TRUE
SINGLE = TRUE
HEADER = TRUE;

-- Batch 2
CREATE OR REPLACE TEMPORARY TABLE temp_orders_2 AS
SELECT * FROM VALUES
  (1009, 'Arjun Das', 'Printer', 2, 780.00, '2026-08-09'::DATE, 'North'),
  (1010, 'Kavita Joshi', 'Router', 6, 420.00, '2026-08-10'::DATE, 'South'),
  (1011, 'Suresh Menon', 'Speaker', 3, 315.00, '2026-08-11'::DATE, 'West'),
  (1012, 'Anita Roy', 'Charger', 15, 225.00, '2026-08-12'::DATE, 'East'),
  (1013, 'Prakash Rao', 'USB Hub', 10, 150.00, '2026-08-13'::DATE, 'South')
  AS t(order_id, customer_name, product, quantity, order_amount, order_date, region);

COPY INTO @raw_data_stage/batch_02/orders_aug_week2.csv
FROM temp_orders_2
FILE_FORMAT = (TYPE='CSV')
OVERWRITE = TRUE
SINGLE = TRUE
HEADER = TRUE;

-- List files in stage
LIST @raw_data_stage;

-- ============================================
-- SECTION 5: CREATE SNOWPIPE
-- ============================================

CREATE OR REPLACE PIPE customer_orders_pipe
  COMMENT = 'Loads customer orders from internal stage'
  AS
  COPY INTO customer_orders (order_id, customer_name, product, quantity, order_amount, order_date, region)
  FROM @raw_data_stage
  FILE_FORMAT = csv_format
  ON_ERROR = 'SKIP_FILE';

-- ============================================
-- SECTION 6: PIPE STATUS & TRIGGER
-- ============================================

-- Check pipe status (real-time)
SELECT SYSTEM$PIPE_STATUS('TASK_PRACTICE_DB.SNOWPIPE_LAB.CUSTOMER_ORDERS_PIPE');

-- Trigger pipe to scan stage and load files
ALTER PIPE customer_orders_pipe REFRESH;

-- Refresh only specific prefix
ALTER PIPE customer_orders_pipe REFRESH PREFIX = 'batch_01/';

-- Refresh with timestamp filter (for backfill)
ALTER PIPE customer_orders_pipe REFRESH
  PREFIX = 'batch_02/'
  MODIFIED_AFTER = '2026-08-14T00:00:00Z';

-- ============================================
-- SECTION 7: VERIFY DATA LOADED
-- ============================================

SELECT COUNT(*) AS total_rows FROM customer_orders;
SELECT * FROM customer_orders ORDER BY order_id;

-- ============================================
-- SECTION 8: LOAD HISTORY (14 days)
-- ============================================

-- Method 1: COPY_HISTORY (Information Schema) - 14 day retention, real-time
SELECT
  FILE_NAME,
  STAGE_LOCATION,
  STATUS,
  ROW_COUNT,
  ROW_PARSED,
  FILE_SIZE,
  ERROR_COUNT,
  FIRST_ERROR_MESSAGE,
  PIPE_CATALOG_NAME || '.' || PIPE_SCHEMA_NAME || '.' || PIPE_NAME AS pipe_full_name,
  LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'CUSTOMER_ORDERS',
  START_TIME => DATEADD(HOURS, -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;

-- Method 2: Check for failed loads only
SELECT FILE_NAME, FIRST_ERROR_MESSAGE, LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'CUSTOMER_ORDERS',
  START_TIME => DATEADD(DAYS, -7, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'Load failed';

-- ============================================
-- SECTION 9: CREDIT USAGE
-- ============================================

-- Real-time credit check (Information Schema - 14 days)
SELECT
  PIPE_NAME,
  START_TIME,
  END_TIME,
  CREDITS_USED,
  BYTES_INSERTED,
  FILES_INSERTED
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  DATE_RANGE_START => DATEADD(HOURS, -24, CURRENT_TIMESTAMP()),
  DATE_RANGE_END => CURRENT_TIMESTAMP(),
  PIPE_NAME => 'TASK_PRACTICE_DB.SNOWPIPE_LAB.CUSTOMER_ORDERS_PIPE'
));

-- Long-term credit history (Account Usage - 365 days, requires ACCOUNTADMIN)
-- USE ROLE ACCOUNTADMIN;
-- SELECT PIPE_NAME, SUM(CREDITS_USED) as total_credits, SUM(FILES_INSERTED) as files
-- FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
-- WHERE START_TIME >= DATEADD(DAYS, -30, CURRENT_TIMESTAMP())
-- GROUP BY PIPE_NAME ORDER BY total_credits DESC;

-- ============================================
-- SECTION 10: PIPE MANAGEMENT
-- ============================================

-- Pause the pipe
ALTER PIPE customer_orders_pipe SET PIPE_EXECUTION_PAUSED = TRUE;

-- Check status (should show PAUSED)
SELECT SYSTEM$PIPE_STATUS('TASK_PRACTICE_DB.SNOWPIPE_LAB.CUSTOMER_ORDERS_PIPE');

-- Resume the pipe
ALTER PIPE customer_orders_pipe SET PIPE_EXECUTION_PAUSED = FALSE;

-- Show pipe details
SHOW PIPES LIKE 'CUSTOMER_ORDERS_PIPE';

-- Describe pipe definition
DESCRIBE PIPE customer_orders_pipe;

-- ============================================
-- SECTION 11: ERROR HANDLING TEST
-- ============================================

-- Create a bad file
CREATE OR REPLACE TEMPORARY TABLE temp_bad_data AS
SELECT * FROM VALUES
  (9001, 'Bad Record', 'Widget', 'NOT_A_NUMBER', 100.00, '2026-08-14'::DATE, 'North')
  AS t(order_id, customer_name, product, quantity, order_amount, order_date, region);

COPY INTO @raw_data_stage/batch_03/orders_bad_data.csv
FROM temp_bad_data
FILE_FORMAT = (TYPE='CSV')
OVERWRITE = TRUE
SINGLE = TRUE
HEADER = TRUE;

-- Trigger pipe to pick up the bad file
ALTER PIPE customer_orders_pipe REFRESH PREFIX = 'batch_03/';

-- Check for errors in load history
SELECT FILE_NAME, STATUS, ERROR_COUNT, FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'CUSTOMER_ORDERS',
  START_TIME => DATEADD(MINUTES, -10, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'Load failed';

-- ============================================
-- SECTION 12: DUPLICATE PREVENTION TEST
-- ============================================

-- Refresh same files again - Snowpipe will NOT reload (14-day dedup)
ALTER PIPE customer_orders_pipe REFRESH;

-- Verify no duplicates
SELECT order_id, COUNT(*) AS cnt
FROM customer_orders
GROUP BY order_id
HAVING cnt > 1;

-- ============================================
-- SECTION 13: CREATE OR REPLACE DANGER DEMO
-- ============================================

-- WARNING: This PURGES load history!
CREATE OR REPLACE PIPE customer_orders_pipe
  COMMENT = 'RECREATED - load history PURGED!'
  AS
  COPY INTO customer_orders (order_id, customer_name, product, quantity, order_amount, order_date, region)
  FROM @raw_data_stage
  FILE_FORMAT = csv_format
  ON_ERROR = 'SKIP_FILE';

-- Refresh now reloads everything (pipe forgot what it already loaded)
ALTER PIPE customer_orders_pipe REFRESH;

-- Check for duplicates (WILL HAVE DUPLICATES!)
SELECT order_id, COUNT(*) AS cnt
FROM customer_orders
GROUP BY order_id
HAVING cnt > 1;

-- ============================================
-- SECTION 14: CLEANUP
-- ============================================

-- Pause pipe (stop billing)
ALTER PIPE customer_orders_pipe SET PIPE_EXECUTION_PAUSED = TRUE;

-- To fully clean up (run if you want to remove everything):
-- DROP PIPE customer_orders_pipe;
-- DROP TABLE customer_orders;
-- DROP STAGE raw_data_stage;
-- DROP FILE FORMAT csv_format;
-- DROP SCHEMA SNOWPIPE_LAB;
