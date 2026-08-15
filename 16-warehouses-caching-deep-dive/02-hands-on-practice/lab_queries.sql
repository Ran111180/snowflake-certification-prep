/*******************************************************************************
 * WAREHOUSES & CACHING DEEP DIVE - Hands-On Lab
 * 
 * 14-step lab covering warehouse management, multi-cluster behavior,
 * caching mechanics, resource monitors, QAS, and monitoring.
 *
 * Prerequisites:
 *   - ACCOUNTADMIN or SYSADMIN role (for warehouse/monitor creation)
 *   - Access to SNOWFLAKE.ACCOUNT_USAGE schema
 *   - Enterprise Edition (for multi-cluster and QAS features)
 ******************************************************************************/

--------------------------------------------------------------------------------
-- STEP 1: Show Warehouses and Current State
--------------------------------------------------------------------------------

-- View all warehouses in the account
SHOW WAREHOUSES;

-- Detailed warehouse info with key columns
SELECT "name", "state", "type", "size", 
       "min_cluster_count", "max_cluster_count",
       "scaling_policy", "auto_suspend", "auto_resume",
       "query_acceleration_max_scale_factor"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check currently active warehouse
SELECT CURRENT_WAREHOUSE();


--------------------------------------------------------------------------------
-- STEP 2: Create Warehouse with Full Options
--------------------------------------------------------------------------------

-- Create a lab warehouse with all common parameters specified
CREATE OR REPLACE WAREHOUSE lab_wh_deep_dive
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 120                    -- 2 minutes idle timeout
  AUTO_RESUME = TRUE                    -- Auto-start on query
  MIN_CLUSTER_COUNT = 1                 -- Multi-cluster minimum
  MAX_CLUSTER_COUNT = 1                 -- Start as single cluster
  SCALING_POLICY = 'STANDARD'           -- Favor performance over cost
  INITIALLY_SUSPENDED = TRUE            -- Don't start immediately
  STATEMENT_TIMEOUT_IN_SECONDS = 1800   -- Kill queries after 30 min
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300  -- Fail queued queries after 5 min
  COMMENT = 'Lab warehouse for caching and performance deep dive';

-- Verify creation
DESCRIBE WAREHOUSE lab_wh_deep_dive;

-- Resume the warehouse for use
ALTER WAREHOUSE lab_wh_deep_dive RESUME;
USE WAREHOUSE lab_wh_deep_dive;


--------------------------------------------------------------------------------
-- STEP 3: Resize Warehouse
--------------------------------------------------------------------------------

-- Resize up to Small (takes effect for next query)
ALTER WAREHOUSE lab_wh_deep_dive SET WAREHOUSE_SIZE = 'SMALL';

-- Verify the resize
SHOW WAREHOUSES LIKE 'lab_wh_deep_dive';

-- Resize back down to XSmall
ALTER WAREHOUSE lab_wh_deep_dive SET WAREHOUSE_SIZE = 'XSMALL';

-- Note: Running queries continue on old size; new queries use new size
-- Check resize history
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_EVENTS_HISTORY
WHERE warehouse_name = 'LAB_WH_DEEP_DIVE'
  AND event_name IN ('RESIZE_WAREHOUSE')
ORDER BY timestamp DESC
LIMIT 10;


--------------------------------------------------------------------------------
-- STEP 4: Multi-Cluster Configuration Demo
--------------------------------------------------------------------------------

-- NOTE: Requires Enterprise Edition or higher

-- Enable multi-cluster (scale out to handle concurrency)
ALTER WAREHOUSE lab_wh_deep_dive SET
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  SCALING_POLICY = 'STANDARD';

-- Verify multi-cluster settings
SHOW WAREHOUSES LIKE 'lab_wh_deep_dive';

-- Switch to ECONOMY to compare behavior
ALTER WAREHOUSE lab_wh_deep_dive SET SCALING_POLICY = 'ECONOMY';

