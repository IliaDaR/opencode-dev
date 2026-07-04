/// Condensed skill knowledge from all 34 desktop OpenCode skills.
/// Injected into the mobile agent's system prompt.
class SkillKnowledge {
  static const String systemDesign = """
## System Design
- Start with data model. Everything flows from it.
- Monolith first, extract services only with concrete reason (scale, team, isolation).
- CAP theorem: choose which constraint to violate.
- Optimize for change: one change = one module.
- Request/Response for sync ops, Event-Driven for async, CQRS for read/write split.
- Database per service only if services scale independently or need different query patterns.
- Anti-patterns: distributed monolith, shared DB as integration point, premature abstraction.
""";

  static const String apiDesign = """
## API Design
- REST: plural nouns (/users), kebab-case, no verbs in URLs.
- HTTP methods semantically: GET read, POST create, PUT replace, PATCH partial, DELETE remove.
- Status codes: 200 ok, 201 created, 400 validation, 401 auth, 403 forbidden, 404 not found, 409 conflict, 429 rate limit, 500 server error.
- Errors: {error:{code,message,details,request_id}}. Never 200 with error body.
- Pagination: cursor-based > offset. Keyset: WHERE created_at > ? AND id > ? ORDER BY LIMIT.
- Version in URL: /v1/users. Sunset header for deprecation.
- GraphQL: PascalCase types, camelCase fields, mutations verb+noun, errors in payload.
""";

  static const String dbDesign = """
## Database Design
- Tables: plural snake_case. Columns: snake_case. FKs: {table}_id.
- Primary keys: UUID v7 or ULID > auto-increment.
- Index every FK and WHERE/JOIN/ORDER BY column.
- Composite index: equality columns first, range last.
- 3NF by default. Denormalize only when read-heavy and value rarely changes.
- Migrations: always reversible, never modify existing, backfill in batches of 1000.
- Dangerous: ADD COLUMN with DEFAULT (table rewrite), changing column type, dropping table.
- EXPLAIN ANALYZE before optimizing. N+1 → JOIN or batch IN query.
""";

  static const String componentArch = """
## Component Architecture
- Presentational (props, no side effects) = 80%. Container (data, state) = 15%. Layout = 5%.
- 3+ required props = split. Props for data, children for layout.
- State: server cache → React Query/SWR. URL state → router. UI → useState. Form → React Hook Form.
- Lift state to nearest common ancestor. Context for rarely-changing values.
- Compound components for related groups. render props when hooks don't work.
- Colocate tests and stories. Barrel export from index.
- Extract reusable only when 3+ identical use cases.
""";

  static const String codeReview = """
## Code Review
- Review order: architecture → correctness → security → performance → error handling → testing → style.
- Look for: off-by-one, null access, race conditions, type coercion, mutable props.
- Security: SQL injection, XSS, secrets in code, missing auth checks, path traversal.
- Performance: N+1 queries, missing indexes, unnecessary re-renders, memory leaks.
- Error handling: empty catch, too-broad catch, no error boundary, internal details to client.
""";

  static const String securityAudit = """
## Security
- Validate ALL input at boundaries (not just UI). Schema validation, not manual checks.
- Passwords: bcrypt/scrypt/argon2 (not SHA/MD5). Salt per password. Rate limit logins.
- JWT: short-lived access (15min) + refresh (7 days). httpOnly, Secure, SameSite=Strict cookies.
- SQL: always parameterized queries. Dynamic table/column names → whitelist.
- Never: eval() with user input, child_process.exec with user input, secrets in code.
- Rate limiting: per-user + per-IP. CORS: explicit origins, never * with credentials.
""";

  static const String performance = """
## Performance
- Measure before optimizing. Profile, find bottleneck, fix, measure again.
- Backend: N+1 → JOIN. Missing index → EXPLAIN ANALYZE. Memory leak → check listeners/caches.
- Cache at outermost layer. Invalidate on write. TTL: short for user data, long for shared.
- Frontend: LCP < 2.5s, INP < 200ms, CLS < 0.1. Lazy load routes. Virtualize long lists.
- React: useMemo for expensive, React.memo for stable props. Debounce rapid events.
- Never: optimize without measurement, non-bottleneck, readable code for micro-optimization.
""";

  static const String errorHandling = """
## Error Handling
- Fail fast, fail explicitly. Errors for programmers, messages for users.
- Error hierarchy: ValidationError, NotFoundError, UnauthorizedError, ForbiddenError, ConflictError, RateLimitError, ServiceUnavailableError, InternalError.
- Retry with exponential backoff + jitter. Only retry transient errors (network, 429).
- Graceful degradation: Promise.allSettled for partial results.
- Every layer adds context. Log: error + request ID + user ID + stack. Never log secrets.
- Never: throw strings, return error codes, catch and wrap without cause, log AND throw.
""";

  static const String typescript = """
## TypeScript
- Discriminated unions over optional props. satisfies for config validation.
- No any, no type assertions (as, !), no @ts-ignore. Use unknown + narrowing.
- Branded types for IDs. Template literal types for event names/routes.
- Prefer type over interface. Use interface only for declaration merging.
- tsconfig: strict, noUncheckedIndexedAccess, noImplicitReturns, isolatedModules.
""";

