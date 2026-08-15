-- ============================================================================
-- 22. SNOWFLAKE ARCHITECTURE DEEP DIVE - HANDS-ON LAB
-- ============================================================================
-- Topics: Warehouse inspection, clustering info, query history analysis,
--         metering history, cache behavior, INFORMATION_SCHEMA exploration
-- ============================================================================

-- ============================================================================
-- LAB 1: WAREHOUSE INSPECTION
-- ============================================================================

-- Show all warehouses and their configuration
SHOW WAREHOUSES;

-- Detailed warehouse properties
DESCRIBE WAREHOUSE COMPUTE_WH;

-- Check current warehouse state
SELECT CURRENT_WAREHOUSE();

-- Show warehouse parameters
SHOW PARAMETERS IN WAREHOUSE COMPUTE_WH;

-- Key warehouse attributes to observe:
-- - size, min_cluster_count, max_cluster_count
-- - auto_suspend (seconds), auto_resume (true/false)
-- - scaling_policy (STANDARD vs ECONOMY)
-- - resource_monitor


-- ============================================================================
-- LAB 2: CLUSTERING INFORMATION
-- ============================================================================

-- Check clustering information for a table
-- Replace with your actual database.schema.table
SELECT SYSTEM$CLUSTERING_INFORMATION('SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM');

-- Detailed clustering info with specific columns
SELECT SYSTEM$CLUSTERING_INFORMATION(
    'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM',
    '(L_SHIPDATE)'
);

-- Understanding the output:
-- cluster_by_keys: columns used for clustering
-- total_partition_count: total micro-partitions
-- total_constant_partition_count: partitions with single distinct value
-- average_overlaps: average overlap between partitions (lower = better)
-- average_depth: average depth of overlap (lower = better, 1 = perfect)

-- Check clustering depth (how well-clustered a table is)
SELECT SYSTEM$CLUSTERING_DEPTH(
    'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS',
    '(O_ORDERDATE)'
);


-- ============================================================================
-- LAB 3: QUERY HISTORY ANALYSIS
-- ============================================================================

-- Recent query history (last 24 hours)
SELECT
    query_id,
    query_text,
    database_name,
    warehouse_name,
    warehouse_size,
    execution_status,
    error_message,
    total_elapsed_time / 1000 AS elapsed_sec,
    bytes_scanned / (1024*1024) AS mb_scanned,
    rows_produced,
    compilation_time / 1000 AS compile_sec,
    execution_time / 1000 AS exec_sec,
    queued_overload_time / 1000 AS queued_sec,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS pct_partitions_scanned,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATEADD('hours', -24, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP(),
    10000
))
ORDER BY start_time DESC
LIMIT 50;

-- Queries that used result cache (no warehouse needed)
SELECT
    query_id,
    query_text,
    warehouse_name,
    total_elapsed_time / 1000 AS elapsed_sec,
    bytes_scanned,
    partitions_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATEADD('hours', -24, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
))
WHERE bytes_scanned = 0
  AND partitions_scanned = 0
  AND execution_status = 'SUCCESS'
  AND warehouse_name IS NULL  -- result cache doesn't use warehouse
ORDER BY start_time DESC
LIMIT 20;

-- Queries with high partition scanning (poor pruning)
SELECT
    query_id,
    SUBSTR(query_text, 1, 100) AS query_preview,
    warehouse_name,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS scan_pct,
    total_elapsed_time / 1000 AS elapsed_sec
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATEADD('hours', -24, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
))
WHERE partitions_total > 100
  AND partitions_scanned / NULLIF(partitions_total, 0) > 0.8
  AND execution_status = 'SUCCESS'
ORDER BY partitions_scanned DESC
LIMIT 20;

-- Cloud services usage by query
SELECT
    query_id,
    SUBSTR(query_text, 1, 80) AS query_preview,
    warehouse_name,
    total_elapsed_time / 1000 AS elapsed_sec,
    compilation_time / 1000 AS compile_sec,
    ROUND(compilation_time / NULLIF(total_elapsed_time, 0) * 100, 1) AS pct_in_cloud_services
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATEADD('hours', -24, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
))
WHERE execution_status = 'SUCCESS'
  AND total_elapsed_time > 0
