-- ============================================================
-- DOMAIN 5A: DATA TRANSFORMATIONS & SQL - Hands-On Queries
-- ============================================================

-- 1. Window functions
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

SELECT category, order_date, amount,
  SUM(amount) OVER (PARTITION BY category ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
  AVG(amount) OVER (PARTITION BY category ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3,
  LAG(amount) OVER (PARTITION BY category ORDER BY order_date) AS prev_amount,
  LEAD(amount) OVER (PARTITION BY category ORDER BY order_date) AS next_amount,
  RANK() OVER (PARTITION BY category ORDER BY amount DESC) AS rank_by_amount
FROM sample_data WHERE order_date >= '2024-01-01' LIMIT 50;

-- 2. QUALIFY (Snowflake-specific)
SELECT * FROM sample_data
QUALIFY ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) <= 3;

-- 3. LATERAL FLATTEN for semi-structured data
CREATE OR REPLACE TABLE json_demo (id INT, data VARIANT);
INSERT INTO json_demo SELECT 1, PARSE_JSON('{"name":"Alice","skills":["SQL","Python","Spark"],"address":{"city":"NYC","zip":"10001"}}');
INSERT INTO json_demo SELECT 2, PARSE_JSON('{"name":"Bob","skills":["Java","Scala"],"address":{"city":"SF","zip":"94105"}}');

-- Flatten array
SELECT j.id, j.data:name::VARCHAR AS name, f.value::VARCHAR AS skill
FROM json_demo j, LATERAL FLATTEN(input => j.data:skills) f;

-- Nested path access
SELECT id, data:name::VARCHAR AS name, data:address.city::VARCHAR AS city, data:address.zip::VARCHAR AS zip FROM json_demo;

-- 4. PIVOT
SELECT * FROM (SELECT category, DATE_TRUNC('month', order_date)::DATE AS month, amount FROM sample_data WHERE order_date >= '2024-01-01')
  PIVOT(SUM(amount) FOR category IN ('Electronics','Clothing','Books','Sports','Home')) ORDER BY month LIMIT 12;

-- 5. UNPIVOT
CREATE OR REPLACE TABLE quarterly_sales (product VARCHAR, q1 NUMBER, q2 NUMBER, q3 NUMBER, q4 NUMBER);
INSERT INTO quarterly_sales VALUES ('Widget',100,150,200,180), ('Gadget',200,250,300,280);
SELECT * FROM quarterly_sales UNPIVOT(sales FOR quarter IN (q1, q2, q3, q4));

-- 6. Recursive CTE (org hierarchy)
CREATE OR REPLACE TABLE org_chart (emp_id INT, name VARCHAR, manager_id INT);
INSERT INTO org_chart VALUES (1,'CEO',NULL),(2,'VP Eng',1),(3,'VP Sales',1),(4,'Director',2),(5,'Manager',4);

WITH RECURSIVE hierarchy AS (
  SELECT emp_id, name, manager_id, 0 AS level, name::VARCHAR AS path FROM org_chart WHERE manager_id IS NULL
  UNION ALL
  SELECT o.emp_id, o.name, o.manager_id, h.level+1, h.path||' > '||o.name FROM org_chart o JOIN hierarchy h ON o.manager_id = h.emp_id
)
SELECT * FROM hierarchy ORDER BY level, emp_id;
