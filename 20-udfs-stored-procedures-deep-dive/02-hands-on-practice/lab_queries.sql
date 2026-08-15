-- ============================================================
-- UDFs & STORED PROCEDURES - Hands-On Lab
-- SnowPro Core Certification Practice
-- ============================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;
CREATE SCHEMA IF NOT EXISTS UDF_LAB;
USE SCHEMA UDF_LAB;

-- ============================================================
-- STEP 1: SQL UDF (Scalar - Single Expression)
-- ============================================================
CREATE OR REPLACE FUNCTION celsius_to_fahrenheit(c DECIMAL(10,2))
RETURNS DECIMAL(10,2)
LANGUAGE SQL
AS 'c * 9/5 + 32';

-- Test it
SELECT celsius_to_fahrenheit(0) AS freezing,
       celsius_to_fahrenheit(100) AS boiling,
       celsius_to_fahrenheit(37) AS body_temp;

-- ============================================================
-- STEP 2: SQL UDF with VARIANT
-- ============================================================
CREATE OR REPLACE FUNCTION extract_email_domain(email VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS 'SPLIT_PART(email, ''@'', 2)';

SELECT extract_email_domain('alice@example.com') AS domain;

-- ============================================================
-- STEP 3: JavaScript UDF (Multi-line Logic)
-- ============================================================
CREATE OR REPLACE FUNCTION classify_amount(amount FLOAT)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS $$
  if (amount === undefined) return 'UNKNOWN';
  if (amount >= 1000) return 'HIGH';
  if (amount >= 100) return 'MEDIUM';
  return 'LOW';
$$;

SELECT classify_amount(1500), classify_amount(50), classify_amount(NULL);

-- ============================================================
-- STEP 4: Python UDF
-- ============================================================
CREATE OR REPLACE FUNCTION slugify(text VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'run'
AS $$
import re
def run(text):
    if text is None:
        return None
    slug = text.lower().strip()
    slug = re.sub(r'[^a-z0-9]+', '-', slug)
    return slug.strip('-')
$$;

SELECT slugify('Hello World! This is a Test') AS slug;

-- ============================================================
-- STEP 5: SQL Table Function (UDTF)
-- ============================================================
CREATE OR REPLACE FUNCTION generate_date_range(start_date DATE, end_date DATE)
RETURNS TABLE(date_val DATE)
LANGUAGE SQL
AS $$
  SELECT DATEADD(day, SEQ4(), start_date) AS date_val
  FROM TABLE(GENERATOR(ROWCOUNT => DATEDIFF(day, start_date, end_date) + 1))
$$;

-- Use the UDTF
SELECT * FROM TABLE(generate_date_range('2026-08-01'::DATE, '2026-08-07'::DATE));

-- ============================================================
-- STEP 6: Stored Procedure (SQL Scripting)
-- ============================================================
CREATE OR REPLACE PROCEDURE insert_sample_data(num_rows INT)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    CREATE TABLE IF NOT EXISTS sample_data (id INT, value VARCHAR, created_at TIMESTAMP);

    LET i INT := 1;
    WHILE (i <= :num_rows) DO
        INSERT INTO sample_data VALUES (:i, 'Row ' || :i, CURRENT_TIMESTAMP());
        i := i + 1;
    END WHILE;

    RETURN 'Inserted ' || :num_rows || ' rows successfully';
END;

-- Call it
CALL insert_sample_data(5);
SELECT * FROM sample_data;

-- ============================================================
-- STEP 7: Stored Procedure with Exception Handling
-- ============================================================
CREATE OR REPLACE PROCEDURE safe_divide(numerator FLOAT, denominator FLOAT)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET result FLOAT;

    IF (:denominator = 0) THEN
        RETURN 'Error: Division by zero';
    END IF;

    result := :numerator / :denominator;
    RETURN 'Result: ' || :result::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'Unexpected error: ' || SQLERRM;
END;

CALL safe_divide(10, 2);    -- Result: 5
CALL safe_divide(10, 0);    -- Error: Division by zero

-- ============================================================
-- STEP 8: OWNER vs CALLER Rights Demo
-- ============================================================

-- Create a table owned by DATA_ENGINEER
CREATE OR REPLACE TABLE secret_data (id INT, secret VARCHAR);
INSERT INTO secret_data VALUES (1, 'Classified Information');

-- OWNER rights: procedure can access secret_data even if caller can't
CREATE OR REPLACE PROCEDURE get_secret_count()
RETURNS INT
LANGUAGE SQL
EXECUTE AS OWNER  -- Runs with DATA_ENGINEER privileges
AS
BEGIN
    RETURN (SELECT COUNT(*) FROM secret_data);
END;

-- CALLER rights: would fail if caller doesn't have SELECT on secret_data
CREATE OR REPLACE PROCEDURE get_secret_count_caller()
RETURNS INT
LANGUAGE SQL
EXECUTE AS CALLER  -- Runs with the calling user's privileges
AS
BEGIN
    RETURN (SELECT COUNT(*) FROM secret_data);
END;

-- Both work for us (we own the table), but behavior differs for other roles
CALL get_secret_count();
CALL get_secret_count_caller();

-- ============================================================
-- STEP 9: Anonymous Block (No CREATE needed)
-- ============================================================
-- Anonymous blocks always run as CALLER
BEGIN
    LET msg VARCHAR := 'Hello from anonymous block!';
    LET count INT := (SELECT COUNT(*) FROM sample_data);
    RETURN msg || ' Rows: ' || count;
END;

-- ============================================================
-- STEP 10: UDF Overloading (Same Name, Different Args)
-- ============================================================
-- Version 1: Single number
CREATE OR REPLACE FUNCTION format_value(val INT)
RETURNS VARCHAR LANGUAGE SQL AS 'val || '' units''';

-- Version 2: Number with label
CREATE OR REPLACE FUNCTION format_value(val INT, label VARCHAR)
RETURNS VARCHAR LANGUAGE SQL AS 'val || '' '' || label';

-- Snowflake resolves by argument signature
SELECT format_value(42);              -- "42 units"
SELECT format_value(42, 'widgets');   -- "42 widgets"

-- ============================================================
-- STEP 11: SECURE Function
-- ============================================================
CREATE OR REPLACE SECURE FUNCTION mask_email(email VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS 'LEFT(email, 1) || ''***@'' || SPLIT_PART(email, ''@'', 2)';

-- Works the same, but definition hidden from non-owners
SELECT mask_email('alice@example.com');  -- a***@example.com

-- Check if function is secure
SHOW USER FUNCTIONS LIKE 'MASK_EMAIL';
-- is_secure column = Y

-- ============================================================
-- STEP 12: IMMUTABLE vs VOLATILE
-- ============================================================
-- IMMUTABLE: Snowflake can cache/optimize
CREATE OR REPLACE FUNCTION double_it(x INT)
RETURNS INT
LANGUAGE SQL
IMMUTABLE
AS 'x * 2';

-- VOLATILE: Called every time (default)
CREATE OR REPLACE FUNCTION random_label()
RETURNS VARCHAR
LANGUAGE SQL
VOLATILE
AS 'CASE WHEN RANDOM() > 0 THEN ''A'' ELSE ''B'' END';

SELECT double_it(5);     -- Always 10 (cacheable)
SELECT random_label();   -- Random each call

-- ============================================================
-- STEP 13: CLEANUP
-- ============================================================
-- DROP FUNCTION celsius_to_fahrenheit(DECIMAL);
-- DROP FUNCTION extract_email_domain(VARCHAR);
-- DROP FUNCTION classify_amount(FLOAT);
-- DROP FUNCTION slugify(VARCHAR);
-- DROP FUNCTION generate_date_range(DATE, DATE);
-- DROP FUNCTION format_value(INT);
-- DROP FUNCTION format_value(INT, VARCHAR);
-- DROP FUNCTION mask_email(VARCHAR);
-- DROP FUNCTION double_it(INT);
-- DROP FUNCTION random_label();
-- DROP PROCEDURE insert_sample_data(INT);
-- DROP PROCEDURE safe_divide(FLOAT, FLOAT);
-- DROP PROCEDURE get_secret_count();
-- DROP PROCEDURE get_secret_count_caller();
-- DROP TABLE sample_data;
-- DROP TABLE secret_data;
-- DROP SCHEMA UDF_LAB;

-- ============================================================
-- KEY TAKEAWAYS:
-- 1. SQL UDFs = single expression only (no multi-statement)
-- 2. JavaScript/Python UDFs = multi-line logic with full language features
-- 3. UDFs are READ-ONLY (cannot do DML)
-- 4. Procedures can do DML (INSERT, UPDATE, DELETE, DDL)
-- 5. Default is EXECUTE AS OWNER (security delegation)
-- 6. CALLER rights = runs with caller's privileges
-- 7. Anonymous blocks always run as CALLER
-- 8. IMMUTABLE = cacheable; VOLATILE = called every time
-- 9. SECURE hides definition AND prevents optimizer pushdown
-- 10. Overloading = same name, different argument types
-- ============================================================