ORDER BY compilation_time DESC
LIMIT 20;


-- ============================================================================
-- LAB 4: WAREHOUSE METERING HISTORY
-- ============================================================================

-- Credit usage by warehouse (last 7 days)
SELECT
    warehouse_name,
    start_time::DATE AS usage_date,
    SUM(credits_used) AS total_credits,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits,
    ROUND(SUM(credits_used_cloud_services) / NULLIF(SUM(credits_used_compute), 0) * 100, 2)
        AS cloud_services_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, usage_date
ORDER BY warehouse_name, usage_date DESC;

-- Daily cloud services vs compute (check 10% threshold)
SELECT
    start_time::DATE AS usage_date,
    SUM(credits_used_compute) AS daily_compute,
    SUM(credits_used_cloud_services) AS daily_cloud_services,
    ROUND(SUM(credits_used_compute) * 0.10, 4) AS free_cs_threshold,
    GREATEST(SUM(credits_used_cloud_services) - (SUM(credits_used_compute) * 0.10), 0)
        AS billed_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_date
ORDER BY usage_date DESC;

-- Warehouse utilization patterns (hourly)
SELECT
    warehouse_name,
    EXTRACT(HOUR FROM start_time) AS hour_of_day,
    COUNT(*) AS measurement_count,
    AVG(credits_used) AS avg_credits_per_hour,
    MAX(credits_used) AS max_credits_in_hour
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, hour_of_day
ORDER BY warehouse_name, hour_of_day;


-- ============================================================================
-- LAB 5: CACHE BEHAVIOR DEMONSTRATION
-- ============================================================================

-- Step 1: Run a query (first execution - no cache)
-- Note the query ID and check the profile afterward
SELECT
    L_RETURNFLAG,
    L_LINESTATUS,
    SUM(L_QUANTITY) AS sum_qty,
    SUM(L_EXTENDEDPRICE) AS sum_base_price,
    AVG(L_DISCOUNT) AS avg_disc,
    COUNT(*) AS count_order
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
WHERE L_SHIPDATE <= DATEADD('day', -90, '1998-12-01')
GROUP BY L_RETURNFLAG, L_LINESTATUS
ORDER BY L_RETURNFLAG, L_LINESTATUS;

-- Step 2: Run the EXACT same query again (should hit result cache)
-- Check profile: "QUERY_RESULT_REUSE" = true, bytes scanned = 0
SELECT
    L_RETURNFLAG,
    L_LINESTATUS,
    SUM(L_QUANTITY) AS sum_qty,
    SUM(L_EXTENDEDPRICE) AS sum_base_price,
    AVG(L_DISCOUNT) AS avg_disc,
    COUNT(*) AS count_order
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
WHERE L_SHIPDATE <= DATEADD('day', -90, '1998-12-01')
GROUP BY L_RETURNFLAG, L_LINESTATUS
ORDER BY L_RETURNFLAG, L_LINESTATUS;

-- Step 3: Slightly modify query (add a space/comment) - cache MISS
-- This demonstrates byte-for-byte matching requirement
SELECT
    L_RETURNFLAG,
    L_LINESTATUS,
    SUM(L_QUANTITY) AS sum_qty,
    SUM(L_EXTENDEDPRICE) AS sum_base_price,
    AVG(L_DISCOUNT) AS avg_disc,
    COUNT(*) AS count_order
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
WHERE L_SHIPDATE <= DATEADD('day', -90, '1998-12-01')
GROUP BY L_RETURNFLAG, L_LINESTATUS
ORDER BY L_RETURNFLAG, L_LINESTATUS
;  -- extra semicolon placement difference = cache miss

