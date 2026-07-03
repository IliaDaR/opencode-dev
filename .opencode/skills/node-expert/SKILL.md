---
name: node-expert
description: Use when building Node.js backends, designing API servers, working with streams, handling async patterns, debugging Node performance, or writing CLI tools with Node.
---

# Node.js Expert

## Async Patterns

### async/await Is the Default
```javascript
// Don't nest callbacks. Don't chain .then() unless in a pipeline.

// Good: linear, readable
async function handleRequest(req, res) {
  const user = await authenticate(req)
  const data = await fetchData(user.id)
  const result = await process(data)
  res.json(result)
}

// Good: parallel with Promise.all for independent work
const [user, settings] = await Promise.all([
  fetchUser(id),
  fetchSettings(id),
])

// Good: Promise.allSettled when some can fail
const results = await Promise.allSettled([
  fetchPrimary(),
  fetchSecondary(),
  fetchOptional(),
])
const data = results
  .filter(r => r.status === "fulfilled")
  .map(r => r.value)
```

### Never Block the Event Loop
```javascript
// Bad: synchronous CPU-heavy work blocks all requests
function heavyComputation(data) {
  return data.map(item => complexCryptoHash(item))  // BLOCKS
}

// Good: offload to worker thread
const { Worker } = require("worker_threads")
function heavyComputation(data) {
  return new Promise((resolve, reject) => {
    const worker = new Worker("./hash-worker.js")
    worker.postMessage(data)
    worker.on("message", resolve)
    worker.on("error", reject)
  })
}

// Good: break up work with setImmediate
async function processLargeArray(items) {
  const batchSize = 100
  for (let i = 0; i < items.length; i += batchSize) {
    items.slice(i, i + batchSize).forEach(processItem)
    await new Promise(resolve => setImmediate(resolve))  // Yield to event loop
  }
}
```

## Error Handling

### Express / Fastify
```javascript
// Never trust that your handler won't throw
// Always wrap with error handling

// Express: global error handler (LAST middleware)
app.use((err, req, res, next) => {
  logger.error({ err, reqId: req.id }, "Unhandled error")
  res.status(err.statusCode || 500).json({
    error: { code: err.code || "INTERNAL_ERROR", message: err.message }
  })
})

// Fastify: built-in via setErrorHandler
app.setErrorHandler((error, request, reply) => {
  reply.status(error.statusCode || 500).send({
    error: { code: error.code, message: error.message }
  })
})

// Wrap async route handlers
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next)
```

### Process-Level
```javascript
process.on("uncaughtException", (error) => {
  logger.fatal({ err: error }, "Uncaught exception — shutting down")
  process.exit(1)  // MUST exit — state is corrupted
})

process.on("unhandledRejection", (reason) => {
  logger.error({ err: reason }, "Unhandled rejection")
  // Don't exit — the promise was rejected but the app might still be stable
})
```

## Streams

```javascript
const { pipeline } = require("stream/promises")
const fs = require("fs")
const zlib = require("zlib")

// Pipeline: clean error handling, proper cleanup
await pipeline(
  fs.createReadStream("input.txt"),
  zlib.createGzip(),
  fs.createWriteStream("output.txt.gz"),
)

// Transform stream
const { Transform } = require("stream")
const lineCounter = new Transform({
  transform(chunk, encoding, callback) {
    const lines = chunk.toString().split("\n").length
    this.push(`Lines: ${lines}\n`)
    callback()
  }
})

// NEVER: read entire file into memory if you can stream it
// Bad:  const data = await fs.readFile("bigfile.csv")  — 2GB in memory
// Good: pipeline(fs.createReadStream("bigfile.csv"), process)
```

## Environment & Config

```javascript
// 12-factor app: config from environment
const config = {
  port: parseInt(process.env.PORT) || 3000,
  dbUrl: process.env.DATABASE_URL,
  // Validate required config at startup
}

// Validate required env vars
const required = ["DATABASE_URL", "REDIS_URL"]
for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required env var: ${key}`)
    process.exit(1)
  }
}
```

## Security Essentials

```javascript
// Helmet: set security headers
app.use(helmet())

// Rate limiting
const rateLimit = require("express-rate-limit")
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }))

// Input validation (always!)
app.post("/users", (req, res) => {
  const result = userSchema.safeParse(req.body)
  if (!result.success) return res.status(400).json({ errors: result.error })
  // result.data is typed and validated
})

// Never eval user input
// Never child_process.exec with user input (use execFile)
// Never require() with user-controlled paths
```

## Production Checklist

- [ ] Cluster mode or PM2 for multi-core
- [ ] Graceful shutdown (SIGTERM handler)
- [ ] Health check endpoint (`/health`)
- [ ] Readiness check endpoint (`/ready`)
- [ ] Request ID per request for traceability
- [ ] Response time logging
- [ ] Memory/CPU monitoring
- [ ] Uncaught exception handler
- [ ] No `console.log` — use structured logger (pino, winston)
- [ ] connection pooling for databases and external services
- [ ] Timeouts on all external HTTP calls (never wait forever)
