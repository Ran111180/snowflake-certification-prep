-- =====================================================
-- Snowflake Tasks - Certification Quick Reference
-- =====================================================

-- ============ CREATE TASK ============
CREATE OR REPLACE TASK my_task
  WAREHOUSE = compute_wh
  SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
  INSERT INTO target SELECT * FROM source;

-- ============ TASK WITH STREAM TRIGGER ============
CREATE OR REPLACE TASK stream_task
  WAREHOUSE = compute_wh
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('my_stream')
AS
  INSERT INTO silver.events SELECT * FROM my_stream WHERE METADATA$ACTION = 'INSERT';

-- ============ TASK DAG (PARENT/CHILD) ============
CREATE TASK parent_task
  WAREHOUSE = wh SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS CALL step_1();

CREATE TASK child_task
  WAREHOUSE = wh
  AFTER parent_task
AS CALL step_2();

-- Resume: children first, root last
ALTER TASK child_task RESUME;
ALTER TASK parent_task RESUME;

-- ============ SERVERLESS TASK ============
CREATE TASK serverless_task
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  SCHEDULE = '60 MINUTE'
AS
  CALL my_procedure();

-- ============ ALTER TASK ============
ALTER TASK my_task SUSPEND;
ALTER TASK my_task RESUME;
ALTER TASK my_task SET SCHEDULE = '30 MINUTE';
ALTER TASK my_task SET WAREHOUSE = new_wh;
ALTER TASK my_task SET SUSPEND_TASK_AFTER_NUM_FAILURES = 3;

-- ============ EXECUTE TASK (MANUAL TRIGGER) ============
EXECUTE TASK my_task;  -- Works even if task is suspended

-- ============ PRIVILEGES ============
-- Only ACCOUNTADMIN can grant these:
GRANT EXECUTE TASK ON ACCOUNT TO ROLE data_engineer;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE data_engineer;

-- Task-level:
GRANT OPERATE ON TASK my_task TO ROLE ops_role;
GRANT MONITOR ON TASK my_task TO ROLE monitor_role;

-- ============ MONITORING ============
SHOW TASKS IN SCHEMA my_db.my_schema;

SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'MY_TASK',
  SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY scheduled_time DESC;

-- Account-level (2+ hour latency)
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE scheduled_time > DATEADD('day', -7, CURRENT_DATE())
ORDER BY scheduled_time DESC;

-- ============ EMAIL NOTIFICATION ============
CREATE NOTIFICATION INTEGRATION email_int
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('user@company.com');

CALL SYSTEM$SEND_EMAIL(
  'email_int',
  'user@company.com',
  'Subject',
  '<html><body><h1>Report</h1></body></html>',
  'text/html'
);

-- ============ CRON EXAMPLES ============
-- 'USING CRON min hour dom month dow timezone'
-- Every day 6 AM UTC:        '0 6 * * * UTC'
-- Weekdays 9 AM IST:         '0 3 * * MON-FRI Asia/Kolkata' (9AM IST = 3:30 UTC)
-- 1st and 15th midnight:     '0 0 1,15 * * UTC'
-- Every 5 minutes:           '*/5 * * * * UTC'
-- Last day of month:         '0 0 L * * UTC'
-- Sunday midnight:           '0 0 * * SUN UTC'

-- ============ DROP / CLEANUP ============
ALTER TASK my_task SUSPEND;
DROP TASK my_task;
