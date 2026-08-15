/***********************************************************************
  SNOWFLAKE CORTEX AI - HANDS-ON LAB
  SnowPro Core Certification Prep
  
  14 Steps covering all major Cortex AI functions:
  - LLM Functions (AI_COMPLETE, AI_SENTIMENT, AI_SUMMARIZE, AI_TRANSLATE, AI_CLASSIFY, AI_EXTRACT)
  - Embeddings (AI_EMBED_TEXT, vector similarity)
  - ML Functions (FORECAST, ANOMALY_DETECTION)
  
  Prerequisites:
  - SNOWFLAKE.CORTEX_USER database role granted to your role
  - A warehouse available for queries
  - Cortex functions available in your region
***********************************************************************/

-- ============================================================
-- STEP 1: SETUP - Create schema and sample data
-- ============================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS cortex_lab;
CREATE SCHEMA IF NOT EXISTS cortex_lab.ai_demo;
USE SCHEMA cortex_lab.ai_demo;

-- Sample customer reviews table
CREATE OR REPLACE TABLE customer_reviews (
    review_id INT AUTOINCREMENT,
    customer_name VARCHAR(100),
    product VARCHAR(100),
    review_text VARCHAR(5000),
    review_date DATE,
    rating INT
);

INSERT INTO customer_reviews (customer_name, product, review_text, review_date, rating)
VALUES
    ('Alice Johnson', 'CloudSync Pro', 'Absolutely love this product! It syncs my data seamlessly across all devices. The setup was incredibly easy and customer support was responsive when I had questions.', '2024-11-15', 5),
    ('Bob Smith', 'CloudSync Pro', 'The product works okay but the interface is confusing. Took me hours to figure out basic settings. Documentation could be much better.', '2024-11-20', 3),
    ('Carol Davis', 'DataVault Enterprise', 'Terrible experience. Data was lost during migration and support took 3 days to respond. We had to restore from our own backups. Never again.', '2024-12-01', 1),
    ('David Lee', 'DataVault Enterprise', 'Solid encryption and compliance features. Meets all our regulatory requirements. The audit trail is comprehensive.', '2024-12-05', 4),
    ('Eve Martinez', 'CloudSync Pro', 'Good value for money. Not the fastest sync but reliable. Have been using it for 6 months without issues.', '2024-12-10', 4),
    ('Frank Wilson', 'AnalyticsHub', 'Game changer for our team! Real-time dashboards, easy sharing, and the AI insights feature saves hours of manual analysis every week.', '2024-12-12', 5),
    ('Grace Kim', 'AnalyticsHub', 'Decent analytics tool but lacks advanced customization. The pre-built templates are limiting for power users who need flexibility.', '2024-12-15', 3),
    ('Henry Brown', 'DataVault Enterprise', 'Setup was complex but once running, it is rock solid. Zero downtime in 8 months. Enterprise features justify the price.', '2024-12-18', 4),
    ('Iris Chen', 'CloudSync Pro', 'Stopped working after the last update. Files are not syncing and I get timeout errors constantly. Very frustrated.', '2024-12-20', 1),
    ('Jack Taylor', 'AnalyticsHub', 'Perfect for small teams. Affordable, intuitive, and the collaboration features make it easy to share insights with stakeholders.', '2024-12-22', 5);

-- Sample documents table for extraction/classification
CREATE OR REPLACE TABLE support_tickets (
    ticket_id INT AUTOINCREMENT,
    ticket_text VARCHAR(2000),
    submitted_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO support_tickets (ticket_text)
VALUES
    ('Hi, I need to cancel my subscription for account #12345. My name is Sarah Connor and my email is sarah@example.com. Please process the cancellation by end of month.'),
    ('URGENT: Our production database is down since 3:00 AM. Error code DB-5001. All 200 users are affected. Company: Acme Corp, Contact: John Reese, Phone: 555-0199.'),
    ('I would like to upgrade from Basic to Enterprise plan. Currently have 50 users, need to add 30 more. Billing contact: Marcus Wright, PO number: PO-2024-789.'),
    ('The export feature is broken in version 4.2.1. When I click Export to CSV, it downloads an empty file. Browser: Chrome 120, OS: Windows 11.'),
    ('Just wanted to say thank you! Your team resolved my issue in under an hour. Excellent customer service. Will definitely recommend to colleagues.');

-- Verify data
SELECT 'customer_reviews' AS table_name, COUNT(*) AS row_count FROM customer_reviews
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;


-- ============================================================
-- STEP 2: AI_COMPLETE - Basic Text Generation
-- ============================================================

-- Simple text generation
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'mistral-large2',
    'Explain what Snowflake virtual warehouses are in 2 sentences.'
) AS generated_text;

