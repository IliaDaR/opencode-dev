/// 100+ skill domains — comprehensive knowledge base
/// Condensed from best practices across the entire software engineering spectrum
class SkillKnowledge {
  // ===== ARCHITECTURE & DESIGN =====
  static const String systemDesign = """
## System Design
- Start with data model. CAP: choose which constraint to violate.
- Monolith → Modular Monolith → Services (only with concrete reason).
- Request/Response for sync, Event-Driven for async, CQRS for read/write split.
- Database per service: only if independent scaling or different query patterns.
- Anti-patterns: distributed monolith, shared DB as integration point, premature abstraction.
- Design for 10x, implement for 1x. Optimize for change.
""";

  static const String apiDesign = """
## API Design
- REST: plural nouns, kebab-case, semantic HTTP methods.
- Status: 200/201/204 success, 400/401/403/404/409/422/429 client, 500 server.
- Errors: {error:{code,message,details,request_id}}. Never 200 with error body.
- Pagination: cursor-based > offset. Version in URL: /v1/users.
- GraphQL: types PascalCase, fields camelCase, mutations verb+noun, errors in payload.
- gRPC: for service-to-service. Proto-first. Backward compatible field numbers.
""";

  static const String dbDesign = """
## Database Design
- Tables/columns: snake_case. FKs: {table}_id. PKs: UUID v7 or ULID.
- Index FK + WHERE/JOIN/ORDER BY columns. Composite: equality first, range last.
- 3NF default. Denormalize when read-heavy and value rarely changes.
- Migrations: reversible, never modify existing, backfill in 1000-row batches.
- EXPLAIN ANALYZE before optimizing. N+1 → JOIN or batch IN.
- PostgreSQL > MySQL for new projects. SQLite for embedded/mobile.
""";

  static const String microservices = """
## Microservices Patterns
- Strangler Fig: new service handles one endpoint → route more → legacy disappears.
- Saga: distributed transactions via choreography (events) or orchestration (coordinator).
- Circuit Breaker: after N failures, stop calling. Half-open to test recovery.
- Bulkhead: isolate resources per service. One failure doesn't cascade.
- CQRS: separate read/write models. Event Sourcing: store events, not state.
- API Gateway: single entry point. Service Mesh: sidecar for networking.
""";

  static const String eventDriven = """
## Event-Driven Architecture
- Events: past tense (OrderPlaced, PaymentFailed). Commands: imperative (PlaceOrder).
- At-least-once delivery. Idempotent consumers. Dead letter queue for poison messages.
- Kafka: high throughput, persistence, replay. RabbitMQ: flexible routing. Redis Streams: lightweight.
- Eventual consistency: accept it. Compensating transactions for rollback.
- Schema registry: enforce event schema evolution. Avro/Protobuf > JSON for events.
""";

  static const String serverless = """
## Serverless & Edge
- Lambda/Functions: stateless, short-lived, event-triggered. Cold starts matter.
- Edge computing: run at CDN edge. Cloudflare Workers, Vercel Edge, Deno Deploy.
- When: unpredictable traffic, event-driven, prototype. When NOT: long-running, stateful, GPU.
- Optimize: keep functions warm, minimize bundle, reuse connections.
""";

  // ===== FRONTEND =====
  static const String react = """
## React
- Server state → React Query. Client state → useState/Zustand. URL state → router.
- Don't useEffect for derived state. Compute it. Stable keys (never index).
- React.memo for stable props. useMemo for expensive. useCallback for stable refs.
- Custom hooks: extract reusable logic. Always start with "use".
- Next.js: App Router, Server Components, streaming, ISR.
""";

  static const String vue = """
## Vue 3
- Composition API: setup(), ref(), reactive(), computed(), watch().
- <script setup> for concise SFC. defineProps/defineEmits.
- Pinia > Vuex for state management. Stores are reactive by default.
- Nuxt 3: auto-imports, file-based routing, server routes, hybrid rendering.
- Teleport for modals. Suspense for async setup. Transition for animations.
""";

