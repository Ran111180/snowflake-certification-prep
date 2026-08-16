-- =============================================================================
-- DATA SECURITY DEEP DIVE - HANDS-ON LAB
-- SnowPro Core Certification Prep
-- Topic 25: Masking Policies, Row Access Policies, Tags, Classification
-- =============================================================================

-- =============================================================================
-- SETUP: Create lab environment
-- =============================================================================

USE ROLE SYSADMIN;

CREATE OR REPLACE DATABASE security_lab_db;
CREATE SCHEMA security_lab_db.raw_data;
CREATE SCHEMA security_lab_db.governance;

-- Create sample tables with sensitive data
CREATE OR REPLACE TABLE security_lab_db.raw_data.employees (
    emp_id NUMBER AUTOINCREMENT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    ssn VARCHAR(11),
    salary NUMBER(10,2),
    department VARCHAR(50),
    region VARCHAR(20),
    hire_date DATE
);

INSERT INTO security_lab_db.raw_data.employees
  (first_name, last_name, email, phone, ssn, salary, department, region, hire_date)
VALUES
  ('Alice', 'Johnson', 'alice.johnson@company.com', '555-123-4567', '123-45-6789', 95000, 'Engineering', 'US', '2020-03-15'),
  ('Bob', 'Smith', 'bob.smith@company.com', '555-234-5678', '234-56-7890', 82000, 'Marketing', 'US', '2019-07-22'),
  ('Clara', 'Garcia', 'clara.garcia@company.com', '555-345-6789', '345-67-8901', 105000, 'Engineering', 'EU', '2021-01-10'),
  ('David', 'Kim', 'david.kim@company.com', '555-456-7890', '456-78-9012', 78000, 'Sales', 'APAC', '2022-06-01'),
  ('Eva', 'Mueller', 'eva.mueller@company.com', '555-567-8901', '567-89-0123', 91000, 'HR', 'EU', '2018-11-30'),
  ('Frank', 'Chen', 'frank.chen@company.com', '555-678-9012', '678-90-1234', 115000, 'Engineering', 'APAC', '2017-04-18'),
  ('Grace', 'Williams', 'grace.williams@company.com', '555-789-0123', '789-01-2345', 88000, 'Finance', 'US', '2021-09-05'),
  ('Henry', 'Brown', 'henry.brown@company.com', '555-890-1234', '890-12-3456', 72000, 'Sales', 'EU', '2023-02-14');

-- Create customer table
CREATE OR REPLACE TABLE security_lab_db.raw_data.customers (
    cust_id NUMBER AUTOINCREMENT,
    name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    credit_card VARCHAR(19),
    tenant_id NUMBER
);

INSERT INTO security_lab_db.raw_data.customers
  (name, email, phone, credit_card, tenant_id)
VALUES
  ('Acme Corp', 'contact@acme.com', '800-111-2222', '4111-1111-1111-1111', 1),
  ('Beta Inc', 'info@beta.io', '800-222-3333', '5500-0000-0000-0004', 1),
  ('Gamma LLC', 'sales@gamma.com', '800-333-4444', '3400-000000-00009', 2),
  ('Delta Systems', 'hello@delta.dev', '800-444-5555', '6011-0000-0000-0004', 2),
  ('Epsilon Co', 'admin@epsilon.org', '800-555-6666', '4222-2222-2222-2222', 3);

-- =============================================================================
-- LAB 1: MASKING POLICIES
-- =============================================================================

USE ROLE SYSADMIN;
USE SCHEMA security_lab_db.governance;

-- 1A: Full Mask Policy (everything hidden)
CREATE OR REPLACE MASKING POLICY full_mask_string
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
    ELSE '**MASKED**'
  END;

-- 1B: Partial Mask (show last 4 characters)
CREATE OR REPLACE MASKING POLICY partial_mask_last4
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
    ELSE CONCAT(REPEAT('*', GREATEST(LENGTH(val) - 4, 0)), RIGHT(val, 4))
  END;

-- 1C: Email Mask (hide username, show domain)
CREATE OR REPLACE MASKING POLICY mask_email
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
    WHEN IS_ROLE_IN_SESSION('HR_ROLE') THEN val
    ELSE CONCAT('****@', SPLIT_PART(val, '@', 2))
  END;

