-- =============================================================================
-- 21. DATA LOADING & UNLOADING - HANDS-ON LAB
-- =============================================================================
-- SnowPro Core Certification Prep
-- Topics: Stages, File Formats, COPY INTO, PUT, LIST, REMOVE, GET,
--         ON_ERROR, VALIDATION_MODE, Transformations, Unloading, FORCE
-- =============================================================================

-- =============================================================================
-- STEP 1: SETUP - Create database and schema for the lab
-- =============================================================================

USE ROLE SYSADMIN;

CREATE OR REPLACE DATABASE DATA_LOADING_LAB;
CREATE OR REPLACE SCHEMA DATA_LOADING_LAB.LOADING;

USE DATABASE DATA_LOADING_LAB;
USE SCHEMA LOADING;

-- Create a warehouse for loading operations
CREATE OR REPLACE WAREHOUSE LOADING_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

USE WAREHOUSE LOADING_WH;

-- =============================================================================
-- STEP 2: CREATE INTERNAL NAMED STAGE
-- =============================================================================

-- Create a basic internal stage (no file format yet)
CREATE OR REPLACE STAGE raw_data_stage
  COMMENT = 'Internal stage for raw data files';

-- Create a stage with directory table enabled
CREATE OR REPLACE STAGE dir_enabled_stage
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage with directory table for file metadata queries';

-- Create a stage with encryption specified
CREATE OR REPLACE STAGE encrypted_stage
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Stage with explicit SSE encryption';

-- View stage properties
DESCRIBE STAGE raw_data_stage;
SHOW STAGES;

-- =============================================================================
-- STEP 3: CREATE FILE FORMAT OBJECTS
-- =============================================================================

-- CSV file format with common options
CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = CSV
  FIELD_DELIMITER = ','
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  COMPRESSION = AUTO
  COMMENT = 'Standard CSV format with header skip';

-- Pipe-delimited format
CREATE OR REPLACE FILE FORMAT pipe_format
  TYPE = CSV
  FIELD_DELIMITER = '|'
  SKIP_HEADER = 1
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- JSON file format
CREATE OR REPLACE FILE FORMAT json_format
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE
  STRIP_NULL_VALUES = FALSE
  IGNORE_UTF8_ERRORS = FALSE
  COMMENT = 'JSON format with outer array stripping';

-- Parquet file format
CREATE OR REPLACE FILE FORMAT parquet_format
  TYPE = PARQUET
  COMPRESSION = SNAPPY
  BINARY_AS_TEXT = TRUE;

-- View file formats
SHOW FILE FORMATS;
DESCRIBE FILE FORMAT csv_format;

-- =============================================================================
-- STEP 4: PUT FILES (Concept & Example)
-- =============================================================================

-- NOTE: PUT command only works from SnowSQL CLI or connectors (JDBC/ODBC/Python)
-- It does NOT work from the Snowsight web UI worksheet.
-- The following are example commands you would run from SnowSQL:

/*
-- Upload a single file to named stage
PUT file://C:/data/sales_2026.csv @raw_data_stage AUTO_COMPRESS=TRUE;

-- Upload multiple files with wildcard
PUT file://C:/data/sales_*.csv @raw_data_stage/sales/ PARALLEL=8;

-- Upload to user stage
PUT file://C:/data/employees.csv @~;

-- Upload to table stage
PUT file://C:/data/products.csv @%products_table;

-- Upload without compression
PUT file://C:/data/already_compressed.csv.gz @raw_data_stage
  AUTO_COMPRESS=FALSE
  SOURCE_COMPRESSION=GZIP;

-- Upload with overwrite
PUT file://C:/data/updated_file.csv @raw_data_stage OVERWRITE=TRUE;
*/

-- Since we can't PUT from a worksheet, let's create sample data directly
-- using internal Snowflake capabilities for this lab:

CREATE OR REPLACE TABLE sample_source AS
SELECT
  SEQ4() AS id,
  'Product_' || SEQ4() AS product_name,
  UNIFORM(10.00, 999.99, RANDOM())::DECIMAL(10,2) AS price,
  UNIFORM(1, 1000, RANDOM()) AS quantity,
  DATEADD(day, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS sale_date,
  ARRAY_CONSTRUCT('Electronics', 'Clothing', 'Food', 'Books', 'Sports')[UNIFORM(0,4,RANDOM())]::VARCHAR AS category
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

-- Unload to create files in our stage (so we can practice loading them back)
COPY INTO @raw_data_stage/sales/
  FROM sample_source
  FILE_FORMAT = (TYPE = CSV HEADER = TRUE COMPRESSION = NONE)
  MAX_FILE_SIZE = 50000  -- Small files for demo (50KB each)
  OVERWRITE = TRUE;

-- =============================================================================
-- STEP 5: LIST STAGE
-- =============================================================================

-- List all files in the stage
LIST @raw_data_stage;

-- List with path prefix
LIST @raw_data_stage/sales/;

-- List with pattern filter (regex!)
LIST @raw_data_stage PATTERN = '.*sales.*';

-- List user stage (will be empty unless you've PUT files)
LIST @~;

-- Check directory table (if enabled)
SELECT * FROM DIRECTORY(@dir_enabled_stage);

-- =============================================================================
-- STEP 6: COPY INTO WITH OPTIONS
-- =============================================================================

-- Create target table for loading
CREATE OR REPLACE TABLE sales_loaded (
  id NUMBER,
  product_name VARCHAR(100),
  price DECIMAL(10,2),
  quantity NUMBER,
  sale_date DATE,
  category VARCHAR(50)
);

-- Basic COPY INTO
COPY INTO sales_loaded
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  ON_ERROR = ABORT_STATEMENT;

-- Check results
SELECT COUNT(*) AS rows_loaded FROM sales_loaded;
SELECT * FROM sales_loaded LIMIT 10;

-- =============================================================================
-- STEP 7: CHECK COPY_HISTORY
-- =============================================================================

-- Query load history (real-time, last 14 days)
SELECT
  FILE_NAME,
  STAGE_LOCATION,
  STATUS,
  ROW_COUNT,
  ROW_PARSED,
  ERROR_COUNT,
  FIRST_ERROR_MESSAGE,
  LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'SALES_LOADED',
  START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;

-- Try to reload the same files (will be skipped due to 64-day history)
COPY INTO sales_loaded
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);
-- Expected: "Copy executed with 0 files processed" (all skipped)

-- =============================================================================
-- STEP 8: ON_ERROR DEMONSTRATION
-- =============================================================================

-- Create a file with intentional errors
CREATE OR REPLACE TABLE error_source AS
SELECT * FROM (
  SELECT 1 AS id, 'Good Row' AS name, 100.00 AS amount
  UNION ALL SELECT 2, 'Also Good', 200.00
  UNION ALL SELECT 3, 'Bad Amount', NULL  -- This is fine (NULL allowed)
  UNION ALL SELECT 4, 'Good Again', 400.00
);

-- Unload clean data
COPY INTO @raw_data_stage/errors/
  FROM error_source
  FILE_FORMAT = (TYPE = CSV HEADER = TRUE COMPRESSION = NONE)
  SINGLE = TRUE
  OVERWRITE = TRUE;

-- Create a target with strict typing for error demos
CREATE OR REPLACE TABLE strict_target (
  id NUMBER NOT NULL,
  name VARCHAR(5),  -- Very short! Will cause truncation errors
  amount DECIMAL(10,2) NOT NULL
);

-- ABORT_STATEMENT (default) - entire load fails on first error
COPY INTO strict_target
  FROM @raw_data_stage/errors/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  ON_ERROR = ABORT_STATEMENT;
-- Expected: Error due to 'Good Row' exceeding VARCHAR(5)

-- CONTINUE - skip bad rows, load good rows
TRUNCATE TABLE strict_target;
COPY INTO strict_target
  FROM @raw_data_stage/errors/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  ON_ERROR = CONTINUE;

SELECT * FROM strict_target;  -- Only rows that fit constraints

-- SKIP_FILE - skip entire file if any error
TRUNCATE TABLE strict_target;
COPY INTO strict_target
  FROM @raw_data_stage/errors/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  ON_ERROR = SKIP_FILE;
-- Expected: Entire file skipped (0 rows loaded)

-- =============================================================================
-- STEP 9: VALIDATION_MODE DEMONSTRATION
-- =============================================================================

-- Create proper target for validation
CREATE OR REPLACE TABLE validation_target (
  id NUMBER,
  product_name VARCHAR(100),
  price DECIMAL(10,2),
  quantity NUMBER,
  sale_date DATE,
  category VARCHAR(50)
);

-- RETURN_ROWS - Preview what would be loaded (no actual load!)
COPY INTO validation_target
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  VALIDATION_MODE = RETURN_5_ROWS;
-- Returns 5 rows showing data preview - table remains EMPTY

-- Verify table is still empty
SELECT COUNT(*) FROM validation_target;  -- Should be 0!

-- RETURN_ALL_ERRORS - Find all problems
COPY INTO validation_target
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  VALIDATION_MODE = RETURN_ALL_ERRORS;
-- Returns error details (if any) - still no data loaded

-- Now actually load
COPY INTO validation_target
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  FORCE = TRUE;  -- FORCE because these files were loaded into sales_loaded earlier
                 -- (different table, but using FORCE for demonstration)

SELECT COUNT(*) FROM validation_target;

-- =============================================================================
-- STEP 10: TRANSFORMATION DURING LOAD ($1, $2, METADATA$FILENAME)
-- =============================================================================

-- Create target table with audit columns
CREATE OR REPLACE TABLE sales_with_audit (
  row_id NUMBER AUTOINCREMENT,
  product_name VARCHAR(100),
  price DECIMAL(10,2),
  sale_date DATE,
  category_upper VARCHAR(50),
  source_file VARCHAR(500),
  file_row_num NUMBER,
  loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Load with transformation: reorder columns, add metadata, transform values
COPY INTO sales_with_audit (product_name, price, sale_date, category_upper, source_file, file_row_num)
  FROM (
    SELECT
      $2,                           -- product_name (2nd column in file)
      $3::DECIMAL(10,2),           -- price with explicit cast
      TO_DATE($5, 'YYYY-MM-DD'),   -- sale_date with format
      UPPER($6),                    -- category transformed to uppercase
      METADATA$FILENAME,            -- capture source filename
      METADATA$FILE_ROW_NUMBER      -- capture row number within file
    FROM @raw_data_stage/sales/
  )
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  FORCE = TRUE;

-- Verify transformation results
SELECT * FROM sales_with_audit LIMIT 20;

-- Check which files contributed data
SELECT
  source_file,
  COUNT(*) AS rows_from_file,
  MIN(file_row_num) AS first_row,
  MAX(file_row_num) AS last_row
FROM sales_with_audit
GROUP BY source_file
ORDER BY source_file;

-- =============================================================================
-- STEP 11: UNLOAD TO STAGE (COPY INTO @stage)
-- =============================================================================

-- Basic unload to internal stage as CSV with headers
COPY INTO @raw_data_stage/exports/csv_export/
  FROM sales_loaded
  FILE_FORMAT = (TYPE = CSV HEADER = TRUE COMPRESSION = GZIP)
  OVERWRITE = TRUE
  MAX_FILE_SIZE = 100000;  -- 100KB per file

-- Unload as Parquet
COPY INTO @raw_data_stage/exports/parquet_export/
  FROM sales_loaded
  FILE_FORMAT = (TYPE = PARQUET)
  OVERWRITE = TRUE;

-- Unload query results (not just a table)
COPY INTO @raw_data_stage/exports/filtered/
  FROM (
    SELECT product_name, price, quantity, category
    FROM sales_loaded
    WHERE price > 500
    AND category = 'Electronics'
  )
  FILE_FORMAT = (TYPE = CSV HEADER = TRUE COMPRESSION = NONE)
  OVERWRITE = TRUE
  SINGLE = TRUE;  -- One output file

-- Unload with PARTITION BY
COPY INTO @raw_data_stage/exports/partitioned/
  FROM sales_loaded
  FILE_FORMAT = (TYPE = PARQUET)
  PARTITION BY ('category=' || category)
  OVERWRITE = TRUE;

-- Verify unloaded files
LIST @raw_data_stage/exports/;
LIST @raw_data_stage/exports/csv_export/;
LIST @raw_data_stage/exports/parquet_export/;
LIST @raw_data_stage/exports/partitioned/;

-- =============================================================================
-- STEP 12: GET COMMAND (Concept)
-- =============================================================================

-- NOTE: GET only works from SnowSQL or connectors, not from Snowsight worksheets.
-- Examples of what you would run from SnowSQL:

/*
-- Download all files from a stage path
GET @raw_data_stage/exports/csv_export/ file://C:/downloads/;

-- Download specific file
GET @raw_data_stage/exports/filtered/data_0_0_0.csv file://C:/downloads/;

-- Download with pattern
GET @raw_data_stage/exports/ file://C:/downloads/ PATTERN='.*parquet.*';

-- Download from user stage
GET @~ file://C:/downloads/;
*/

-- =============================================================================
-- STEP 13: FORCE = TRUE RELOAD DEMONSTRATION
-- =============================================================================

-- Check current row count
SELECT COUNT(*) AS before_force FROM sales_loaded;

-- Try normal COPY (will skip - files already in 64-day history)
COPY INTO sales_loaded
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);
-- Result: 0 files processed (skipped)

-- Now use FORCE=TRUE to reload (creates DUPLICATES!)
COPY INTO sales_loaded
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  FORCE = TRUE;

-- Check count - should be doubled!
SELECT COUNT(*) AS after_force FROM sales_loaded;

-- This demonstrates why FORCE=TRUE is dangerous - duplicate data!
-- Clean up the duplicates
TRUNCATE TABLE sales_loaded;
COPY INTO sales_loaded
  FROM @raw_data_stage/sales/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
  FORCE = TRUE;

SELECT COUNT(*) AS clean_count FROM sales_loaded;

-- =============================================================================
-- STEP 14: MATCH_BY_COLUMN_NAME DEMONSTRATION
-- =============================================================================

-- First, unload data with headers to a clean location
CREATE OR REPLACE TABLE match_source (
  customer_id NUMBER,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  email VARCHAR(100),
  signup_date DATE
);

INSERT INTO match_source VALUES
  (1, 'Alice', 'Smith', 'alice@example.com', '2026-01-15'),
  (2, 'Bob', 'Jones', 'bob@example.com', '2026-02-20'),
  (3, 'Charlie', 'Brown', 'charlie@example.com', '2026-03-10');

-- Unload with headers (column names in the file)
COPY INTO @raw_data_stage/match_test/
  FROM match_source
  FILE_FORMAT = (TYPE = CSV HEADER = TRUE COMPRESSION = NONE)
  OVERWRITE = TRUE
  SINGLE = TRUE;

-- Create target with DIFFERENT column order
CREATE OR REPLACE TABLE match_target (
  email VARCHAR(100),
  last_name VARCHAR(50),
  customer_id NUMBER,
  signup_date DATE,
  first_name VARCHAR(50)
);

-- Load WITHOUT match_by_column_name (positional) - columns will be WRONG
COPY INTO match_target
  FROM @raw_data_stage/match_test/
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)  -- skip header, use position
  FORCE = TRUE;

