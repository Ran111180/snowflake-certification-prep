-- ============================================================
-- DOMAIN 1.1: CLOUD ARCHITECTURE - Hands-On Queries
-- ============================================================

-- 1. Check your account details
SELECT CURRENT_ACCOUNT() AS account,
       CURRENT_REGION() AS region,
       CURRENT_ORGANIZATION_NAME() AS org_name,
       CURRENT_VERSION() AS snowflake_version;

-- 2. Platform info
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO() AS platform_info;

-- 3. View account parameters
SHOW PARAMETERS IN ACCOUNT;

-- 4. Create study warehouse
CREATE WAREHOUSE IF NOT EXISTS CERT_STUDY_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- 5. Show all warehouses
SHOW WAREHOUSES;

-- 6. Create study database
CREATE DATABASE IF NOT EXISTS CERT_STUDY_DB;
CREATE SCHEMA IF NOT EXISTS CERT_STUDY_DB.ARCHITECTURE;

-- 7. Create sample data (1M rows)
CREATE OR REPLACE TABLE CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA AS
SELECT SEQ4() AS id,
       UNIFORM(1, 1000, RANDOM()) AS amount,
       DATEADD(day, UNIFORM(1, 365, RANDOM()), '2024-01-01')::DATE AS order_date,
       ARRAY_CONSTRUCT('Electronics','Clothing','Food','Books','Sports')
         [UNIFORM(0,4,RANDOM())]::VARCHAR AS category
FROM TABLE(GENERATOR(ROWCOUNT => 1000000));

-- 8. Check table storage (micro-partitions)
SELECT TABLE_NAME, ROW_COUNT, BYTES, ROUND(BYTES/(1024*1024),2) AS size_mb
FROM CERT_STUDY_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ARCHITECTURE' AND TABLE_NAME = 'SAMPLE_DATA';

-- 9. Result cache demo (run twice - second is instant)
SELECT category, COUNT(*) AS cnt, AVG(amount) AS avg_amount
FROM CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA
GROUP BY category ORDER BY cnt DESC;

-- 10. Resource monitor
CREATE OR REPLACE RESOURCE MONITOR cert_study_monitor
  WITH CREDIT_QUOTA = 10
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 75 PERCENT DO NOTIFY
           ON 100 PERCENT DO SUSPEND;