-- Generate product descriptions from data
SELECT 
    product,
    SNOWFLAKE.CORTEX.AI_COMPLETE(
        'mistral-large2',
        'Write a one-sentence marketing tagline for a product called "' || product || '" based on this review: ' || review_text
    ) AS tagline
FROM customer_reviews
WHERE rating = 5
LIMIT 3;


-- ============================================================
-- STEP 3: AI_COMPLETE - With System Prompt and Temperature
-- ============================================================

-- Low temperature (deterministic, factual)
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'mistral-large2',
    [
        {'role': 'system', 'content': 'You are a technical documentation writer. Be precise and factual. Use bullet points.'},
        {'role': 'user', 'content': 'What are the key benefits of columnar storage in data warehouses?'}
    ],
    {'temperature': 0.1, 'max_tokens': 300}
) AS factual_response;

-- High temperature (creative)
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'mistral-large2',
    [
        {'role': 'system', 'content': 'You are a creative marketing copywriter. Be engaging and enthusiastic.'},
        {'role': 'user', 'content': 'Write a catchy headline for a cloud data platform that emphasizes speed and simplicity.'}
    ],
    {'temperature': 0.9, 'max_tokens': 100}
) AS creative_response;


-- ============================================================
-- STEP 4: AI_COMPLETE - Multi-Turn Chat (Message Array)
-- ============================================================

-- Simulate a conversation with context
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'mistral-large2',
    [
        {'role': 'system', 'content': 'You are a Snowflake expert helping users understand features. Keep answers concise.'},
        {'role': 'user', 'content': 'What is a Snowflake stage?'},
        {'role': 'assistant', 'content': 'A Snowflake stage is a location where data files are stored for loading into or unloading from tables. Stages can be internal (managed by Snowflake) or external (referencing cloud storage like S3, Azure Blob, or GCS).'},
        {'role': 'user', 'content': 'How is that different from a table?'},
        {'role': 'assistant', 'content': 'A table stores structured, queryable data in Snowflake columnar format. A stage stores raw files (CSV, JSON, Parquet, etc.) that have not yet been loaded into tables. Think of a stage as a landing zone and a table as the final destination.'},
        {'role': 'user', 'content': 'Can I query files directly from a stage without loading them?'}
    ],
    {'temperature': 0.2, 'max_tokens': 200}
) AS multi_turn_response;


-- ============================================================
-- STEP 5: AI_SENTIMENT - Analyze Customer Reviews
-- ============================================================

-- Get sentiment scores for all reviews
SELECT 
    review_id,
    customer_name,
    product,
    rating,
    SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) AS sentiment_score,
    CASE 
        WHEN SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) > 0.3 THEN 'Positive'
        WHEN SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) < -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END AS sentiment_label,
    LEFT(review_text, 80) AS review_preview
FROM customer_reviews
ORDER BY sentiment_score DESC;

-- Compare sentiment score vs. star rating
SELECT 
    product,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text)), 3) AS avg_sentiment
FROM customer_reviews
GROUP BY product
ORDER BY avg_sentiment DESC;


-- ============================================================
-- STEP 6: AI_SUMMARIZE - Summarize Long Text
-- ============================================================

-- Summarize individual reviews
SELECT 
    review_id,
    product,
    SNOWFLAKE.CORTEX.AI_SUMMARIZE(review_text) AS summary
FROM customer_reviews
WHERE LENGTH(review_text) > 100
LIMIT 5;

-- Summarize all reviews for a product (concatenated)
SELECT 
    product,
    SNOWFLAKE.CORTEX.AI_SUMMARIZE(
        LISTAGG(review_text, ' | ') WITHIN GROUP (ORDER BY review_date)
    ) AS product_summary
FROM customer_reviews
GROUP BY product;


-- ============================================================
-- STEP 7: AI_TRANSLATE - Translate Text
-- ============================================================

-- Translate reviews to French
SELECT 
    review_id,
    review_text AS original_english,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(review_text, 'en', 'fr') AS french_translation
FROM customer_reviews
LIMIT 3;

-- Translate to Spanish
SELECT 
    review_id,
    review_text AS original_english,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(review_text, 'en', 'es') AS spanish_translation
FROM customer_reviews
LIMIT 3;

