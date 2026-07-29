-- ============================================================
-- DOMAIN 4B: PRODUCTION PIPELINES - Hands-On Queries
-- ============================================================

-- 1. SCD Type 2 implementation
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

-- SCD2 table structure
CREATE OR REPLACE TABLE dim_customer_scd2 (
  customer_key INTEGER AUTOINCREMENT, customer_id VARCHAR,
  name VARCHAR, email VARCHAR, city VARCHAR,
  effective_from TIMESTAMP, effective_to TIMESTAMP DEFAULT '9999-12-31'::TIMESTAMP,
  is_current BOOLEAN DEFAULT TRUE
);

-- Staging table for incoming data
CREATE OR REPLACE TABLE stg_customers (customer_id VARCHAR, name VARCHAR, email VARCHAR, city VARCHAR);
INSERT INTO stg_customers VALUES ('C001','Alice','alice@new.com','Mumbai'), ('C002','Bob','bob@new.com','Delhi');

-- SCD2 MERGE pattern
MERGE INTO dim_customer_scd2 t
USING stg_customers s ON t.customer_id = s.customer_id AND t.is_current = TRUE
WHEN MATCHED AND (t.email != s.email OR t.city != s.city) THEN
  UPDATE SET is_current = FALSE, effective_to = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (customer_id, name, email, city, effective_from) VALUES (s.customer_id, s.name, s.email, s.city, CURRENT_TIMESTAMP());

-- Insert new versions for changed records
INSERT INTO dim_customer_scd2 (customer_id, name, email, city, effective_from)
SELECT s.customer_id, s.name, s.email, s.city, CURRENT_TIMESTAMP()
FROM stg_customers s JOIN dim_customer_scd2 t ON s.customer_id = t.customer_id
WHERE t.is_current = FALSE AND t.effective_to = (SELECT MAX(effective_to) FROM dim_customer_scd2 WHERE customer_id = s.customer_id AND is_current = FALSE);

-- 2. Deduplication pattern
CREATE OR REPLACE TABLE raw_events (event_id VARCHAR, user_id VARCHAR, event_type VARCHAR, ts TIMESTAMP, data VARIANT);
INSERT INTO raw_events VALUES ('E1','U1','click',CURRENT_TIMESTAMP(),NULL), ('E1','U1','click',CURRENT_TIMESTAMP(),NULL);

SELECT * FROM raw_events QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ts DESC) = 1;

-- 3. Error handling in pipelines
SELECT file_name, status, rows_parsed, rows_loaded, error_count, first_error_message
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(TABLE_NAME=>'RAW_EVENTS', START_TIME=>DATEADD('day',-7,CURRENT_TIMESTAMP())));

-- 4. Stream + Task orchestration
CREATE OR REPLACE STREAM raw_events_stream ON TABLE raw_events APPEND_ONLY = TRUE;
-- CREATE OR REPLACE TASK process_events_task WAREHOUSE = COMPUTE_WH SCHEDULE = '5 MINUTE'
-- WHEN SYSTEM$STREAM_HAS_DATA('raw_events_stream')
-- AS MERGE INTO processed_events t USING raw_events_stream s ON t.event_id = s.event_id
--    WHEN NOT MATCHED THEN INSERT VALUES (s.event_id, s.user_id, s.event_type, s.ts, s.data);
