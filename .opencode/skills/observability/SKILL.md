---
name: observability
description: Use when setting up logging, metrics, tracing, alerting, or debugging production issues through observability data.
---

# Observability

## The Three Pillars

| Pillar | Question | Tool |
|--------|----------|------|
| **Logs** | What happened? | Structured logger (pino, winston, structlog) |
| **Metrics** | How many? How fast? | Prometheus, Datadog, CloudWatch |
| **Traces** | Where did it happen? | OpenTelemetry, Jaeger, Zipkin |

Logs + Metrics + Traces together = you can answer any question about your system.

## Structured Logging

### Always Structured, Never String Interpolation
```python
# Bad: unsearchable, unparseable
logger.info(f"User {user_id} created order {order_id} for ${total}")

# Good: structured fields
logger.info("order_created", extra={
    "user_id": user_id,
    "order_id": order_id,
    "total": total,
    "items": len(items),
})
```

### Log Levels — When to Use
```
FATAL — System is dead, manual intervention required
ERROR — Something failed that needs attention NOW
WARN  — Something unexpected but system can handle it (retry, fallback)
INFO  — Important business events (order placed, user registered, deployment)
DEBUG — Detailed info for debugging (request params, query results)
TRACE — Extremely detailed (every function call, every loop iteration)
```

### What to Log on Every Request
```json
{
  "level": "info",
  "message": "request_completed",
  "method": "POST",
  "path": "/api/orders",
  "status_code": 201,
  "duration_ms": 142,
  "user_id": "usr_abc123",
  "request_id": "req_K8x9L2mN",
  "user_agent": "Mozilla/5.0...",
  "ip": "203.0.113.42"
}
```

### What NEVER to Log
- Passwords, tokens, API keys
- Credit card numbers
- Personal data (GDPR): names, emails, addresses — unless you have a lawful basis
- Full request/response bodies without redaction

## Metrics

### The Four Golden Signals
1. **Latency**: How long does it take? (p50, p95, p99)
2. **Traffic**: How many requests? (req/s)
3. **Errors**: What fraction fail? (error rate %)
4. **Saturation**: How full is the system? (CPU, memory, connections, queue depth)

### RED Method (for Services)
- **Rate**: Requests per second
- **Errors**: Failed requests per second
- **Duration**: Latency distribution

### USE Method (for Resources)
- **Utilization**: % of resource used
- **Saturation**: Queue depth, backlog
- **Errors**: Failed operations

### Metric Names
```
<namespace>_<metric>_<unit>

http_requests_total           # Counter: only goes up
http_request_duration_seconds  # Histogram: distribution
active_connections             # Gauge: current value
db_pool_available             # Gauge: current value
```

## Distributed Tracing

### How It Works
```
Request ID: req_123
├── Span: GET /api/orders  (200ms)
│   ├── Span: auth.check_token  (5ms)
│   ├── Span: db.query_orders  (150ms)
│   │   └── Span: postgres.execute  (148ms)
│   └── Span: cache.set  (2ms)
└── Total: 200ms
```

### Implementation
```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

async def create_order(request):
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("user_id", request.user_id)
        span.set_attribute("items_count", len(request.items))

        with tracer.start_as_current_span("validate_items"):
            validate(request.items)

        with tracer.start_as_current_span("calculate_total"):
            total = calculate(request.items)

        with tracer.start_as_current_span("save_order"):
            order = await db.save(request)

        return order
```

## Alerting

### Alert on Symptoms, Not Causes
```
Bad:  Alert when CPU > 90%           (cause — users don't care)
Good: Alert when p95 latency > 2s    (symptom — users experience slowness)
Bad:  Alert when disk is full        (cause)
Good: Alert when writes failing      (symptom)
```

### Alert Design Checklist
- [ ] Does it require immediate human action? (If not → dashboard, not alert)
- [ ] Is the threshold meaningful? (tested against real data)
- [ ] Is there a runbook? (what does the on-call person DO?)
- [ ] Does it fire during normal operations? (adjust threshold)
- [ ] Can it wait 5 minutes? (add `for: 5m` to avoid flapping)

### No Alert Fatigue
If an alert fires and the response is "oh, that again" → fix the root cause or adjust the threshold. Every alert should surprise you.

## Dashboards

### Home Dashboard
Show the system's health at a glance:
- Top services by error rate
- Overall latency p95
- Request rate
- Key business metrics (orders/min, signups/hour)

### Service Dashboard
Deep dive for one service:
- RED metrics (rate, errors, duration)
- Dependency health (DB connections, cache hit rate)
- Resource saturation (CPU, memory)

### Business Dashboard
Metrics that matter to the business:
- Signups per hour
- Revenue per minute
- Feature adoption %

## Logging Libraries

- **Node.js**: pino (fastest, structured by default)
- **Python**: structlog (structured, composable processors)
- **Go**: zerolog or zap
- **Rust**: tracing (structured, async-aware)

Don't use `console.log` or `print` in production. Ever.