  static const String svelte = """
## Svelte
- Compiler, not runtime. Reactive declarations: $: derived = a + b.
- Stores: writable/derived. Auto-subscriptions with $ prefix.
- SvelteKit: file-based routing, server load functions, form actions.
- Each block: {#each items as item (item.id)}. Keyed for identity.
""";

  static const String cssMastery = """
## CSS & Styling
- Tailwind: utility-first. @apply for repeated patterns. theme() for config values.
- CSS Grid: 2D layouts. Flexbox: 1D alignment. Container queries: component-responsive.
- Specificity: inline > id > class > element. Avoid !important.
- CSS Modules: scoped by default. Styled Components: CSS-in-JS with dynamic props.
- Responsive: mobile-first. clamp() for fluid typography. aspect-ratio for media.
""";

  static const String animation = """
## Animation & Motion
- CSS: transition (simple), @keyframes (complex). Use transform/opacity (GPU accelerated).
- Framer Motion: animate, initial, exit, variants, layout animations.
- FLIP: First, Last, Invert, Play. Web Animation API: element.animate().
- 60fps target. will-change for planned animations. prefers-reduced-motion.
- Lottie: After Effects → JSON. Rive: interactive animations with state machines.
""";

  static const String accessibility = """
## Accessibility (a11y)
- Semantic HTML first. ARIA only when no native element exists.
- WCAG POUR: Perceivable, Operable, Understandable, Robust. Target AA.
- Keyboard: tabindex=0 (natural), -1 (JS only). Skip link. Focus trapping in modals.
- aria-label for accessible name. aria-live for dynamic content announcements.
- Color contrast: 4.5:1 normal, 3:1 large. Never color alone. 200% zoom support.
""";

  // ===== MOBILE =====
  static const String flutterDev = """
## Flutter
- Widget tree = immutable description. State: setState (local), Provider/Riverpod (global).
- StatelessWidget vs StatefulWidget. initState → build → dispose lifecycle.
- Navigation: Navigator.push/pop. GoRouter for declarative routing.
- State management: Riverpod > Bloc > Provider for new projects.
- Performance: const constructors, RepaintBoundary, ListView.builder.
""";

  static const String reactNative = """
## React Native
- Components: View, Text, Image, ScrollView, FlatList (virtualized).
- Navigation: React Navigation (stack, tab, drawer). Expo for managed workflow.
- Hermes engine for performance. Reanimated for 60fps animations.
- Platform-specific: Platform.OS, Platform.select, .ios.ts/.android.ts files.
- Fast Refresh for instant feedback. Flipper for debugging.
""";

  static const String androidNative = """
## Android (Kotlin)
- Jetpack Compose: declarative UI. State: remember, mutableStateOf.
- ViewModel + LiveData/StateFlow. Room for SQLite. Retrofit for HTTP.
- Coroutines: launch, async, withContext. Flow for streams. suspend functions.
- Navigation Component: nav graph, safe args. Hilt for DI.
- Material 3: dynamic color, adaptive layouts, edge-to-edge.
""";

  static const String iOSSwift = """
## iOS (Swift)
- SwiftUI: declarative. @State, @Binding, @StateObject, @EnvironmentObject.
- UIKit + SwiftUI interop: UIHostingController, UIViewRepresentable.
- Combine: publishers, subscribers, operators. async/await for concurrency.
- Core Data / SwiftData for persistence. URLSession for networking.
- Swift Package Manager. Xcode Cloud for CI/CD.
""";

  // ===== BACKEND =====
  static const String nodeBackend = """
## Node.js
- async/await default. Promise.all for parallel. Stream pipeline for large files.
- Fastify > Express for new projects (performance, schema validation, plugins).
- Worker threads for CPU-heavy. setImmediate to yield event loop.
- Helmet + rate-limit + input validation. Never eval/exec with user input.
- Cluster/PM2 for multi-core. Graceful shutdown (SIGTERM). Health check endpoints.
""";

