-- =============================================================================
-- SQL Fundamentals Deep Dive - Hands-On Lab
-- Module 24: Window Functions, CTEs, MERGE, PIVOT, Conditionals, Dates
-- =============================================================================

-- =============================================================================
-- SECTION 1: SETUP - Create Sample Data
-- =============================================================================

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SQL_FUNDAMENTALS_LAB;
USE DATABASE SQL_FUNDAMENTALS_LAB;
CREATE SCHEMA IF NOT EXISTS PRACTICE;
USE SCHEMA PRACTICE;

-- Employees table
CREATE OR REPLACE TABLE employees (
    employee_id INT,
    name VARCHAR(50),
    department VARCHAR(30),
    salary NUMBER(10,2),
    hire_date DATE,
    manager_id INT
);

INSERT INTO employees VALUES
(1, 'Alice', 'Engineering', 120000, '2020-01-15', NULL),
(2, 'Bob', 'Engineering', 115000, '2020-03-20', 1),
(3, 'Carol', 'Engineering', 115000, '2021-06-01', 1),
(4, 'Dave', 'Marketing', 95000, '2019-11-10', NULL),
(5, 'Eve', 'Marketing', 90000, '2021-02-28', 4),
(6, 'Frank', 'Marketing', 90000, '2022-07-15', 4),
(7, 'Grace', 'Sales', 105000, '2020-08-01', NULL),
(8, 'Henry', 'Sales', 98000, '2021-01-10', 7),
(9, 'Iris', 'Sales', 92000, '2022-03-22', 7),
(10, 'Jack', 'Engineering', 130000, '2018-05-01', NULL);

-- Sales data with duplicates for testing
CREATE OR REPLACE TABLE daily_sales (
    sale_date DATE,
    product VARCHAR(20),
    region VARCHAR(20),
    amount NUMBER(10,2)
);

INSERT INTO daily_sales VALUES
('2024-01-01', 'Widget', 'North', 100),
('2024-01-01', 'Widget', 'South', 150),
('2024-01-01', 'Gadget', 'North', 200),
('2024-01-02', 'Widget', 'North', 120),
('2024-01-02', 'Gadget', 'South', 180),
('2024-01-03', 'Widget', 'North', 90),
('2024-01-03', 'Widget', 'South', 110),
('2024-01-03', 'Gadget', 'North', 220),
('2024-01-04', 'Widget', 'North', 130),
('2024-01-04', 'Gadget', 'South', 160);

-- Staging table for MERGE
CREATE OR REPLACE TABLE employee_updates (
    employee_id INT,
    name VARCHAR(50),
    department VARCHAR(30),
    salary NUMBER(10,2),
    action VARCHAR(10) -- 'UPDATE', 'INSERT', 'DELETE'
);

INSERT INTO employee_updates VALUES
(2, 'Bob', 'Engineering', 125000, 'UPDATE'),
(5, 'Eve', 'Marketing', 95000, 'UPDATE'),
(8, 'Henry', 'Sales', 0, 'DELETE'),
(11, 'Karen', 'Engineering', 110000, 'INSERT'),
(12, 'Leo', 'Sales', 88000, 'INSERT');

-- Quarterly revenue for PIVOT/UNPIVOT
CREATE OR REPLACE TABLE quarterly_revenue (
    product VARCHAR(20),
    q1_revenue NUMBER(10,2),
    q2_revenue NUMBER(10,2),
    q3_revenue NUMBER(10,2),
    q4_revenue NUMBER(10,2)
);

INSERT INTO quarterly_revenue VALUES
('Widget', 5000, 6200, 5800, 7100),
('Gadget', 8000, 7500, 9200, 8800),
('Doohickey', 3000, 3500, 4000, 4500);

-- =============================================================================
-- SECTION 2: WINDOW FUNCTIONS COMPARISON
-- =============================================================================

-- Lab 2.1: Compare ROW_NUMBER, RANK, DENSE_RANK
-- Observe the differences with tied salaries (Bob and Carol both have 115000)
SELECT 
    name, department, salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC) as row_num,
    RANK()       OVER (ORDER BY salary DESC) as rnk,
    DENSE_RANK() OVER (ORDER BY salary DESC) as dense_rnk,
    NTILE(3)     OVER (ORDER BY salary DESC) as tertile
FROM employees
ORDER BY salary DESC;

-- Lab 2.2: LAG and LEAD - Compare with previous/next hire
SELECT 
    name, hire_date, salary,
    LAG(name)    OVER (ORDER BY hire_date) as prev_hire,
    LEAD(name)   OVER (ORDER BY hire_date) as next_hire,
    salary - LAG(salary, 1, salary) OVER (ORDER BY hire_date) as salary_diff_from_prev