-- View cluster activity (shows when additional clusters spin up)
SELECT warehouse_name, cluster_number, 
       start_time, end_time,
       credits_used, credits_used_compute, credits_used_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'LAB_WH_DEEP_DIVE'
  AND start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- Reset to single cluster for remaining labs
ALTER WAREHOUSE lab_wh_deep_dive SET
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 1;


--------------------------------------------------------------------------------
-- STEP 5: Auto-Suspend Behavior Test
--------------------------------------------------------------------------------

-- Set very short auto-suspend for testing (minimum is 60 seconds)
ALTER WAREHOUSE lab_wh_deep_dive SET AUTO_SUSPEND = 60;

-- Run a query to reset the suspend timer
SELECT CURRENT_TIMESTAMP() AS timer_reset_at;

-- After 60 seconds of no activity, check warehouse state:
-- (Wait at least 60 seconds, then run:)
SHOW WAREHOUSES LIKE 'lab_wh_deep_dive';
-- Look at "state" column - should show 'SUSPENDED'

-- This next query will auto-resume the warehouse (AUTO_RESUME = TRUE)
SELECT 'Warehouse auto-resumed for this query' AS status;

-- Demonstrate: AUTO_SUSPEND = 0 means NEVER suspend
-- (Don't actually set this in production without good reason!)
-- ALTER WAREHOUSE lab_wh_deep_dive SET AUTO_SUSPEND = 0;

-- Set back to reasonable value
ALTER WAREHOUSE lab_wh_deep_dive SET AUTO_SUSPEND = 120;


--------------------------------------------------------------------------------
-- STEP 6: Resource Monitor Setup
--------------------------------------------------------------------------------

-- Create a resource monitor with notification and suspend triggers
-- NOTE: Requires ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR lab_monitor_deep_dive
  WITH 
    CREDIT_QUOTA = 10                    -- 10 credits per interval
    FREQUENCY = DAILY                    -- Reset daily
    START_TIMESTAMP = IMMEDIATELY        -- Start monitoring now
    TRIGGERS
      ON 50 PERCENT DO NOTIFY            -- Warn at 50%
      ON 75 PERCENT DO NOTIFY            -- Warn at 75%
      ON 90 PERCENT DO NOTIFY            -- Warn at 90%
      ON 100 PERCENT DO SUSPEND          -- Graceful suspend at 100%
      ON 110 PERCENT DO SUSPEND_IMMEDIATE; -- Hard stop at 110%

-- Assign the monitor to our lab warehouse
ALTER WAREHOUSE lab_wh_deep_dive SET RESOURCE_MONITOR = lab_monitor_deep_dive;

-- Verify assignment
SHOW RESOURCE MONITORS;

-- View monitor details
DESCRIBE RESOURCE MONITOR lab_monitor_deep_dive;

-- Check resource monitor usage
SELECT * 
FROM SNOWFLAKE.ACCOUNT_USAGE.RESOURCE_MONITORS
WHERE name = 'LAB_MONITOR_DEEP_DIVE'
ORDER BY start_time DESC
LIMIT 5;

USE ROLE SYSADMIN;


--------------------------------------------------------------------------------
-- STEP 7: Cache Demonstration (Result Cache & SSD Cache)
--------------------------------------------------------------------------------

-- Ensure we're using our lab warehouse
USE WAREHOUSE lab_wh_deep_dive;

-- Step 7a: First execution - full scan (populates both result and SSD cache)
SELECT COUNT(*) AS row_count, 
       MIN(start_time) AS earliest,
       MAX(start_time) AS latest
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP());

-- Step 7b: Second execution - should hit RESULT CACHE (0 bytes scanned)
-- Run the EXACT same query again:
SELECT COUNT(*) AS row_count, 
       MIN(start_time) AS earliest,
       MAX(start_time) AS latest
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP());

