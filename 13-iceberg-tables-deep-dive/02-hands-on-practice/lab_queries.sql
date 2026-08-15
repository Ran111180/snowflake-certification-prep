-- ============================================================
-- ICEBERG TABLES - Hands-On Lab
-- SnowPro Core Certification Practice
-- ============================================================
-- NOTE: Iceberg tables require an External Volume configured
-- with cloud storage (S3/Azure/GCS). If you don't have one,
-- you can still learn the syntax and concepts from this file.
-- Steps that require an external volume are marked [REQUIRES EV]
-- ============================================================

-- ============================================================
-- STEP 1: SETUP
-- ============================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;

CREATE SCHEMA IF NOT EXISTS ICEBERG_LAB;
USE SCHEMA ICEBERG_LAB;

-- ============================================================
-- STEP 2: UNDERSTAND ICEBERG CONCEPTS (No External Volume Needed)
-- ============================================================

-- Check what external volumes exist (if any)
SHOW EXTERNAL VOLUMES;

-- Check what catalog integrations exist
SHOW CATALOG INTEGRATIONS;

-- ============================================================
-- STEP 3: [REQUIRES EV] CREATE EXTERNAL VOLUME
-- ============================================================
-- Uncomment and modify for your cloud provider:

-- AWS S3:
-- CREATE OR REPLACE EXTERNAL VOLUME iceberg_lab_vol
--   STORAGE_LOCATIONS = (
--     (
--       NAME = 'iceberg-lab-s3'
--       STORAGE_BASE_URL = 's3://YOUR-BUCKET/iceberg-lab/'
--       STORAGE_PROVIDER = 'S3'
--       STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR-ACCOUNT:role/YOUR-ROLE'
--     )
--   )
--   ALLOW_WRITES = TRUE;

-- Verify the volume
-- DESC EXTERNAL VOLUME iceberg_lab_vol;

-- ============================================================
-- STEP 4: [REQUIRES EV] CREATE SNOWFLAKE-MANAGED ICEBERG TABLE
-- ============================================================

-- CREATE OR REPLACE ICEBERG TABLE orders_iceberg (
--     order_id INT,
--     customer_name VARCHAR(100),
--     product VARCHAR(100),
--     quantity INT,
--     amount DECIMAL(10,2),
--     order_date DATE,
--     region VARCHAR(50)
-- )
--   CATALOG = 'SNOWFLAKE'
--   EXTERNAL_VOLUME = 'iceberg_lab_vol'
--   BASE_LOCATION = 'orders/';

-- ============================================================
-- STEP 5: [REQUIRES EV] DML OPERATIONS (Full Read/Write)
-- ============================================================

-- INSERT (same as native table)
-- INSERT INTO orders_iceberg VALUES
--   (1, 'Alice', 'Laptop', 2, 2599.98, '2026-08-15', 'US-West'),
--   (2, 'Bob', 'Monitor', 1, 499.99, '2026-08-15', 'US-East'),
--   (3, 'Carol', 'Keyboard', 5, 399.95, '2026-08-14', 'EU-West'),
--   (4, 'David', 'Mouse', 10, 299.90, '2026-08-14', 'APAC'),
--   (5, 'Eva', 'Webcam', 3, 389.97, '2026-08-13', 'US-West');

-- SELECT (verify data)
-- SELECT * FROM orders_iceberg ORDER BY order_id;

-- UPDATE (works on Snowflake-managed!)
-- UPDATE orders_iceberg SET quantity = 3 WHERE order_id = 1;

-- DELETE (works on Snowflake-managed!)
-- DELETE FROM orders_iceberg WHERE order_id = 5;

-- MERGE (upsert pattern)
-- MERGE INTO orders_iceberg t
-- USING (SELECT 2 AS order_id, 'Bob' AS customer_name, 'Monitor 4K' AS product,
--              2 AS quantity, 1099.98 AS amount, '2026-08-15'::DATE AS order_date,
--              'US-East' AS region) s
-- ON t.order_id = s.order_id
-- WHEN MATCHED THEN UPDATE SET t.product = s.product, t.quantity = s.quantity, t.amount = s.amount
-- WHEN NOT MATCHED THEN INSERT VALUES (s.order_id, s.customer_name, s.product, s.quantity, s.amount, s.order_date, s.region);

