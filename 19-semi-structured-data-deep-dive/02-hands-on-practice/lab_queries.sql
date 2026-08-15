-- ============================================================
-- SEMI-STRUCTURED DATA - Hands-On Lab
-- SnowPro Core Certification Practice
-- ============================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE DATABASE TASK_PRACTICE_DB;
CREATE SCHEMA IF NOT EXISTS SEMI_STRUCTURED_LAB;
USE SCHEMA SEMI_STRUCTURED_LAB;

-- ============================================================
-- STEP 1: Create table with VARIANT column
-- ============================================================
CREATE OR REPLACE TABLE raw_events (
    event_data VARIANT,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- STEP 2: Insert JSON data using PARSE_JSON
-- ============================================================
INSERT INTO raw_events (event_data) SELECT PARSE_JSON('{
  "event_id": "evt_001",
  "user": {"name": "Alice", "age": 30, "email": "alice@example.com"},
  "action": "purchase",
  "items": [
    {"product": "Laptop", "price": 999.99, "qty": 1},
    {"product": "Mouse", "price": 29.99, "qty": 2}
  ],
  "metadata": {"source": "web", "ip": "192.168.1.1", "timestamp": "2026-08-15T10:30:00Z"}
}');

INSERT INTO raw_events (event_data) SELECT PARSE_JSON('{
  "event_id": "evt_002",
  "user": {"name": "Bob", "age": 25, "email": "bob@example.com"},
  "action": "view",
  "items": [{"product": "Monitor", "price": 499.99, "qty": 1}],
  "metadata": {"source": "mobile", "ip": "10.0.0.5", "timestamp": "2026-08-15T11:00:00Z"}
}');

INSERT INTO raw_events (event_data) SELECT PARSE_JSON('{
  "event_id": "evt_003",
  "user": {"name": "Carol", "age": 35, "email": "carol@example.com"},
  "action": "purchase",
  "items": [
    {"product": "Keyboard", "price": 79.99, "qty": 1},
    {"product": "Webcam", "price": 129.99, "qty": 1},
    {"product": "Headset", "price": 199.99, "qty": 2}
  ],
  "metadata": {"source": "web", "ip": "172.16.0.1", "timestamp": "2026-08-15T12:00:00Z"}
}');

-- ============================================================
-- STEP 3: Dot notation (colon) access
-- ============================================================
-- Access top-level keys
SELECT
    event_data:event_id::VARCHAR AS event_id,
    event_data:action::VARCHAR AS action,
    event_data:user.name::VARCHAR AS user_name,
    event_data:user.age::INT AS user_age,
    event_data:metadata.source::VARCHAR AS source
FROM raw_events;

-- ============================================================
-- STEP 4: Bracket notation (case-sensitive keys)
-- ============================================================
SELECT
    event_data['event_id']::VARCHAR AS event_id,
    event_data['user']['name']::VARCHAR AS name,
    event_data['user']['email']::VARCHAR AS email
FROM raw_events;

-- ============================================================
-- STEP 5: TYPEOF - check value types
-- ============================================================
SELECT
    TYPEOF(event_data:event_id) AS id_type,        -- VARCHAR
    TYPEOF(event_data:user) AS user_type,           -- OBJECT
    TYPEOF(event_data:items) AS items_type,         -- ARRAY
    TYPEOF(event_data:user.age) AS age_type         -- INTEGER
FROM raw_events LIMIT 1;

-- ============================================================
-- STEP 6: LATERAL FLATTEN - explode arrays into rows
-- ============================================================
-- Flatten the items array (one row per item)
SELECT
    event_data:event_id::VARCHAR AS event_id,
    event_data:user.name::VARCHAR AS user_name,
    f.index AS item_index,
    f.value:product::VARCHAR AS product,
    f.value:price::DECIMAL(10,2) AS price,
    f.value:qty::INT AS quantity
FROM raw_events,
LATERAL FLATTEN(input => event_data:items) f;

-- ============================================================
-- STEP 7: FLATTEN with aggregation
-- ============================================================
-- Total spend per user
SELECT
    event_data:user.name::VARCHAR AS user_name,
    COUNT(f.value) AS total_items,
    SUM(f.value:price::DECIMAL(10,2) * f.value:qty::INT) AS total_spend
FROM raw_events,
LATERAL FLATTEN(input => event_data:items) f
WHERE event_data:action::VARCHAR = 'purchase'
GROUP BY 1;

-- ============================================================
-- STEP 8: OBJECT_CONSTRUCT - build JSON from SQL
-- ============================================================
SELECT OBJECT_CONSTRUCT(
    'full_name', event_data:user.name::VARCHAR,
    'total_items', ARRAY_SIZE(event_data:items),
    'event_type', event_data:action::VARCHAR
) AS summary
FROM raw_events;

-- ============================================================
-- STEP 9: ARRAY functions
-- ============================================================
-- ARRAY_SIZE
SELECT
    event_data:event_id::VARCHAR AS event_id,
    ARRAY_SIZE(event_data:items) AS item_count
FROM raw_events;

-- ARRAY_CONSTRUCT
SELECT ARRAY_CONSTRUCT(1, 2, 3, 'hello', NULL) AS my_array;

-- ARRAY_AGG (aggregate rows into array)
SELECT ARRAY_AGG(event_data:action::VARCHAR) AS all_actions
FROM raw_events;

-- ARRAY_CONTAINS
SELECT
    event_data:event_id::VARCHAR,
    ARRAY_CONTAINS('Laptop'::VARIANT, event_data:items[0]:product) AS has_laptop_first
FROM raw_events;

-- ============================================================
-- STEP 10: Nested FLATTEN (array within object)
-- ============================================================
-- Create more complex nested data
CREATE OR REPLACE TABLE orders_nested AS
SELECT PARSE_JSON('{
  "order_id": "ORD001",
  "customer": "Alice",
  "departments": [
    {"name": "Electronics", "items": ["Laptop", "Mouse", "Keyboard"]},
    {"name": "Office", "items": ["Paper", "Pens"]}
  ]
}') AS data;

-- Double FLATTEN: departments → items within each department
SELECT
    data:order_id::VARCHAR AS order_id,
    dept.value:name::VARCHAR AS department,
    item.value::VARCHAR AS item_name
FROM orders_nested,
LATERAL FLATTEN(input => data:departments) dept,
LATERAL FLATTEN(input => dept.value:items) item;

-- ============================================================
-- STEP 11: OBJECT_KEYS and OBJECT_AGG
-- ============================================================
-- Get all keys from an object
SELECT OBJECT_KEYS(event_data:user) AS user_keys
FROM raw_events LIMIT 1;

-- Build aggregated object
SELECT OBJECT_AGG(
    event_data:event_id::VARCHAR,
    event_data:action::VARCHAR
) AS event_map
FROM raw_events;

-- ============================================================
-- STEP 12: NULL handling (SQL NULL vs JSON null)
-- ============================================================
SELECT PARSE_JSON('{"a": null, "b": "hello"}') AS data;

-- JSON null vs SQL NULL
SELECT
    PARSE_JSON('{"a": null}'):a IS NULL AS json_null_is_null,     -- FALSE!
    PARSE_JSON('{"a": null}'):a = 'null'::VARIANT AS is_json_null, -- TRUE
    PARSE_JSON('{"a": null}'):missing_key IS NULL AS missing_is_null -- TRUE (SQL NULL)
;

-- ============================================================
-- STEP 13: GET_PATH for dynamic access
-- ============================================================
SELECT
    GET_PATH(event_data, 'user.name')::VARCHAR AS name_via_path,
    GET_PATH(event_data, 'metadata.source')::VARCHAR AS source_via_path
FROM raw_events;

-- ============================================================
-- STEP 14: Loading JSON from stage (concept demo)
-- ============================================================
-- Create a file format for JSON loading
CREATE OR REPLACE FILE FORMAT json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    STRIP_NULL_VALUES = FALSE
    IGNORE_UTF8_ERRORS = TRUE;

-- Typical COPY INTO pattern:
-- COPY INTO raw_events (event_data)
--   FROM @my_stage/events/
--   FILE_FORMAT = json_format;

-- ============================================================
-- STEP 15: Materialized columns pattern (performance optimization)
-- ============================================================
-- Extract frequently-queried paths into typed columns
CREATE OR REPLACE TABLE events_materialized AS
SELECT
    event_data:event_id::VARCHAR AS event_id,
    event_data:user.name::VARCHAR AS user_name,
    event_data:user.age::INT AS user_age,
    event_data:action::VARCHAR AS action,
    event_data:metadata.source::VARCHAR AS source,
    event_data:metadata.timestamp::TIMESTAMP AS event_timestamp,
    event_data  -- keep original for ad-hoc queries
FROM raw_events;

-- This table has typed columns (better pruning) + raw VARIANT (flexibility)
SELECT * FROM events_materialized WHERE action = 'purchase' AND user_age > 28;

-- ============================================================
-- STEP 16: CLEANUP
-- ============================================================
-- DROP TABLE raw_events;
-- DROP TABLE orders_nested;
-- DROP TABLE events_materialized;
-- DROP FILE FORMAT json_format;
-- DROP SCHEMA SEMI_STRUCTURED_LAB;

-- ============================================================
-- KEY TAKEAWAYS:
-- 1. VARIANT holds any semi-structured data (JSON, XML, Avro)
-- 2. Colon notation (data:key) is case-sensitive
-- 3. LATERAL FLATTEN explodes arrays/objects into rows
-- 4. Always cast (::TYPE) before using in WHERE, JOIN, GROUP BY
-- 5. JSON null ≠ SQL NULL (common exam trap)
-- 6. OBJECT_CONSTRUCT/ARRAY_CONSTRUCT build structured data
-- 7. Materialized columns improve performance for frequent queries
-- 8. Max VARIANT size = 16 MB per value
-- ============================================================