  static const String react = """
## React / SolidJS
- Server state → React Query/SWR. Client state → useState/useStore. URL state → router.
- Don't useEffect for derived state. Compute it directly.
- React.memo for expensive components. useMemo for expensive computations.
- Stable keys (never array index). useState functional update when depends on prev.
- Cleanup every effect that creates subscription. Don't mix controlled/uncontrolled.
- Huge component trees → virtualize. Context for frequent updates → Zustand.
""";

  static const String nodeBackend = """
## Node.js Backend
- async/await is default. Promise.all for parallel, Promise.allSettled for partial.
- Never block event loop. Heavy CPU → worker thread. Large array → setImmediate batches.
- Express: global error handler last. Fastify: setErrorHandler. Wrap async handlers.
- Stream pipeline for large files. Don't read entire file into memory.
- Production: cluster/PM2, graceful shutdown (SIGTERM), health/readiness endpoints.
- Security: helmet, rate-limit, input validation, never eval/exec with user input.
""";

  static const String python = """
## Python
- Type hints on all signatures. Pydantic for runtime validation. Data classes (frozen).
- Match/case (3.10+) for structural pattern matching.
- Custom exception hierarchy. except SpecificError, not bare except.
- asyncio for I/O. TaskGroup (3.11+) for concurrent. Never mix sync blocking in async.
- pyproject.toml for deps + tools. ruff for linting, mypy for type checking.
- List comprehensions > map/filter. Generators for large data. lru_cache for pure functions.
""";

  static const String sql = """
## SQL
- Never SELECT *. Explicit column list. Parameterized queries always.
- JOIN types: INNER (both), LEFT (all left), LATERAL (per-row subquery).
- Window functions: ROW_NUMBER, LAG/LEAD, SUM OVER.
- CTEs for readability. Indexes: single for exact, composite (equality first, range last).
- UUID for distributed, auto-increment for single-DB. TIMESTAMPTZ always.
- Upsert: INSERT ON CONFLICT DO UPDATE. Cursor pagination: keyset with ORDER BY.
- Batch updates in 1000-row chunks. Soft delete with deleted_at column + view.
""";

  static const String dockerK8s = """
## Docker / K8s
- Multi-stage builds. Specific tags (no :latest). Least privileged user (not root).
- COPY deps first → install → COPY code. Layer caching works.
- K8s: Deployment + Service. Resources: requests (guaranteed) + limits (max).
- Readiness probe (traffic) + liveness probe (restart). ConfigMap + Secret.
- One process per container. Sidecar for helpers. Health checks always.
- Anti-patterns: :latest, root user, npm install instead of ci, no health checks.
""";

  static const String cicd = """
## CI/CD
- Fail fast: lint → typecheck → test → build → deploy.
- Deterministic builds. Lock all versions. Pipeline as code.
- GitHub Actions: concurrency cancel-in-progress. Matrix for parallel tests.
- Cache: setup-node cache, Docker gha cache, custom keyed by lockfile hash.
- Secrets: never in logs, use environment protection rules.
- Deploy: rolling (zero-downtime), blue-green (instant rollback), canary (gradual).
- Monitor after deploy: health, error rate, latency. Auto-rollback on regression.
""";

  static const String gitMastery = """
## Git
- Trunk-based: short branches (<2 days), PR to main, feature flags for WIP.
- Interactive rebase for local cleanup. Never rebase pushed commits.
- Conventional commits: type(scope): message. Types: feat, fix, docs, chore, refactor, test.
- Fix mistakes: amend (--no-edit), reset (--soft/--hard), revert (new commit), reflog (undo).
- Bisect to find bug-introducing commit. Worktrees for parallel branches.
- Never: force push on shared, commit secrets, commit generated files.
""";

  static const String testing = """
## Testing
- Pyramid: 70% unit, 20% integration, 10% E2E.
- AAA: Arrange, Act, Assert. One concept per test. Descriptive names.
- Test behavior, not implementation. Test error paths, not just happy path.
- Database tests: real test DB, migrate + seed, rollback after.
- API tests: request(app).post().expect(status). async: always await/return promise.
- Flaky tests = broken. Fix immediately. Common causes: shared state, time, random, order.
- Coverage is a metric, not a goal. Don't write tests just to hit a number.
""";

  static const String debugging = """
## Debugging
- Reproduce reliably first. Minimal reproduction case.
- Binary search: code, git history (bisect), input data.
- Hypotheses, not guesses. Change one variable at a time.
- Print at boundaries, decision points, error paths. Interactive debugger for complex.
- Common bugs: null/undefined, race conditions, off-by-one, state update timing, reference vs value.
- Walk away after 30+ min on same hypothesis. Sleep on it.
""";

  static const String refactoring = """
## Refactoring
- Change structure without changing behavior. Write tests first if none exist.
- One small change → test → commit → repeat.
- Extract function: duplicated logic or >50 lines. Inline variable: used once, no clarity.
- Simplify conditional: redundant boolean, double negative, extract complex to named function.
- Replace conditional with polymorphism: switch on type → strategy pattern.
- Never refactor without tests, close to deadline, or code you don't understand.
""";

  static String get all {
    return [
      systemDesign,
      apiDesign,
      dbDesign,
      componentArch,
      codeReview,
      securityAudit,
      performance,
      errorHandling,
      typescript,
      react,
      nodeBackend,
      python,
      sql,
      dockerK8s,
      cicd,
      gitMastery,
      testing,
      debugging,
      refactoring,
    ].join("\n");
  }
}
