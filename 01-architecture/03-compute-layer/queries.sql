-- ============================================================
-- DOMAIN 1.3: COMPUTE LAYER - Hands-On Queries
-- ============================================================

-- 1. Show all warehouses with details
SHOW WAREHOUSES;

-- 2. Create ETL warehouse
CREATE WAREHOUSE IF NOT EXISTS ETL_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  MAX_CONCURRENCY_LEVEL = 4
  COMMENT = 'ETL/data loading warehouse';

-- 3. Credit usage by warehouse (last 7 days)
SELECT warehouse_name, SUM(credits_used) AS total_credits,
       SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cloud_svc_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name ORDER BY total_credits DESC;

-- 4. Cache experiment (disable result cache)
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
SELECT order_date, SUM(amount) FROM CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA
WHERE category = 'Electronics' GROUP BY order_date ORDER BY order_date LIMIT 5;
-- Run again to test local SSD cache
SELECT order_date, SUM(amount) FROM CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA
WHERE category = 'Electronics' GROUP BY order_date ORDER BY order_date LIMIT 5;
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- 5. Suspend/Resume demo
ALTER WAREHOUSE COMPUTE_WH SUSPEND;
SHOW DATABASES; -- Works without warehouse (Cloud Services!)
ALTER WAREHOUSE COMPUTE_WH RESUME;
