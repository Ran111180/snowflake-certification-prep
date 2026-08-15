-- ============================================================================
-- 18. CLUSTERING & SEARCH OPTIMIZATION - HANDS-ON LAB
-- ============================================================================
-- This lab walks through:
--   1. Creating a large table to observe clustering behavior
--   2. Checking natural clustering with SYSTEM$CLUSTERING_INFORMATION
--   3. Adding an explicit clustering key
--   4. Verifying clustering improvement
--   5. Setting up Search Optimization Service (SOS)
--   6. Query Profile analysis for partition pruning
-- ============================================================================

-- ============================================================================
-- SETUP: Create database and schema for the lab
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS CLUSTERING_LAB;
CREATE SCHEMA IF NOT EXISTS CLUSTERING_LAB.PRACTICE;
USE SCHEMA CLUSTERING_LAB.PRACTICE;

CREATE OR REPLACE WAREHOUSE CLUSTERING_LAB_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE;

USE WAREHOUSE CLUSTERING_LAB_WH;


-- ============================================================================
-- STEP 1: Create a large table with random data distribution
-- ============================================================================

-- Create a table simulating sales transactions with poor natural clustering
-- (data deliberately loaded in random order to demonstrate clustering need)
CREATE OR REPLACE TABLE sales_transactions (
    transaction_id    NUMBER AUTOINCREMENT,
    transaction_date  DATE,
    customer_id       VARCHAR(20),
    region            VARCHAR(20),
    product_category  VARCHAR(30),
    amount            DECIMAL(12,2),
    quantity          INT,
    store_id          VARCHAR(10)
);

-- Generate ~10 million rows with random distribution across dates/regions
-- This simulates data loaded from multiple sources in random order
INSERT INTO sales_transactions (transaction_date, customer_id, region, product_category, amount, quantity, store_id)
SELECT
    DATEADD('day', UNIFORM(0, 730, RANDOM()), '2022-01-01')::DATE AS transaction_date,
    'CUST-' || LPAD(UNIFORM(1, 100000, RANDOM())::VARCHAR, 6, '0') AS customer_id,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'NORTH'
        WHEN 2 THEN 'SOUTH'
        WHEN 3 THEN 'EAST'
        WHEN 4 THEN 'WEST'
        ELSE 'CENTRAL'
    END AS region,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 'Electronics'
        WHEN 2 THEN 'Clothing'
        WHEN 3 THEN 'Food'
        WHEN 4 THEN 'Home'
        WHEN 5 THEN 'Sports'
        ELSE 'Books'
    END AS product_category,
    ROUND(UNIFORM(5.00, 2000.00, RANDOM())::DECIMAL(12,2), 2) AS amount,
    UNIFORM(1, 20, RANDOM()) AS quantity,
    'STR-' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 4, '0') AS store_id
FROM TABLE(GENERATOR(ROWCOUNT => 10000000));

-- Verify row count
SELECT COUNT(*) AS total_rows FROM sales_transactions;
-- Expected: 10,000,000 rows


-- ============================================================================
-- STEP 2: Check natural clustering (BEFORE adding clustering key)
-- ============================================================================

-- Check clustering on transaction_date (the column we'll cluster on)
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date)');
-- Note: average_depth will likely be high (poor) because data was loaded randomly

-- Check clustering on (transaction_date, region) compound key
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date, region)');

-- Check clustering on region alone
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(region)');

-- Record the results! Key metrics to note:
--   average_depth: Higher = worse clustering
--   average_overlaps: Higher = more partition overlap
--   total_constant_partition_count: Lower = worse clustering


-- ============================================================================
-- STEP 3: Baseline query performance (BEFORE clustering)
-- ============================================================================

-- Run these queries and note the Query Profile metrics:
--   - Partitions scanned vs total
--   - Bytes scanned
--   - Execution time

-- Query A: Date range filter
SELECT
    region,
    product_category,
    SUM(amount) AS total_sales,
    COUNT(*) AS transaction_count
FROM sales_transactions
WHERE transaction_date BETWEEN '2023-01-01' AND '2023-01-31'
GROUP BY region, product_category
ORDER BY total_sales DESC;

-- Query B: Region + date compound filter
SELECT
    transaction_date,
    SUM(amount) AS daily_sales,
    AVG(amount) AS avg_transaction
