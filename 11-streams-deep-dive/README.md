# 11 - Streams Deep Dive

Complete certification prep for Snowflake Streams covering Change Data Capture (CDC), stream types, offset management, staleness, Streams+Tasks patterns, SCD implementations, and comparison with Dynamic Tables.

## Structure

```
11-streams-deep-dive/
├── 01-certification-reference/
│   ├── 11_01_Streams_Theory_Part1.html    # Fundamentals: CDC, Syntax, Types, Metadata, Offset, Staleness
│   ├── 11_02_Streams_Theory_Part2.html    # Advanced: Streams+Tasks, SCD, Dynamic Tables, RBAC, Debug
│   └── 11_03_Streams_50_Questions.html    # 50 interactive exam questions (click to answer)
└── 02-hands-on-practice/
    └── (lab to be added during hands-on session)
```

## Topics Covered

### Part 1 - Fundamentals
- What are Streams (CDC, offset model, near-zero storage)
- Complete syntax (CREATE, ALTER, DESCRIBE, DROP)
- Stream Types: Standard, Append-Only, Insert-Only
- Metadata Columns: METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID
- Offset advancement rules (only committed DML advances)
- Staleness (DATA_RETENTION + 14 days, cannot recover)
- Streams on tables, views, external tables, directory tables
- Consuming streams (DML transactions)
- 15 Features, 15 Limitations, Best Practices

### Part 2 - Advanced
- Streams + Tasks automated CDC pattern
- SYSTEM$STREAM_HAS_DATA in Task WHEN clause
- SCD Type 1 (overwrite) and Type 2 (history) with Streams
- Streams vs Dynamic Tables decision framework
- RBAC & Privileges (who creates, consumes, monitors)
- Production debugging (stale streams, empty streams, permission errors)
- Multi-stream patterns (multiple consumers, chained streams)
- Cost & performance considerations
- Change Tracking mechanism and CHANGES clause

### 50 Interactive Questions
- Click options to answer (green=correct, red=wrong)
- Live score tracking with reset
- Explanations shown after each answer

## Key Exam Traps
1. **SELECT does NOT advance offset** — only committed DML does
2. **Staleness = DATA_RETENTION + 14 days** — not just retention
3. **Stale streams CANNOT be recovered** — must drop and recreate
4. **Updates = DELETE + INSERT pair** with METADATA$ISUPDATE=TRUE
5. **Near-zero storage** — streams store offsets, not data copies
6. **CREATE OR REPLACE TABLE breaks all streams** on that table
7. **Standard streams show NET changes** — insert+delete=nothing