-- 1D: Salary Mask (NULL for unauthorized)
CREATE OR REPLACE MASKING POLICY mask_salary
  AS (val NUMBER(10,2)) RETURNS NUMBER(10,2) ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
    WHEN IS_ROLE_IN_SESSION('FINANCE_ROLE') THEN val
    ELSE NULL
  END;

-- 1E: SHA2 Tokenization Mask (for analytics without PII exposure)
CREATE OR REPLACE MASKING POLICY sha2_mask
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
    ELSE SHA2(val, 256)
  END;

-- =============================================================================
-- LAB 2: APPLY MASKING POLICIES TO COLUMNS
-- =============================================================================

-- Apply policies to employees table
ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN ssn SET MASKING POLICY security_lab_db.governance.partial_mask_last4;

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN email SET MASKING POLICY security_lab_db.governance.mask_email;

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN phone SET MASKING POLICY security_lab_db.governance.full_mask_string;

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN salary SET MASKING POLICY security_lab_db.governance.mask_salary;

-- Apply to customers table
ALTER TABLE security_lab_db.raw_data.customers
  ALTER COLUMN credit_card SET MASKING POLICY security_lab_db.governance.partial_mask_last4;

ALTER TABLE security_lab_db.raw_data.customers
  ALTER COLUMN email SET MASKING POLICY security_lab_db.governance.mask_email;

-- =============================================================================
-- LAB 3: TEST MASKING WITH DIFFERENT ROLES
-- =============================================================================

-- Create test roles
USE ROLE SECURITYADMIN;
CREATE OR REPLACE ROLE hr_role;
CREATE OR REPLACE ROLE finance_role;
CREATE OR REPLACE ROLE analyst_role;

-- Grant access
GRANT USAGE ON DATABASE security_lab_db TO ROLE hr_role;
GRANT USAGE ON DATABASE security_lab_db TO ROLE finance_role;
GRANT USAGE ON DATABASE security_lab_db TO ROLE analyst_role;

GRANT USAGE ON SCHEMA security_lab_db.raw_data TO ROLE hr_role;
GRANT USAGE ON SCHEMA security_lab_db.raw_data TO ROLE finance_role;
GRANT USAGE ON SCHEMA security_lab_db.raw_data TO ROLE analyst_role;

GRANT SELECT ON ALL TABLES IN SCHEMA security_lab_db.raw_data TO ROLE hr_role;
GRANT SELECT ON ALL TABLES IN SCHEMA security_lab_db.raw_data TO ROLE finance_role;
GRANT SELECT ON ALL TABLES IN SCHEMA security_lab_db.raw_data TO ROLE analyst_role;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE hr_role;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE finance_role;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE analyst_role;

-- Grant roles to current user (replace YOUR_USER with actual username)
-- GRANT ROLE hr_role TO USER YOUR_USER;
-- GRANT ROLE finance_role TO USER YOUR_USER;
-- GRANT ROLE analyst_role TO USER YOUR_USER;

-- Test as SYSADMIN (should see everything)
USE ROLE SYSADMIN;
SELECT first_name, email, phone, ssn, salary
FROM security_lab_db.raw_data.employees
LIMIT 3;

-- Test as HR_ROLE (should see email, but not salary)
-- USE ROLE hr_role;
-- SELECT first_name, email, phone, ssn, salary
-- FROM security_lab_db.raw_data.employees LIMIT 3;

-- Test as ANALYST_ROLE (should see masked everything)
-- USE ROLE analyst_role;
-- SELECT first_name, email, phone, ssn, salary
-- FROM security_lab_db.raw_data.employees LIMIT 3;

-- =============================================================================
-- LAB 4: ROW ACCESS POLICY
-- =============================================================================

USE ROLE SYSADMIN;
USE SCHEMA security_lab_db.governance;

-- Create a mapping table for role-based row access
CREATE OR REPLACE TABLE security_lab_db.governance.region_access_map (
    role_name VARCHAR(50),
    allowed_region VARCHAR(20)
);

INSERT INTO security_lab_db.governance.region_access_map VALUES
  ('US_ANALYST', 'US'),
  ('EU_ANALYST', 'EU'),
  ('APAC_ANALYST', 'APAC'),
  ('HR_ROLE', 'US'),
  ('HR_ROLE', 'EU'),
  ('HR_ROLE', 'APAC');