FROM sales_transactions
WHERE region = 'NORTH'
  AND transaction_date BETWEEN '2023-06-01' AND '2023-06-30'
GROUP BY transaction_date
ORDER BY transaction_date;

-- Query C: Point lookup (will benefit from SOS later)
SELECT *
FROM sales_transactions
WHERE customer_id = 'CUST-050000';

-- Record Query IDs from the Query History for comparison later!
-- SELECT LAST_QUERY_ID();


-- ============================================================================
-- STEP 4: Add clustering key
-- ============================================================================

-- Add clustering key based on most common query patterns (date range + region)
ALTER TABLE sales_transactions CLUSTER BY (transaction_date, region);

-- Verify clustering key was set
SHOW TABLES LIKE 'SALES_TRANSACTIONS';
-- Look at the "cluster_by" column in results

-- NOTE: Reclustering happens in the BACKGROUND over time.
-- For this lab, we can check progress:
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date, region)');

-- Monitor reclustering progress (may take minutes to hours for large tables)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.AUTOMATIC_CLUSTERING_HISTORY(
    DATE_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    TABLE_NAME => 'SALES_TRANSACTIONS'
));


-- ============================================================================
-- STEP 5: Verify clustering improvement
-- ============================================================================

-- Re-check clustering quality after some time has passed
-- (In production, wait hours/days for large tables; in lab, check periodically)
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date, region)');

-- Compare average_depth and average_overlaps with Step 2 results
-- Expected: Both values should be LOWER after reclustering

-- Re-run baseline queries and compare Query Profile:

-- Query A again: Date range filter
SELECT
    region,
    product_category,
    SUM(amount) AS total_sales,
    COUNT(*) AS transaction_count
FROM sales_transactions
WHERE transaction_date BETWEEN '2023-01-01' AND '2023-01-31'
GROUP BY region, product_category
ORDER BY total_sales DESC;

-- Query B again: Region + date compound filter
SELECT
    transaction_date,
    SUM(amount) AS daily_sales,
    AVG(amount) AS avg_transaction
FROM sales_transactions
WHERE region = 'NORTH'
  AND transaction_date BETWEEN '2023-06-01' AND '2023-06-30'
GROUP BY transaction_date
ORDER BY transaction_date;

-- Compare partitions scanned in Query Profile:
--   BEFORE clustering: likely high (poor pruning)
--   AFTER clustering: should be significantly lower (better pruning)


-- ============================================================================
-- STEP 6: Set up Search Optimization Service (SOS)
-- ============================================================================

-- Enable SOS for point lookups on customer_id (high cardinality — not suited for clustering)
ALTER TABLE sales_transactions ADD SEARCH OPTIMIZATION
  ON EQUALITY(customer_id);

-- Check SOS status
DESCRIBE SEARCH OPTIMIZATION ON sales_transactions;

-- Note: SOS takes time to build search access paths in the background

-- Monitor SOS build progress
SELECT *
FROM TABLE(INFORMATION_SCHEMA.SEARCH_OPTIMIZATION_HISTORY(
    DATE_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    TABLE_NAME => 'SALES_TRANSACTIONS'
));

-- After SOS is active, re-run the point lookup query:
-- Query C: Point lookup (should be MUCH faster with SOS)
SELECT *
FROM sales_transactions
WHERE customer_id = 'CUST-050000';

-- Also test IN-list lookups (SOS helps these too)
SELECT *
FROM sales_transactions
WHERE customer_id IN ('CUST-000001', 'CUST-050000', 'CUST-099999');

-- Compare Query Profile partitions scanned: should be dramatically lower with SOS


-- ============================================================================
-- STEP 7: Query Profile analysis exercises
-- ============================================================================

-- Exercise 1: Find queries with poor pruning in your session
SELECT
    query_id,
    SUBSTR(query_text, 1, 80) AS query_preview,
    partitions_scanned,
    partitions_total,
    ROUND((partitions_total - partitions_scanned) * 100.0 / NULLIF(partitions_total, 0), 1) AS prune_pct,
    bytes_scanned,
    total_elapsed_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    RESULT_LIMIT => 50,
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP())
))
WHERE query_type = 'SELECT'
  AND partitions_total > 0
