-- ============================================================
-- DOMAIN 5B: UDFs, TASKS, STREAMS, DYNAMIC TABLES
-- ============================================================

-- 1. User-Defined Functions
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

-- SQL UDF
CREATE OR REPLACE FUNCTION mask_email(email VARCHAR)
RETURNS VARCHAR AS $$ CONCAT(LEFT(email, 2), '***@', SPLIT_PART(email, '@', 2)) $$;
SELECT mask_email('ranga.naik@example.com');

-- JavaScript UDF
CREATE OR REPLACE FUNCTION calc_age(birth_date DATE)
RETURNS NUMBER LANGUAGE JAVASCRIPT AS $$ return Math.floor((Date.now() - new Date(BIRTH_DATE)) / (365.25*24*60*60*1000)); $$;

-- UDTF (Table Function)
CREATE OR REPLACE FUNCTION generate_dates(start_date DATE, num_days NUMBER)
RETURNS TABLE(dt DATE) LANGUAGE SQL AS $$ SELECT DATEADD('day', seq4(), start_date) AS dt FROM TABLE(GENERATOR(ROWCOUNT => num_days)) $$;
SELECT * FROM TABLE(generate_dates('2024-01-01'::DATE, 7));

-- 2. Stored Procedure
CREATE OR REPLACE PROCEDURE get_category_stats(cat_name VARCHAR)
RETURNS VARCHAR LANGUAGE SQL AS
BEGIN
  LET cnt INTEGER := 0;
  LET total FLOAT := 0;
  SELECT COUNT(*), SUM(amount) INTO cnt, total FROM sample_data WHERE category = :cat_name;
  RETURN 'Category: ' || cat_name || ', Count: ' || cnt::VARCHAR || ', Total: $' || ROUND(total,2)::VARCHAR;
END;
CALL get_category_stats('Electronics');

-- 3. Streams (CDC)
CREATE OR REPLACE STREAM raw_events_stream ON TABLE raw_events APPEND_ONLY = TRUE;
SELECT SYSTEM$STREAM_HAS_DATA('raw_events_stream');
-- Insert data then check stream
INSERT INTO raw_events VALUES ('E99','U5','purchase',CURRENT_TIMESTAMP(),NULL);
SELECT * FROM raw_events_stream;

-- 4. Tasks
-- CREATE OR REPLACE TASK process_events_task
--   WAREHOUSE = COMPUTE_WH SCHEDULE = '5 MINUTE'
--   WHEN SYSTEM$STREAM_HAS_DATA('raw_events_stream')
-- AS INSERT INTO processed_events SELECT * FROM raw_events_stream;
-- ALTER TASK process_events_task RESUME;
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) ORDER BY SCHEDULED_TIME DESC LIMIT 5;

-- 5. Dynamic Tables
CREATE OR REPLACE DYNAMIC TABLE category_daily_summary
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH
AS SELECT category, order_date::DATE AS day, COUNT(*) AS orders, SUM(amount) AS revenue
   FROM sample_data GROUP BY category, day;
SELECT * FROM category_daily_summary ORDER BY day DESC, revenue DESC LIMIT 10;

-- Check Dynamic Table refresh
SELECT name, target_lag, refresh_mode, scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES()) WHERE name = 'CATEGORY_DAILY_SUMMARY';
