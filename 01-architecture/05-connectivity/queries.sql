-- ============================================================
-- DOMAIN 1.5: CONNECTIVITY - Hands-On Queries
-- ============================================================

-- 1. Session info
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_SESSION(),
       CURRENT_CLIENT(), CURRENT_VERSION();

-- 2. Login history (who's connecting)
SELECT event_timestamp, user_name, reported_client_type,
       reported_client_version, client_ip, is_success, first_authentication_factor
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC LIMIT 20;

-- 3. Client types analysis
SELECT reported_client_type, reported_client_version,
       COUNT(*) AS login_count, first_authentication_factor
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP()) AND is_success = 'YES'
GROUP BY 1,2,4 ORDER BY login_count DESC;

-- 4. Unique IPs
SELECT client_ip, COUNT(*) AS connections,
       MIN(event_timestamp)::DATE AS first_seen, MAX(event_timestamp)::DATE AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP()) AND is_success = 'YES' AND client_ip != '0.0.0.0'
GROUP BY client_ip ORDER BY connections DESC;

-- 5. Network policies and integrations
SHOW NETWORK POLICIES;
SHOW SECURITY INTEGRATIONS;
