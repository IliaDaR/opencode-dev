---
name: performance
description: Use when optimizing application performance, debugging slow endpoints, reducing latency, improving bundle size, or profiling CPU/memory usage. Covers frontend, backend, and database optimization.
---

# Performance Optimization

## First Rule: Measure, Don't Assume

Never optimize based on intuition. Profile first, find the bottleneck, measure improvement.

```
1. Set performance target (e.g., "API response < 200ms p95")
2. Measure current state
3. Profile to find bottleneck
4. Optimize the bottleneck
5. Measure again — did it improve?
6. If target not met → repeat from step 3
```

## Backend Performance

### Common Bottlenecks & Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Linear slowdown with users | N+1 queries | JOIN or batch load |
| Sudden spike in latency | Missing index | Add index, verify with EXPLAIN |
| Gradual memory growth | Memory leak | Check event listeners, closures, caches without TTL |
| Slow at startup, fast after | Cold cache | Warm cache on deploy |
| Random slow requests | GC pauses | Reduce allocations, reuse objects |
| Queue building up | Backpressure | Add queue consumer, rate limit producers |

### Query Optimization
```sql
-- Find slow queries (Postgres)
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- Check if index is used
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
-- Look for: "Index Scan" = good, "Seq Scan" on large table = bad
-- "Heap Fetches" vs "Rows" ratio: high = index losing selectivity
```

### Caching Strategy
```
Browser → CDN (edge) → API Gateway → App Cache (Redis) → Database
                                                          ↓
                                                    Read Replica
```

- Cache at the outermost layer possible
- Invalidate on write (write-through or write-behind)
- Set TTLs: shorter for user-specific data, longer for shared data
- Cache stampede prevention: lock on cache miss, not simultaneous re-computes

### Connection Pooling
```python
# Database pool sizing
pool_size = (core_count * 2) + effective_spindle_count  # PostgreSQL formula
# OR
pool_size = max_connections / number_of_app_instances * 0.8  # Safe ceiling

# HTTP connection pooling
# Reuse connections (keep-alive), don't create per-request
# Pool idle timeout: long enough for traffic patterns, short enough to free resources
```

## Frontend Performance

### Core Web Vitals
| Metric | Target | What it measures |
|--------|--------|-----------------|
| LCP (Largest Contentful Paint) | < 2.5s | Loading speed |
| FID (First Input Delay) | < 100ms | Interactivity |
| INP (Interaction to Next Paint) | < 200ms | Responsiveness |
| CLS (Cumulative Layout Shift) | < 0.1 | Visual stability |

### Bundle Size
```bash
# Analyze what's in your bundle
npx webpack-bundle-analyzer stats.json
# Or: npx source-map-explorer build/static/js/*.js

# Find heavy dependencies
npx depcheck  # unused deps
npx bundle-phobia-cli <package-name>  # check cost before adding
```

### Loading Strategies
- **Route-based splitting**: `React.lazy(() => import("./HeavyPage"))`
- **Above-the-fold first**: critical CSS inline, rest deferred
- **Images**: lazy load (`loading="lazy"`), responsive sizes, WebP/AVIF format
- **Fonts**: `font-display: swap`, subset to needed characters, preload critical fonts
- **Third-party scripts**: defer or async, self-host when possible

### Rendering Performance
```jsx
// React/Solid: memoize expensive computations
const sorted = useMemo(() => data.sort(expensiveCompare), [data])

// React: prevent unnecessary re-renders
const MemoizedChild = React.memo(Child)

// Virtualize long lists
import { FixedSizeList } from "react-window"

// Debounce rapid events (scroll, resize, input)
const debounced = useMemo(() => debounce(handler, 150), [])
```

### Network
- HTTP/2 multiplexing: one connection, many requests
- Compression: gzip or brotli for text, don't compress images
- CDN: serve static assets from edge
- Preconnect to critical origins: `<link rel="preconnect" href="https://api.example.com">`
- Avoid redirect chains: each redirect costs a round trip

## Memory Leaks

### Common Causes
```javascript
// Event listeners not cleaned up
useEffect(() => {
  window.addEventListener("resize", handler)
  return () => window.removeEventListener("resize", handler)  // CRITICAL
}, [])

// Intervals without cleanup
useEffect(() => {
  const id = setInterval(tick, 1000)
  return () => clearInterval(id)
}, [])

// Growing caches
const cache = new Map()  // Never pruned → memory leak
// Fix: use LRU cache or Map + periodic cleanup

// Detached DOM nodes (JS still has reference to removed element)
// Fix: null out references in cleanup
```

## When NOT to Optimize

- **Without measurement**: "I think this is slow" ≠ it is slow
- **Non-bottleneck**: Optimizing a function that takes 0.1% of total time
- **Readable code**: Don't sacrifice clarity for micro-optimization
- **Premature**: During initial development before you know real usage patterns
- **Wrong level**: Adding a cache when the problem is an N+1 query
