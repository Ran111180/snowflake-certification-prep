-- ============================================================================
-- 17. RBAC & Access Control Deep Dive - Hands-On Lab Queries
-- ============================================================================
-- Topics: Custom roles, role hierarchy, FUTURE grants, managed access schemas,
--         ownership transfer, privilege testing
-- ============================================================================

-- ============================================================================
-- LAB 1: Creating Custom Roles & Building a Hierarchy
-- ============================================================================

-- Use USERADMIN to create roles (best practice)
USE ROLE USERADMIN;

-- Create functional roles
CREATE ROLE IF NOT EXISTS lab_data_admin
  COMMENT = 'Admin role for lab database management';

CREATE ROLE IF NOT EXISTS lab_analyst
  COMMENT = 'Read-only analyst role for lab exercises';

CREATE ROLE IF NOT EXISTS lab_engineer
  COMMENT = 'ETL/write access for data engineers';

CREATE ROLE IF NOT EXISTS lab_viewer
  COMMENT = 'Minimal read-only access';

-- Build role hierarchy: viewer → analyst → engineer → data_admin → SYSADMIN
USE ROLE SECURITYADMIN;

GRANT ROLE lab_viewer TO ROLE lab_analyst;
GRANT ROLE lab_analyst TO ROLE lab_engineer;
GRANT ROLE lab_engineer TO ROLE lab_data_admin;
GRANT ROLE lab_data_admin TO ROLE SYSADMIN;

-- Grant roles to current user for testing
GRANT ROLE lab_data_admin TO USER CURRENT_USER;
GRANT ROLE lab_analyst TO USER CURRENT_USER;
GRANT ROLE lab_viewer TO USER CURRENT_USER;

-- Verify hierarchy
SHOW GRANTS OF ROLE lab_viewer;
SHOW GRANTS OF ROLE lab_analyst;
SHOW GRANTS OF ROLE lab_data_admin;

-- ============================================================================
-- LAB 2: Granting Object Privileges
-- ============================================================================

USE ROLE SYSADMIN;

-- Create lab database and schema
CREATE DATABASE IF NOT EXISTS rbac_lab_db;
CREATE SCHEMA IF NOT EXISTS rbac_lab_db.lab_schema;
CREATE SCHEMA IF NOT EXISTS rbac_lab_db.sensitive_schema;

-- Create sample tables
CREATE OR REPLACE TABLE rbac_lab_db.lab_schema.sales (
    sale_id INT AUTOINCREMENT,
    product_name VARCHAR(100),
    amount DECIMAL(10,2),
    sale_date DATE DEFAULT CURRENT_DATE()
);

CREATE OR REPLACE TABLE rbac_lab_db.lab_schema.customers (
    customer_id INT AUTOINCREMENT,
    name VARCHAR(100),
    email VARCHAR(200),
    tier VARCHAR(20)
);

CREATE OR REPLACE TABLE rbac_lab_db.sensitive_schema.salary_data (
    employee_id INT,
    salary DECIMAL(12,2),
    department VARCHAR(50)
);

-- Insert sample data
INSERT INTO rbac_lab_db.lab_schema.sales (product_name, amount) 
VALUES ('Widget A', 99.99), ('Widget B', 149.99), ('Widget C', 29.99);

INSERT INTO rbac_lab_db.lab_schema.customers (name, email, tier)
VALUES ('Alice Smith', 'alice@example.com', 'Gold'),
       ('Bob Jones', 'bob@example.com', 'Silver');

INSERT INTO rbac_lab_db.sensitive_schema.salary_data
VALUES (1, 85000, 'Engineering'), (2, 92000, 'Marketing');

-- Grant privileges to lab_viewer: database + schema USAGE + SELECT
USE ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE rbac_lab_db TO ROLE lab_viewer;
GRANT USAGE ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA rbac_lab_db.lab_schema TO ROLE lab_viewer;

-- Grant warehouse usage (use your warehouse name)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE lab_viewer;

-- Grant additional write privileges to lab_engineer
GRANT USAGE ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_engineer;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rbac_lab_db.lab_schema TO ROLE lab_engineer;
GRANT CREATE TABLE ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_engineer;

-- Grant full control to lab_data_admin
GRANT ALL PRIVILEGES ON DATABASE rbac_lab_db TO ROLE lab_data_admin;
GRANT ALL PRIVILEGES ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_data_admin;
GRANT ALL PRIVILEGES ON SCHEMA rbac_lab_db.sensitive_schema TO ROLE lab_data_admin;

-- ============================================================================
-- LAB 3: Testing Privilege Inheritance
-- ============================================================================

-- Test as lab_viewer (should have SELECT only)
USE ROLE lab_viewer;
USE WAREHOUSE COMPUTE_WH;

SELECT * FROM rbac_lab_db.lab_schema.sales;          -- Should SUCCEED
SELECT * FROM rbac_lab_db.lab_schema.customers;      -- Should SUCCEED

-- These should FAIL for lab_viewer:
-- INSERT INTO rbac_lab_db.lab_schema.sales (product_name, amount) VALUES ('Test', 10.00);
-- SELECT * FROM rbac_lab_db.sensitive_schema.salary_data;