-- Step 7c: Check the query history to compare execution
SELECT query_id, query_text, 
       execution_status,
       total_elapsed_time,
       bytes_scanned,
       percentage_scanned_from_cache,
       rows_produced,
       compilation_time,
       execution_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
  RESULT_LIMIT => 10,
  END_TIME_RANGE_START => DATEADD('minute', -5, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%QUERY_HISTORY%row_count%'
ORDER BY start_time DESC;

-- Observe: 
--   First run:  bytes_scanned > 0, execution_time > 0
--   Second run: bytes_scanned = 0, execution_time = 0 (result cache hit!)

-- Step 7d: Force cache miss by changing the query slightly
SELECT COUNT(*) AS row_count, 
       MIN(start_time) AS earliest,
       MAX(start_time) AS latest
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
/* different comment forces cache miss */;

-- Step 7e: Disable result cache and re-run to see SSD cache behavior
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT COUNT(*) AS row_count, 
       MIN(start_time) AS earliest,
       MAX(start_time) AS latest
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP());

-- Check percentage_scanned_from_cache (SSD cache) - should be > 0%
-- since the data was cached in local SSD from previous runs

-- Re-enable result cache
ALTER SESSION SET USE_CACHED_RESULT = TRUE;


--------------------------------------------------------------------------------
-- STEP 8: QAS Eligibility Check
--------------------------------------------------------------------------------

-- Check which recent queries would have benefited from QAS
SELECT query_id, 
       query_text,
       warehouse_name,
       total_elapsed_time / 1000 AS elapsed_seconds,
       eligible_query_acceleration_time / 1000 AS qas_eligible_seconds,
       ROUND(eligible_query_acceleration_time / NULLIF(total_elapsed_time, 0) * 100, 1) 
         AS pct_accelerable
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND eligible_query_acceleration_time > 0
  AND total_elapsed_time > 5000   -- Only queries that took > 5 seconds
ORDER BY eligible_query_acceleration_time DESC
LIMIT 20;

-- Use system function for a specific query (replace with actual query_id)
-- SELECT SYSTEM$ESTIMATE_QUERY_ACCELERATION('<your_query_id>');

-- Check current QAS settings on the warehouse
SHOW WAREHOUSES LIKE 'lab_wh_deep_dive';
-- Look at query_acceleration_max_scale_factor column

-- Enable QAS on the lab warehouse (Enterprise Edition required)
ALTER WAREHOUSE lab_wh_deep_dive SET 
  ENABLE_QUERY_ACCELERATION = TRUE
  QUERY_ACCELERATION_MAX_SCALE_FACTOR = 4;

-- View QAS usage history
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 10;


--------------------------------------------------------------------------------
-- STEP 9: Warehouse Metering History Analysis
--------------------------------------------------------------------------------

-- Credit consumption by warehouse over the past 7 days
SELECT warehouse_name,
       SUM(credits_used) AS total_credits,
       SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cloud_services_credits,
       COUNT(DISTINCT DATE_TRUNC('hour', start_time)) AS active_hours
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;

-- Hourly credit consumption pattern (find peak hours)
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -3, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- Identify warehouses with high cloud services ratio (potential issue)
SELECT warehouse_name,
       SUM(credits_used_compute) AS compute,
       SUM(credits_used_cloud_services) AS cloud_svc,
       ROUND(SUM(credits_used_cloud_services) / NULLIF(SUM(credits_used), 0) * 100, 2) 
         AS cloud_svc_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
HAVING SUM(credits_used) > 0
ORDER BY cloud_svc_pct DESC;


--------------------------------------------------------------------------------
-- STEP 10: Query History Analysis for Performance Patterns
--------------------------------------------------------------------------------

-- Top 10 most expensive queries (by execution time)
SELECT query_id, query_type, 
       warehouse_name, warehouse_size,
       total_elapsed_time / 1000 AS elapsed_sec,
       bytes_scanned / POWER(1024, 3) AS gb_scanned,
       rows_produced,
       percentage_scanned_from_cache AS cache_hit_pct,
       partitions_scanned, partitions_total,
       ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 1) AS partition_scan_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND query_type = 'SELECT'
  AND warehouse_name IS NOT NULL
