---
name: sql-expert
description: Use when writing SQL queries, designing schemas, optimizing query performance, writing migrations, or debugging slow database operations. Covers PostgreSQL, MySQL, and SQLite patterns.
---

# SQL Expert

## Query Fundamentals

### SELECT: Only What You Need
```sql
-- Bad: fetches unnecessary columns, blocks index-only scans
SELECT * FROM users WHERE email = 'alice@example.com';

-- Good: explicit columns
SELECT id, name, email FROM users WHERE email = 'alice@example.com';

-- Best: if index on (email) covers id, name — index-only scan, no table access
```

### JOIN Types
```sql
-- INNER JOIN: rows that match in both tables
SELECT u.name, o.total
FROM users u
INNER JOIN orders o ON o.user_id = u.id

-- LEFT JOIN: all users, even those without orders
SELECT u.name, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
-- o.total is NULL for users with no orders

-- LATERAL JOIN: run subquery for each row (Postgres)
SELECT u.name, recent.total
FROM users u
LEFT JOIN LATERAL (
  SELECT total FROM orders
  WHERE user_id = u.id
  ORDER BY created_at DESC
  LIMIT 1
) recent ON true
```

### Aggregation
```sql
-- GROUP BY: collapse rows into groups
SELECT
  user_id,
  COUNT(*) AS order_count,
  SUM(total) AS total_spent,
  MAX(created_at) AS last_order
FROM orders
GROUP BY user_id
HAVING COUNT(*) > 5  -- filter groups, not rows
ORDER BY total_spent DESC
```

### Window Functions
```sql
-- ROW_NUMBER: unique number per partition
SELECT
  user_id,
  created_at,
  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
FROM orders
-- rn = 1 gives the most recent order per user

-- Running total:
SELECT
  date,
  amount,
  SUM(amount) OVER (ORDER BY date) AS running_total
FROM daily_sales

-- LAG / LEAD: access previous/next row
SELECT
  date,
  amount,
  LAG(amount) OVER (ORDER BY date) AS prev_amount,
  amount - LAG(amount) OVER (ORDER BY date) AS change
FROM daily_sales
```

### CTEs (WITH clauses)
```sql
WITH recent_users AS (
  SELECT id, name FROM users WHERE created_at > NOW() - INTERVAL '7 days'
),
user_order_counts AS (
  SELECT user_id, COUNT(*) AS cnt FROM orders GROUP BY user_id
)
SELECT ru.name, COALESCE(uoc.cnt, 0) AS order_count
FROM recent_users ru
LEFT JOIN user_order_counts uoc ON uoc.user_id = ru.id
```

## Performance

### Indexing Strategy
```sql
-- Single-column index for exact matches
CREATE INDEX idx_users_email ON users(email);

-- Composite index: equality first, range last
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at DESC);
-- Supports: WHERE user_id = ? AND created_at > ?
-- Also supports: WHERE user_id = ? (left prefix)
-- Does NOT support: WHERE created_at > ? (not left prefix)

-- Partial index: index only interesting rows
CREATE INDEX idx_orders_active ON orders(user_id)
WHERE status = 'active';
-- Much smaller, faster for active-only queries

-- Covering index (Postgres): include extra columns
CREATE INDEX idx_users_email_cover ON users(email)
INCLUDE (name, avatar_url);
-- Index-only scan for: SELECT name, avatar_url FROM users WHERE email = ?
```

### EXPLAIN Reading
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ...

-- Look for:
-- "Seq Scan" on large table (>10K rows) → missing index
-- "Index Scan" → good, using index
-- "Index Only Scan" → best, no table access
-- "Bitmap Heap Scan" → ok, combining multiple indexes
-- "Nested Loop" → join strategy, fine for small inner set
-- "Hash Join" → good for larger sets
-- High "Buffers: shared hit/read" → too much I/O
-- "actual time" vs "planned rows" mismatch → stale statistics
```

### Query Anti-Patterns
```sql
-- Bad: function on indexed column prevents index use
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
-- Fix: create index on LOWER(email) or store email lowercased

-- Bad: leading wildcard prevents index use
SELECT * FROM users WHERE email LIKE '%@example.com';
-- Fix: use full-text search or reverse index for suffix search

-- Bad: NOT IN with nullable column
SELECT * FROM users WHERE id NOT IN (SELECT user_id FROM orders);
-- If any user_id is NULL → entire query returns empty
-- Fix: NOT EXISTS (SELECT 1 FROM orders WHERE user_id = users.id)

-- Bad: implicit cross join
SELECT * FROM users, orders  -- Cartesian product!
-- Fix: always use explicit JOIN ... ON
```

## Schema Design

### Constraints Are Your Friend
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Foreign key ensures referential integrity
-- CHECK prevents invalid data at DB level (defense in depth)
-- DEFAULT + NOT NULL = safe inserts
```

### UUID vs Auto-Increment
- **UUID**: no collisions across shards, no sequential guess, exposes no count
- **Auto-increment**: smaller index, faster inserts, sortable, human-readable
- Default: UUID for distributed systems, auto-increment for single-DB apps

### Timestamps
```sql
-- ALWAYS use TIMESTAMPTZ (with timezone)
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
-- Stores UTC, displays in session timezone
-- Avoid TIMESTAMP (without TZ) — ambiguous!

-- updated_at trigger (Postgres):
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_orders_updated
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

## Common Recipes

### Upsert (Postgres)
```sql
INSERT INTO users (id, email, name)
VALUES ('123', 'alice@example.com', 'Alice')
ON CONFLICT (email) DO UPDATE SET
  name = EXCLUDED.name,
  updated_at = NOW()
-- If email exists → update; if not → insert
```

### Pagination
```sql
-- Cursor-based (recommended for real-time data)
SELECT * FROM orders
WHERE (created_at, id) > ('2024-01-01', 'uuid-123')
ORDER BY created_at, id
LIMIT 50

-- Offset-based (ok for static data, small-ish tables)
SELECT * FROM orders
ORDER BY created_at DESC
LIMIT 50 OFFSET 100
```

### Batch Update
```sql
-- Update in batches to avoid long locks
WITH batch AS (
  SELECT id FROM orders
  WHERE status = 'pending' AND created_at < NOW() - INTERVAL '30 days'
  LIMIT 1000
)
UPDATE orders SET status = 'expired'
FROM batch WHERE orders.id = batch.id
```

### Finding Duplicates
```sql
SELECT email, COUNT(*)
FROM users
GROUP BY email
HAVING COUNT(*) > 1
```

### Soft Delete
```sql
-- Add column instead of actual DELETE
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- All queries must filter:
SELECT * FROM users WHERE deleted_at IS NULL;

-- Create a view for safety:
CREATE VIEW active_users AS
SELECT * FROM users WHERE deleted_at IS NULL;
```