-- ============================================================
-- STEP 6: [REQUIRES EV] SCHEMA EVOLUTION
-- ============================================================

-- Add column (no data file rewrite!)
-- ALTER ICEBERG TABLE orders_iceberg ADD COLUMN discount_pct DECIMAL(5,2);

-- Verify (existing rows have NULL for new column)
-- SELECT order_id, customer_name, discount_pct FROM orders_iceberg;

-- Rename column
-- ALTER ICEBERG TABLE orders_iceberg RENAME COLUMN discount_pct TO discount_percent;

-- Drop column (metadata-only, no file rewrite)
-- ALTER ICEBERG TABLE orders_iceberg DROP COLUMN discount_percent;

-- ============================================================
-- STEP 7: [REQUIRES EV] TIME TRAVEL ON ICEBERG
-- ============================================================

-- Time Travel works on Snowflake-managed Iceberg tables!
-- SELECT * FROM orders_iceberg AT(OFFSET => -300);  -- 5 minutes ago

-- Check current row count vs historical
-- SELECT COUNT(*) AS current_count FROM orders_iceberg;
-- SELECT COUNT(*) AS count_5min_ago FROM orders_iceberg AT(OFFSET => -300);

-- ============================================================
-- STEP 8: [REQUIRES EV] CLUSTERING
-- ============================================================

-- Add clustering (Snowflake-managed only)
-- ALTER ICEBERG TABLE orders_iceberg CLUSTER BY (order_date, region);

-- Check clustering info
-- SELECT SYSTEM$CLUSTERING_INFORMATION('orders_iceberg', '(order_date, region)');

-- ============================================================
-- STEP 9: [REQUIRES EV] CREATE STREAM ON ICEBERG TABLE
-- ============================================================

-- Streams work on Snowflake-managed Iceberg!
-- CREATE OR REPLACE STREAM iceberg_orders_stream
--   ON ICEBERG TABLE orders_iceberg;

-- Make a change
-- INSERT INTO orders_iceberg VALUES
--   (6, 'Frank', 'Headset', 2, 259.98, '2026-08-15', 'EU-West');

-- Check stream output
-- SELECT * FROM iceberg_orders_stream;

-- ============================================================
-- STEP 10: COMPARE ICEBERG vs NATIVE TABLE SYNTAX
-- ============================================================

-- Native table (for comparison)
CREATE OR REPLACE TABLE native_comparison (
    id INT,
    name VARCHAR(50),
    value DECIMAL(10,2)
);

INSERT INTO native_comparison VALUES (1, 'Test', 99.99);

-- Key differences in DDL:
-- Native: CREATE TABLE ...  (no CATALOG, no EXTERNAL_VOLUME)
-- Iceberg: CREATE ICEBERG TABLE ... CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='vol' BASE_LOCATION='path/'

-- Both support:
-- INSERT, UPDATE, DELETE, MERGE, Time Travel, Clustering, Streams
-- Iceberg DOES NOT support: Fail-safe, Temporary/Transient, Materialized Views

-- ============================================================
-- STEP 11: PRACTICE - CATALOG INTEGRATION CONCEPTS
-- ============================================================

-- These are the types you need to know for the exam:

-- 1. SNOWFLAKE catalog (Snowflake manages metadata)
--    CATALOG = 'SNOWFLAKE'

-- 2. AWS Glue (external catalog)
--    CREATE CATALOG INTEGRATION ... CATALOG_SOURCE = GLUE

-- 3. REST catalog (Polaris, Tabular, custom)
--    CREATE CATALOG INTEGRATION ... CATALOG_SOURCE = ICEBERG_REST