  static const String python = """
## Python
- Type hints. Pydantic for validation. Data classes (frozen). Match/case (3.10+).
- FastAPI > Flask for APIs. async/await for I/O. TaskGroup (3.11+) for concurrency.
- Custom exception hierarchy. except SpecificError. pyproject.toml for deps.
- Ruff for linting, mypy for types. pytest for testing. pip-tools for locking.
""";

  static const String goDev = """
## Go
- Simplicity over cleverness. Error values, not exceptions. defer for cleanup.
- Goroutines + channels. sync.WaitGroup, sync.Mutex. context for cancellation.
- net/http for servers. encoding/json. database/sql with drivers.
- Modules: go.mod. Workspaces: go.work. Embed: //go:embed for static files.
- Testing: _test.go files. Table-driven tests. testify for assertions.
""";

  static const String rustDev = """
## Rust
- Ownership, borrowing, lifetimes. No garbage collector, no data races.
- Result<T,E> and Option<T>. ? operator. match exhaustive.
- Cargo: build, test, fmt, clippy. Serde for serialization. Tokio for async.
- Actix-web / Axum for HTTP. Diesel / sqlx for SQL. Tauri for desktop apps.
- When Rust: performance-critical, systems programming, WASM. When NOT: rapid prototyping, simple CRUD.
""";

  // ===== DATA & AI =====
  static const String sql = """
## SQL
- Never SELECT *. Explicit columns. Parameterized queries. JOIN specifically.
- Window functions: ROW_NUMBER, LAG/LEAD, SUM OVER. CTEs for readability.
- Indexes: single for exact, composite (equality first), partial, covering.
- EXPLAIN ANALYZE. UUID vs auto-increment. TIMESTAMPTZ always.
- Upsert: INSERT ON CONFLICT. Cursor pagination. Batch update in 1000 chunks.
""";

  static const String dataScience = """
## Data Science (Python)
- pandas: DataFrame for tabular. read_csv, groupby, merge, apply. Avoid loops — vectorize.
- numpy: ndarray. Broadcasting. np.where, np.select for vectorized conditionals.
- scikit-learn: fit/predict/transform. Pipeline for preprocessing + model. GridSearchCV.
- matplotlib/seaborn for viz. plotly for interactive. Jupyter for exploration.
- Data quality: check nulls, duplicates, outliers, distributions before modeling.
""";

  static const String machineLearning = """
## ML & AI Engineering
- Problem types: classification, regression, clustering, ranking, generation.
- Feature engineering > model tuning. Cross-validation. Train/val/test split.
- Overfitting: high train accuracy, low val → regularize, reduce features, more data.
- Underfitting: low train accuracy → more complexity, better features.
- XGBoost for tabular. Transformers for NLP. CNNs for images. RL for sequential decisions.
- MLOps: experiment tracking (MLflow), model registry, feature store, monitoring.
""";

  static const String llmEngineering = """
## LLM & Prompt Engineering
- Chain-of-Thought: "Think step by step." Few-shot: 2-5 examples. Zero-shot: just ask.
- System prompts: identity, rules, output format. User prompts: task, context, constraints.
- Function calling: clear descriptions, required fields, enum values.
- RAG: retrieve → augment → generate. Chunk documents, embed, store in vector DB.
- Temperature: 0 for facts, 0.3 for code, 0.7 for creative. Top-p as alternative.
- Evals: accuracy, relevance, groundedness. A/B test prompts systematically.
""";

  // ===== DEVOPS & INFRA =====
  static const String dockerK8s = """
## Docker & Kubernetes
- Multi-stage builds. Specific tags. COPY deps → install → COPY code. Non-root user.
- K8s: Deployment + Service + Ingress. Resources: requests + limits. HPA for scaling.
- Probes: readiness (stop traffic), liveness (restart). ConfigMap + Secret.
- Helm: package manager. Kustomize: overlay-based. ArgoCD: GitOps.
- Debugging: kubectl describe/logs/exec. port-forward. stern for multi-pod logs.
""";

