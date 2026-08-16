-- =============================================================================
-- 26. NETWORK SECURITY DEEP DIVE - Hands-On Lab Queries
-- =============================================================================
-- Topics: Network Policies, Network Rules, SYSTEM$ALLOWLIST,
--         External Access Integration concepts, LOGIN_HISTORY monitoring
-- =============================================================================
-- IMPORTANT: Be VERY careful with network policies in a real account.
--            Misconfiguration can lock you out! Always test on a user first.
-- =============================================================================

USE ROLE SECURITYADMIN;

-- =============================================================================
-- LAB 1: Basic Network Policy Operations
-- =============================================================================

-- 1.1 Check your current IP address (CRITICAL: note this before any policy work)
SELECT CURRENT_CLIENT() AS my_current_ip;

-- 1.2 Create a network policy that allows your current IP
-- Replace <YOUR_IP> with the result from above
CREATE OR REPLACE NETWORK POLICY lab_basic_policy
  ALLOWED_IP_LIST = ('<YOUR_IP>/32')  -- /32 = single IP
  COMMENT = 'Lab: Basic network policy allowing only my IP';

-- 1.3 View the policy
SHOW NETWORK POLICIES;
DESCRIBE NETWORK POLICY lab_basic_policy;

-- 1.4 Create a policy with allowed AND blocked
CREATE OR REPLACE NETWORK POLICY lab_mixed_policy
  ALLOWED_IP_LIST = ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
  BLOCKED_IP_LIST = ('10.0.0.99', '172.16.0.99')
  COMMENT = 'Lab: Private ranges allowed, specific IPs blocked';

DESCRIBE NETWORK POLICY lab_mixed_policy;

-- 1.5 Alter an existing policy
ALTER NETWORK POLICY lab_mixed_policy SET
  ALLOWED_IP_LIST = ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '203.0.113.0/24');

DESCRIBE NETWORK POLICY lab_mixed_policy;

-- =============================================================================
-- LAB 2: Applying Network Policies (CAREFULLY!)
-- =============================================================================

-- 2.1 Create a test user for safe experimentation
USE ROLE USERADMIN;
CREATE OR REPLACE USER lab_network_test_user
  PASSWORD = 'TempPass123!'
  DEFAULT_ROLE = PUBLIC
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Temporary user for network policy testing';

