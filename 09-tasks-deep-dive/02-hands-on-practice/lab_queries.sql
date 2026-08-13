-- =====================================================
-- COMPLETE LAB: Tasks + RBAC + Email Notifications
-- Run each section in order
-- =====================================================

-- ============================================================
-- STEP 0: RBAC SETUP
-- ============================================================

-- 0A: Create roles (run as SECURITYADMIN)
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DATA_ENGINEER
  COMMENT = 'Builds pipelines, creates tasks, owns transformations';
CREATE ROLE IF NOT EXISTS ANALYST
  COMMENT = 'Read-only access to report tables';

GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;
GRANT ROLE ANALYST TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER TO USER RANGAK565;
GRANT ROLE ANALYST TO USER RANGAK565;

-- 0B: Create infrastructure (run as SYSADMIN)
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS TASK_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS TASK_PRACTICE_DB;

GRANT OWNERSHIP ON DATABASE TASK_PRACTICE_DB TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE TASK_WH TO ROLE DATA_ENGINEER;
GRANT OPERATE ON WAREHOUSE TASK_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE TASK_WH TO ROLE ANALYST;

-- 0C: Account-level privileges (run as ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ENGINEER;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE DATA_ENGINEER;

-- ============================================================
-- STEP 1: SCHEMAS (run as DATA_ENGINEER)
-- ============================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;

CREATE SCHEMA IF NOT EXISTS BASE COMMENT = 'Source tables';
CREATE SCHEMA IF NOT EXISTS REPORTS COMMENT = 'Report tables';

-- ============================================================
-- STEP 2: BASE TABLES
-- ============================================================
USE SCHEMA BASE;

CREATE OR REPLACE TABLE ACCOUNTS (
    account_id INT, account_name VARCHAR(100), industry VARCHAR(50),
    region VARCHAR(30), annual_revenue DECIMAL(15,2),
    created_date DATE, is_active BOOLEAN
);
INSERT INTO ACCOUNTS VALUES
(1,'Tata Consultancy','Technology','APAC',15000000,'2022-01-15',TRUE),
(2,'Infosys Ltd','Technology','APAC',12000000,'2022-03-20',TRUE),
(3,'Reliance Digital','Retail','APAC',8000000,'2022-06-10',TRUE),
(4,'HDFC Bank','Banking','APAC',20000000,'2021-11-01',TRUE),
(5,'Wipro Technologies','Technology','APAC',9500000,'2022-09-14',TRUE),
(6,'Amazon Web Services','Cloud','NA',50000000,'2020-05-22',TRUE),
(7,'Microsoft India','Technology','APAC',35000000,'2021-02-10',TRUE),
(8,'Flipkart','E-Commerce','APAC',6000000,'2023-01-05',TRUE),
(9,'Accenture','Consulting','EMEA',18000000,'2021-08-30',TRUE),
(10,'Deloitte','Consulting','NA',22000000,'2020-12-18',FALSE);

CREATE OR REPLACE TABLE OPPORTUNITIES (
    opp_id INT, account_id INT, opp_name VARCHAR(200), stage VARCHAR(50),
    amount DECIMAL(15,2), close_date DATE, created_date DATE, owner_name VARCHAR(100)
);
INSERT INTO OPPORTUNITIES VALUES
(101,1,'TCS Cloud Migration','Closed Won',2500000,'2026-06-15','2026-01-10','Ravi Kumar'),
(102,1,'TCS Data Platform','Negotiation',1800000,'2026-09-30','2026-04-20','Priya Sharma'),
(103,2,'Infosys Analytics','Closed Won',1200000,'2026-05-20','2026-02-15','Ravi Kumar'),
(104,3,'Reliance BI Dashboard','Closed Lost',800000,'2026-04-10','2026-01-25','Ankit Patel'),
(105,4,'HDFC Fraud Detection','Closed Won',3500000,'2026-07-01','2026-03-10','Priya Sharma'),
(106,5,'Wipro DevOps','Proposal',950000,'2026-10-15','2026-06-01','Ankit Patel'),
(107,6,'AWS Partnership','Closed Won',5000000,'2026-03-30','2025-11-15','Ravi Kumar'),
(108,7,'Microsoft Integration','Qualification',2200000,'2026-12-01','2026-07-05','Sneha Reddy'),
(109,8,'Flipkart Recommender','Closed Won',1500000,'2026-08-10','2026-05-12','Sneha Reddy'),
(110,9,'Accenture Consulting','Negotiation',4000000,'2026-11-20','2026-06-25','Ravi Kumar'),
(111,4,'HDFC Credit Scoring','Proposal',2800000,'2026-10-30','2026-07-15','Priya Sharma'),
(112,2,'Infosys Migration','Closed Won',1600000,'2026-08-01','2026-04-10','Ankit Patel');

CREATE OR REPLACE TABLE CONTACTS (
    contact_id INT, account_id INT, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100), title VARCHAR(100), phone VARCHAR(20), created_date DATE
);
INSERT INTO CONTACTS VALUES
(201,1,'Rajesh','Gopinathan','rajesh.g@tcs.com','CTO','+91-9876543210','2022-01-15'),
(202,1,'Meena','Iyer','meena.i@tcs.com','VP Engineering','+91-9876543211','2022-03-20'),
(203,2,'Salil','Parekh','salil.p@infosys.com','CEO','+91-9876543212','2022-03-20'),
(204,3,'Amit','Jain','amit.j@reliance.com','Head of Data','+91-9876543213','2022-06-10'),
(205,4,'Sashi','Jagdishan','sashi.j@hdfc.com','CIO','+91-9876543214','2021-11-01'),
(206,5,'Thierry','Delaporte','thierry.d@wipro.com','CEO','+91-9876543215','2022-09-14'),
(207,6,'Prasad','Kalyanaraman','prasad.k@aws.com','Solutions Architect','+1-5551234567','2020-05-22'),
(208,7,'Anant','Maheshwari','anant.m@microsoft.com','President','+91-9876543216','2021-02-10'),
(209,8,'Kalyan','Krishnamurthy','kalyan.k@flipkart.com','CEO','+91-9876543217','2023-01-05'),
(210,9,'Julie','Sweet','julie.s@accenture.com','CEO','+1-5559876543','2021-08-30');

