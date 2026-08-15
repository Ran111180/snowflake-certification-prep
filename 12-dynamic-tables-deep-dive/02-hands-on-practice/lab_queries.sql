-- ============================================================
-- DYNAMIC TABLES - Hands-On Lab
-- SnowPro Core Certification Practice
-- ============================================================
-- Run each section step by step in Snowsight
-- Observe results before moving to the next section
-- ============================================================

-- ============================================================
-- STEP 1: SETUP (Database, Schema, Warehouse, Role)
-- ============================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;

CREATE SCHEMA IF NOT EXISTS DYNAMIC_TABLES_LAB;
USE SCHEMA DYNAMIC_TABLES_LAB;

-- ============================================================
-- STEP 2: CREATE SOURCE TABLES (Raw Data - Bronze Layer)
-- ============================================================

-- Raw orders table (simulates incoming data)
CREATE OR REPLACE TABLE raw_orders (
    order_id INT,
    customer_id INT,
    product_name VARCHAR(100),
    quantity INT,
    unit_price DECIMAL(10,2),
    order_date TIMESTAMP_NTZ,
    status VARCHAR(20),
    region VARCHAR(50)
);

-- Customers reference table
CREATE OR REPLACE TABLE customers (
    customer_id INT,
    customer_name VARCHAR(100),
    email VARCHAR(200),
    segment VARCHAR(50),
    signup_date DATE
);

-- Insert sample customers
INSERT INTO customers VALUES
    (1, 'Alice Johnson', 'alice@example.com', 'Enterprise', '2024-01-15'),
    (2, 'Bob Smith', 'bob@example.com', 'SMB', '2024-03-20'),
    (3, 'Carol Davis', 'carol@example.com', 'Enterprise', '2024-02-10'),
    (4, 'David Wilson', 'david@example.com', 'Startup', '2024-06-01'),
    (5, 'Eva Martinez', 'eva@example.com', 'SMB', '2024-04-15');

-- Insert initial orders
INSERT INTO raw_orders VALUES
    (1001, 1, 'Laptop Pro', 2, 1299.99, '2026-08-01 10:00:00', 'COMPLETED', 'US-West'),
    (1002, 2, 'Keyboard', 5, 79.99, '2026-08-01 11:30:00', 'COMPLETED', 'US-East'),
    (1003, 3, 'Monitor 4K', 1, 549.99, '2026-08-02 09:00:00', 'COMPLETED', 'EU-West'),
    (1004, 1, 'Mouse Wireless', 3, 49.99, '2026-08-02 14:00:00', 'PENDING', 'US-West'),
    (1005, 4, 'Webcam HD', 2, 129.99, '2026-08-03 08:00:00', 'COMPLETED', 'US-East'),
    (1006, 5, 'Headset Pro', 1, 199.99, '2026-08-03 16:00:00', 'CANCELLED', 'EU-West'),
    (1007, 2, 'USB Hub', 4, 39.99, '2026-08-04 10:00:00', 'COMPLETED', 'US-East'),
    (1008, 3, 'Laptop Pro', 1, 1299.99, '2026-08-04 12:00:00', 'COMPLETED', 'EU-West'),
    (1009, 4, 'Monitor 4K', 2, 549.99, '2026-08-05 09:30:00', 'PENDING', 'US-East'),
    (1010, 1, 'Keyboard', 1, 79.99, '2026-08-05 15:00:00', 'COMPLETED', 'US-West');

-- Verify source data
SELECT COUNT(*) AS order_count FROM raw_orders;
SELECT COUNT(*) AS customer_count FROM customers;

-- ============================================================
-- STEP 3: CREATE FIRST DYNAMIC TABLE (Silver Layer - Cleaned)
-- ============================================================

-- This DT cleans and validates the raw data
CREATE OR REPLACE DYNAMIC TABLE silver_orders
    TARGET_LAG = '1 minute'
    WAREHOUSE = TASK_WH
