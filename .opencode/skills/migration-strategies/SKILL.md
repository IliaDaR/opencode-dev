---
name: migration-strategies
description: Use when planning database migrations, API versioning, data backfills, framework upgrades, or any kind of incremental transition from old system to new.
---

# Migration Strategies

## Database Migrations

### The Golden Rules
1. Every migration must be reversible (write `down` script)
2. Never modify an existing migration — create a new one
3. Backfill in batches (1000 rows at a time)
4. Expensive migrations during low-traffic window
5. Test migration on a copy of production data

### Add Column Without Downtime
```
Step 1: Add column (nullable, no default)
  ALTER TABLE users ADD COLUMN bio TEXT;
  
Step 2: Deploy code that writes to both old and new column
  (if there's an old column being replaced)
  
Step 3: Backfill existing rows
  UPDATE users SET bio = old_description WHERE bio IS NULL;

Step 4: Deploy code that reads from new column, stops writing to old

Step 5: Drop old column
  ALTER TABLE users DROP COLUMN old_description;
```

### Rename Column (3 Deploys)
```
Deploy 1: Add new column, write to both
Deploy 2: Backfill, read from new column, stop writing to old
Deploy 3: Drop old column
```
Never rename in a single deploy — running old code will break.

### Dangerous Operations
| Operation | Risk | Mitigation |
|-----------|------|------------|
| Add column with DEFAULT | Table rewrite (pre-PG11) | Add nullable first, then set default |
| Change column type | Table rewrite, lock | Create new column, backfill, swap |
| Drop table | Irreversible data loss | Rename first, wait N days, then drop |
| Add unique index | Locks writes, may fail on duplicates | Create CONCURRENTLY, clean duplicates first |
| Remove column | Old code breaks | Follow 3-deploy rename pattern |

### Testing Migrations
```bash
# Test forward migration
pg_dump production > prod_schema.sql
# Run migration on copy
# Compare schemas

# Test rollback
# Run migration forward
# Run migration backward
# Schema should be identical to before
```

## API Migration (Versioning)

### Strategy: URL Versioning
```
/v1/users  → Old API
/v2/users  → New API
```

### Deprecation Timeline
```
Week 1:  Announce deprecation (docs, changelog, email)
Week 2:  Add Sunset header to /v1 responses
Week 4:  Add Warning header for /v1 usage
Week 8:  Start logging /v1 usage with rate, alert heavy users
Week 12: Disable /v1 (return 410 Gone)
```

### Sunset Header
```
Sunset: Sat, 31 Dec 2026 23:59:59 GMT
Deprecation: true
Link: </v2/users>; rel="successor-version"
```

## Data Backfill

```python
# NEVER: one massive UPDATE
UPDATE users SET status = 'active' WHERE status IS NULL  # Locks millions of rows

# ALWAYS: batch processing
def backfill(batch_size=1000):
    while True:
        updated = db.execute("""
            WITH batch AS (
                SELECT id FROM users 
                WHERE status IS NULL 
                LIMIT :batch_size
            )
            UPDATE users SET status = 'active'
            FROM batch WHERE users.id = batch.id
        """, {"batch_size": batch_size})
        if updated == 0:
            break
        sleep(0.1)  # Don't hammer the database
```

## Framework / Library Upgrades

### Major Version Upgrades
1. Read the migration guide (both the official one AND community experiences)
2. Run linter/codemod if available (e.g., React codemods)
3. Upgrade in a branch
4. Fix type errors first, then runtime errors
5. Run full test suite
6. Deploy to staging, let it bake for N hours
7. Deploy to production during low traffic

### Breaking Change Mitigation
```
If library X v3 breaks API:
1. Create abstraction layer (Adapter pattern)
2. Adapter implements old API using new library
3. Upgrade library, update adapter
4. Gradually migrate callers from old API to new API
5. Remove adapter when no old callers remain
```

## Monolith → Services Extraction

### The Strangler Fig Pattern
```
Phase 1: New service handles ONE endpoint
  /api/v2/users → new service
  Everything else → monolith

Phase 2: Route more endpoints to new service
  /api/v2/users, /api/v2/orders → new service

Phase 3: All new endpoints go to services

Phase 4: Migrate legacy one at a time
  /v1/users → handled by new service, proxied through monolith

Phase 5: Monolith becomes a thin router, then disappears
```

### When NOT to Extract
- Two features that always change together → keep in same service
- Feature that shares database tables heavily → extract carefully
- Feature with no independent scaling need → monolith is fine

## Rollback Planning

Every migration must have a rollback plan documented BEFORE execution:

```
Migration: Add tags column to posts
Rollback: ALTER TABLE posts DROP COLUMN tags
Risks: None (adding nullable column)
Data loss risk: None (new column is empty)

Migration: Normalize addresses into separate table
Rollback: Complex. Keep original address column for 1 week.
         Restore from backup if necessary.
Risks: Data inconsistency if rollback needed after new writes
```

If rollback takes longer than the migration itself, consider a different approach.