-- Test as lab_analyst (inherits from lab_viewer, should also have SELECT)
USE ROLE lab_analyst;
SELECT * FROM rbac_lab_db.lab_schema.sales;          -- Should SUCCEED (inherited)

-- Test as lab_engineer (should have write access)
USE ROLE lab_engineer;
INSERT INTO rbac_lab_db.lab_schema.sales (product_name, amount) VALUES ('Test Product', 55.00);
SELECT * FROM rbac_lab_db.lab_schema.sales;          -- Should show the new row

-- ============================================================================
-- LAB 4: FUTURE Grants
-- ============================================================================

USE ROLE SECURITYADMIN;

-- Set FUTURE grants at schema level
GRANT SELECT ON FUTURE TABLES IN SCHEMA rbac_lab_db.lab_schema TO ROLE lab_viewer;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA rbac_lab_db.lab_schema TO ROLE lab_viewer;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA rbac_lab_db.lab_schema TO ROLE lab_engineer;

-- Set FUTURE grants at database level
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE rbac_lab_db TO ROLE lab_viewer;

-- Verify FUTURE grants
SHOW FUTURE GRANTS IN SCHEMA rbac_lab_db.lab_schema;
SHOW FUTURE GRANTS IN DATABASE rbac_lab_db;

-- Test: Create a new table and verify FUTURE grants apply
USE ROLE SYSADMIN;
CREATE TABLE rbac_lab_db.lab_schema.orders (
    order_id INT AUTOINCREMENT,
    customer_id INT,
    total DECIMAL(10,2),
    order_date DATE DEFAULT CURRENT_DATE()
);

INSERT INTO rbac_lab_db.lab_schema.orders (customer_id, total) VALUES (1, 250.00);

-- Verify lab_viewer automatically has SELECT (thanks to FUTURE grant)
USE ROLE lab_viewer;
SELECT * FROM rbac_lab_db.lab_schema.orders;  -- Should SUCCEED without explicit grant!

-- ============================================================================
-- LAB 5: Managed Access Schema
-- ============================================================================

USE ROLE SYSADMIN;

-- Create a managed access schema
CREATE SCHEMA IF NOT EXISTS rbac_lab_db.managed_schema WITH MANAGED ACCESS;

-- Create a table in the managed access schema
CREATE TABLE rbac_lab_db.managed_schema.restricted_data (
    id INT,
    secret_value VARCHAR(100)
);

INSERT INTO rbac_lab_db.managed_schema.restricted_data VALUES (1, 'classified-info');

-- Grant the engineer role usage on the managed schema
USE ROLE SECURITYADMIN;
GRANT USAGE ON SCHEMA rbac_lab_db.managed_schema TO ROLE lab_engineer;

-- Now test: lab_engineer owns the table but CANNOT grant on it
-- (The schema owner/SYSADMIN must do grants in managed access schemas)
USE ROLE lab_engineer;
-- This will FAIL in a managed access schema:
-- GRANT SELECT ON TABLE rbac_lab_db.managed_schema.restricted_data TO ROLE lab_viewer;

-- Only the schema owner (SYSADMIN) or SECURITYADMIN (MANAGE GRANTS) can grant
USE ROLE SECURITYADMIN;
GRANT SELECT ON TABLE rbac_lab_db.managed_schema.restricted_data TO ROLE lab_viewer;

-- Now lab_viewer can access it
USE ROLE lab_viewer;
SELECT * FROM rbac_lab_db.managed_schema.restricted_data;  -- Should SUCCEED

-- Verify managed access status
USE ROLE SYSADMIN;
SHOW SCHEMAS IN DATABASE rbac_lab_db;
-- Look for 'MANAGED ACCESS' = 'Y' in the output

-- ============================================================================
-- LAB 6: Ownership Transfer
-- ============================================================================

USE ROLE SYSADMIN;

-- Create a table owned by SYSADMIN
CREATE TABLE rbac_lab_db.lab_schema.transfer_test (
    id INT,
    data VARCHAR(50)
);

INSERT INTO rbac_lab_db.lab_schema.transfer_test VALUES (1, 'original data');

-- Grant SELECT to lab_viewer
USE ROLE SECURITYADMIN;
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.transfer_test TO ROLE lab_viewer;

-- Check current grants before transfer
SHOW GRANTS ON TABLE rbac_lab_db.lab_schema.transfer_test;

-- Transfer ownership WITH COPY CURRENT GRANTS
GRANT OWNERSHIP ON TABLE rbac_lab_db.lab_schema.transfer_test 
  TO ROLE lab_data_admin 
  COPY CURRENT GRANTS;

-- Verify: lab_viewer should still have SELECT (grants were copied)
SHOW GRANTS ON TABLE rbac_lab_db.lab_schema.transfer_test;
USE ROLE lab_viewer;
SELECT * FROM rbac_lab_db.lab_schema.transfer_test;  -- Should SUCCEED