AS
    SELECT
        order_id,
        customer_id,
        UPPER(TRIM(product_name)) AS product_name,
        quantity,
        unit_price,
        quantity * unit_price AS total_amount,
        order_date,
        status,
        UPPER(region) AS region
    FROM raw_orders
    WHERE order_id IS NOT NULL
      AND quantity > 0
      AND unit_price > 0;

-- ============================================================
-- STEP 4: VERIFY DYNAMIC TABLE CREATION
-- ============================================================

-- Check DT exists and status
SHOW DYNAMIC TABLES LIKE 'SILVER_ORDERS';

-- Query the DT (reads materialized data - fast!)
SELECT * FROM silver_orders ORDER BY order_id;

-- Check refresh mode (should be INCREMENTAL if possible)
SELECT NAME, REFRESH_MODE, SCHEDULING_STATE, TARGET_LAG
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE NAME = 'SILVER_ORDERS';

-- ============================================================
-- STEP 5: CREATE SECOND DT (Silver - Enriched with Customer Data)
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE silver_orders_enriched
    TARGET_LAG = DOWNSTREAM   -- Only refreshes when downstream needs it
    WAREHOUSE = TASK_WH
AS
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_name,
        c.segment,
        o.product_name,
        o.quantity,
        o.unit_price,
        o.total_amount,
        o.order_date,
        o.status,
        o.region
    FROM silver_orders o
    JOIN customers c ON o.customer_id = c.customer_id;

-- Verify the enriched DT
SELECT * FROM silver_orders_enriched ORDER BY order_id;

-- ============================================================
-- STEP 6: CREATE GOLD LAYER DTs (Business Aggregations)
-- ============================================================

-- Gold: Daily revenue by region
CREATE OR REPLACE DYNAMIC TABLE gold_daily_revenue
    TARGET_LAG = '1 minute'
    WAREHOUSE = TASK_WH
AS
    SELECT
        DATE_TRUNC('day', order_date) AS revenue_date,
        region,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM silver_orders_enriched
    WHERE status = 'COMPLETED'
    GROUP BY 1, 2;

-- Gold: Customer segment analysis
CREATE OR REPLACE DYNAMIC TABLE gold_segment_metrics
    TARGET_LAG = '1 minute'
    WAREHOUSE = TASK_WH
AS
    SELECT
        segment,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders
    FROM silver_orders_enriched
    GROUP BY segment;

-- Query the Gold DTs
SELECT * FROM gold_daily_revenue ORDER BY revenue_date, region;
SELECT * FROM gold_segment_metrics;

-- ============================================================
-- STEP 7: OBSERVE THE DEPENDENCY DAG
-- ============================================================

-- See all DTs and their dependencies
SHOW DYNAMIC TABLES IN SCHEMA DYNAMIC_TABLES_LAB;

-- Check refresh history
SELECT NAME, STATE, REFRESH_START_TIME, REFRESH_END_TIME,
       DATEDIFF(second, REFRESH_START_TIME, REFRESH_END_TIME) AS duration_sec
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES_LAB'
ORDER BY REFRESH_START_TIME DESC
LIMIT 20;

-- ============================================================
-- STEP 8: TEST INCREMENTAL REFRESH (Add New Source Data)
-- ============================================================

-- Insert new orders into the source table
INSERT INTO raw_orders VALUES
    (1011, 2, 'Laptop Pro', 1, 1299.99, '2026-08-10 09:00:00', 'COMPLETED', 'US-East'),
    (1012, 5, 'Monitor 4K', 3, 549.99, '2026-08-10 10:30:00', 'COMPLETED', 'EU-West'),
    (1013, 1, 'Headset Pro', 2, 199.99, '2026-08-10 14:00:00', 'PENDING', 'US-West');

-- Wait ~1 minute for refresh, then check
-- (Or force immediate refresh)
ALTER DYNAMIC TABLE silver_orders REFRESH;

-- Verify new data appears in all layers
SELECT COUNT(*) AS silver_count FROM silver_orders;  -- Should be 13
SELECT COUNT(*) AS enriched_count FROM silver_orders_enriched;  -- Should be 13
SELECT * FROM gold_daily_revenue WHERE revenue_date = '2026-08-10' ORDER BY region;