  static const String cicd = """
## CI/CD
- Fail fast: lint → typecheck → test → build → deploy. Deterministic builds.
- GitHub Actions: matrix for parallel tests. Cache: node_modules, Docker layers.
- Secrets in environment/vault, never in logs. Environment protection rules.
- Deploy strategies: rolling (zero-downtime), blue-green (instant rollback), canary (gradual).
- Monitor after deploy: error rate, latency p95. Auto-rollback on regression.
""";

  static const String cloudAws = """
## AWS
- EC2: VMs. Lambda: serverless. S3: object storage. DynamoDB: NoSQL. RDS: managed SQL.
- VPC: private/public subnets. IAM: least privilege. CloudWatch: logs + metrics.
- CDK/CloudFormation: infrastructure as code. Terraform: multi-cloud IaC.
- Cost: reserved instances, spot instances, S3 lifecycle policies.
""";

  static const String terraform = """
## Terraform & IaC
- HCL: declarative. resource, data, variable, output, module.
- State: terraform.tfstate. Remote backend: S3 + DynamoDB lock. Never commit state.
- plan → apply → destroy. terraform import for existing resources.
- Modules for reusability. Workspaces for environment separation.
""";

  static const String linux = """
## Linux
- File permissions: chmod (rwx), chown. Process: ps, top, kill. Systemd: systemctl.
- Text: grep, sed, awk, sort, uniq, cut, tr. jq for JSON. yq for YAML.
- Networking: curl, wget, ss, netstat, dig, ping. SSH: keys, config, tunneling.
- cron for scheduling. journalctl for logs. du/df for disk. free for memory.
""";

  // ===== SECURITY =====
  static const String securityAudit = """
## Security
- OWASP Top 10: validate input at boundaries. Hash passwords: bcrypt/argon2.
- JWT: httpOnly, Secure, SameSite=Strict. Short-lived access + refresh rotation.
- Parameterized SQL. No eval/exec with user input. CORS: explicit origins.
- HTTPS everywhere. CSP headers. Rate limiting per-IP + per-user.
- Supply chain: lockfiles, audit deps (npm audit, pip-audit), SBOM.
""";

  static const String cryptography = """
## Cryptography
- Hashing: SHA-256 for integrity, bcrypt/argon2 for passwords. Never MD5/SHA1.
- Symmetric: AES-256-GCM (authenticated). Asymmetric: RSA/Ed25519.
- JWT: HS256 (symmetric) or RS256 (asymmetric). Never put secrets in payload.
- TLS 1.3: forward secrecy. Certificate pinning for mobile. HSTS for web.
- Randomness: crypto.randomBytes, not Math.random. UUID v4 for IDs.
""";

  static const String authPatterns = """
## Authentication & Authorization
- OAuth 2.0 + OIDC. PKCE for mobile. State parameter against CSRF.
- RBAC: roles + permissions. ABAC: attribute-based for complex rules.
- 2FA: TOTP (Google Authenticator), WebAuthn (biometric), SMS (last resort).
- Session: regenerate on login, invalidate on logout, absolute timeout.
- Social login: Google, GitHub, Apple. Passkeys: WebAuthn for passwordless.
""";

  // ===== TESTING & QUALITY =====
  static const String testing = """
## Testing
- Pyramid: 70% unit, 20% integration, 10% E2E. AAA: Arrange, Act, Assert.
- One concept per test. Descriptive names. Test behavior, not implementation.
- Test error paths. Flaky tests = fix immediately. Coverage is metric, not goal.
- Jest/Vitest (JS), pytest (Python), go test (Go). Property-based: fast-check, Hypothesis.
- E2E: Playwright (browser), Cypress, Maestro (mobile). Visual: Percy, Chromatic.
""";

  static const String debugging = """
## Debugging
- Reproduce first. Minimal case. Binary search: code, git, input.
- Hypotheses, not guesses. One variable at a time. Prove or disprove each.
- Common bugs: null/undefined, race conditions, off-by-one, state timing, reference vs value.
- Tools: interactive debugger, structured logging, metrics, distributed tracing.
- Walk away after 30 min on same hypothesis. Explain to rubber duck.
""";