ORDER BY total_elapsed_time DESC
LIMIT 10;

-- Cache effectiveness analysis
SELECT warehouse_name,
       COUNT(*) AS total_queries,
       SUM(CASE WHEN bytes_scanned = 0 THEN 1 ELSE 0 END) AS result_cache_hits,
       ROUND(AVG(percentage_scanned_from_cache), 1) AS avg_ssd_cache_pct,
       ROUND(SUM(CASE WHEN bytes_scanned = 0 THEN 1 ELSE 0 END) / 
             NULLIF(COUNT(*), 0) * 100, 1) AS result_cache_hit_rate
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND query_type = 'SELECT'
  AND warehouse_name IS NOT NULL
GROUP BY warehouse_name
ORDER BY total_queries DESC;

-- Queuing analysis (are warehouses undersized?)
SELECT warehouse_name, warehouse_size,
       COUNT(*) AS total_queries,
       AVG(queued_overload_time) / 1000 AS avg_queue_sec,
       MAX(queued_overload_time) / 1000 AS max_queue_sec,
       SUM(CASE WHEN queued_overload_time > 0 THEN 1 ELSE 0 END) AS queries_queued,
       ROUND(SUM(CASE WHEN queued_overload_time > 0 THEN 1 ELSE 0 END) / 
             NULLIF(COUNT(*), 0) * 100, 1) AS queue_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND warehouse_name IS NOT NULL
GROUP BY warehouse_name, warehouse_size
HAVING COUNT(*) > 10
ORDER BY avg_queue_sec DESC;


--------------------------------------------------------------------------------
-- STEP 11: ALTER Warehouse Parameters
--------------------------------------------------------------------------------

-- Change statement timeout (kill queries running > 20 minutes)
ALTER WAREHOUSE lab_wh_deep_dive SET STATEMENT_TIMEOUT_IN_SECONDS = 1200;

-- Change queued query timeout (fail after 3 minutes of queuing)
ALTER WAREHOUSE lab_wh_deep_dive SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 180;

-- Update comment
ALTER WAREHOUSE lab_wh_deep_dive SET COMMENT = 'Lab WH - updated parameters for testing';

-- Add a tag for governance/tracking
-- ALTER WAREHOUSE lab_wh_deep_dive SET TAG my_db.my_schema.cost_center = 'ENGINEERING';

-- View all current parameters
SHOW PARAMETERS IN WAREHOUSE lab_wh_deep_dive;

-- Show specific parameters
SHOW PARAMETERS LIKE 'STATEMENT%' IN WAREHOUSE lab_wh_deep_dive;


--------------------------------------------------------------------------------
-- STEP 12: Suspend and Resume Operations
--------------------------------------------------------------------------------

-- Graceful suspend (waits for running queries to finish)
ALTER WAREHOUSE lab_wh_deep_dive SUSPEND;

-- Check state (should be SUSPENDED)
SHOW WAREHOUSES LIKE 'lab_wh_deep_dive';

-- Resume the warehouse
ALTER WAREHOUSE lab_wh_deep_dive RESUME;

-- Verify resumed state
SELECT "name", "state", "running", "queued"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'LAB_WH_DEEP_DIVE';

-- Note: If AUTO_RESUME = TRUE and warehouse is suspended,
-- any submitted query will auto-resume it (you don't need manual RESUME)

-- Demonstrate: resume IF SUSPENDED (avoids error if already running)
ALTER WAREHOUSE lab_wh_deep_dive RESUME IF SUSPENDED;


--------------------------------------------------------------------------------
-- STEP 13: Monitoring Dashboard Queries
--------------------------------------------------------------------------------

-- === WAREHOUSE HEALTH DASHBOARD ===

-- 1. Current warehouse utilization snapshot
SELECT warehouse_name, 
       state,
       CASE WHEN state = 'STARTED' THEN 'RUNNING' 
            WHEN state = 'SUSPENDED' THEN 'IDLE' 
            ELSE state END AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) 