-- Now test REVOKE CURRENT GRANTS behavior
USE ROLE lab_data_admin;
CREATE TABLE rbac_lab_db.lab_schema.transfer_test_2 (id INT, info VARCHAR(50));
INSERT INTO rbac_lab_db.lab_schema.transfer_test_2 VALUES (1, 'test data');

USE ROLE SECURITYADMIN;
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.transfer_test_2 TO ROLE lab_viewer;

-- Transfer with REVOKE CURRENT GRANTS
GRANT OWNERSHIP ON TABLE rbac_lab_db.lab_schema.transfer_test_2
  TO ROLE SYSADMIN
  REVOKE CURRENT GRANTS;

-- Check: lab_viewer should have LOST SELECT
SHOW GRANTS ON TABLE rbac_lab_db.lab_schema.transfer_test_2;
-- lab_viewer's SELECT will be gone

-- ============================================================================
-- LAB 7: WITH GRANT OPTION & CASCADE Revoke
-- ============================================================================

USE ROLE SECURITYADMIN;

-- Create additional test roles
USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS lab_delegator COMMENT = 'Role with grant option';
CREATE ROLE IF NOT EXISTS lab_recipient COMMENT = 'Receives delegated grants';

USE ROLE SECURITYADMIN;
GRANT ROLE lab_delegator TO ROLE SYSADMIN;
GRANT ROLE lab_recipient TO ROLE SYSADMIN;
GRANT ROLE lab_delegator TO USER CURRENT_USER;
GRANT ROLE lab_recipient TO USER CURRENT_USER;

-- Grant USAGE prerequisites
GRANT USAGE ON DATABASE rbac_lab_db TO ROLE lab_delegator;
GRANT USAGE ON DATABASE rbac_lab_db TO ROLE lab_recipient;
GRANT USAGE ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_delegator;
GRANT USAGE ON SCHEMA rbac_lab_db.lab_schema TO ROLE lab_recipient;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE lab_delegator;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE lab_recipient;

-- Grant SELECT with GRANT OPTION to lab_delegator
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.sales 
  TO ROLE lab_delegator 
  WITH GRANT OPTION;

-- lab_delegator re-grants to lab_recipient
USE ROLE lab_delegator;
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.sales TO ROLE lab_recipient;

-- Verify both can access
USE ROLE lab_recipient;
SELECT * FROM rbac_lab_db.lab_schema.sales;  -- Should SUCCEED

-- Now revoke from lab_delegator WITHOUT CASCADE
USE ROLE SECURITYADMIN;
REVOKE SELECT ON TABLE rbac_lab_db.lab_schema.sales FROM ROLE lab_delegator;

-- lab_recipient should STILL have access (no CASCADE)
USE ROLE lab_recipient;
SELECT * FROM rbac_lab_db.lab_schema.sales;  -- Should still SUCCEED

-- Re-grant and test CASCADE
USE ROLE SECURITYADMIN;
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.sales 
  TO ROLE lab_delegator WITH GRANT OPTION;

USE ROLE lab_delegator;
GRANT SELECT ON TABLE rbac_lab_db.lab_schema.sales TO ROLE lab_recipient;

-- Now revoke WITH CASCADE
USE ROLE SECURITYADMIN;
REVOKE SELECT ON TABLE rbac_lab_db.lab_schema.sales FROM ROLE lab_delegator CASCADE;

-- lab_recipient should now LOSE access (cascaded)
USE ROLE lab_recipient;
-- SELECT * FROM rbac_lab_db.lab_schema.sales;  -- Should FAIL

-- ============================================================================
-- LAB 8: Auditing & Verification
-- ============================================================================

USE ROLE SECURITYADMIN;

-- Show all privileges granted TO a role
SHOW GRANTS TO ROLE lab_analyst;

-- Show all privileges ON a specific object
SHOW GRANTS ON TABLE rbac_lab_db.lab_schema.sales;

-- Show which users/roles HAVE a specific role
SHOW GRANTS OF ROLE lab_data_admin;

-- Show all roles in the account
SHOW ROLES;

-- Show role hierarchy
SHOW GRANTS OF ROLE lab_viewer;    -- Who has lab_viewer?
SHOW GRANTS TO ROLE lab_viewer;    -- What can lab_viewer do?

-- ============================================================================
-- CLEANUP (Run when done with labs)
-- ============================================================================

/*
USE ROLE SECURITYADMIN;
REVOKE ROLE lab_data_admin FROM USER CURRENT_USER;
REVOKE ROLE lab_analyst FROM USER CURRENT_USER;
REVOKE ROLE lab_viewer FROM USER CURRENT_USER;
REVOKE ROLE lab_delegator FROM USER CURRENT_USER;
REVOKE ROLE lab_recipient FROM USER CURRENT_USER;

USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS rbac_lab_db;

USE ROLE SECURITYADMIN;
DROP ROLE IF EXISTS lab_recipient;
DROP ROLE IF EXISTS lab_delegator;
DROP ROLE IF EXISTS lab_viewer;
DROP ROLE IF EXISTS lab_analyst;
DROP ROLE IF EXISTS lab_engineer;
DROP ROLE IF EXISTS lab_data_admin;
*/