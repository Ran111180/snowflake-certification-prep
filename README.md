# Snowflake SnowPro Core Certification & Interview Prep

Complete hands-on study material for the **Snowflake SnowPro Core Certification** (COF-C02), covering all 8 exam domains with deep-dive HTML guides and runnable SQL queries tested on a live Snowflake account.

## Repository Structure

```
├── 01-architecture/
│   ├── 01-cloud-architecture/    # 3-layer architecture, SaaS model
│   ├── 02-storage-layer/         # Micro-partitions, columnar storage, pruning
│   ├── 03-compute-layer/         # Virtual warehouses, multi-cluster, caching
│   ├── 04-cloud-services/        # Metadata, optimization, transactions
│   └── 05-connectivity/          # Drivers, connectors, SnowSQL, Snowpark
├── 02-security/
│   ├── 01-authentication/        # Key-pair, MFA, SSO/SAML, OAuth, PAT
│   ├── 02-access-control-rbac/   # Roles hierarchy, privileges, database roles
│   ├── 03-network-security/      # Network policies, rules, private connectivity
│   ├── 04-data-security/         # Masking, row access, tags, classification
│   └── 05-governance/            # ACCESS_HISTORY, ACCOUNT_USAGE, Trust Center
├── 03-performance/               # Query Profile, clustering, SOS, QAS, caching
├── 04-data-loading/
│   ├── 01-basics/                # Stages, file formats, COPY INTO, Snowpipe
│   └── 02-production-pipelines/  # Kafka, SCD1/SCD2, dedup, error handling
├── 05-transformations/
│   ├── 01-sql-fundamentals/      # Window functions, QUALIFY, PIVOT, FLATTEN
│   └── 02-udfs-tasks-streams/    # UDFs, stored procs, Streams, Tasks, Dynamic Tables
├── 06-data-protection-sharing/   # Time Travel, Fail-safe, cloning, data sharing
├── 07-cortex-ai/                 # AI_COMPLETE, sentiment, translate, embeddings
├── 08-ecosystem-advanced/        # Iceberg, Native Apps, SPCS, Clean Rooms
├── 09-tasks-deep-dive/            # Tasks: CRON, DAGs, Streams+Tasks, Serverless, Email
│   ├── 01-certification-reference/ # Part 1 & Part 2 HTML, queries.sql
│   └── 02-hands-on-practice/       # Full lab with RBAC, stored proc, email notifications
├── 10-snowpipe-deep-dive/         # Snowpipe: Auto-Ingest, Streaming, Kafka, RBAC, Debug
│   ├── 01-certification-reference/ # Part 1 (Fundamentals), Part 2 (Advanced), 50 Questions
│   └── 02-hands-on-practice/       # Hands-on lab with internal stage, error handling, dedup
├── 11-streams-deep-dive/          # Streams: CDC, Offset, Staleness, Streams+Tasks, SCD
│   ├── 01-certification-reference/ # Part 1, Part 2, 50 Questions, Edge Cases
│   └── 02-hands-on-practice/       # Full lab: DML changes, consume, append-only, tasks
├── 12-dynamic-tables-deep-dive/   # Dynamic Tables: Declarative Pipelines, Target Lag, Refresh
│   ├── 01-certification-reference/ # Part 1 (Fundamentals), Part 2 (Advanced), 50 Questions, Edge Cases
│   └── 02-hands-on-practice/       # Full lab: medallion pipeline, DOWNSTREAM, stream on DT
└── 13-iceberg-tables-deep-dive/   # Iceberg Tables: Open Format, External Volumes, Catalog Integrations
    ├── 01-certification-reference/ # Part 1 (Fundamentals), Part 2 (Advanced), 50 Questions, Edge Cases
    └── 02-hands-on-practice/       # Lab: create Iceberg table, DML, schema evolution, Time Travel
```

Each folder contains:
- **`.html`** - Comprehensive study guide with concepts, diagrams, interview Q&A
- **`queries.sql`** - Hands-on SQL scripts tested on a live Snowflake account

## Exam Domains Covered

| # | Domain | Weight |
|---|--------|--------|
| 1 | Snowflake Cloud Data Platform & Architecture | 25% |
| 2 | Account Access & Security | 20% |
| 3 | Performance Concepts | 15% |
| 4 | Data Loading & Unloading | 10% |
| 5 | Data Transformations | 15% |
| 6 | Data Protection & Data Sharing | 10% |
| 7 | Cortex AI & Modern Features | — |
| 8 | Ecosystem & Advanced Features | 5% |

## How to Use

1. **Read the HTML guide** for conceptual understanding and interview prep
2. **Run the SQL queries** against your own Snowflake trial account
3. **Explore Query Profile** after each query to understand execution plans
4. **Review interview questions** at the end of each HTML document

## Environment Used

- **Snowflake Edition**: Standard (Trial)
- **Cloud Provider**: AWS (ap-southeast-1)
- **Warehouse**: COMPUTE_WH (X-Small, Gen2)
- **Database**: CERT_STUDY_DB / Schema: ARCHITECTURE

## Key Features Demonstrated

- Micro-partition pruning and clustering depth analysis
- Multi-cluster warehouse scaling and queue detection
- RBAC with custom role hierarchies and FUTURE grants
- Network policies and security integrations
- SCD Type 2 implementation with MERGE
- Stream + Task orchestration patterns
- Dynamic Tables with automatic refresh
- Zero-copy cloning (1M rows, instant)
- Cortex AI sentiment analysis and LLM inference
- Semi-structured data processing with LATERAL FLATTEN

## Author

**Ranga Naik K** - Snowflake Data Engineer

---

*Generated as part of SnowPro Core certification preparation, July 2026*
