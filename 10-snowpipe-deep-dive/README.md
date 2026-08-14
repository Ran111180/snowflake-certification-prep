# 10 - Snowpipe Deep Dive

Complete certification prep for Snowpipe covering file-based ingestion, Snowpipe Streaming, Kafka integration, RBAC, production debugging, and cost optimization.

## Structure

```
10-snowpipe-deep-dive/
├── 01-certification-reference/
│   ├── 10_01_Snowpipe_Theory_Part1.html    # Fundamentals, Syntax, Stages, Auto-Ingest, REST API
│   ├── 10_02_Snowpipe_Theory_Part2.html    # Streaming, Kafka, RBAC, Debug, Optimization, Cost
│   └── 10_03_Snowpipe_50_Questions.html    # 50 exam-level practice questions with answers
└── 02-hands-on-practice/
    └── lab_queries.sql                      # All SQL from hands-on session (copy-paste ready)
```

## Topics Covered

### Part 1 - Fundamentals
- What is Snowpipe (serverless, file-based, ~1 min latency)
- Complete syntax (CREATE, ALTER, DESCRIBE, DROP, SYSTEM$PIPE_STATUS)
- Internal vs External stages
- Auto-Ingest setup (AWS SQS, Azure Event Grid, GCS Pub/Sub)
- REST API loading (insertFiles, insertReport)
- File formats & limited transformations
- Load history & monitoring (COPY_HISTORY, PIPE_USAGE_HISTORY)
- 15 Features, 15 Limitations
- Best practices & top 5 exam traps

### Part 2 - Advanced
- Snowpipe Streaming (row-level, seconds latency, SDK)
- Kafka & streaming sources integration
- All ingestion methods compared (7 methods)
- RBAC & privileges (CREATE PIPE, OPERATE, MONITOR, owner's rights)
- Production debugging guide (8 common issues)
- Optimizing slow pipelines (file size, batching, compression)
- Cost model & billing mechanics
- Error handling (ON_ERROR options, ERROR_INTEGRATION)
- Architecture patterns (ELT, multi-source, error recovery)

### Practice Questions
- 50 exam-level questions covering all topics
- Interactive show/hide answers with explanations
- Scoring guide for self-assessment

## Key Exam Traps
1. **CREATE OR REPLACE** purges load history → duplicates
2. **PATTERN** in Snowpipe trims stage URL first (differs from COPY INTO)
3. **AUTO_INGEST** only works with external stages
4. **14-day metadata** — after 14 days, file can be reloaded
5. **Snowpipe does NOT use your warehouse** — serverless compute

## Hands-On Lab Practiced
- Created internal stage + file format
- Uploaded sample CSV data to stage
- Created Snowpipe with ON_ERROR = SKIP_FILE
- Triggered via ALTER PIPE REFRESH
- Verified 14-day dedup (no duplicates on re-refresh)
- Tested error handling with bad data file
- Demonstrated CREATE OR REPLACE duplicate danger
- Monitored with COPY_HISTORY and PIPE_USAGE_HISTORY
- Pipe management (pause/resume/status)
