-- ============================================================
-- DOMAIN 1.2: STORAGE LAYER - Hands-On Queries
-- ============================================================

-- 1. Check clustering depth
SELECT SYSTEM$CLUSTERING_DEPTH('CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA', '(order_date)') AS depth_by_date;

-- 2. Storage metrics
SELECT TABLE_NAME, ROW_COUNT, BYTES, ROUND(BYTES/(1024*1024),2) AS size_mb
FROM CERT_STUDY_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ARCHITECTURE' AND ROW_COUNT > 0;

-- 3. Immutability demo (UPDATE creates new partitions)
CREATE OR REPLACE TABLE CERT_STUDY_DB.ARCHITECTURE.storage_demo (id INT, name VARCHAR, value NUMBER);
INSERT INTO storage_demo VALUES (1,'Alpha',100),(2,'Beta',200),(3,'Gamma',300);
UPDATE storage_demo SET value = 999 WHERE id = 1;
DELETE FROM storage_demo WHERE id = 3;

-- 4. Table types comparison
CREATE OR REPLACE TABLE perm_table (id INT) DATA_RETENTION_TIME_IN_DAYS = 7;
CREATE OR REPLACE TRANSIENT TABLE transient_table (id INT) DATA_RETENTION_TIME_IN_DAYS = 1;
CREATE OR REPLACE TEMPORARY TABLE temp_table (id INT) DATA_RETENTION_TIME_IN_DAYS = 0;
SHOW TABLES IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;

-- 5. Account-level storage usage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE ORDER BY USAGE_DATE DESC LIMIT 7;
