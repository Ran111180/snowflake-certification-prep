-- ============================================================
-- DOMAIN 6: DATA PROTECTION & SHARING - Hands-On Queries
-- ============================================================

-- 1. Time Travel
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

CREATE OR REPLACE TABLE time_travel_demo (id INT, value VARCHAR);
INSERT INTO time_travel_demo VALUES (1,'original'), (2,'data');

-- Query historical data
SELECT * FROM time_travel_demo AT(OFFSET => -60);
-- SELECT * FROM time_travel_demo BEFORE(STATEMENT => '<query_id>');

-- Restore dropped table
DROP TABLE time_travel_demo;
UNDROP TABLE time_travel_demo;

-- Check retention settings
SHOW TABLES LIKE 'TIME_TRAVEL_DEMO';

-- 2. Zero-Copy Cloning
CREATE OR REPLACE TABLE sample_data_clone CLONE sample_data;
SELECT COUNT(*) AS clone_rows FROM sample_data_clone;
-- Clones share storage until modified - check with:
SELECT TABLE_NAME, ACTIVE_BYTES, TIME_TRAVEL_BYTES, FAILSAFE_BYTES, RETAINED_FOR_CLONE_BYTES
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'CERT_STUDY_DB' AND TABLE_NAME IN ('SAMPLE_DATA','SAMPLE_DATA_CLONE');

-- 3. Clone schemas/databases (metadata operation - instant)
-- CREATE DATABASE dev_db CLONE cert_study_db;
-- CREATE SCHEMA test_schema CLONE architecture;

-- 4. Data Sharing
CREATE OR REPLACE SHARE cert_study_share;
GRANT USAGE ON DATABASE CERT_STUDY_DB TO SHARE cert_study_share;
GRANT USAGE ON SCHEMA CERT_STUDY_DB.ARCHITECTURE TO SHARE cert_study_share;
GRANT SELECT ON TABLE CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA TO SHARE cert_study_share;
SHOW SHARES;

-- 5. Secure Views for sharing
CREATE OR REPLACE SECURE VIEW shared_summary AS
SELECT category, COUNT(*) AS orders, SUM(amount) AS revenue FROM sample_data GROUP BY category;
GRANT SELECT ON VIEW CERT_STUDY_DB.ARCHITECTURE.SHARED_SUMMARY TO SHARE cert_study_share;

-- 6. Fail-safe check
SELECT TABLE_NAME, ACTIVE_BYTES/(1024*1024) AS active_mb, FAILSAFE_BYTES/(1024*1024) AS failsafe_mb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'CERT_STUDY_DB' AND ACTIVE_BYTES > 0 ORDER BY active_mb DESC;