CREATE OR REPLACE TABLE ACTIVITIES (
    activity_id INT, opp_id INT, account_id INT, activity_type VARCHAR(30),
    subject VARCHAR(200), activity_date DATE, duration_minutes INT, owner_name VARCHAR(100)
);
INSERT INTO ACTIVITIES VALUES
(301,101,1,'Meeting','Discovery Call','2026-01-15',60,'Ravi Kumar'),
(302,101,1,'Email','Proposal Sent','2026-02-10',5,'Ravi Kumar'),
(303,101,1,'Meeting','Technical Deep Dive','2026-03-05',90,'Ravi Kumar'),
(304,103,2,'Call','Initial Discussion','2026-02-20',30,'Ravi Kumar'),
(305,103,2,'Meeting','Demo Session','2026-03-15',60,'Ravi Kumar'),
(306,105,4,'Meeting','Executive Presentation','2026-04-10',45,'Priya Sharma'),
(307,105,4,'Email','Contract Review','2026-05-20',10,'Priya Sharma'),
(308,107,6,'Meeting','Partnership Kickoff','2025-12-01',120,'Ravi Kumar'),
(309,109,8,'Call','Requirements Gathering','2026-05-20',45,'Sneha Reddy'),
(310,109,8,'Meeting','Solution Presentation','2026-06-15',60,'Sneha Reddy'),
(311,110,9,'Meeting','Scope Discussion','2026-07-01',90,'Ravi Kumar'),
(312,111,4,'Call','Credit Model Overview','2026-07-20',30,'Priya Sharma');

-- ============================================================
-- STEP 3: STORED PROCEDURE + EMAIL
-- ============================================================
CREATE OR REPLACE PROCEDURE REPORTS.REFRESH_ALL_REPORTS()
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
  v_body STRING DEFAULT '';
  v_cnt1 INT; v_cnt2 INT; v_cnt3 INT;
  v_cnt4 INT; v_cnt5 INT; v_cnt6 INT;