-- Alternative: use SHOW WAREHOUSES and parse result

;
SHOW WAREHOUSES;

-- 2. Credit burn rate (last 24 hours, per hour)
SELECT DATE_TRUNC('hour', start_time) AS hour,
       SUM(credits_used) AS credits_per_hour
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1;

-- 3. Warehouse idle time analysis (cost waste indicator)
WITH warehouse_activity AS (
  SELECT warehouse_name,
         MIN(start_time) AS first_active,
         MAX(end_time) AS last_active,
         SUM(credits_used) AS total_credits,
         COUNT(*) AS metering_intervals
  FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
  WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  GROUP BY warehouse_name
)
SELECT warehouse_name,
       total_credits,
       metering_intervals,
       ROUND(total_credits / NULLIF(metering_intervals, 0), 4) AS avg_credits_per_interval
FROM warehouse_activity
ORDER BY total_credits DESC;

-- 4. Failed/error queries (identify problematic patterns)
SELECT warehouse_name, error_code, error_message,
       COUNT(*) AS error_count,
       MAX(start_time) AS latest_occurrence
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'FAIL'
  AND warehouse_name IS NOT NULL
GROUP BY warehouse_name, error_code, error_message
ORDER BY error_count DESC
LIMIT 20;

-- 5. Spilling queries (warehouse may be undersized)
SELECT warehouse_name, warehouse_size,
       query_id, query_type,
       bytes_spilled_to_local_storage / POWER(1024, 3) AS gb_spilled_local,
       bytes_spilled_to_remote_storage / POWER(1024, 3) AS gb_spilled_remote,
       total_elapsed_time / 1000 AS elapsed_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 20;

-- 6. Auto-suspend effectiveness (are warehouses suspending properly?)
SELECT warehouse_name,
       event_name,
       COUNT(*) AS event_count,
       MIN(timestamp) AS first_event,
       MAX(timestamp) AS last_event
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_EVENTS_HISTORY
WHERE timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND event_name IN ('SUSPEND_WAREHOUSE', 'RESUME_WAREHOUSE', 'RESIZE_WAREHOUSE')
GROUP BY warehouse_name, event_name
ORDER BY warehouse_name, event_name;


--------------------------------------------------------------------------------
-- STEP 14: Cleanup
--------------------------------------------------------------------------------

-- Drop the lab warehouse
DROP WAREHOUSE IF EXISTS lab_wh_deep_dive;

-- Drop the resource monitor (requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
DROP RESOURCE MONITOR IF EXISTS lab_monitor_deep_dive;

-- Switch back to default role
USE ROLE SYSADMIN;

-- Verify cleanup
SHOW WAREHOUSES LIKE 'lab_wh%';
SHOW RESOURCE MONITORS LIKE 'lab_monitor%';

-- Summary of what was covered:
-- Step 1:  SHOW WAREHOUSES - inventory and state
-- Step 2:  CREATE WAREHOUSE with full parameter set
-- Step 3:  Resize operations and behavior
-- Step 4:  Multi-cluster configuration (Standard vs Economy)
-- Step 5:  Auto-suspend timing and behavior
-- Step 6:  Resource monitor with tiered triggers
-- Step 7:  Result cache and SSD cache demonstration
-- Step 8:  QAS eligibility and configuration
-- Step 9:  WAREHOUSE_METERING_HISTORY analysis
-- Step 10: QUERY_HISTORY performance patterns
-- Step 11: ALTER warehouse parameters
-- Step 12: Suspend/Resume operations
-- Step 13: Monitoring dashboard queries
-- Step 14: Cleanup
