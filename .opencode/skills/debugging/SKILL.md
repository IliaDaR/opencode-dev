---
name: debugging
description: Use when debugging software issues — runtime errors, unexpected behavior, performance problems, or test failures. Systematic approach to finding root causes.
---

# Debugging

## The Debugging Process

### 1. Reproduce Reliably
A bug you can't reproduce is a bug you can't fix. Find the minimal reproduction:
- What exact input triggers it?
- Does it happen every time or intermittently?
- What environment (OS, browser, Node version)?
- Create a minimal reproduction script/case

### 2. Narrow the Problem Space
```python
# Binary search through code: comment out half, see if bug persists
# Binary search through git history: git bisect
# Binary search through input: remove half the data, see if bug persists

# The problem is always in the DIFFERENCE
# What's different between working case and broken case?
```

### 3. Form Hypotheses, Don't Guess
```
Bad: "Maybe it's the database connection. I'll rewrite that."
Good: "If the database connection is the problem, 
       we should see a timeout in the logs. 
       Let me check the logs. → No timeout. Hypothesis rejected."
```

### 4. Change One Thing at a Time
Change ONE variable, test. If you change 3 things and it works, you don't know which fixed it.

## Techniques

### Print Debugging (When It's the Right Tool)
```python
# Strategic, not random
print(f"[checkout] cart_id={cart.id} items={len(cart.items)} user={cart.user_id}")
# Put at function boundaries, decision points, error paths

# Better: structured
logger.debug("checkout_start", cart_id=cart.id, items=len(cart.items))
```

### Interactive Debugger
```python
# Python
breakpoint()  # Python 3.7+: drops into pdb

# Node.js
debugger;  # Run with: node --inspect-brk script.js

# Chrome DevTools for Node: node --inspect-brk → chrome://inspect
```

### Rubber Duck Debugging
Explain the code line by line to an inanimate object. 50% of the time you'll find the bug before finishing the explanation.

### The "Have You Tried Turning It Off" Method
- Clear caches
- Delete node_modules and reinstall
- Delete build artifacts and rebuild
- Restart the dev server
Surprisingly effective for "it was working yesterday" bugs.

## Common Bug Categories & Fixes

### Null/Undefined Errors
```
TypeError: Cannot read properties of undefined
```
Check trace: which variable is undefined? Add guard or default. Check if async data arrived.

### Race Conditions
```javascript
// Bug: second request finishes before first, 
// state from first overwrites second
let latestData

async function load(id) {
  const data = await fetch(`/api/${id}`)
  latestData = data  // BUG: doesn't check if this is still the latest request
}

// Fix: abort or check sequence
let currentId = 0
async function load(id) {
  const requestId = ++currentId
  const data = await fetch(`/api/${id}`)
  if (requestId === currentId) {
    latestData = data  // Only update if still latest
  }
}
```

### Off-by-One Errors
```javascript
// Check: is it < or <=?
// Check: is the index 0-based or 1-based?
// Check: is the end inclusive or exclusive?

// Common fix: extract boundaries into named constants
const MAX_ITEMS = 50
if (items.length <= MAX_ITEMS) { ... }
```

### State Update Timing
```javascript
// React: setState is async
setCount(count + 1)  // BUG: count is stale
setCount(c => c + 1)  // FIX: functional update

// The test: run the update twice in a row
setCount(count + 1)
setCount(count + 1)
// count increases by 1 (BUG) or 2 (FIX)?
```

### Reference vs Value
```javascript
// Objects/arrays are compared by reference
[1, 2] === [1, 2]  // false!

// Immutable updates in state:
const newArray = [...oldArray, newItem]  // Creates new reference
```

## Debugging Tools

### Node.js
```bash
# Heap snapshot (memory leaks)
node --heapsnapshot-signal=SIGUSR2 app.js
kill -USR2 <pid>  # Creates heap snapshot

# CPU profiling
node --cpu-prof app.js

# Trace warnings
node --trace-warnings app.js

# Debug specific module
NODE_DEBUG=module,http node app.js
```

### Browser DevTools
- Sources tab: set breakpoints, conditional breakpoints, XHR breakpoints
- Network tab: throttle, block requests, replay XHR
- Performance tab: record, analyze flame chart
- Memory tab: heap snapshot, allocation timeline
- Application tab: inspect localStorage, IndexedDB, cookies

### Database
```sql
-- Find slow queries (Postgres)
SELECT query, calls, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;

-- Find long-running queries
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;

-- Kill a stuck query
SELECT pg_terminate_backend(pid);
```

## Remote / Production Debugging

1. Read logs — they exist for a reason
2. Check monitoring dashboards — any metrics spiking?
3. Check recent deployments — what changed?
4. Can you reproduce in staging? If not, what's different?
5. If you must debug in production: read-only queries, don't modify state
6. Add temporary detailed logging (with a TTL to auto-remove)

## When to Walk Away

- 30+ minutes stuck on the same hypothesis
- You're making random changes hoping something works
- You're tired/stressed (bugs get harder to find, decisions get worse)

Take a break. Explain the problem to someone else. Sleep on it.