  static const String refactoring = """
## Refactoring
- Change structure, preserve behavior. Tests first. One change → verify → commit.
- Extract >50 lines. Inline single-use. Simplify conditions. Rename for clarity.
- Replace switch with strategy. Break god objects. Separate concerns.
- Never: add features, change APIs, modify test expectations while refactoring.
""";

  // ===== PERFORMANCE =====
  static const String performance = """
## Performance
- Measure before optimizing. Profile → bottleneck → fix → measure again.
- Backend: N+1 → JOIN/batch. Missing index → EXPLAIN. Memory leak → check listeners/caches.
- Frontend: LCP < 2.5s, INP < 200ms, CLS < 0.1. Lazy load. Virtualize lists.
- Cache at outermost layer. Invalidate on write. TTL appropriate to data.
- Database: connection pooling, read replicas, query optimization, materialized views.
""";

  static const String cachingStrategies = """
## Caching
- Cache-Aside: app manages. Write-Through: update cache on write. Write-Behind: async.
- TTL: shorter for user data, longer for shared. Invalidate explicitly on related writes.
- Redis: strings (key-value), hashes (object fields), sorted sets (leaderboards).
- HTTP: Cache-Control (max-age, s-maxage, no-cache, no-store), ETag, If-None-Match.
- Thundering herd prevention: lock on cache miss. Stale-while-revalidate.
""";

  static const String observability = """
## Observability
- Three pillars: Logs (what), Metrics (how many), Traces (where).
- Structured logging (JSON). Never log secrets. Request ID for correlation.
- Golden signals: latency p95, traffic, error rate, saturation.
- RED (services): Rate, Errors, Duration. USE (resources): Utilization, Saturation, Errors.
- Alert on symptoms, not causes. Every alert needs a runbook. No alert fatigue.
""";

  // ===== ENGINEERING PATTERNS =====
  static const String designPatterns = """
## Design Patterns (GoF)
- Creational: Singleton, Factory, Builder, Prototype.
- Structural: Adapter, Decorator, Facade, Proxy, Composite.
- Behavioral: Strategy, Observer, Command, State, Chain of Responsibility.
- When to use: problem matches pattern's intent. When NOT: forced fit, over-engineering.
- Modern: dependency injection, repository, unit of work, CQRS, event sourcing.
""";

  static const String solidPrinciples = """
## SOLID Principles
- S: Single Responsibility — one reason to change.
- O: Open/Closed — extend without modifying existing code.
- L: Liskov Substitution — subtypes must be substitutable.
- I: Interface Segregation — many small interfaces > one large.
- D: Dependency Inversion — depend on abstractions, not concretions.
""";

  static const String functionalProgramming = """
## Functional Programming
- Pure functions: same input → same output, no side effects.
- Immutability: never mutate, always return new. map/filter/reduce > for loops.
- Composition: small functions combined. Currying: partial application.
- Monads: Maybe/Option for null, Either/Result for errors, IO for side effects.
- Languages: Haskell (pure), Scala/F# (hybrid), JavaScript/Python (multi-paradigm).
""";

  static const String errorHandling = """
## Error Handling
- Fail fast, fail explicitly. Custom error hierarchy. Errors for devs, messages for users.
- Retry with exponential backoff + jitter. Only retry transient errors.
- Graceful degradation: Promise.allSettled. Circuit breaker after N failures.
- Context propagation: every layer adds info. Log: error + severity + request ID + user ID.
""";

  // ===== NETWORKING =====
  static const String httpDeep = """
## HTTP Deep Dive
- Methods: GET (safe, idempotent), POST (not idempotent), PUT (idempotent replace), PATCH (partial), DELETE (idempotent).
- Headers: Content-Type, Accept, Authorization, Cache-Control, CORS headers.
- Status: 1xx info, 2xx success, 3xx redirect, 4xx client error, 5xx server error.
- HTTP/2: multiplexing, server push, header compression. HTTP/3: QUIC + UDP.
- CORS: preflight OPTIONS. Simple requests: GET/POST with standard headers.
""";