-- Step 4: Disable result cache and re-run
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT
    L_RETURNFLAG,
    L_LINESTATUS,
    SUM(L_QUANTITY) AS sum_qty,
    SUM(L_EXTENDEDPRICE) AS sum_base_price,
    AVG(L_DISCOUNT) AS avg_disc,
    COUNT(*) AS count_order
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
WHERE L_SHIPDATE <= DATEADD('day', -90, '1998-12-01')
GROUP BY L_RETURNFLAG, L_LINESTATUS
ORDER BY L_RETURNFLAG, L_LINESTATUS;

-- Re-enable result cache
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- Step 5: Demonstrate metadata cache (instant response, no warehouse needed)
-- COUNT(*) uses metadata only
SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;
SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;
SELECT MIN(O_ORDERDATE), MAX(O_ORDERDATE) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;


-- ============================================================================
-- LAB 6: INFORMATION_SCHEMA EXPLORATION
-- ============================================================================

-- List all schemas in current database
SELECT * FROM INFORMATION_SCHEMA.SCHEMATA;

-- List all tables in a specific schema
SELECT
    table_catalog,
    table_schema,
    table_name,
    table_type,
    row_count,
    bytes,
    ROUND(bytes / (1024*1024), 2) AS size_mb,
    clustering_key,
    created,
    last_altered
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'PUBLIC'
ORDER BY bytes DESC NULLS LAST;

-- Column details for a specific table
SELECT
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default,
    ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'PUBLIC'
  AND table_name = 'MY_TABLE'
ORDER BY ordinal_position;

-- Active warehouses information
SELECT *
FROM INFORMATION_SCHEMA.WAREHOUSES
ORDER BY warehouse_name;

-- Functions and procedures
SELECT
    function_name,
    function_schema,
    argument_signature,
    data_type AS return_type,
    function_language
FROM INFORMATION_SCHEMA.FUNCTIONS
WHERE function_schema = 'PUBLIC'
ORDER BY function_name;

-- Views
SELECT
    table_name AS view_name,
    table_schema,
    view_definition,
    is_secure
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'PUBLIC'
ORDER BY view_name;

-- Stages
SELECT *
FROM INFORMATION_SCHEMA.STAGES
WHERE stage_schema = 'PUBLIC';

-- File formats
SELECT *
FROM INFORMATION_SCHEMA.FILE_FORMATS
WHERE file_format_schema = 'PUBLIC';

-- Applicable roles for current user
SELECT * FROM INFORMATION_SCHEMA.APPLICABLE_ROLES;

-- Current session context
SELECT
    CURRENT_ACCOUNT() AS account,
    CURRENT_REGION() AS region,
    CURRENT_USER() AS username,
    CURRENT_ROLE() AS active_role,
    CURRENT_DATABASE() AS database,
    CURRENT_SCHEMA() AS schema,
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_SESSION() AS session_id,
    CURRENT_VERSION() AS snowflake_version;


-- ============================================================================
-- LAB 7: ARCHITECTURE VERIFICATION QUERIES
-- ============================================================================

-- Verify micro-partition count and size for a table
SELECT
    TABLE_NAME,
    ROW_COUNT,
    BYTES,
    ROUND(BYTES / (1024*1024*1024), 3) AS size_gb,
    -- Estimate micro-partition count (each ~16MB compressed on average)
    ROUND(BYTES / (16 * 1024 * 1024), 0) AS estimated_partitions
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'PUBLIC'
  AND BYTES > 0
ORDER BY BYTES DESC;

-- Storage usage over time (Account Usage - requires ACCOUNTADMIN or appropriate role)
SELECT
    usage_date,
    ROUND(storage_bytes / POWER(1024, 4), 4) AS storage_tb,
    ROUND(stage_bytes / POWER(1024, 4), 4) AS stage_tb,
    ROUND(failsafe_bytes / POWER(1024, 4), 4) AS failsafe_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY usage_date DESC;

-- Login history (Cloud Services layer activity)
SELECT
    event_timestamp,
    user_name,
    client_ip,
    reported_client_type,
    first_authentication_factor,
    is_success
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC
LIMIT 50;
