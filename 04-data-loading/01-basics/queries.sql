-- ============================================================
-- DOMAIN 4A: DATA LOADING & UNLOADING - Hands-On Queries
-- ============================================================

-- 1. Stage management
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

-- List available stages
SHOW STAGES;

-- Internal stage operations
CREATE OR REPLACE STAGE cert_loading_stage
  FILE_FORMAT = (TYPE='CSV' FIELD_DELIMITER=',' SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

-- 2. File format exploration
CREATE OR REPLACE FILE FORMAT csv_format TYPE='CSV' FIELD_DELIMITER=',' SKIP_HEADER=1
  NULL_IF=('NULL','null','') EMPTY_FIELD_AS_NULL=TRUE FIELD_OPTIONALLY_ENCLOSED_BY='"';

CREATE OR REPLACE FILE FORMAT json_format TYPE='JSON' STRIP_OUTER_ARRAY=TRUE;

CREATE OR REPLACE FILE FORMAT parquet_format TYPE='PARQUET';

-- 3. COPY INTO with transformations
-- COPY INTO target_table (col1, col2, col3)
-- FROM (SELECT $1, $2::NUMBER, CURRENT_TIMESTAMP() FROM @my_stage/file.csv)
-- FILE_FORMAT = (FORMAT_NAME = csv_format)
-- ON_ERROR = 'CONTINUE'
-- PURGE = TRUE;

-- 4. Validate before loading (dry run)
-- COPY INTO target_table FROM @my_stage VALIDATION_MODE = 'RETURN_ALL_ERRORS';

-- 5. Check COPY history
SELECT file_name, status, rows_parsed, rows_loaded, error_count,
       first_error_message, first_error_line_num
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'SAMPLE_DATA', START_TIME => DATEADD('day', -7, CURRENT_TIMESTAMP())
));

-- 6. Snowpipe status check
-- SELECT SYSTEM$PIPE_STATUS('my_pipe');
-- ALTER PIPE my_pipe REFRESH;

-- 7. Data unloading
-- COPY INTO @cert_loading_stage/export/
-- FROM (SELECT * FROM sample_data WHERE category = 'Electronics')
-- FILE_FORMAT = (TYPE='PARQUET') HEADER = TRUE MAX_FILE_SIZE = 100000000;