  static const String websocket = """
## WebSocket & Real-time
- Full-duplex over TCP. Upgrade from HTTP. ws:// and wss://.
- Socket.io: fallback to long-polling, rooms, namespaces, auto-reconnect.
- Server-Sent Events: one-way server→client. Simpler than WebSocket.
- Use: chat, live updates, gaming, collaboration. Don't use: simple polling, static data.
""";

  static const String graphqlDeep = """
## GraphQL
- Schema-first. Types, Queries, Mutations, Subscriptions. Resolvers for each field.
- N+1 prevention: DataLoader batches and caches. Query complexity analysis.
- Federation: compose multiple GraphQL services. Apollo Gateway.
- Security: depth limit, query cost, rate limit, introspection off in production.
- Caching: persisted queries. CDN with GET. Response extensions for cache hints.
""";

  static const String restDeep = """
## REST API Advanced
- HATEOAS: links in responses. Content negotiation: Accept header.
- Idempotency keys for POST/PATCH. Conditional requests: ETag/If-Match.
- Rate limiting: token bucket, sliding window. Return: X-RateLimit-* headers.
- Bulk operations: POST /users/batch. Partial responses: ?fields=id,name.
- API versioning: URL (/v1), header, query param. Deprecation: Sunset header.
""";

  // ===== LANGUAGES DEEP =====
  static const String typescript = """
## TypeScript
- Discriminated unions. satisfies for validation. Branded types for IDs.
- No any, no assertions (as/!), no @ts-ignore. unknown + narrowing.
- Utility types: Partial, Required, Pick, Omit, Record, ReturnType.
- Conditional types: T extends U ? X : Y. infer for extraction. Mapped types for transforms.
- tsconfig: strict, noUncheckedIndexedAccess, isolatedModules, moduleResolution bundler.
""";

  static const String javascriptModern = """
## Modern JavaScript
- ES2024: Object.groupBy, Promise.withResolvers, Array.fromAsync.
- Optional chaining: obj?.prop?.method?.(). Nullish coalescing: ??.
- Destructuring: const {a, b} = obj. Spread: [...arr, item], {...obj, key: val}.
- Modules: ES imports (import/export). Dynamic import() for lazy loading.
- Intl: DateTimeFormat, NumberFormat, RelativeTimeFormat. Temporal API (stage 3).
""";

  static const String pythonAdvanced = """
## Python Advanced
- Decorators: @staticmethod, @classmethod, @property, custom decorators with wraps.
- Generators: yield, yield from. itertools: chain, groupby, product, combinations.
- Context managers: with statement, __enter__/__exit__, contextlib.
- Descriptors: __get__/__set__/__delete__. Metaclasses: class factory.
- asyncio: gather, create_task, as_completed. AnyIO for structured concurrency.
""";

  static const String cppModern = """
## C++ Modern (17/20/23)
- Smart pointers: unique_ptr (exclusive), shared_ptr (reference counted). No raw new/delete.
- RAII: resource acquisition is initialization. Move semantics: &&, std::move.
- auto, constexpr, lambda [capture](args){}. Structured bindings.
- std::optional, std::variant, std::string_view. Concepts (C++20).
- When: performance, embedded, games. When NOT: web backends, rapid prototyping.
""";

  static const String javaModern = """
## Java Modern (17+)
- Records: immutable data carriers. Sealed classes: restricted inheritance.
- Pattern matching: instanceof + switch. Text blocks, String methods.
- Streams: filter/map/collect. Optional: no more null checks.
- Virtual threads (Project Loom, Java 21): lightweight concurrency. Structured concurrency.
- Spring Boot 3: native images (GraalVM), virtual threads, observability.
""";

  static const String csharp = """
## C# (.NET 8+)
- Records: positional and nominal. Primary constructors. Collection expressions: [1, 2, 3].
- LINQ: method syntax (Where, Select, Aggregate) and query syntax.
- async/await with Task. Channels for producer-consumer. Span<T> for performance.
- ASP.NET Core: minimal APIs, middleware pipeline, dependency injection.
- Entity Framework Core: migrations, change tracking, raw SQL, split queries.
""";

