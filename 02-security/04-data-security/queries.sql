-- ============================================================
-- DOMAIN 2.4: DATA SECURITY - Hands-On Queries
-- ============================================================

-- 1. Create and apply tags for data classification
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

CREATE OR REPLACE TAG data_sensitivity ALLOWED_VALUES 'PII', 'SENSITIVE', 'PUBLIC';
CREATE OR REPLACE TAG data_domain ALLOWED_VALUES 'HR', 'FINANCE', 'MARKETING';

-- Apply tags to tables/columns
ALTER TABLE employees SET TAG data_sensitivity = 'PII';
ALTER TABLE employees MODIFY COLUMN email SET TAG data_sensitivity = 'PII';
ALTER TABLE employees MODIFY COLUMN salary SET TAG data_sensitivity = 'SENSITIVE';
ALTER TABLE sample_data SET TAG data_domain = 'FINANCE';

-- 2. Verify tag assignments
SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('CERT_STUDY_DB.ARCHITECTURE.EMPLOYEES', 'TABLE'));
SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('CERT_STUDY_DB.ARCHITECTURE.EMPLOYEES', 'TABLE'));

-- 3. Masking policy (requires Enterprise edition)
-- CREATE OR REPLACE MASKING POLICY email_mask AS (val STRING) RETURNS STRING ->
--   CASE WHEN CURRENT_ROLE() IN ('SYSADMIN','ACCOUNTADMIN') THEN val
--        ELSE CONCAT(LEFT(val,2), '***@***.com') END;
-- ALTER TABLE employees MODIFY COLUMN email SET MASKING POLICY email_mask;

-- 4. Row access policy (requires Enterprise edition)
-- CREATE OR REPLACE ROW ACCESS POLICY dept_filter AS (dept_val VARCHAR) RETURNS BOOLEAN ->
--   CURRENT_ROLE() = 'ACCOUNTADMIN' OR dept_val = CURRENT_ROLE();

-- 5. Object tagging - find all PII tagged objects
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE TAG_NAME = 'DATA_SENSITIVITY' AND TAG_VALUE = 'PII'
ORDER BY OBJECT_MODIFIED_AT DESC;
