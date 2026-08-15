/*******************************************************************************
 * DATA SHARING LAB - Hands-On Practice
 * Snowflake SnowPro Certification Prep
 * 
 * 14 Steps covering the full data sharing lifecycle
 * Run these in order using a role with appropriate privileges (ACCOUNTADMIN)
 ******************************************************************************/

-- =============================================================================
-- STEP 1: SETUP - Create source database, schema, and sample data
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE DATABASE sharing_lab_provider;
CREATE SCHEMA sharing_lab_provider.sales_data;

-- Create sample tables
CREATE OR REPLACE TABLE sharing_lab_provider.sales_data.customers (
    customer_id     INT AUTOINCREMENT,
    customer_name   VARCHAR(100),
    email           VARCHAR(200),
    region          VARCHAR(50),
    tier            VARCHAR(20),
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE sharing_lab_provider.sales_data.orders (
    order_id        INT AUTOINCREMENT,
    customer_id     INT,
    order_date      DATE,
    product_name    VARCHAR(200),
    quantity        INT,
    unit_price      DECIMAL(10,2),
    total_amount    DECIMAL(12,2)
);

-- Insert sample data
INSERT INTO sharing_lab_provider.sales_data.customers (customer_name, email, region, tier)
VALUES
    ('Acme Corp', 'contact@acme.com', 'US-EAST', 'GOLD'),
    ('Globex Inc', 'info@globex.com', 'US-WEST', 'SILVER'),
    ('Initech', 'hello@initech.com', 'EU-WEST', 'GOLD'),
    ('Umbrella Ltd', 'sales@umbrella.com', 'APAC', 'PLATINUM'),
    ('Stark Industries', 'tony@stark.com', 'US-EAST', 'PLATINUM'),
    ('Wayne Enterprises', 'bruce@wayne.com', 'US-EAST', 'GOLD'),
    ('Wonka Industries', 'willy@wonka.com', 'EU-WEST', 'SILVER'),
    ('Cyberdyne Systems', 'info@cyberdyne.com', 'US-WEST', 'SILVER');

INSERT INTO sharing_lab_provider.sales_data.orders (customer_id, order_date, product_name, quantity, unit_price, total_amount)
VALUES
    (1, '2025-01-15', 'Widget Pro', 100, 29.99, 2999.00),
    (1, '2025-02-20', 'Gadget Plus', 50, 49.99, 2499.50),
    (2, '2025-01-22', 'Widget Pro', 75, 29.99, 2249.25),
    (3, '2025-03-01', 'Mega Bundle', 10, 199.99, 1999.90),
    (4, '2025-02-14', 'Widget Pro', 200, 29.99, 5998.00),
    (4, '2025-03-10', 'Gadget Plus', 150, 49.99, 7498.50),
    (5, '2025-01-30', 'Mega Bundle', 25, 199.99, 4999.75),
    (5, '2025-03-15', 'Widget Pro', 300, 29.99, 8997.00),
    (6, '2025-02-28', 'Gadget Plus', 80, 49.99, 3999.20),
    (7, '2025-03-05', 'Widget Pro', 40, 29.99, 1199.60);

-- Verify data
SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM sharing_lab_provider.sales_data.customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM sharing_lab_provider.sales_data.orders;


-- =============================================================================
-- STEP 2: CREATE SHARE
-- =============================================================================

-- Create an outbound share
CREATE OR REPLACE SHARE sales_data_share
    COMMENT = 'Lab share: Sales data for partner consumption';

-- Verify share was created
SHOW SHARES LIKE 'sales_data_share';

-- Note: At this point the share is empty (no objects granted yet)


-- =============================================================================
-- STEP 3: ADD TABLES TO SHARE
-- =============================================================================

-- Grant usage on database and schema (required before granting on objects)
GRANT USAGE ON DATABASE sharing_lab_provider TO SHARE sales_data_share;
GRANT USAGE ON SCHEMA sharing_lab_provider.sales_data TO SHARE sales_data_share;

-- Grant SELECT on the orders table to the share
GRANT SELECT ON TABLE sharing_lab_provider.sales_data.orders TO SHARE sales_data_share;

-- Verify grants
SHOW GRANTS TO SHARE sales_data_share;

-- Note: We intentionally did NOT share the customers table directly
-- because it contains PII (email). We'll use a secure view instead.


-- =============================================================================
-- STEP 4: SECURE VIEW CREATION (for controlled data access)
-- =============================================================================

-- Create a secure view that masks PII but provides useful customer info
CREATE OR REPLACE SECURE VIEW sharing_lab_provider.sales_data.v_customers_safe AS
SELECT
    customer_id,
    customer_name,
    -- Mask email: show only domain
    CONCAT('***@', SPLIT_PART(email, '@', 2)) AS masked_email,
    region,
    tier,
    created_at
FROM sharing_lab_provider.sales_data.customers;

-- Create a secure view for order summaries with customer context
CREATE OR REPLACE SECURE VIEW sharing_lab_provider.sales_data.v_order_summary AS
SELECT
    o.order_id,
    c.customer_name,
    c.region,
    c.tier,
    o.order_date,
    o.product_name,
    o.quantity,
    o.unit_price,
    o.total_amount
FROM sharing_lab_provider.sales_data.orders o
JOIN sharing_lab_provider.sales_data.customers c
    ON o.customer_id = c.customer_id;

-- Verify the views work
SELECT * FROM sharing_lab_provider.sales_data.v_customers_safe LIMIT 5;
SELECT * FROM sharing_lab_provider.sales_data.v_order_summary LIMIT 5;


-- =============================================================================
-- STEP 5: ADD SECURE VIEWS TO SHARE
-- =============================================================================

-- Grant SELECT on secure views to the share
GRANT SELECT ON VIEW sharing_lab_provider.sales_data.v_customers_safe TO SHARE sales_data_share;
GRANT SELECT ON VIEW sharing_lab_provider.sales_data.v_order_summary TO SHARE sales_data_share;

-- Verify all grants on the share
SHOW GRANTS TO SHARE sales_data_share;

-- The share now contains:
--   - orders table (direct access)
--   - v_customers_safe (PII masked)
--   - v_order_summary (joined view with customer context)


-- =============================================================================
-- STEP 6: ADD CONSUMER ACCOUNT
-- =============================================================================

-- Add a consumer account to the share
-- Replace 'CONSUMER_ACCOUNT_LOCATOR' with the actual account locator
-- Format: orgname.account_name OR account_locator

-- Example (will fail unless you have a real consumer account):
-- ALTER SHARE sales_data_share ADD ACCOUNTS = ORGNAME.CONSUMER_ACCOUNT;

-- To see your own account identifier (useful for testing):
SELECT CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() AS full_account_id;
SELECT CURRENT_ACCOUNT() AS account_locator;

-- For lab purposes, you can add your own account to test (same-account share):
-- ALTER SHARE sales_data_share ADD ACCOUNTS = <your_account_locator>;

-- Show which accounts have access
SHOW GRANTS OF SHARE sales_data_share;


-- =============================================================================
-- STEP 7: CONSUMER-SIDE - Create Database from Share
-- =============================================================================

-- NOTE: Run these commands from the CONSUMER account
-- (or same account if you added yourself in Step 6)

-- Consumer creates a local database from the inbound share
-- Replace PROVIDER_ACCOUNT with the provider's account locator

-- CREATE DATABASE shared_sales_data FROM SHARE PROVIDER_ACCOUNT.sales_data_share;

-- If testing in same account, the syntax is:
-- CREATE DATABASE shared_sales_data FROM SHARE sales_data_share;

-- Grant access to roles that need to query shared data
-- GRANT IMPORTED PRIVILEGES ON DATABASE shared_sales_data TO ROLE SYSADMIN;


-- =============================================================================
-- STEP 8: QUERY SHARED DATA (Consumer perspective)
-- =============================================================================

-- These queries simulate what a consumer would run
-- For lab purposes, query the source data to understand the consumer experience

-- Consumer queries the shared secure views
SELECT * FROM sharing_lab_provider.sales_data.v_customers_safe;

SELECT * FROM sharing_lab_provider.sales_data.v_order_summary
WHERE region = 'US-EAST'
ORDER BY total_amount DESC;

-- Consumer can run aggregations on shared data
SELECT
    product_name,
    COUNT(*) AS order_count,
    SUM(quantity) AS total_units,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value
FROM sharing_lab_provider.sales_data.v_order_summary
GROUP BY product_name
ORDER BY total_revenue DESC;

-- Consumer can join shared data with their own local data
-- (they would create their own tables and join)


-- =============================================================================
-- STEP 9: SHOW SHARES - Monitoring and Metadata
-- =============================================================================

-- Show all outbound shares (provider perspective)
SHOW SHARES;

-- Show details of a specific share
DESCRIBE SHARE sales_data_share;

-- Show all grants TO a share (what objects are in the share)
SHOW GRANTS TO SHARE sales_data_share;

-- Show all grants OF a share (which accounts have access)
SHOW GRANTS OF SHARE sales_data_share;

-- Show inbound shares (consumer perspective)
-- SHOW SHARES; -- Look for kind = 'INBOUND'


-- =============================================================================
-- STEP 10: REVOKE ACCESS
-- =============================================================================

-- Revoke a specific object from the share
REVOKE SELECT ON VIEW sharing_lab_provider.sales_data.v_order_summary FROM SHARE sales_data_share;

-- Verify it was removed
SHOW GRANTS TO SHARE sales_data_share;

-- Re-add it (for continued lab use)
GRANT SELECT ON VIEW sharing_lab_provider.sales_data.v_order_summary TO SHARE sales_data_share;

-- Remove a consumer account from the share
-- ALTER SHARE sales_data_share REMOVE ACCOUNTS = ORGNAME.CONSUMER_ACCOUNT;

-- Verify accounts
SHOW GRANTS OF SHARE sales_data_share;


-- =============================================================================
-- STEP 11: READER ACCOUNT CONCEPTS
-- =============================================================================

-- Reader accounts are created BY the provider for consumers without Snowflake accounts
-- The provider pays for all compute in reader accounts

-- Create a reader account (ACCOUNTADMIN required)
-- CREATE MANAGED ACCOUNT reader_partner_1
--     ADMIN_NAME = 'partner_admin',
--     ADMIN_PASSWORD = 'SecureP@ss123!',
--     TYPE = READER,
--     COMMENT = 'Reader account for Partner 1 - lab exercise';

-- Show managed (reader) accounts
SHOW MANAGED ACCOUNTS;

-- Share data with the reader account
-- ALTER SHARE sales_data_share ADD ACCOUNTS = <reader_account_locator>;

-- Key points about reader accounts:
-- 1. Provider creates warehouses for the reader account
-- 2. Provider PAYS for all compute credits consumed
-- 3. Provider should ALWAYS set resource monitors
-- 4. Reader can ONLY access data from the creating provider
-- 5. Reader CANNOT access Marketplace or other providers
-- 6. Reader CANNOT load data or create databases (except from share)

-- Best practice: Create a resource monitor for reader account warehouses
-- CREATE RESOURCE MONITOR reader_monitor
--     WITH CREDIT_QUOTA = 10
--     FREQUENCY = MONTHLY
--     START_TIMESTAMP = IMMEDIATELY
--     TRIGGERS
--         ON 75 PERCENT DO NOTIFY
--         ON 90 PERCENT DO SUSPEND
--         ON 100 PERCENT DO SUSPEND_IMMEDIATE;


-- =============================================================================
-- STEP 12: MONITORING QUERIES
-- =============================================================================

-- Monitor share usage (who is querying shared data)
-- Requires ACCOUNTADMIN or appropriate privileges

-- Data sharing usage (provider sees consumer query activity)
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
WHERE TRANSFER_TYPE = 'REPLICATION'
ORDER BY START_TIME DESC
LIMIT 20;

-- Storage used by shared data
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
ORDER BY USAGE_DATE DESC
LIMIT 10;

-- List all active shares and their status
SELECT
    SHARE_NAME,
    DATABASE_NAME,
    OWNER,
    COMMENT,
    CREATED_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.SHARES
WHERE DELETED_ON IS NULL
ORDER BY CREATED_ON DESC;

-- Monitor reader account warehouse usage (provider pays!)
-- SELECT *
-- FROM SNOWFLAKE.READER_ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
-- ORDER BY START_TIME DESC;

-- Check for shares with no consumers (potential cleanup candidates)
SHOW SHARES;
-- Look for shares where accounts list is empty


-- =============================================================================
-- STEP 13: LISTING CONCEPTS (Snowflake Marketplace)
-- =============================================================================

-- Listings are the Marketplace mechanism for sharing data publicly or privately
-- They build on top of shares but add discovery, auto-fulfillment, and billing

-- Key concepts:
-- 1. STANDARD LISTING: Available to any Snowflake account (public marketplace)
-- 2. PRIVATE LISTING: Shared with specific accounts (targeted sharing)
-- 3. AUTO-FULFILLMENT: Handles cross-region delivery automatically via replication
-- 4. PERSONALIZED LISTING: Custom pricing and terms per consumer
-- 5. FREE vs PAID: Listings can be free or have usage-based/subscription pricing

-- View available listings (consumer perspective)
-- SHOW LISTINGS;

-- Marketplace benefits over direct shares:
-- * Discovery: Consumers can find data through the Marketplace UI
-- * Cross-region: Auto-fulfillment handles replication transparently
-- * Billing: Built-in monetization for paid listings
-- * Terms & conditions: Legal agreements managed through the platform
-- * Metrics: Usage analytics for providers

-- Important exam distinctions:
-- * Direct Share: Same region only, manual account management, no billing
-- * Listing: Cross-region capable, discoverable, supports monetization
-- * Both use zero-copy architecture within the same region


-- =============================================================================
-- STEP 14: CLEANUP
-- =============================================================================

-- Remove the share first (this will drop consumer imported databases!)
DROP SHARE IF EXISTS sales_data_share;

-- Drop reader accounts if created
-- DROP MANAGED ACCOUNT IF EXISTS reader_partner_1;

-- Drop the provider database
DROP DATABASE IF EXISTS sharing_lab_provider;

-- Verify cleanup
SHOW SHARES LIKE 'sales_data%';
SHOW DATABASES LIKE 'sharing_lab%';

-- Lab complete!
-- Key takeaways:
--   1. Always grant USAGE on database AND schema before granting on objects
--   2. Use SECURE views to control what data consumers see
--   3. DROP SHARE immediately removes consumer access (no undo!)
--   4. Reader accounts: provider pays compute, always use resource monitors
--   5. Cross-region sharing requires replication or Marketplace auto-fulfillment
--   6. Consumers get read-only access; cannot clone, re-share, or modify