FROM employees
ORDER BY hire_date;

-- Lab 2.3: FIRST_VALUE and LAST_VALUE with frame
-- Notice LAST_VALUE behavior with default vs explicit frame
SELECT 
    name, department, salary,
    FIRST_VALUE(name) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) as highest_paid_name,
    -- DEFAULT frame: LAST_VALUE returns current row (wrong!)
    LAST_VALUE(name) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) as last_val_default,
    -- CORRECT frame: see actual last value
    LAST_VALUE(name) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as lowest_paid_name
FROM employees
ORDER BY department, salary DESC;

-- Lab 2.4: ROWS vs RANGE difference with tied dates
-- Insert duplicate dates to demonstrate
SELECT 
    sale_date, amount,
    SUM(amount) OVER (ORDER BY sale_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as rows_running_total,
    SUM(amount) OVER (ORDER BY sale_date 
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as range_running_total
FROM daily_sales
WHERE product = 'Widget' AND region = 'North'
ORDER BY sale_date;
-- Notice: RANGE groups same-date rows together; ROWS processes one at a time

-- =============================================================================
-- SECTION 3: QUALIFY CLAUSE
-- =============================================================================

-- Lab 3.1: Top earner per department
SELECT department, name, salary
FROM employees
QUALIFY ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) = 1;

-- Lab 3.2: All tied top earners (use RANK instead)
SELECT department, name, salary
FROM employees
QUALIFY RANK() OVER (PARTITION BY department ORDER BY salary DESC) = 1;

-- Lab 3.3: QUALIFY with inline window function (not in SELECT)
SELECT name, salary
FROM employees
WHERE department = 'Engineering'
QUALIFY DENSE_RANK() OVER (ORDER BY salary DESC) <= 2;

-- Lab 3.4: Bottom 2 by hire date per department
SELECT department, name, hire_date
FROM employees
QUALIFY ROW_NUMBER() OVER (PARTITION BY department ORDER BY hire_date DESC) <= 2;

-- =============================================================================
-- SECTION 4: COMMON TABLE EXPRESSIONS (CTEs)
-- =============================================================================

-- Lab 4.1: Multiple CTEs chained together
WITH dept_stats AS (
    SELECT department,
           AVG(salary) as avg_salary,
           COUNT(*) as headcount
    FROM employees
    GROUP BY department
),
ranked_depts AS (
    SELECT department, avg_salary, headcount,
           RANK() OVER (ORDER BY avg_salary DESC) as salary_rank
    FROM dept_stats
)
SELECT * FROM ranked_depts ORDER BY salary_rank;

-- Lab 4.2: CTE for deduplication before analysis
WITH latest_sales AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY sale_date, product ORDER BY amount DESC) as rn
    FROM daily_sales
)
SELECT sale_date, product, SUM(amount) as total_amount
FROM latest_sales
WHERE rn = 1
GROUP BY sale_date, product
ORDER BY sale_date, product;

-- =============================================================================
-- SECTION 5: RECURSIVE CTE
-- =============================================================================

-- Lab 5.1: Organization hierarchy
WITH RECURSIVE org_tree AS (
    -- Anchor: top-level managers
    SELECT employee_id, name, manager_id, 
           1 as level,
           name::VARCHAR(200) as path
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive: find reports
    SELECT e.employee_id, e.name, e.manager_id,
           t.level + 1,
           t.path || ' > ' || e.name
    FROM employees e
    JOIN org_tree t ON e.manager_id = t.employee_id
)
SELECT level, name, path, manager_id
FROM org_tree
ORDER BY path;

-- Lab 5.2: Generate a number series with recursive CTE
WITH RECURSIVE numbers AS (
    SELECT 1 as n
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 20
)
SELECT n, n * n as square, POWER(2, n) as power_of_2
FROM numbers;

-- Lab 5.3: Date series generation (alternative to GENERATOR)
WITH RECURSIVE date_series AS (
    SELECT '2024-01-01'::DATE as dt
    UNION ALL
    SELECT DATEADD('day', 1, dt) FROM date_series WHERE dt < '2024-01-31'
)
SELECT dt, DAYNAME(dt) as day_name, WEEKISO(dt) as week_num
FROM date_series
ORDER BY dt;

-- =============================================================================
-- SECTION 6: MERGE STATEMENT
-- =============================================================================

-- Lab 6.1: Create a target copy to merge into
CREATE OR REPLACE TABLE employees_target AS SELECT * FROM employees;

-- Lab 6.2: Full MERGE with INSERT, UPDATE, DELETE
MERGE INTO employees_target t
USING employee_updates s
ON t.employee_id = s.employee_id

