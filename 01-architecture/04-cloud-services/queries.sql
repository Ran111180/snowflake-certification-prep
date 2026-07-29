-- ============================================================
-- DOMAIN 1.4: CLOUD SERVICES LAYER - Hands-On Queries
-- ============================================================

-- 1. INFORMATION_SCHEMA (real-time, current DB)
SELECT table_name, row_count, bytes, created
FROM CERT_STUDY_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ARCHITECTURE' AND row_count > 0 ORDER BY row_count DESC;

-- 2. ACCOUNT_USAGE (account-wide, 45min-3hr lag, 365 day history)
SELECT user_name, query_type, COUNT(*) AS query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY user_name, query_type ORDER BY query_count DESC LIMIT 20;

-- 3. Transaction demo
CREATE OR REPLACE TABLE CERT_STUDY_DB.ARCHITECTURE.txn_demo (id INT, val VARCHAR);
INSERT INTO txn_demo VALUES (1, 'auto-committed');
-- Explicit transaction would use: BEGIN; INSERT...; COMMIT; or ROLLBACK;

-- 4. Cloud Services credit monitoring
SELECT DATE_TRUNC('day', start_time) AS day,
       SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cs_credits,
       ROUND(SUM(credits_used_cloud_services)/NULLIF(SUM(credits_used_compute),0)*100,2) AS cs_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY day ORDER BY day DESC;
