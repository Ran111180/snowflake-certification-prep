-- ============================================================
-- DOMAIN 7: CORTEX AI & MODERN FEATURES - Hands-On Queries
-- ============================================================

-- 1. Cortex AI Complete (LLM inference)
USE DATABASE CERT_STUDY_DB;
USE SCHEMA ARCHITECTURE;

SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Explain micro-partitions in Snowflake in 2 sentences') AS answer;

-- 2. Sentiment Analysis
CREATE OR REPLACE TABLE product_reviews (id INT, product VARCHAR, review TEXT);
INSERT INTO product_reviews VALUES
  (1, 'Laptop', 'Amazing performance, best purchase ever!'),
  (2, 'Phone', 'Terrible battery life, very disappointed'),
  (3, 'Tablet', 'Good value for money, decent screen quality'),
  (4, 'Headphones', 'Absolutely love the noise cancellation'),
  (5, 'Mouse', 'Stopped working after 2 days, waste of money');

SELECT id, product, review, SNOWFLAKE.CORTEX.SENTIMENT(review) AS sentiment_score
FROM product_reviews ORDER BY sentiment_score DESC;

-- 3. AI Translate
SELECT SNOWFLAKE.CORTEX.TRANSLATE('Snowflake is a cloud data platform', 'en', 'es') AS spanish,
       SNOWFLAKE.CORTEX.TRANSLATE('Snowflake is a cloud data platform', 'en', 'fr') AS french;

-- 4. AI Summarize
SELECT SNOWFLAKE.CORTEX.SUMMARIZE('Snowflake is a cloud-based data warehousing platform that provides data storage, processing, and analytic solutions. It was founded in 2012 and is known for its unique architecture that separates storage and compute. The platform supports structured and semi-structured data, enables data sharing across organizations, and offers features like automatic scaling, time travel, and zero-copy cloning.') AS summary;

-- 5. Embedding for semantic search
SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m-v1.5', 'data warehouse performance tuning') AS embedding;

-- 6. AI Classification (with COMPLETE)
SELECT review,
  SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
    'Classify this review into exactly one category: POSITIVE, NEGATIVE, NEUTRAL. Only respond with the category.\nReview: ' || review) AS classification
FROM product_reviews;
