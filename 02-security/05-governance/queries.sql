-- ============================================================
-- DOMAIN 2.5: GOVERNANCE - Hands-On Queries
-- ============================================================

-- 1. Access history - who queried what tables
SELECT user_name, query_id, query_start_time,
       direct_objects_accessed[0]:objectName::STRING AS table_accessed,
       direct_objects_accessed[0]:objectDomain::STRING AS object_type
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC LIMIT 20;

-- 2. Login history - authentication audit
SELECT user_name, event_timestamp, event_type, is_success,
       client_ip, reported_client_type, first_authentication_factor
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC LIMIT 20;

-- 3. Failed logins (security investigation)
SELECT user_name, COUNT(*) AS failed_attempts, MIN(event_timestamp) AS first_fail, MAX(event_timestamp) AS last_fail
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO' AND event_timestamp > DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY user_name ORDER BY failed_attempts DESC;

-- 4. Grants changes - privilege audit
SELECT created_on, modified_on, privilege, granted_on, name, granted_to, grantee_name, grant_option
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE created_on > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY created_on DESC LIMIT 20;

-- 5. Data metric functions usage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_METRIC_FUNCTION_REFERENCES
WHERE ref_database_name = 'CERT_STUDY_DB' LIMIT 10;

-- 6. Account usage views catalog
SHOW VIEWS IN SCHEMA SNOWFLAKE.ACCOUNT_USAGE;