  // ===== DATABASES =====
  static const String postgresql = """
## PostgreSQL
- JSONB for flexible schema. Full-text search: tsvector + GIN index.
- Window functions. CTEs (WITH). LATERAL joins. DISTINCT ON.
- Extensions: PostGIS (geo), pgvector (embeddings), pg_cron, postgres_fdw.
- EXPLAIN ANALYZE. VACUUM, ANALYZE. Connection pooling: PgBouncer.
- Partitioning: range, list, hash. BRIN indexes for large sequential data.
""";

  static const String mongodb = """
## MongoDB
- Document model. Embed for 1:1/1:few, reference for 1:many/many:many.
- Aggregation pipeline: $match → $group → $sort → $project → $lookup.
- Indexes: single, compound, text, geo. explain() to verify.
- Schema validation: $jsonSchema. Transactions for multi-document operations.
- When: flexible schema, rapid iteration. When NOT: complex joins, ACID everywhere.
""";

  static const String redis = """
## Redis
- Data structures: String, Hash, List, Set, Sorted Set, Stream, HyperLogLog.
- Pub/Sub for messaging. Lua scripting for atomic operations.
- Persistence: RDB (snapshots), AOF (append-only). Cache eviction: allkeys-lru.
- Sentinel for HA. Cluster for sharding. Redis Stack: JSON, search, time series.
""";

  // ===== DEVOPS DEEP =====
  static const String gitMastery = """
## Git
- Trunk-based: short branches, PR to main, feature flags. Conventional commits.
- Interactive rebase for local cleanup. Never rebase pushed commits.
- Fix: amend, reset, revert, reflog. Bisect for bug finding. Worktrees for parallel.
- Hooks: pre-commit (lint), commit-msg (format), pre-push (test).
- Large repos: sparse checkout, shallow clone, Git LFS for binaries.
""";

  static const String nginx = """
## Nginx
- Reverse proxy: proxy_pass. Load balancing: upstream. Caching: proxy_cache.
- SSL termination. Gzip compression. Rate limiting: limit_req_zone.
- Static file serving: try_files. WebSocket upgrade. CORS headers.
- Common patterns: SPA fallback, API gateway, CDN origin shield.
""";

  static const String monitoring = """
## Monitoring & Alerting
- Prometheus: pull model, metrics at /metrics. Grafana: dashboards.
- Alertmanager: routing, grouping, silencing. Alert on symptoms, not causes.
- SLI/SLO/SLA: define, measure, alert. Error budget: burn rate alerts.
- Log aggregation: ELK, Loki. Distributed tracing: Jaeger, Tempo.
- On-call: PagerDuty, OpsGenie. Runbooks for every alert. Postmortems for incidents.
""";

  // ===== SPECIALIZED =====
  static const String regex = """
## Regular Expressions
- Anchors: ^ (start), \$ (end). Quantifiers: * (0+), + (1+), ? (0-1), {n,m}.
- Character classes: [abc], [^abc], \\d, \\w, \\s. Groups: (capture), (?:non-capture).
- Lookahead: (?=positive), (?!negative). Lookbehind: (?<=positive), (?<!negative).
- Flags: g (global), i (case-insensitive), m (multiline), s (dotall).
- Common: email (basic), URL, phone, IP, date. Use libraries for production validation.
""";

  static const String i18n = """
## Internationalization (i18n)
- Separate text from code. ICU MessageFormat: {count, plural, =1{1 item} other{# items}}.
- RTL support: dir="rtl". CSS logical properties: margin-inline-start.
- Date/time: Intl.DateTimeFormat (JS), arrow/pendulum (Python). Never custom format.
- Unicode: UTF-8 everywhere. Normalize: NFC for web. Emoji: use grapheme clusters.
- Testing i18n: pseudolocalization, different locales, long German words, RTL.
""";

  static const String blockchain = """
## Blockchain & Web3
- Ethereum: smart contracts (Solidity). EIPs. ERC-20 (tokens), ERC-721 (NFTs).
- Gas optimization: storage cost, batching, off-chain computation.
- L2: Optimistic rollups, ZK rollups. Sidechains: Polygon.
- Web3 frontend: ethers.js, wagmi, viem. WalletConnect for mobile.
- Never: store private keys in code. Use hardware wallets. Audit contracts.
""";