-- ============================================================
-- STEP 9: CHECK REFRESH DETAILS (Incremental vs Full)
-- ============================================================

-- Did it use incremental or full?
SELECT NAME, REFRESH_MODE, REFRESH_MODE_REASON
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES_LAB';

-- Refresh statistics (rows processed)
SELECT NAME, STATE,
       STATISTICS:numInsertedRows::INT AS inserted,
       STATISTICS:numDeletedRows::INT AS deleted,
       STATISTICS:numUpdatedRows::INT AS updated
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES_LAB'
ORDER BY REFRESH_START_TIME DESC
LIMIT 10;

-- ============================================================
-- STEP 10: ALTER DYNAMIC TABLE (Change Settings)
-- ============================================================

-- Change target lag (no suspend needed!)
ALTER DYNAMIC TABLE gold_daily_revenue SET TARGET_LAG = '5 minutes';

-- Verify the change
SELECT NAME, TARGET_LAG
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE NAME = 'GOLD_DAILY_REVENUE';

-- Suspend a DT (stops refreshing)
ALTER DYNAMIC TABLE gold_segment_metrics SUSPEND;

-- Check it's suspended
SELECT NAME, SCHEDULING_STATE
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE NAME = 'GOLD_SEGMENT_METRICS';

-- Resume
ALTER DYNAMIC TABLE gold_segment_metrics RESUME;

-- ============================================================
-- STEP 11: CREATE A STREAM ON A DYNAMIC TABLE
-- ============================================================

-- You CAN create streams on DTs to track their output changes
CREATE OR REPLACE STREAM silver_orders_changes
    ON DYNAMIC TABLE silver_orders;

-- Currently empty (no changes since stream creation)
SELECT * FROM silver_orders_changes;

-- Add more source data
INSERT INTO raw_orders VALUES
    (1014, 3, 'USB Hub', 10, 39.99, '2026-08-11 08:00:00', 'COMPLETED', 'EU-West'),
    (1015, 4, 'Webcam HD', 1, 129.99, '2026-08-11 09:00:00', 'COMPLETED', 'US-East');

-- Force refresh
ALTER DYNAMIC TABLE silver_orders REFRESH;

-- Now check the stream — shows what changed in the DT!
SELECT * FROM silver_orders_changes;
-- You'll see the 2 new rows as INSERT actions

-- ============================================================
-- STEP 12: TEST EDGE CASE - Source Table Truncate
-- ============================================================

-- What happens when source is truncated?
-- First, note current counts
SELECT 'before_truncate' AS stage, COUNT(*) FROM silver_orders;

-- Truncate source
TRUNCATE TABLE raw_orders;

-- Force refresh
ALTER DYNAMIC TABLE silver_orders REFRESH;

-- DT should now be empty (source is empty, DT reflects source state)
SELECT 'after_truncate' AS stage, COUNT(*) FROM silver_orders;
SELECT * FROM gold_daily_revenue;  -- Also empty now

-- Restore data for next steps
INSERT INTO raw_orders VALUES
    (2001, 1, 'Laptop Pro', 1, 1299.99, '2026-08-15 10:00:00', 'COMPLETED', 'US-West'),
    (2002, 2, 'Monitor 4K', 2, 549.99, '2026-08-15 11:00:00', 'COMPLETED', 'US-East'),
    (2003, 3, 'Keyboard', 3, 79.99, '2026-08-15 12:00:00', 'PENDING', 'EU-West');

ALTER DYNAMIC TABLE silver_orders REFRESH;
SELECT * FROM silver_orders;

-- ============================================================
-- STEP 13: TEST EDGE CASE - Non-Deterministic Function (Forces FULL)
-- ============================================================

-- This DT uses CURRENT_TIMESTAMP — forces FULL refresh
CREATE OR REPLACE DYNAMIC TABLE dt_with_timestamp
    TARGET_LAG = '5 minutes'
    WAREHOUSE = TASK_WH
