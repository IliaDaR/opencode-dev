---
name: autopilot
description: Use when the user gives a high-level goal and expects autonomous execution — plan, implement, test, and iterate without hand-holding. The agent drives the entire workflow end-to-end.
---

# Autopilot Mode

## When to Engage

User says things like:
- "Build a REST API for tasks"
- "Add authentication to the app"  
- "Fix all the type errors"
- "Set up CI/CD"
- "Refactor the database layer"

These are multi-step goals. The user expects you to drive.

## The Autopilot Loop

```
1. PLAN    → Delegate to architect (or do quick plan yourself if simple)
2. IMPLEMENT → Delegate to scribe for code, typesmith for types
3. VERIFY   → Run typecheck, tests, lint
4. FIX      → If verify fails, delegate to quick-fix or debugger
5. REPORT   → Summarize what was done, what's left
6. REPEAT   → If more work remains, loop to step 1
```

## Plan Depth

### Simple Task (1-3 files, < 100 lines total)
```
Don't delegate. Plan mentally. Execute immediately.

Example: "Add email validation to the signup form"
→ Edit signup.ts, add validation function, done.
```

### Medium Task (3-8 files, 100-500 lines)
```
Quick mental plan. Delegate implementation to scribe.

Example: "Add a comments feature to the blog"
→ Architect plan (1 min) → Scribe implements (3 files) → Verify → Report
```

### Complex Task (8+ files, 500+ lines, new subsystem)
```
Full autopilot loop.

Example: "Add real-time notifications"
→ Architect designs → Scribe implements backend → Scribe implements frontend
→ Debugger fixes test failures → Refactor cleans up → Report
```

## Parallel Execution

When a task has independent sub-parts, run them in parallel:

```
User: "Add login, signup, and password reset"

Not: login → signup → reset (sequential, slow)
But:  Launch 3 scribe agents simultaneously
      Each handles one feature
      You integrate the results
```

## Error Recovery

### When Something Fails

```
1. Read the error message carefully (don't guess)
2. Is it a simple fix? → Quick-fix agent
3. Is it unclear? → Debugger agent
4. Is it an architecture problem? → Architect agent (re-plan)
5. Did YOU cause it? → Fix it yourself, learn, continue

Never: ignore the error and continue
Never: retry the exact same thing hoping it works
Never: make random changes until it passes
```

### 3-Strike Rule
```
Attempt 1: Try the obvious fix
Attempt 2: Try the less obvious fix
Attempt 3: Re-think the approach entirely (delegate to debugger/architect)

If 3 attempts fail → tell the user what's blocking you. Don't loop.
```

## Progress Reporting

### Every Major Milestone
```
✅ Auth system: login, signup, password reset done
✅ Database: migrations created, indexes added
🔄 Frontend: login form in progress (scribe working on it)
⏳ Tests: pending after frontend done
❌ CI/CD: blocked — need to decide on deployment target
```

Use emojis sparingly — they're for status, not decoration.

### Final Report
```
## Done
- src/auth/login.ts — JWT-based login with httpOnly cookies
- src/auth/signup.ts — email/password registration with validation
- src/auth/reset.ts — password reset via email token

## Verified
- Typecheck: PASS
- Tests: 12 new tests, all PASS
- Lint: PASS

## Notes
- Session duration: 7 days (configurable via SESSION_DURATION env var)
- Rate limiting: 5 attempts/minute per IP
```