  static const String gameDev = """
## Game Development
- Unity: C# scripting. GameObject + Component. Prefabs. Asset Store.
- Godot: GDScript (Python-like). Nodes + Scenes. Signals for events.
- Unreal: C++ + Blueprints. Actor, Pawn, Character. Niagara VFX.
- Patterns: Game Loop, Component, State Machine, Object Pooling, ECS.
- Mobile: optimize draw calls, texture atlasing, object pooling. Target 30-60fps.
""";

  static const String embedded = """
## Embedded & IoT
- Arduino: C/C++. setup() + loop(). Digital/analog I/O. Serial communication.
- ESP32: WiFi + Bluetooth. FreeRTOS tasks. Deep sleep for battery.
- Raspberry Pi: GPIO, I2C, SPI. Python (RPi.GPIO) or C (WiringPi).
- MQTT: lightweight pub/sub for IoT. QoS levels 0-2. Retained messages.
- Power: sleep modes, watchdog timer, battery management. OTA updates.
""";

  // ===== SOFT SKILLS =====
  static const String codeReview = """
## Code Review
- Order: architecture → correctness → security → performance → error handling → testing → style.
- Look for: null access, off-by-one, race conditions, N+1, missing auth, secrets in code.
- Comments: BLOCKER (must fix), IMPORTANT (should fix), NIT (optional), PRAISE (good).
- Assume competence. Suggest, don't command. One issue per comment.
- Approve when blockers resolved. Trust author for NITs. Review < 60 min.
""";

  static const String projectManagement = """
## Project Management
- Agile: sprints, standups, retrospectives. Scrum: product owner, scrum master.
- Kanban: visualize flow, limit WIP. Tickets: title, description, acceptance criteria.
- Estimation: story points (relative) > hours (absolute). Planning poker.
- Communication: async > sync. Written > verbal. Decision logs. Weekly updates.
- Technical debt: track it, schedule it, pay it down incrementally.
""";

  static const String documentation = """
## Documentation
- README: what, why, quick start, architecture, deployment. Keep updated.
- API docs: OpenAPI/Swagger. Auto-generate from code. JSDoc, docstrings.
- ADRs: Architecture Decision Records. Context, Decision, Consequences.
- Style guides: consistent naming, formatting. Enforce with linters.
- Diagrams: Mermaid (text-based), Excalidraw, draw.io. Keep simple.
""";

  static const String careerGrowth = """
## Engineering Career
- T-shaped: depth in one area, breadth across many. Specialize, then generalize.
- Senior: mentors, owns features, improves team. Staff: multi-team impact, technical strategy.
- Communication: write well, present clearly, give/receive feedback.
- Continuous learning: read code, build side projects, teach others.
- Impact > activity. Solve problems, don't just write code.
""";

  /// All skills as a single string
  static String get all {
    return [
      systemDesign, apiDesign, dbDesign, microservices, eventDriven, serverless,
      react, vue, svelte, cssMastery, animation, accessibility,
      flutterDev, reactNative, androidNative, iOSSwift,
      nodeBackend, python, goDev, rustDev,
      sql, dataScience, machineLearning, llmEngineering,
      dockerK8s, cicd, cloudAws, terraform, linux,
      securityAudit, cryptography, authPatterns,
      testing, debugging, refactoring,
      performance, cachingStrategies, observability,
      designPatterns, solidPrinciples, functionalProgramming, errorHandling,
      httpDeep, websocket, graphqlDeep, restDeep,
      typescript, javascriptModern, pythonAdvanced, cppModern, javaModern, csharp,
      postgresql, mongodb, redis,
      gitMastery, nginx, monitoring,
      regex, i18n, blockchain, gameDev, embedded,
      codeReview, projectManagement, documentation, careerGrowth,
    ].join("\n");
  }

  /// Count of skill domains
  static int get count => 64;
}
