---
name: code-review
description: Use when reviewing pull requests, doing pre-commit review, auditing code for bugs and anti-patterns, or checking adherence to style guides and best practices.
---

# Code Review

## Review Order (by impact)

1. **Architecture & Design** — Is this the right solution? Does it fit the existing system?
2. **Correctness** — Does it work? Edge cases handled? Off-by-one errors?
3. **Security** — Injection risks? Exposed secrets? Auth checks present?
4. **Performance** — N+1 queries? Unnecessary loops? Memory leaks?
5. **Error Handling** — Are errors caught appropriately? Good error messages?
6. **Testing** — Right things tested? Edge cases covered? No testing implementation details?
7. **Style** — Naming consistent? Matches conventions? (Lowest priority.)

## What to Look For

### Bugs
- Off-by-one errors in loops/bounds
- Null/undefined access without guards
- Race conditions (async code without proper sequencing)
- Incorrect boolean logic (missing `!`, wrong `&&`/`||`)
- Type coercion surprises (`0`, `""`, `null`, `undefined` in conditionals)
- Mutating props/inputs that should be immutable

### Security
- SQL injection: any raw queries with string interpolation?
- XSS: unsanitized user input in HTML?
- Secrets: API keys, tokens, passwords in code or logs?
- Auth: is every endpoint checking permissions?
- Path traversal: user-controlled file paths?
- Prototype pollution: `Object.assign({}, userInput)`?

### Performance
- N+1 queries: loops containing DB/API calls
- Missing database indexes for queried columns
- Unnecessary re-renders (React/Solid/Vue)
- Large bundle sizes from heavy imports
- Memory leaks: untracked event listeners, intervals, subscriptions
- Blocking the event loop: sync CPU-heavy work in Node

### Error Handling
- try/catch with empty catch block (swallowing errors)
- Catching too broadly: `catch (error)` without checking type
- No error boundary for async operations
- Exposing internal error details to the client
- Retry logic missing or naive (no backoff, no max retries)

### Testing
- Tests that pass without assertions
- Tests that don't test the claimed behavior
- Mocking what you're testing
- Hardcoded time/random values without control
- No test for the error/failure path

### Code Organization
- Files over 300 lines without clear sections
- Functions over 50 lines (harder to test, harder to reason about)
- Deep nesting (>3 levels of if/for/try)
- Magic numbers without named constants (except 0, 1, -1)
- Duplicated logic across 3+ files (DRY violation)
- Dead code: unreachable branches, unused functions, commented-out code

## Review Comments Format

```
<severity>: <observation>

<why it matters (one sentence)>

<suggestion (one sentence, optionally with code)>
```

Severity levels:
- **BLOCKER**: Bug, security issue, data loss risk. Must fix before merge.
- **IMPORTANT**: Architectural concern, performance issue, maintainability risk. Should fix.
- **NIT**: Style, naming, minor improvements. Optional.
- **PRAISE**: Good pattern, well done. Positive reinforcement.

## Review Etiquette
- Assume competence. "I don't understand this — can you explain?" not "This is wrong."
- One comment per issue. Don't list 5 problems in one comment.
- Suggest, don't command. "Consider X because Y" not "Change this to X."
- Acknowledge when the author made a valid but non-obvious choice.
- Approve when issues are non-blocking. Trust the author to address NITs.
- Don't review for more than 60 minutes. Attention drops; you'll miss things.

## Before Approving
- [ ] Pull and actually run the code
- [ ] All CI checks pass
- [ ] No blockers remain
- [ ] Tests cover the change
- [ ] Documentation updated if the API changed