-- Create row access policy using mapping table
CREATE OR REPLACE ROW ACCESS POLICY rap_by_region
  AS (region_col VARCHAR) RETURNS BOOLEAN ->
  IS_ROLE_IN_SESSION('SYSADMIN')
  OR EXISTS (
    SELECT 1 FROM security_lab_db.governance.region_access_map
    WHERE role_name = CURRENT_ROLE()
      AND allowed_region = region_col
  );

-- Apply to employees table
ALTER TABLE security_lab_db.raw_data.employees
  ADD ROW ACCESS POLICY security_lab_db.governance.rap_by_region ON (region);

-- Test: SYSADMIN sees all rows
USE ROLE SYSADMIN;
SELECT emp_id, first_name, department, region
FROM security_lab_db.raw_data.employees;
-- Should see all 8 rows

-- Create regional analyst roles for testing
USE ROLE SECURITYADMIN;
CREATE OR REPLACE ROLE us_analyst;
GRANT USAGE ON DATABASE security_lab_db TO ROLE us_analyst;
GRANT USAGE ON SCHEMA security_lab_db.raw_data TO ROLE us_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA security_lab_db.raw_data TO ROLE us_analyst;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE us_analyst;

-- Test as US_ANALYST (should only see US rows)
-- GRANT ROLE us_analyst TO USER YOUR_USER;
-- USE ROLE us_analyst;
-- SELECT emp_id, first_name, department, region
-- FROM security_lab_db.raw_data.employees;
-- Should see only US rows (Alice, Bob, Grace)

-- =============================================================================
-- LAB 5: OBJECT TAGGING
-- =============================================================================

USE ROLE SYSADMIN;
USE SCHEMA security_lab_db.governance;

-- Create tags
CREATE OR REPLACE TAG pii_type
  ALLOWED_VALUES 'email', 'phone', 'ssn', 'name', 'credit_card', 'salary';

CREATE OR REPLACE TAG data_sensitivity
  ALLOWED_VALUES 'high', 'medium', 'low';

CREATE OR REPLACE TAG data_domain
  ALLOWED_VALUES 'hr', 'finance', 'sales', 'customer';

-- Apply tags to columns
ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN email SET TAG security_lab_db.governance.pii_type = 'email';

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN phone SET TAG security_lab_db.governance.pii_type = 'phone';

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN ssn SET TAG security_lab_db.governance.pii_type = 'ssn';

ALTER TABLE security_lab_db.raw_data.employees
  ALTER COLUMN salary SET TAG security_lab_db.governance.pii_type = 'salary';

ALTER TABLE security_lab_db.raw_data.customers
  ALTER COLUMN credit_card SET TAG security_lab_db.governance.pii_type = 'credit_card';

-- Apply tags to tables
ALTER TABLE security_lab_db.raw_data.employees
  SET TAG security_lab_db.governance.data_sensitivity = 'high';

ALTER TABLE security_lab_db.raw_data.employees
  SET TAG security_lab_db.governance.data_domain = 'hr';

ALTER TABLE security_lab_db.raw_data.customers
  SET TAG security_lab_db.governance.data_sensitivity = 'high';

ALTER TABLE security_lab_db.raw_data.customers
  SET TAG security_lab_db.governance.data_domain = 'customer';

-- Query tag assignments
SELECT SYSTEM$GET_TAG(
  'security_lab_db.governance.pii_type',
  'security_lab_db.raw_data.employees.email',
  'COLUMN'
) AS tag_value;

-- Find all columns with the pii_type tag
SELECT *
FROM TABLE(
  INFORMATION_SCHEMA.TAG_REFERENCES(
    'security_lab_db.governance.pii_type',
    'COLUMN'
  )
);

-- =============================================================================
-- LAB 6: DATA CLASSIFICATION
-- =============================================================================

USE ROLE SYSADMIN;

-- Run automatic classification on the employees table
-- NOTE: Requires Enterprise Edition or higher
-- SELECT SYSTEM$CLASSIFY('security_lab_db.raw_data.employees');

-- Extract semantic categories (detailed results)
-- SELECT *
-- FROM TABLE(
--   EXTRACT_SEMANTIC_CATEGORIES('security_lab_db.raw_data.employees')
-- );