BEGIN
  CREATE OR REPLACE TABLE REPORTS.RPT_REVENUE_BY_REGION AS
  SELECT a.region, COUNT(DISTINCT a.account_id) AS total_accounts,
    COUNT(o.opp_id) AS total_opps,
    SUM(CASE WHEN o.stage='Closed Won' THEN o.amount ELSE 0 END) AS won_revenue,
    SUM(o.amount) AS pipeline_total, CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.ACCOUNTS a LEFT JOIN BASE.OPPORTUNITIES o ON a.account_id=o.account_id
  GROUP BY a.region;
  SELECT COUNT(*) INTO :v_cnt1 FROM REPORTS.RPT_REVENUE_BY_REGION;

  CREATE OR REPLACE TABLE REPORTS.RPT_SALES_REP_PERFORMANCE AS
  SELECT o.owner_name, COUNT(*) AS total_deals,
    SUM(CASE WHEN o.stage='Closed Won' THEN 1 ELSE 0 END) AS won,
    SUM(CASE WHEN o.stage='Closed Won' THEN o.amount ELSE 0 END) AS revenue,
    ROUND(SUM(CASE WHEN o.stage='Closed Won' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS win_pct,
    CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.OPPORTUNITIES o GROUP BY o.owner_name;
  SELECT COUNT(*) INTO :v_cnt2 FROM REPORTS.RPT_SALES_REP_PERFORMANCE;

  CREATE OR REPLACE TABLE REPORTS.RPT_PIPELINE_BY_STAGE AS
  SELECT stage, COUNT(*) AS deals, SUM(amount) AS total, AVG(amount) AS avg_size,
    CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.OPPORTUNITIES GROUP BY stage;
  SELECT COUNT(*) INTO :v_cnt3 FROM REPORTS.RPT_PIPELINE_BY_STAGE;

  CREATE OR REPLACE TABLE REPORTS.RPT_ACCOUNT_HEALTH AS
  SELECT a.account_id, a.account_name, a.industry, a.region,
    COUNT(act.activity_id) AS activities, MAX(act.activity_date) AS last_activity,
    DATEDIFF('day',MAX(act.activity_date),CURRENT_DATE()) AS days_inactive,
    CASE WHEN DATEDIFF('day',MAX(act.activity_date),CURRENT_DATE())<=30 THEN 'Healthy'
         WHEN DATEDIFF('day',MAX(act.activity_date),CURRENT_DATE())<=90 THEN 'At Risk'
         ELSE 'Inactive' END AS status,
    CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.ACCOUNTS a LEFT JOIN BASE.ACTIVITIES act ON a.account_id=act.account_id
  WHERE a.is_active=TRUE GROUP BY a.account_id,a.account_name,a.industry,a.region;
  SELECT COUNT(*) INTO :v_cnt4 FROM REPORTS.RPT_ACCOUNT_HEALTH;

  CREATE OR REPLACE TABLE REPORTS.RPT_INDUSTRY_SUMMARY AS
  SELECT a.industry, COUNT(DISTINCT a.account_id) AS accounts,
    SUM(a.annual_revenue) AS annual_rev, COUNT(o.opp_id) AS opps,
    SUM(CASE WHEN o.stage='Closed Won' THEN o.amount ELSE 0 END) AS won,
    CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.ACCOUNTS a LEFT JOIN BASE.OPPORTUNITIES o ON a.account_id=o.account_id
  GROUP BY a.industry;
  SELECT COUNT(*) INTO :v_cnt5 FROM REPORTS.RPT_INDUSTRY_SUMMARY;

  CREATE OR REPLACE TABLE REPORTS.RPT_MONTHLY_ACTIVITY AS
  SELECT DATE_TRUNC('month',activity_date) AS month, activity_type,
    COUNT(*) AS cnt, SUM(duration_minutes) AS mins,
    COUNT(DISTINCT account_id) AS accounts, CURRENT_TIMESTAMP() AS refreshed_at
  FROM BASE.ACTIVITIES GROUP BY 1,2;
  SELECT COUNT(*) INTO :v_cnt6 FROM REPORTS.RPT_MONTHLY_ACTIVITY;

  -- HTML Email
  v_body := '<html><body style="font-family:Segoe UI,Arial,sans-serif;padding:20px">'
    || '<div style="background:linear-gradient(135deg,#29B5E8,#1B8FBF);padding:20px;border-radius:8px 8px 0 0;text-align:center">'
    || '<h1 style="color:#fff;margin:0">Report Refresh Complete</h1>'
    || '<p style="color:#e0f4fc;margin:5px 0">' || CURRENT_TIMESTAMP()::STRING || '</p></div>'
    || '<div style="padding:20px;background:#fff;border:1px solid #eee;border-radius:0 0 8px 8px">'
    || '<table style="width:100%;border-collapse:collapse;font-size:14px">'
    || '<tr style="background:#29B5E8;color:#fff"><th style="padding:10px;text-align:left">Report</th><th style="padding:10px;text-align:center">Rows</th><th style="padding:10px;text-align:center">Status</th></tr>'
    || '<tr><td style="padding:8px;border-bottom:1px solid #eee">RPT_REVENUE_BY_REGION</td><td style="text-align:center;border-bottom:1px solid #eee"><b>' || :v_cnt1 || '</b></td><td style="text-align:center;border-bottom:1px solid #eee;color:green">OK</td></tr>'
    || '<tr style="background:#f9f9f9"><td style="padding:8px;border-bottom:1px solid #eee">RPT_SALES_REP_PERFORMANCE</td><td style="text-align:center;border-bottom:1px solid #eee"><b>' || :v_cnt2 || '</b></td><td style="text-align:center;border-bottom:1px solid #eee;color:green">OK</td></tr>'
    || '<tr><td style="padding:8px;border-bottom:1px solid #eee">RPT_PIPELINE_BY_STAGE</td><td style="text-align:center;border-bottom:1px solid #eee"><b>' || :v_cnt3 || '</b></td><td style="text-align:center;border-bottom:1px solid #eee;color:green">OK</td></tr>'
    || '<tr style="background:#f9f9f9"><td style="padding:8px;border-bottom:1px solid #eee">RPT_ACCOUNT_HEALTH</td><td style="text-align:center;border-bottom:1px solid #eee"><b>' || :v_cnt4 || '</b></td><td style="text-align:center;border-bottom:1px solid #eee;color:green">OK</td></tr>'
    || '<tr><td style="padding:8px;border-bottom:1px solid #eee">RPT_INDUSTRY_SUMMARY</td><td style="text-align:center;border-bottom:1px solid #eee"><b>' || :v_cnt5 || '</b></td><td style="text-align:center;border-bottom:1px solid #eee;color:green">OK</td></tr>'
    || '<tr style="background:#f9f9f9"><td style="padding:8px">RPT_MONTHLY_ACTIVITY</td><td style="text-align:center"><b>' || :v_cnt6 || '</b></td><td style="text-align:center;color:green">OK</td></tr>'
    || '</table>'
    || '<div style="margin-top:16px;padding:10px;background:#f0f8ff;border-left:4px solid #29B5E8;border-radius:4px;font-size:12px">'
    || '<b>Task:</b> BIWEEKLY_REFRESH_TASK | <b>Warehouse:</b> TASK_WH | <b>Total:</b> ' || (:v_cnt1+:v_cnt2+:v_cnt3+:v_cnt4+:v_cnt5+:v_cnt6) || ' rows</div>'
    || '</div></body></html>';

  CALL SYSTEM$SEND_EMAIL(
    'LEARNING_EMAIL_NOTIFICATION',
    'ranga.k565@gmail.com',
    'Report Refresh Complete - ' || CURRENT_DATE()::STRING || ' | ' || (:v_cnt1+:v_cnt2+:v_cnt3+:v_cnt4+:v_cnt5+:v_cnt6) || ' Total Rows',
    :v_body,
    'text/html'
  );

  RETURN '6 tables refreshed. Email sent. Total: ' || (:v_cnt1+:v_cnt2+:v_cnt3+:v_cnt4+:v_cnt5+:v_cnt6);
END;

-- ============================================================
-- STEP 4: CREATE TASK
-- ============================================================
CREATE OR REPLACE TASK REPORTS.BIWEEKLY_REFRESH_TASK
  WAREHOUSE = TASK_WH
  SCHEDULE = 'USING CRON 0 0 1,15 * * Asia/Kolkata'
  COMMENT = 'Refreshes all 6 report tables biweekly'
AS
  CALL REPORTS.REFRESH_ALL_REPORTS();

ALTER TASK REPORTS.BIWEEKLY_REFRESH_TASK RESUME;

-- ============================================================
-- STEP 5: TEST & MONITOR
-- ============================================================
-- Manual test
CALL REPORTS.REFRESH_ALL_REPORTS();

-- Check history
SELECT name, state, scheduled_time, completed_time, return_value, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'BIWEEKLY_REFRESH_TASK',
  SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY scheduled_time DESC;

-- ============================================================
-- STEP 6: CLEANUP
-- ============================================================
ALTER TASK REPORTS.BIWEEKLY_REFRESH_TASK SUSPEND;
-- DROP TASK REPORTS.BIWEEKLY_REFRESH_TASK;
-- DROP DATABASE TASK_PRACTICE_DB;
-- DROP WAREHOUSE TASK_WH;