-- Auto-detect source language (empty string)
SELECT SNOWFLAKE.CORTEX.AI_TRANSLATE(
    'Bonjour, comment puis-je configurer le partage de donnees?',
    '',    -- auto-detect source language
    'en'   -- translate to English
) AS translated_to_english;


-- ============================================================
-- STEP 8: AI_CLASSIFY - Categorize Text
-- ============================================================

-- Classify support tickets by type
SELECT 
    ticket_id,
    LEFT(ticket_text, 80) AS ticket_preview,
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        ticket_text,
        ['Account Cancellation', 'Technical Issue', 'Upgrade Request', 'Bug Report', 'Positive Feedback']
    ) AS classification
FROM support_tickets;

-- Classify review sentiment into categories
SELECT 
    review_id,
    product,
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        review_text,
        ['Product Praise', 'Feature Request', 'Bug Report', 'Complaint', 'General Feedback']
    ) AS review_category,
    rating
FROM customer_reviews;


-- ============================================================
-- STEP 9: AI_EXTRACT - Extract Structured Data from Text
-- ============================================================

-- Extract contact info from support tickets
SELECT 
    ticket_id,
    SNOWFLAKE.CORTEX.AI_EXTRACT(
        ticket_text,
        ['customer_name', 'email', 'phone', 'company', 'account_number']
    ) AS extracted_info
FROM support_tickets;

-- Extract specific fields and access them
SELECT 
    ticket_id,
    extracted:customer_name::VARCHAR AS customer_name,
    extracted:email::VARCHAR AS email,
    extracted:company::VARCHAR AS company
FROM (
    SELECT 
        ticket_id,
        SNOWFLAKE.CORTEX.AI_EXTRACT(
            ticket_text,
            ['customer_name', 'email', 'phone', 'company', 'account_number', 'urgency_level']
        ) AS extracted
    FROM support_tickets
);


-- ============================================================
-- STEP 10: AI_EMBED_TEXT - Generate Embeddings
-- ============================================================

-- Generate embeddings for reviews
CREATE OR REPLACE TABLE review_embeddings AS
SELECT 
    review_id,
    product,
    review_text,
    SNOWFLAKE.CORTEX.AI_EMBED_TEXT('snowflake-arctic-embed-m-v1.5', review_text) AS embedding
FROM customer_reviews;

-- Check the embedding (it's a vector)
SELECT 
    review_id,
    review_text,
    embedding
FROM review_embeddings
LIMIT 2;


-- ============================================================
-- STEP 11: Vector Similarity Search (Cosine Similarity)
-- ============================================================

-- Find reviews most similar to a search query
SET search_query = 'product reliability and uptime';

SELECT 
    review_id,
    product,
    review_text,
    VECTOR_COSINE_SIMILARITY(
        embedding,
        SNOWFLAKE.CORTEX.AI_EMBED_TEXT('snowflake-arctic-embed-m-v1.5', $search_query)
    ) AS similarity_score
FROM review_embeddings
ORDER BY similarity_score DESC
LIMIT 5;

-- Find reviews similar to "customer support experience"
SELECT 
    review_id,
    product,
    review_text,
    VECTOR_COSINE_SIMILARITY(
        embedding,
        SNOWFLAKE.CORTEX.AI_EMBED_TEXT('snowflake-arctic-embed-m-v1.5', 'customer support experience')
    ) AS similarity_score
FROM review_embeddings
ORDER BY similarity_score DESC
LIMIT 3;

-- Compare L2 distance (lower = more similar)
SELECT 
    review_id,
    product,
    LEFT(review_text, 60) AS preview,
    VECTOR_L2_DISTANCE(
        embedding,
        SNOWFLAKE.CORTEX.AI_EMBED_TEXT('snowflake-arctic-embed-m-v1.5', 'data security and encryption')
    ) AS l2_distance
FROM review_embeddings
ORDER BY l2_distance ASC
LIMIT 5;


-- ============================================================
-- STEP 12: FORECAST - Time Series Prediction
-- ============================================================

-- Create sample time series data (daily sales for 6 months)
CREATE OR REPLACE TABLE daily_sales AS
SELECT 
    DATEADD(day, SEQ4(), '2024-01-01')::DATE AS sale_date,
    -- Base trend + seasonality + noise
    ROUND(
        1000 + (SEQ4() * 2.5) +                          -- upward trend
        (150 * SIN(SEQ4() * 3.14159 / 7)) +              -- weekly seasonality
        (300 * SIN(SEQ4() * 3.14159 / 30)) +             -- monthly seasonality
        (UNIFORM(-80, 80, RANDOM()))                       -- random noise
    , 2) AS daily_revenue
FROM TABLE(GENERATOR(ROWCOUNT => 180));

-- View the data
SELECT * FROM daily_sales ORDER BY sale_date LIMIT 10;
SELECT COUNT(*) AS total_days, MIN(sale_date) AS start_date, MAX(sale_date) AS end_date FROM daily_sales;

-- Create a view for the forecast model input
CREATE OR REPLACE VIEW sales_time_series AS
SELECT sale_date, daily_revenue FROM daily_sales;

-- Create the forecast model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST sales_forecast_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'sales_time_series'),
    TIMESTAMP_COLNAME => 'SALE_DATE',
    TARGET_COLNAME => 'DAILY_REVENUE'
);