WHEN MATCHED AND s.action = 'DELETE' THEN
    DELETE

WHEN MATCHED AND s.action = 'UPDATE' THEN
    UPDATE SET t.salary = s.salary, t.name = s.name

WHEN NOT MATCHED AND s.action = 'INSERT' THEN
    INSERT (employee_id, name, department, salary, hire_date, manager_id)
    VALUES (s.employee_id, s.name, s.department, s.salary, CURRENT_DATE(), NULL);

-- Verify results
SELECT * FROM employees_target ORDER BY employee_id;

-- Lab 6.3: Demonstrate MERGE duplicate key error
-- Uncomment to test (will error):
-- CREATE OR REPLACE TABLE dup_source AS 
--   SELECT * FROM employee_updates WHERE employee_id = 2
--   UNION ALL SELECT 2, 'Bobby', 'Eng', 130000, 'UPDATE';
-- MERGE INTO employees_target t USING dup_source s ON t.employee_id = s.employee_id
-- WHEN MATCHED THEN UPDATE SET t.name = s.name;

-- =============================================================================
-- SECTION 7: PIVOT AND UNPIVOT
-- =============================================================================

-- Lab 7.1: PIVOT - rows to columns
SELECT *
FROM daily_sales
PIVOT (
    SUM(amount) FOR region IN ('North', 'South')
) AS p (sale_date, product, north_sales, south_sales)
ORDER BY sale_date, product;

-- Lab 7.2: UNPIVOT - columns to rows
SELECT product, quarter, revenue
FROM quarterly_revenue
UNPIVOT (
    revenue FOR quarter IN (q1_revenue, q2_revenue, q3_revenue, q4_revenue)
)
ORDER BY product, quarter;

-- Lab 7.3: Pivot with specific products
SELECT *
FROM daily_sales
PIVOT (
    SUM(amount) FOR product IN ('Widget', 'Gadget')
) AS p (sale_date, region, widget_total, gadget_total)
ORDER BY sale_date;

-- =============================================================================
-- SECTION 8: GENERATOR AND SEQUENCES
-- =============================================================================

-- Lab 8.1: Generate rows with GENERATOR
SELECT 
    SEQ4() as seq_num,
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as row_num,
    DATEADD('day', SEQ4(), '2024-01-01'::DATE) as date_val
FROM TABLE(GENERATOR(ROWCOUNT => 10));

-- Lab 8.2: Generate sample data
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    'User_' || (SEQ4() + 1)::VARCHAR as username,
    UNIFORM(18, 65, RANDOM()) as age,
    ROUND(UNIFORM(30000, 150000, RANDOM()), 2) as salary
FROM TABLE(GENERATOR(ROWCOUNT => 20));

-- Lab 8.3: Sequence usage
CREATE OR REPLACE SEQUENCE order_seq START = 1000 INCREMENT = 1;

SELECT order_seq.NEXTVAL as order_id, 'Order_' || order_seq.CURRVAL as label
FROM TABLE(GENERATOR(ROWCOUNT => 5));

-- =============================================================================
-- SECTION 9: CONDITIONAL EXPRESSIONS
-- =============================================================================

-- Lab 9.1: IFF vs CASE
SELECT 
    name, salary,
    IFF(salary > 100000, 'Senior', 'Standard') as band_iff,
    CASE 
        WHEN salary >= 120000 THEN 'Executive'
        WHEN salary >= 100000 THEN 'Senior'
        WHEN salary >= 90000  THEN 'Mid'
        ELSE 'Junior'
    END as band_case
FROM employees;

-- Lab 9.2: DECODE with NULL handling
SELECT 
    name, manager_id,
    DECODE(manager_id, NULL, 'Top Manager', 1, 'Reports to Alice', 4, 'Reports to Dave', 7, 'Reports to Grace', 'Other') as reporting_line
FROM employees;
-- Note: DECODE treats NULL = NULL as TRUE (finds 'Top Manager')

-- Lab 9.3: NVL, COALESCE, NULLIF, ZEROIFNULL
SELECT 
    name,
    NVL(manager_id::VARCHAR, 'None') as mgr_nvl,
    COALESCE(manager_id::VARCHAR, 'No Manager') as mgr_coalesce,
    NULLIF(salary, 0) as salary_null_if_zero,
    ZEROIFNULL(manager_id) as mgr_zero_if_null
FROM employees;

-- =============================================================================
-- SECTION 10: DATE FUNCTIONS
-- =============================================================================

