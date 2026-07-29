-- ============================================================
-- DOMAIN 2.1: AUTHENTICATION - Hands-On Queries
-- ============================================================

-- 1. View user details
DESCRIBE USER RANGAK565;

-- 2. Auth method breakdown
SELECT first_authentication_factor, second_authentication_factor,
       COUNT(*) AS login_count
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'YES' AND event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1,2 ORDER BY login_count DESC;

-- 3. Failed logins (security monitoring)
SELECT event_timestamp, user_name, client_ip, reported_client_type, error_code, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO' AND event_timestamp > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC;

-- 4. Security integrations
SHOW SECURITY INTEGRATIONS;
SHOW AUTHENTICATION POLICIES;

-- 5. Show all users
SHOW USERS;
