-- ============================================================
-- DOMAIN 2.3-2.5: NETWORK, DATA SECURITY, GOVERNANCE
-- ============================================================

-- === NETWORK SECURITY ===
SHOW NETWORK POLICIES;
DESCRIBE NETWORK POLICY ALLOW_ALL_IPS;

CREATE OR REPLACE NETWORK RULE CERT_STUDY_DB.ARCHITECTURE.cert_study_ip_rule
  TYPE = IPV4 MODE = INGRESS VALUE_LIST = ('0.0.0.0/0')
  COMMENT = 'Demo network rule';
SHOW NETWORK RULES IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;

-- === DATA SECURITY (Tags) ===
CREATE OR REPLACE TAG CERT_STUDY_DB.ARCHITECTURE.data_sensitivity
  COMMENT = 'Classifies data by sensitivity level';
CREATE OR REPLACE TAG CERT_STUDY_DB.ARCHITECTURE.data_domain
  COMMENT = 'Business domain';

ALTER TABLE CERT_STUDY_DB.ARCHITECTURE.employees
  SET TAG CERT_STUDY_DB.ARCHITECTURE.data_sensitivity = 'CONFIDENTIAL';
ALTER TABLE CERT_STUDY_DB.ARCHITECTURE.employees
  MODIFY COLUMN ssn SET TAG CERT_STUDY_DB.ARCHITECTURE.data_sensitivity = 'RESTRICTED';

SELECT tag_name, tag_value, object_name, column_name, domain
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
  'CERT_STUDY_DB.ARCHITECTURE.EMPLOYEES', 'TABLE'));

-- === GOVERNANCE ===
-- Query patterns
SELECT user_name, query_type, COUNT(*) AS query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -3, CURRENT_TIMESTAMP())
GROUP BY 1,2 ORDER BY query_count DESC LIMIT 15;

-- Long running queries
SELECT query_id, user_name, SUBSTR(query_text,1,80) AS query,
       total_elapsed_time/1000 AS seconds, bytes_scanned/(1024*1024) AS mb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -3, CURRENT_TIMESTAMP()) AND total_elapsed_time > 1000
ORDER BY total_elapsed_time DESC LIMIT 10;

SHOW TAGS IN SCHEMA CERT_STUDY_DB.ARCHITECTURE;
