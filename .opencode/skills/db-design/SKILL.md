---
name: db-design
description: Use when designing database schemas, writing migrations, optimizing queries, choosing between SQL/NoSQL, or reviewing database changes. Covers schema design, indexing, migrations, and query patterns.
---

# Database Design

## Schema Design

### Naming Conventions
- Tables: plural, snake_case (`users`, `order_items`)
- Columns: snake_case (`created_at`, `user_id`)
- Foreign keys: `{referenced_table_singular}_id` (`user_id` references `users.id`)
- Indexes: `idx_{table}_{column}` (`idx_users_email`)
- Unique constraints: `uq_{table}_{column}` (`uq_users_email`)
- Primary keys: always `id`, prefer UUID v7 or ULID over auto-increment

### Column Types — Choose the Smallest Possible

| Data | Use | Not |
|------|-----|-----|
| Text < 255 chars | `VARCHAR(255)` | `TEXT` |
| Long text | `TEXT` | `VARCHAR(10000)` |
| Boolean | `BOOLEAN` | `TINYINT(1)` |
| Money | `DECIMAL(19,4)` or `INTEGER` (cents) | `FLOAT` |
| Timestamp | `TIMESTAMPTZ` | `TIMESTAMP` without TZ |
| JSON payload | `JSONB` (Postgres) | `TEXT` with JSON.parse |
| Enum-like values | Lookup table | ENUM type or string |

### Normalization Rules
- **1NF**: No repeating groups, atomic values
- **2NF**: No partial dependencies on composite keys
- **3NF**: No transitive dependencies (non-key depends on another non-key)
- **Stop at 3NF** unless you have a specific reason to go further

### When to Denormalize
- Read-heavy workload, write-light
- The denormalized value rarely changes
- Joins are the bottleneck (measured, not guessed)
- Cache summary counts if queries are expensive: `users.comment_count`

## Indexing

### Rules of Thumb
- Index every foreign key
- Index columns used in WHERE, JOIN, ORDER BY
- Composite index: equality columns first, range columns last
- Covering index: include SELECT columns to avoid table lookups
- Partial index for filtered queries: `WHERE deleted_at IS NULL`
- Text search: use full-text index (GIN/GiST), not `LIKE '%keyword%'`

### When NOT to Index
- Small tables (< 1000 rows): sequential scan is faster
- Columns with low cardinality (boolean, status with 3 values): index won't help
- Tables with heavy writes: every index slows INSERT/UPDATE/DELETE
- Never-indexed columns in queries: dead indexes waste space and write time

### Index Analysis
```sql
EXPLAIN ANALYZE SELECT ... -- Check if index is used
-- Look for: Seq Scan (bad for large tables), Index Scan (good), Bitmap Scan (ok)
```

## Migrations

### Rules
- Every migration must be reversible (write `down` script)
- Never modify an existing migration — create a new one
- Expensive migrations: run during low-traffic window
- Backfill: update in batches (1000 rows at a time), not one massive UPDATE
- Add column with default = lock-free in Postgres 11+
- Renaming a column used by old code = deploy in 3 steps:
  1. Add new column (writes go to both)
  2. Migrate old data, update readers to use new column
  3. Drop old column

### Dangerous Operations (Postgres)
- `ALTER TABLE ... ADD COLUMN ... DEFAULT ...` (pre-PG11): rewrites entire table
- `VARCHAR(255)` → `VARCHAR(256)`: metadata-only (safe)
- `VARCHAR(255)` → `TEXT`: metadata-only (safe)
- Dropping a column that is read: breaks running app instances

## Query Patterns

### N+1 Problem
```python
# Bad: N+1 queries
users = db.query("SELECT * FROM users")
for user in users:
    orders = db.query("SELECT * FROM orders WHERE user_id = ?", user.id)

# Good: one query with JOIN or IN
users = db.query("SELECT * FROM users")
user_ids = [u.id for u in users]
orders = db.query("SELECT * FROM orders WHERE user_id IN (?)", user_ids)
```

### Pagination
- Cursor-based > offset-based for real-time data
- Keyset pagination: `WHERE created_at > ? AND id > ? ORDER BY created_at, id LIMIT 50`
- Count queries are expensive: cache total, or use `has_more` boolean instead of total

### Write Patterns
- Batch inserts: `INSERT INTO t (a,b) VALUES (1,2), (3,4), (5,6)` not 3 separate INSERTs
- Upsert: `INSERT ... ON CONFLICT ... DO UPDATE` (Postgres) or `REPLACE INTO` (MySQL)
- Bulk update: use `WHERE id IN (...)` with batches of 1000

## SQL vs NoSQL

| Requirement | SQL | NoSQL |
|-------------|-----|-------|
| Complex joins | ✅ | ❌ |
| Schema flexibility | ❌ | ✅ |
| ACID transactions | ✅ | Varies |
| Horizontal scale writes | Harder | Easier |
| Ad-hoc queries | ✅ | Limited |
| Relationships | ✅ Built-in | Manual in code |

Default choice: PostgreSQL. Deviate only with a specific, measured reason.

## Query Optimization Checklist

1. `EXPLAIN ANALYZE` first — never optimize by guessing
2. Missing index? → Add and re-measure
3. Fetching too many columns? → `SELECT col1, col2` not `SELECT *`
4. Fetching too many rows? → Add LIMIT, paginate
5. N+1 detected? → JOIN or batch IN query
6. Slow aggregation? → Materialized view or summary table
7. Lock contention? → Check transaction isolation level, reduce transaction duration