-- 2.2 Apply policy to the TEST USER (safe - won't lock you out)
USE ROLE SECURITYADMIN;
ALTER USER lab_network_test_user SET NETWORK_POLICY = 'lab_basic_policy';

-- 2.3 Verify the policy is applied
DESCRIBE USER lab_network_test_user;
-- Look for NETWORK_POLICY property

-- 2.4 Remove policy from user
ALTER USER lab_network_test_user UNSET NETWORK_POLICY;

-- 2.5 Apply to account (DANGEROUS in production - safe in a lab/trial account)
-- UNCOMMENT ONLY IF you're sure your IP is in the allowed list:
-- USE ROLE ACCOUNTADMIN;
-- ALTER ACCOUNT SET NETWORK_POLICY = 'lab_basic_policy';
-- 
-- Verify you can still query:
-- SELECT CURRENT_USER(), CURRENT_CLIENT();
--
-- Remove it immediately after testing:
-- ALTER ACCOUNT UNSET NETWORK_POLICY;

-- =============================================================================
-- LAB 3: Network Rules
-- =============================================================================

USE ROLE SYSADMIN;

-- 3.1 Create a database/schema for network rules
CREATE DATABASE IF NOT EXISTS lab_network_security;
CREATE SCHEMA IF NOT EXISTS lab_network_security.rules;

USE SCHEMA lab_network_security.rules;

-- 3.2 Create an INGRESS network rule (for inbound access control)
CREATE OR REPLACE NETWORK RULE corporate_office_ips
  TYPE = IPV4
  VALUE_LIST = ('10.1.0.0/16', '10.2.0.0/16')
  MODE = INGRESS
  COMMENT = 'Corporate office IP ranges';

CREATE OR REPLACE NETWORK RULE vpn_gateway_ips
  TYPE = IPV4
  VALUE_LIST = ('203.0.113.10', '203.0.113.11')
  MODE = INGRESS
  COMMENT = 'VPN gateway exit IPs';

-- 3.3 View network rules
SHOW NETWORK RULES IN SCHEMA lab_network_security.rules;
DESCRIBE NETWORK RULE corporate_office_ips;

-- 3.4 Create a policy that uses network rules
USE ROLE SECURITYADMIN;

CREATE OR REPLACE NETWORK POLICY lab_rule_based_policy
  ALLOWED_NETWORK_RULE_LIST = (
    'lab_network_security.rules.corporate_office_ips',
    'lab_network_security.rules.vpn_gateway_ips'
  )
  COMMENT = 'Lab: Policy using network rules for IP management';

DESCRIBE NETWORK POLICY lab_rule_based_policy;

-- 3.5 Create an EGRESS network rule (for External Access Integration)
USE ROLE SYSADMIN;
USE SCHEMA lab_network_security.rules;

CREATE OR REPLACE NETWORK RULE external_api_rule
  TYPE = HOST_PORT
  VALUE_LIST = ('api.example.com:443', 'webhook.site:443')
  MODE = EGRESS
  COMMENT = 'Allowed outbound endpoints for UDFs';

-- 3.6 Create an INTERNAL_STAGE network rule
CREATE OR REPLACE NETWORK RULE stage_access_rule
  TYPE = IPV4
  VALUE_LIST = ('10.0.0.0/8')
  MODE = INTERNAL_STAGE
  COMMENT = 'Restrict stage access to internal network';

-- 3.7 Alter a network rule
ALTER NETWORK RULE corporate_office_ips SET
  VALUE_LIST = ('10.1.0.0/16', '10.2.0.0/16', '10.3.0.0/16');

DESCRIBE NETWORK RULE corporate_office_ips;

-- =============================================================================
-- LAB 4: SYSTEM$ALLOWLIST
-- =============================================================================

-- 4.1 View Snowflake's public IPs/hostnames your firewall should allow
SELECT SYSTEM$ALLOWLIST();

-- 4.2 Parse the JSON output for easier reading
SELECT
  VALUE:type::STRING AS entry_type,
  VALUE:host::STRING AS hostname,
  VALUE:port::INTEGER AS port
FROM TABLE(FLATTEN(PARSE_JSON(SYSTEM$ALLOWLIST())));

-- 4.3 View PrivateLink-specific allowlist (if PrivateLink is enabled)
-- This may return empty or error if PrivateLink is not configured
-- SELECT SYSTEM$ALLOWLIST_PRIVATELINK();

-- 4.4 View PrivateLink configuration (if enabled)
-- SELECT SYSTEM$GET_PRIVATELINK_CONFIG();

-- =============================================================================
-- LAB 5: External Access Integration (Concept Demonstration)
-- =============================================================================

-- Note: This demonstrates the setup. Actual HTTP calls require
-- a working external endpoint and appropriate permissions.

USE ROLE SYSADMIN;
USE SCHEMA lab_network_security.rules;

-- 5.1 The egress rule (already created above)
DESCRIBE NETWORK RULE external_api_rule;

-- 5.2 Create a secret for API authentication
CREATE OR REPLACE SECRET lab_network_security.rules.demo_api_key
  TYPE = GENERIC_STRING
  SECRET_STRING = 'demo-key-not-real-12345';

-- 5.3 Create External Access Integration (requires ACCOUNTADMIN or CREATE INTEGRATION)
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION lab_external_api_access
  ALLOWED_NETWORK_RULES = (lab_network_security.rules.external_api_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (lab_network_security.rules.demo_api_key)
  ENABLED = TRUE
  COMMENT = 'Lab: Demonstrates external access for UDFs';

-- 5.4 View the integration
SHOW EXTERNAL ACCESS INTEGRATIONS;
DESCRIBE EXTERNAL ACCESS INTEGRATION lab_external_api_access;

-- 5.5 Example UDF that would use external access (conceptual)
-- This would work if api.example.com existed and returned data:
/*
CREATE OR REPLACE FUNCTION lab_network_security.rules.call_external_api(endpoint STRING)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.10'
  EXTERNAL_ACCESS_INTEGRATIONS = (lab_external_api_access)
  SECRETS = ('api_key' = lab_network_security.rules.demo_api_key)
  PACKAGES = ('requests')
  HANDLER = 'main'
AS $$
import requests
import _snowflake

def main(endpoint):
    key = _snowflake.get_generic_secret_string('api_key')
    response = requests.get(
        f'https://api.example.com/{endpoint}',
        headers={'Authorization': f'Bearer {key}'},
        timeout=10
    )
    return response.text
$$;
*/

-- =============================================================================
-- LAB 6: LOGIN_HISTORY Monitoring
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- 6.1 View recent login attempts (ACCOUNT_USAGE - up to 45 min latency)
SELECT
  EVENT_TIMESTAMP,
  USER_NAME,
  CLIENT_IP,
  IS_SUCCESS,
  ERROR_CODE,
  ERROR_MESSAGE,
  REPORTED_CLIENT_TYPE,
  FIRST_AUTHENTICATION_FACTOR
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
ORDER BY EVENT_TIMESTAMP DESC
LIMIT 20;

-- 6.2 Find failed logins (potential network policy blocks)
SELECT
  EVENT_TIMESTAMP,
  USER_NAME,
  CLIENT_IP,
  ERROR_MESSAGE
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
ORDER BY EVENT_TIMESTAMP DESC
LIMIT 50;

-- 6.3 Real-time login history (INFORMATION_SCHEMA - no latency, 7-day window)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.LOGIN_HISTORY(
  TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY EVENT_TIMESTAMP DESC;

-- 6.4 Logins by IP address (anomaly detection)
SELECT
  CLIENT_IP,
  COUNT(*) AS total_attempts,
  SUM(CASE WHEN IS_SUCCESS = 'YES' THEN 1 ELSE 0 END) AS successful,
  SUM(CASE WHEN IS_SUCCESS = 'NO' THEN 1 ELSE 0 END) AS failed,
  COUNT(DISTINCT USER_NAME) AS distinct_users
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP
ORDER BY failed DESC
LIMIT 20;

-- 6.5 Detect logins from unexpected client types
SELECT
  REPORTED_CLIENT_TYPE,
  COUNT(*) AS login_count,
  COUNT(DISTINCT USER_NAME) AS users
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'YES'
  AND EVENT_TIMESTAMP > DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY REPORTED_CLIENT_TYPE
ORDER BY login_count DESC;

-- =============================================================================
-- LAB 7: Policy Inspection and Audit
-- =============================================================================

USE ROLE SECURITYADMIN;

-- 7.1 Show all network policies in the account
SHOW NETWORK POLICIES;

-- 7.2 Check which users have user-level policies
-- (There's no direct view; check each user or use SHOW USERS)
SHOW USERS;
-- Look for NETWORK_POLICY in the output

-- 7.3 Check current account-level policy
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;

-- =============================================================================
-- CLEANUP
-- =============================================================================

-- IMPORTANT: Clean up in reverse order

-- Remove policies from any users/account first
ALTER USER lab_network_test_user UNSET NETWORK_POLICY;
-- If you applied to account: ALTER ACCOUNT UNSET NETWORK_POLICY;

-- Drop policies
USE ROLE SECURITYADMIN;
DROP NETWORK POLICY IF EXISTS lab_basic_policy;
DROP NETWORK POLICY IF EXISTS lab_mixed_policy;
DROP NETWORK POLICY IF EXISTS lab_rule_based_policy;

-- Drop integration
USE ROLE ACCOUNTADMIN;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS lab_external_api_access;

-- Drop network rules and database
USE ROLE SYSADMIN;
DROP NETWORK RULE IF EXISTS lab_network_security.rules.corporate_office_ips;
DROP NETWORK RULE IF EXISTS lab_network_security.rules.vpn_gateway_ips;
DROP NETWORK RULE IF EXISTS lab_network_security.rules.external_api_rule;
DROP NETWORK RULE IF EXISTS lab_network_security.rules.stage_access_rule;
DROP SECRET IF EXISTS lab_network_security.rules.demo_api_key;
DROP SCHEMA IF EXISTS lab_network_security.rules;
DROP DATABASE IF EXISTS lab_network_security;

-- Drop test user
USE ROLE USERADMIN;
DROP USER IF EXISTS lab_network_test_user;

-- Verify cleanup
USE ROLE SECURITYADMIN;
SHOW NETWORK POLICIES;
-- Should show no lab policies

SELECT 'Lab cleanup complete!' AS status;