-- Apply classification tags automatically
-- CALL ASSOCIATE_SEMANTIC_CATEGORY_TAGS(
--   'security_lab_db.raw_data.employees',
--   EXTRACT_SEMANTIC_CATEGORIES('security_lab_db.raw_data.employees')
-- );

-- Verify system tags were applied
-- SELECT SYSTEM$GET_TAG(
--   'SNOWFLAKE.CORE.SEMANTIC_CATEGORY',
--   'security_lab_db.raw_data.employees.email',
--   'COLUMN'
-- );

-- =============================================================================
-- LAB 7: POLICY REFERENCES & GOVERNANCE QUERIES
-- =============================================================================

USE ROLE SYSADMIN;

-- Find all columns with masking policies applied
SELECT *
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'security_lab_db.raw_data.employees',
  REF_ENTITY_DOMAIN => 'TABLE'
));

-- Find where a specific policy is used
SELECT *
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
  POLICY_NAME => 'security_lab_db.governance.mask_email'
));

-- List all masking policies in the governance schema
SHOW MASKING POLICIES IN SCHEMA security_lab_db.governance;

-- List all row access policies
SHOW ROW ACCESS POLICIES IN SCHEMA security_lab_db.governance;

-- List all tags
SHOW TAGS IN SCHEMA security_lab_db.governance;

-- =============================================================================
-- LAB 8: ADVANCED - TAG-BASED MASKING POLICY
-- =============================================================================

USE ROLE SYSADMIN;
USE SCHEMA security_lab_db.governance;

-- First, remove directly-applied masking policies (can't have both tag-based and direct)
-- ALTER TABLE security_lab_db.raw_data.employees
--   ALTER COLUMN email UNSET MASKING POLICY;

-- Create a single tag-based policy that masks differently by tag value
-- CREATE OR REPLACE MASKING POLICY tag_based_mask
--   AS (val VARCHAR) RETURNS VARCHAR ->
--   CASE
--     WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
--     WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('security_lab_db.governance.pii_type') = 'email'
--       THEN CONCAT('****@', SPLIT_PART(val, '@', 2))
--     WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('security_lab_db.governance.pii_type') = 'phone'
--       THEN CONCAT('***-***-', RIGHT(val, 4))
--     WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('security_lab_db.governance.pii_type') = 'ssn'
--       THEN CONCAT('***-**-', RIGHT(val, 4))
--     WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('security_lab_db.governance.pii_type') = 'credit_card'
--       THEN CONCAT('****-****-****-', RIGHT(val, 4))
--     ELSE '**MASKED**'
--   END;

-- Attach policy to tag (all tagged columns auto-masked!)
-- ALTER TAG security_lab_db.governance.pii_type
--   SET MASKING POLICY security_lab_db.governance.tag_based_mask;

-- =============================================================================
-- CLEANUP
-- =============================================================================

-- Remove row access policy
-- ALTER TABLE security_lab_db.raw_data.employees
--   DROP ROW ACCESS POLICY security_lab_db.governance.rap_by_region;

-- Remove masking policies
-- ALTER TABLE security_lab_db.raw_data.employees ALTER COLUMN ssn UNSET MASKING POLICY;
-- ALTER TABLE security_lab_db.raw_data.employees ALTER COLUMN email UNSET MASKING POLICY;
-- ALTER TABLE security_lab_db.raw_data.employees ALTER COLUMN phone UNSET MASKING POLICY;
-- ALTER TABLE security_lab_db.raw_data.employees ALTER COLUMN salary UNSET MASKING POLICY;
-- ALTER TABLE security_lab_db.raw_data.customers ALTER COLUMN credit_card UNSET MASKING POLICY;
-- ALTER TABLE security_lab_db.raw_data.customers ALTER COLUMN email UNSET MASKING POLICY;

-- Drop roles
-- USE ROLE SECURITYADMIN;
-- DROP ROLE IF EXISTS hr_role;
-- DROP ROLE IF EXISTS finance_role;
-- DROP ROLE IF EXISTS analyst_role;
-- DROP ROLE IF EXISTS us_analyst;

-- Drop database
-- USE ROLE SYSADMIN;
-- DROP DATABASE IF EXISTS security_lab_db;