-- Lab 10.1: DATEDIFF boundary crossing
SELECT 
    name, hire_date,
    DATEDIFF('day', hire_date, CURRENT_DATE()) as days_employed,
    DATEDIFF('month', hire_date, CURRENT_DATE()) as months_employed,
    DATEDIFF('year', hire_date, CURRENT_DATE()) as years_boundary,
    DATEDIFF('day', hire_date, CURRENT_DATE()) / 365.25 as actual_years
FROM employees
ORDER BY hire_date;

-- Lab 10.2: DATE_TRUNC and DATEADD
SELECT 
    hire_date,
    DATE_TRUNC('month', hire_date) as month_start,
    DATE_TRUNC('quarter', hire_date) as quarter_start,
    DATE_TRUNC('week', hire_date) as week_start_monday,
    DATEADD('month', 6, hire_date) as six_months_later,
    LAST_DAY(hire_date) as month_end
FROM employees
ORDER BY hire_date;

-- Lab 10.3: Demonstrate DATEDIFF boundary gotcha
SELECT 
    '2023-12-31'::DATE as date1,
    '2024-01-01'::DATE as date2,
    DATEDIFF('year', '2023-12-31', '2024-01-01') as year_diff,   -- 1 (not 0!)
    DATEDIFF('month', '2024-01-31', '2024-02-01') as month_diff, -- 1 (not 0!)
    DATEDIFF('day', '2024-01-31', '2024-02-01') as day_diff;     -- 1

-- =============================================================================
-- SECTION 11: GROUPING SETS / CUBE / ROLLUP
-- =============================================================================

-- Lab 11.1: GROUPING SETS
SELECT 
    product, region,
    SUM(amount) as total_sales,
    GROUPING(product) as is_product_total,
    GROUPING(region) as is_region_total
FROM daily_sales
GROUP BY GROUPING SETS (
    (product, region),
    (product),
    (region),
    ()
)
ORDER BY product NULLS LAST, region NULLS LAST;

-- Lab 11.2: ROLLUP (hierarchical subtotals)
SELECT 
    product, region,
    SUM(amount) as total_sales
FROM daily_sales
GROUP BY ROLLUP(product, region)
ORDER BY product NULLS LAST, region NULLS LAST;

-- Lab 11.3: CUBE (all combinations)
SELECT 
    product, region,
    SUM(amount) as total_sales,
    COUNT(*) as num_sales
FROM daily_sales
GROUP BY CUBE(product, region)
ORDER BY product NULLS LAST, region NULLS LAST;

-- =============================================================================
-- SECTION 12: NULL TRAPS AND EDGE CASES
-- =============================================================================

-- Lab 12.1: NULL arithmetic
SELECT 
    NULL + 5 as null_plus_5,           -- NULL
    NULL * 100 as null_times_100,      -- NULL
    CONCAT('Hello', NULL) as concat_null, -- 'Hello' (CONCAT ignores NULL)
    'Hello' || NULL as pipe_null;      -- NULL (|| propagates NULL!)

-- Lab 12.2: NOT IN trap with NULL
CREATE OR REPLACE TABLE test_null_in (val INT);
INSERT INTO test_null_in VALUES (1), (2), (3), (NULL);

-- This returns ZERO rows (not 1, 2, 3)!
SELECT * FROM employees WHERE employee_id NOT IN (SELECT val FROM test_null_in);

-- Fix: filter NULLs or use NOT EXISTS
SELECT * FROM employees e 
WHERE NOT EXISTS (
    SELECT 1 FROM test_null_in t WHERE t.val = e.employee_id
);

-- Lab 12.3: Integer division trap
SELECT 
    5 / 2 as int_division,           -- 2 (not 2.5!)
    5.0 / 2 as decimal_division,     -- 2.500000
    5::FLOAT / 2 as float_division,  -- 2.5
    3 / 7 * 100 as wrong_pct,        -- 0 (integer 3/7=0, then 0*100=0)
    3.0 / 7 * 100 as correct_pct;    -- 42.857...

-- Lab 12.4: COUNT(*) vs COUNT(column) with NULLs
SELECT 
    COUNT(*) as count_all,            -- counts all rows including NULL
    COUNT(manager_id) as count_non_null, -- excludes NULL manager_ids
    COUNT(*) - COUNT(manager_id) as null_count
FROM employees;

-- Lab 12.5: Aggregate on all-NULL column
SELECT SUM(val) as sum_val    -- Returns NULL, not 0!
FROM (SELECT NULL::INT as val UNION ALL SELECT NULL::INT);

-- =============================================================================
-- SECTION 13: CLEANUP
-- =============================================================================

-- Uncomment to clean up:
-- DROP DATABASE IF EXISTS SQL_FUNDAMENTALS_LAB;