SELECT * FROM match_target;  -- Data in wrong columns!

-- Now load WITH match_by_column_name - columns matched correctly
TRUNCATE TABLE match_target;
COPY INTO match_target
  FROM @raw_data_stage/match_test/
  FILE_FORMAT = (TYPE = CSV PARSE_HEADER = TRUE)  -- PARSE_HEADER required!
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  FORCE = TRUE;

SELECT * FROM match_target;  -- Data in correct columns!

-- =============================================================================
-- STEP 15: CLEANUP
-- =============================================================================

-- Remove files from stage
REMOVE @raw_data_stage/sales/;
REMOVE @raw_data_stage/errors/;
REMOVE @raw_data_stage/exports/;
REMOVE @raw_data_stage/match_test/;

-- Verify stage is empty
LIST @raw_data_stage;

-- Drop lab objects (uncomment when done with lab)
-- DROP DATABASE IF EXISTS DATA_LOADING_LAB;
-- DROP WAREHOUSE IF EXISTS LOADING_WH;

-- =============================================================================
-- KEY TAKEAWAYS FOR CERTIFICATION:
-- =============================================================================
/*
1. STAGES: User (@~), Table (@%table), Named (@stage) - only named supports GRANT
2. FILE FORMAT: Schema-level reusable object, 6 types (CSV, JSON, Parquet, Avro, ORC, XML)
3. COPY INTO default ON_ERROR: ABORT_STATEMENT (bulk) vs SKIP_FILE (Snowpipe)
4. 64-DAY HISTORY: Tracks file name + checksum per table; FORCE=TRUE bypasses
5. VALIDATION_MODE: Dry-run only - NEVER loads data
6. TRANSFORMATIONS: $1/$2 positional, METADATA$ columns, no JOINs/subqueries/aggregates
7. MATCH_BY_COLUMN_NAME: Requires PARSE_HEADER=TRUE for CSV
8. UNLOAD: OVERWRITE default FALSE, MAX_FILE_SIZE 16MB (CSV) / 256MB (Parquet)
9. PUT/GET: Internal stages only, SnowSQL/connectors only (not Snowsight)
10. FILE SIZING: 100-250 MB compressed optimal for parallel loading
11. PATTERN: Uses Java regex (NOT SQL LIKE % and _)
12. METADATA$: Only available during COPY INTO transformation (not regular queries)
13. PURGE=TRUE: Deletes only successfully loaded files from stage
14. COPY is auto-committed: Cannot rollback a successful COPY INTO
15. STORAGE INTEGRATION: Secure credential-free access; requires CREATE INTEGRATION privilege
*/