# 09 - Snowflake Tasks Deep Dive

Complete reference and hands-on lab for Snowflake Tasks, Stored Procedures, and Email Notifications.

## Contents

### 01-certification-reference/
- **09_01_Tasks_Certification.html** - All Task commands, syntax, and exam-relevant concepts
- **queries.sql** - Quick-reference SQL commands for Tasks

### 02-hands-on-practice/
- **09_02_Tasks_Hands_On_Lab.html** - Full step-by-step lab: RBAC setup → Base tables → Stored Procedure → Task → HTML Email notification
- **lab_queries.sql** - Complete lab SQL (copy-paste ready)

## Key Concepts Covered
- Task creation, scheduling (CRON), chaining (DAGs)
- Stored procedures with SQL scripting (DECLARE, variables, INTO)
- SYSTEM$SEND_EMAIL with HTML formatting
- Enterprise RBAC (SECURITYADMIN → SYSADMIN → DATA_ENGINEER → ANALYST)
- EXECUTE TASK / EXECUTE MANAGED TASK privileges
- Task monitoring (TASK_HISTORY, SHOW TASKS)
- Dynamic Tables vs Tasks (when to use which)

## Prerequisites
- Snowflake account with ACCOUNTADMIN access (for initial setup)
- Email notification integration configured
