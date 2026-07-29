-- ============================================================
-- DOMAIN 3: PERFORMANCE & TUNING - Hands-On Queries
-- ============================================================

-- 1. Query with filter (observe pruning in Query Profile)
SELECT category, DATE_TRUNC('month', order_date) AS month, SUM(amount) AS total, COUNT(*) AS cnt
FROM CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA
WHERE order_date BETWEEN '2024-04-01' AND '2024-06-30'
GROUP BY category, month ORDER BY month, total DESC;

-- 2. Clustering depth comparison
SELECT SYSTEM$CLUSTERING_DEPTH('CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA', '(order_date)') AS by_date,
       SYSTEM$CLUSTERING_DEPTH('CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA', '(category)') AS by_category,
       SYSTEM$CLUSTERING_DEPTH('CERT_STUDY_DB.ARCHITECTURE.SAMPLE_DATA', '(id)') AS by_id;

-- 3. Find spilling queries
SELECT query_id, SUBSTR(query_text,1,80) AS query, warehouse_size,
       bytes_spilled_to_local_storage/(1024*1024*1024) AS gb_spill_local,
       bytes_spilled_to_remote_storage/(1024*1024*1024) AS gb_spill_remote
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC LIMIT 10;

-- 4. Cache effectiveness
SELECT DATE_TRUNC('day', start_time) AS day, COUNT(*) AS total_queries,
       SUM(CASE WHEN bytes_scanned = 0 AND rows_produced > 0 THEN 1 ELSE 0 END) AS cache_hits,
       ROUND(SUM(CASE WHEN bytes_scanned=0 AND rows_produced>0 THEN 1 ELSE 0 END)/COUNT(*)*100,1) AS hit_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP()) AND query_type = 'SELECT' AND warehouse_name IS NOT NULL
GROUP BY day ORDER BY day DESC;

-- 5. Queued queries check
SELECT COUNT(*) AS total, SUM(CASE WHEN queued_overload_time > 0 THEN 1 ELSE 0 END) AS queued
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD('day', -3, CURRENT_TIMESTAMP()) AND query_type = 'SELECT';