-- 4. Object Store (direct metadata path, simplest)
--    CREATE CATALOG INTEGRATION ... CATALOG_SOURCE = OBJECT_STORE
--    + METADATA_FILE_PATH in CREATE TABLE

-- Quick reference: When to use each?
-- - Snowflake is only engine → CATALOG = 'SNOWFLAKE'
-- - Spark + Glue + Snowflake → CATALOG_SOURCE = GLUE
-- - Multi-engine with Polaris → CATALOG_SOURCE = ICEBERG_REST
-- - One-off file access → CATALOG_SOURCE = OBJECT_STORE

-- ============================================================
-- STEP 12: PRACTICE - EXTERNAL TABLE vs ICEBERG TABLE
-- ============================================================

-- External Table (older approach — file-based, limited features)
-- CREATE EXTERNAL TABLE ext_events (
--   event_id VARCHAR AS (VALUE:event_id::VARCHAR),
--   event_type VARCHAR AS (VALUE:event_type::VARCHAR)
-- )
--   LOCATION = @my_stage/events/
--   FILE_FORMAT = (TYPE = PARQUET);

-- Iceberg Table (modern approach — full table semantics)
-- CREATE ICEBERG TABLE iceberg_events (...)
--   CATALOG = 'SNOWFLAKE'
--   EXTERNAL_VOLUME = 'my_vol'
--   BASE_LOCATION = 'events/';

-- Key differences:
-- External Table: READ-ONLY, no Time Travel, no clustering, no DML
-- Iceberg (SF-managed): Full DML, Time Travel, clustering, streams
-- Both: Data on YOUR storage, readable by other engines

-- ============================================================
-- STEP 13: MONITORING QUERIES
-- ============================================================

-- Check all Iceberg tables in schema
SHOW ICEBERG TABLES IN SCHEMA ICEBERG_LAB;

-- If you have an Iceberg table, check its properties:
-- DESC ICEBERG TABLE orders_iceberg;

-- Check storage metrics (if table exists):
-- SELECT TABLE_NAME, ACTIVE_BYTES, TIME_TRAVEL_BYTES
-- FROM INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
-- WHERE TABLE_SCHEMA = 'ICEBERG_LAB';

-- ============================================================
-- STEP 14: EXAM KEY POINTS REVIEW
-- ============================================================

-- Run these as mental exercises / discussion points:

-- Q: What is the minimum setup needed for a Snowflake-managed Iceberg table?
-- A: 1) External Volume (cloud storage + IAM), 2) CREATE ICEBERG TABLE with CATALOG='SNOWFLAKE'

-- Q: Can two engines write to the same Iceberg table simultaneously?
-- A: For Snowflake-managed: NO (only Snowflake writes)
--    For externally-managed: Depends on external catalog's concurrency control

-- Q: What's the billing model?
-- A: Compute: Snowflake credits (querying). Storage: YOUR cloud bill (S3/Azure/GCS).

-- Q: Can I use Snowflake governance (masking, RAP) on Iceberg tables?
-- A: YES — full governance stack works on both managed and external Iceberg tables.

-- ============================================================
-- STEP 15: CLEANUP
-- ============================================================

DROP TABLE IF EXISTS native_comparison;
-- DROP ICEBERG TABLE IF EXISTS orders_iceberg;
-- DROP STREAM IF EXISTS iceberg_orders_stream;
-- DROP SCHEMA ICEBERG_LAB;

-- ============================================================
-- LAB COMPLETE!
-- Key Takeaways:
-- 1. Iceberg = Open format (Parquet) on YOUR storage
-- 2. Snowflake-managed = full DML + Time Travel + Clustering
-- 3. Externally-managed = READ-ONLY in Snowflake
-- 4. No fail-safe for any Iceberg table
-- 5. External Volume = bridge between Snowflake and your cloud storage
-- 6. Schema evolution doesn't rewrite data files (metadata-only)
-- 7. Can join Iceberg + native tables seamlessly
-- 8. Streams, DTs, Snowpipe all work with Snowflake-managed Iceberg
-- ============================================================