---
name: security-audit
description: Use when reviewing code for security vulnerabilities, hardening applications, handling authentication/authorization, or working with sensitive data. Covers OWASP Top 10, common attack vectors, and secure coding patterns.
---

# Security Audit

## OWASP Top 10 Quick Reference

1. Broken Access Control — missing auth checks, IDOR
2. Cryptographic Failures — weak hashing, plaintext secrets
3. Injection — SQL, NoSQL, OS command, LDAP
4. Insecure Design — missing rate limiting, no input validation
5. Security Misconfiguration — debug mode on, default passwords
6. Vulnerable Components — outdated deps with known CVEs
7. Auth Failures — weak password policy, no MFA, session fixation
8. Software & Data Integrity — unsigned updates, deserialization
9. Logging & Monitoring — no audit trail, no alerting
10. SSRF — user-controlled URLs fetching internal resources

## Input Validation

### Always Validate at the Boundary
```typescript
// The moment data enters your system — validate
function handleUserInput(raw: unknown): UserInput {
  // Schema validation, not manual checks
  const result = UserInputSchema.safeParse(raw)
  if (!result.success) throw new ValidationError(result.error)
  return result.data
}
```

### Specific Rules
- Strings: max length, allowed characters, trim
- Numbers: min/max range, integer vs float
- Enums: exact match against allowed set
- Email: verify format, don't try to regex it perfectly (use validator lib)
- URLs: parse and validate scheme (http/https only), not just regex
- File uploads: type check by magic bytes, not extension; size limit; scan content
- HTML/rich text: sanitize server-side (DOMPurify), never trust client sanitization

## Authentication

### Password Handling
- Hash with bcrypt/scrypt/argon2 (NOT SHA, NOT MD5)
- Salt per password (bcrypt handles this)
- Cost factor: measure on your hardware, target ~300ms per hash
- Never log passwords or password hashes
- Rate limit login attempts (account-level AND IP-level)

### Token Management
- JWT: short-lived access (15 min) + refresh token (7 days)
- Refresh tokens: single-use, rotate on refresh, revocable
- Store tokens in httpOnly, Secure, SameSite=Strict cookies (not localStorage)
- Never put sensitive data in JWT payload (it's base64, not encrypted)

### Session Security
- Regenerate session ID on login (prevent session fixation)
- Invalidate all sessions on password change
- Set absolute session timeout (not just idle timeout)
- CSRF token for state-changing operations

## Authorization

### Patterns
```python
# RBAC (Role-Based Access Control)
# Simple, flat — good for most apps
if user.role not in ["admin", "moderator"]:
    raise Forbidden()

# ABAC (Attribute-Based) — for complex rules
if not (user.department == doc.department or user.clearance >= doc.clearance):
    raise Forbidden()

# ReBAC (Relationship-Based) — for social/org graphs
if not org.has_member(user) or not user.can("edit_documents"):
    raise Forbidden()
```

### Rules
- Default deny. Explicitly grant access.
- Check authorization on EVERY endpoint, not just the UI
- Object-level authorization: can THIS user access THIS resource?
- Don't rely on client-side hiding of UI elements

## SQL Injection Prevention

```python
# ALWAYS parameterized queries
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))

# NEVER string interpolation
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")  # DEATH

# Dynamic table/column names? Whitelist, don't escape
ALLOWED_SORT = {"name", "email", "created_at"}
if sort not in ALLOWED_SORT:
    raise ValueError(f"Invalid sort column: {sort}")
# Then safely interpolate the whitelisted value
```

## Secrets Management

- Never in code. Not in comments. Not in "temporary" test files.
- Environment variables for deployment, vault for production
- .env files MUST be in .gitignore
- Rotate secrets regularly; automate rotation for production
- Audit: scan repo history for leaked secrets (`git log -p | grep SECRET`)
- Prefer managed identity (IAM roles, service accounts) over static keys

## Common Vulnerabilities by Stack

### Node.js
- `eval()`, `new Function()`, `vm.runInNewContext()` — never with user input
- `child_process.exec(userInput)` — use `execFile` with argument array
- `JSON.parse` is safe, but `require(userInput)` is not
- `_.template()` in lodash can execute code — know what you pass

### React
- `dangerouslySetInnerHTML` — sanitize first (DOMPurify)
- `javascript:` URLs in href — disallow
- Server-side rendering: don't embed user data without escaping

### SQL
- Dynamic ORDER BY / GROUP BY — whitelist or use CASE
- LIKE with user input: escape `%` and `_` wildcards
- COPY/IMPORT from user-provided paths — validate path

### APIs
- Rate limiting: per-user, per-IP, per-endpoint
- Response headers: remove `X-Powered-By`, `Server`
- CORS: explicit origins, never `Access-Control-Allow-Origin: *` with credentials
- GraphQL: query depth limit, query cost analysis, introspection off in production
