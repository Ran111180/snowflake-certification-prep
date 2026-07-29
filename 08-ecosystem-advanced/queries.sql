-- ============================================================
-- DOMAIN 8: ECOSYSTEM & ADVANCED FEATURES - Hands-On Queries
-- ============================================================

-- 1. Iceberg Tables (External Volume required)
-- CREATE OR REPLACE ICEBERG TABLE my_iceberg_table (id INT, name VARCHAR, ts TIMESTAMP)
--   CATALOG = 'SNOWFLAKE'
--   EXTERNAL_VOLUME = 'my_ext_volume'
--   BASE_LOCATION = 'iceberg/my_table/';

-- 2. Native App Framework
-- CREATE APPLICATION PACKAGE my_app_pkg;
-- CREATE APPLICATION my_app FROM APPLICATION PACKAGE my_app_pkg;

-- 3. Snowpark Container Services
-- CREATE COMPUTE POOL my_pool MIN_NODES=1 MAX_NODES=3 INSTANCE_FAMILY=CPU_X64_XS;
-- CREATE SERVICE my_service IN COMPUTE POOL my_pool FROM SPECIFICATION_FILE='spec.yaml';

-- 4. Data Clean Rooms (conceptual - requires setup)
-- Collaboration between two accounts without exposing raw data

-- 5. Account-level metadata queries
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

-- Account info
SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_VERSION(), CURRENT_CLIENT();

-- All objects in our study database
SELECT table_type, COUNT(*) AS cnt FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'ARCHITECTURE' GROUP BY table_type;

-- 6. Replication
-- ALTER DATABASE CERT_STUDY_DB ENABLE REPLICATION TO ACCOUNTS org.target_account;
-- CREATE DATABASE replica_db AS REPLICA OF org.source_account.CERT_STUDY_DB;

-- 7. Resource Monitors
-- CREATE RESOURCE MONITOR study_monitor WITH CREDIT_QUOTA = 10
--   TRIGGERS ON 80 PERCENT DO NOTIFY ON 100 PERCENT DO SUSPEND;
-- ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = study_monitor;

-- 8. Summary of all objects created during certification study
SHOW TABLES IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW VIEWS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW STREAMS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW TASKS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW DYNAMIC TABLES IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW PROCEDURES IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW USER FUNCTIONS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
SHOW SHARES;
SHOW TAGS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