-- Generate forecast for next 30 days
CALL sales_forecast_model!FORECAST(
    FORECASTING_PERIODS => 30,
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

-- View forecast results (the output from CALL is returned directly)
-- The results include: TS (timestamp), FORECAST, LOWER_BOUND, UPPER_BOUND


-- ============================================================
-- STEP 13: ANOMALY_DETECTION - Detect Outliers
-- ============================================================

-- Create data with some anomalies injected
CREATE OR REPLACE TABLE server_metrics AS
SELECT 
    DATEADD(hour, SEQ4(), '2024-06-01 00:00:00')::TIMESTAMP_NTZ AS metric_time,
    CASE 
        -- Inject anomalies at specific points
        WHEN SEQ4() IN (50, 51, 120, 200, 201, 202, 350) THEN 
            ROUND(85 + UNIFORM(10, 25, RANDOM()), 1)  -- abnormally high CPU
        ELSE 
            ROUND(35 + (15 * SIN(SEQ4() * 3.14159 / 24)) + UNIFORM(-5, 5, RANDOM()), 1)  -- normal range 20-55%
    END AS cpu_usage
FROM TABLE(GENERATOR(ROWCOUNT => 400));

-- View the metrics
SELECT * FROM server_metrics ORDER BY metric_time LIMIT 20;

-- Create view for anomaly detection
CREATE OR REPLACE VIEW metrics_for_anomaly AS
SELECT metric_time, cpu_usage FROM server_metrics;

-- Create anomaly detection model (unsupervised - no labels)
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION cpu_anomaly_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'metrics_for_anomaly'),
    TIMESTAMP_COLNAME => 'METRIC_TIME',
    TARGET_COLNAME => 'CPU_USAGE',
    LABEL_COLNAME => ''
);

-- Detect anomalies on the same data (or new data)
CALL cpu_anomaly_model!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'metrics_for_anomaly'),
    TIMESTAMP_COLNAME => 'METRIC_TIME',
    TARGET_COLNAME => 'CPU_USAGE',
    CONFIG_OBJECT => {'prediction_interval': 0.99}
);

-- The output includes: TS, Y, FORECAST, IS_ANOMALY, PERCENTILE, DISTANCE


-- ============================================================
-- STEP 14: CLEANUP
-- ============================================================

-- Drop all objects created in this lab
-- Uncomment below when ready to clean up:

/*
DROP TABLE IF EXISTS cortex_lab.ai_demo.customer_reviews;
DROP TABLE IF EXISTS cortex_lab.ai_demo.support_tickets;
DROP TABLE IF EXISTS cortex_lab.ai_demo.review_embeddings;
DROP TABLE IF EXISTS cortex_lab.ai_demo.daily_sales;
DROP TABLE IF EXISTS cortex_lab.ai_demo.server_metrics;
DROP VIEW IF EXISTS cortex_lab.ai_demo.sales_time_series;
DROP VIEW IF EXISTS cortex_lab.ai_demo.metrics_for_anomaly;
DROP SNOWFLAKE.ML.FORECAST IF EXISTS cortex_lab.ai_demo.sales_forecast_model;
DROP SNOWFLAKE.ML.ANOMALY_DETECTION IF EXISTS cortex_lab.ai_demo.cpu_anomaly_model;
DROP SCHEMA IF EXISTS cortex_lab.ai_demo;
DROP DATABASE IF EXISTS cortex_lab;
*/

-- Verify cleanup (run after uncommenting above)
-- SHOW SCHEMAS IN DATABASE cortex_lab;  -- should error if DB dropped