ORDER BY prune_pct ASC;

-- Exercise 2: Identify queries with spilling
SELECT
    query_id,
    SUBSTR(query_text, 1, 80) AS query_preview,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage,
    warehouse_size,
    total_elapsed_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    RESULT_LIMIT => 50,
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP())
))
WHERE bytes_spilled_to_local_storage > 0
   OR bytes_spilled_to_remote_storage > 0
ORDER BY bytes_spilled_to_remote_storage DESC;

-- Exercise 3: Check if QAS would help any of your queries
SELECT
    query_id,
    SUBSTR(query_text, 1, 80) AS query_preview,
    eligible_query_acceleration_time,
    total_elapsed_time,
    ROUND(eligible_query_acceleration_time * 100.0 / NULLIF(total_elapsed_time, 0), 1) AS pct_acceleratable
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    RESULT_LIMIT => 50,
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP())
))
WHERE eligible_query_acceleration_time > 0
ORDER BY eligible_query_acceleration_time DESC;


-- ============================================================================
-- STEP 8: Advanced — Testing clustering key changes
-- ============================================================================

-- Try different clustering keys and compare SYSTEM$CLUSTERING_INFORMATION results

-- Option A: Cluster only on date
ALTER TABLE sales_transactions CLUSTER BY (transaction_date);
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date)');

-- Option B: Cluster on region first (for queries primarily filtering by region)
ALTER TABLE sales_transactions CLUSTER BY (region, transaction_date);
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(region, transaction_date)');

-- Option C: Cluster with expression (reduce timestamp cardinality)
ALTER TABLE sales_transactions CLUSTER BY (transaction_date, region);
SELECT SYSTEM$CLUSTERING_INFORMATION('sales_transactions', '(transaction_date, region)');

-- Restore our preferred clustering key
ALTER TABLE sales_transactions CLUSTER BY (transaction_date, region);


-- ============================================================================
-- STEP 9: Cost monitoring and management
-- ============================================================================

-- Check reclustering credits used
SELECT
    table_name,
    start_time,
    end_time,
    credits_used,
    num_bytes_reclustered,
    num_rows_reclustered
FROM TABLE(INFORMATION_SCHEMA.AUTOMATIC_CLUSTERING_HISTORY(
    DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    TABLE_NAME => 'SALES_TRANSACTIONS'
))
ORDER BY start_time DESC;

-- Check SOS credits used
SELECT
    table_name,
    start_time,
    end_time,
    credits_used,
    num_bytes_persisted
FROM TABLE(INFORMATION_SCHEMA.SEARCH_OPTIMIZATION_HISTORY(
    DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    TABLE_NAME => 'SALES_TRANSACTIONS'
))
ORDER BY start_time DESC;

-- Suspend reclustering if costs are too high
-- ALTER TABLE sales_transactions SUSPEND RECLUSTER;

-- Resume when ready
-- ALTER TABLE sales_transactions RESUME RECLUSTER;


-- ============================================================================
-- CLEANUP (run when done with lab)
-- ============================================================================

-- Remove SOS
-- ALTER TABLE sales_transactions DROP SEARCH OPTIMIZATION;

-- Remove clustering key
-- ALTER TABLE sales_transactions DROP CLUSTERING KEY;

-- Drop lab objects
-- DROP DATABASE IF EXISTS CLUSTERING_LAB;
-- DROP WAREHOUSE IF EXISTS CLUSTERING_LAB_WH;


-- ============================================================================
-- LAB SUMMARY CHECKLIST
-- ============================================================================
-- [ ] Created table with random data (poor natural clustering)
-- [ ] Checked natural clustering with SYSTEM$CLUSTERING_INFORMATION
-- [ ] Ran baseline queries and noted Query Profile metrics
-- [ ] Added CLUSTER BY (transaction_date, region)
-- [ ] Verified clustering improvement (lower depth, better pruning)
-- [ ] Enabled SOS on customer_id for point lookups
-- [ ] Confirmed SOS improved point lookup query performance
-- [ ] Analyzed Query Profile for pruning efficiency
-- [ ] Reviewed cost monitoring views
-- [ ] Understood when to use clustering vs SOS vs QAS
-- ============================================================================