AS
    SELECT
        order_id,
        product_name,
        total_amount,
        CURRENT_TIMESTAMP() AS last_refreshed_at  -- Non-deterministic!
    FROM silver_orders;

-- Check refresh mode — should be FULL
SELECT NAME, REFRESH_MODE, REFRESH_MODE_REASON
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE NAME = 'DT_WITH_TIMESTAMP';

-- Clean up this test DT
DROP DYNAMIC TABLE dt_with_timestamp;

-- ============================================================
-- STEP 14: TEST EDGE CASE - DT is READ-ONLY
-- ============================================================

-- Try to INSERT into a DT (will FAIL)
-- Uncomment to test:
-- INSERT INTO silver_orders (order_id, customer_id, product_name, quantity, unit_price, total_amount, order_date, status, region)
-- VALUES (9999, 1, 'TEST', 1, 10.00, 10.00, CURRENT_TIMESTAMP(), 'TEST', 'TEST');
-- ERROR: "DML operations are not allowed on dynamic tables"

-- Try to UPDATE (will FAIL)
-- UPDATE silver_orders SET status = 'FAILED' WHERE order_id = 2001;
-- ERROR: "DML operations are not allowed on dynamic tables"

-- ============================================================
-- STEP 15: MONITORING DASHBOARD QUERIES
-- ============================================================

-- Pipeline health overview
SELECT
    NAME,
    SCHEDULING_STATE,
    TARGET_LAG,
    REFRESH_MODE,
    DATA_TIMESTAMP,
    DATEDIFF(minute, DATA_TIMESTAMP, CURRENT_TIMESTAMP()) AS current_lag_min
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES_LAB'
ORDER BY NAME;

-- Refresh performance over last 24 hours
SELECT
    NAME,
    COUNT(*) AS refresh_count,
    COUNT_IF(STATE = 'SUCCEEDED') AS success_count,
    COUNT_IF(STATE = 'FAILED') AS fail_count,
    AVG(DATEDIFF(second, REFRESH_START_TIME, REFRESH_END_TIME)) AS avg_duration_sec,
    MAX(DATEDIFF(second, REFRESH_START_TIME, REFRESH_END_TIME)) AS max_duration_sec
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE SCHEMA_NAME = 'DYNAMIC_TABLES_LAB'
  AND REFRESH_START_TIME > DATEADD(day, -1, CURRENT_TIMESTAMP())
GROUP BY NAME
ORDER BY refresh_count DESC;

-- ============================================================
-- STEP 16: CLEANUP
-- ============================================================

-- Suspend all DTs first (stop credit consumption)
ALTER DYNAMIC TABLE gold_daily_revenue SUSPEND;
ALTER DYNAMIC TABLE gold_segment_metrics SUSPEND;
ALTER DYNAMIC TABLE silver_orders_enriched SUSPEND;
ALTER DYNAMIC TABLE silver_orders SUSPEND;

-- To fully clean up (uncomment when done practicing):
-- DROP DYNAMIC TABLE gold_daily_revenue;
-- DROP DYNAMIC TABLE gold_segment_metrics;
-- DROP DYNAMIC TABLE silver_orders_enriched;
-- DROP DYNAMIC TABLE silver_orders;
-- DROP STREAM silver_orders_changes;
-- DROP TABLE raw_orders;
-- DROP TABLE customers;
-- DROP SCHEMA DYNAMIC_TABLES_LAB;

-- ============================================================
-- LAB COMPLETE!
-- Key takeaways:
-- 1. DTs are declarative — you define WHAT, Snowflake handles WHEN/HOW
-- 2. Multi-layer pipelines auto-detect dependencies
-- 3. DOWNSTREAM avoids unnecessary intermediate refreshes
-- 4. Streams work ON DTs to track output changes
-- 5. No DML allowed — DTs are strictly read-only
-- 6. Non-deterministic functions force FULL refresh
-- 7. ALTER TARGET_LAG doesn't need SUSPEND (unlike tasks)
-- 8. Truncating source → DT becomes empty on next refresh
-- ============================================================