---
name: api-design
description: Use when designing REST APIs, GraphQL schemas, RPC interfaces, or SDK surfaces. Use for API reviews, endpoint design, versioning strategy, or when defining request/response contracts.
---

# API Design

## REST API Design Rules

### Resource Naming
- Use plural nouns: `/users`, `/orders`, not `/user`, `/getOrder`
- Use kebab-case for multi-word: `/shipping-addresses`
- Nest for ownership: `/users/42/orders` (only if orders don't exist independently)
- Flat for independent resources: `/orders?user_id=42`
- No verbs in URLs: `POST /orders` creates, `DELETE /orders/42` deletes

### HTTP Methods
| Method | Meaning | Idempotent |
|--------|---------|------------|
| GET | Read | Yes |
| POST | Create | No |
| PUT | Full replace | Yes |
| PATCH | Partial update | No |
| DELETE | Remove | Yes |

### Status Codes
- `200` — success with body
- `201` — resource created (return Location header + body)
- `204` — success, no body (DELETE)
- `400` — client error (validation)
- `401` — not authenticated
- `403` — authenticated but not authorized
- `404` — resource not found
- `409` — conflict (duplicate, stale version)
- `422` — unprocessable (semantic validation failure)
- `429` — rate limited
- `500` — server error (never expose stack traces)

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [
      {"field": "email", "issue": "invalid_format", "value": "notanemail"}
    ],
    "request_id": "req_abc123"
  }
}
```

Always return the same error shape. Never return `200` with `{"success": false}`.

### Pagination
```json
{
  "data": [...],
  "pagination": {
    "cursor": "opaque_cursor_string",
    "has_more": true,
    "total": 1542
  }
}
```
Prefer cursor-based over offset-based. Offset pagination breaks when rows are inserted/deleted during paging.

### Versioning
- URL prefix: `/v1/users` — explicit, easy to route
- Header: `Accept: application/vnd.api+json;version=1` — cleaner URLs, harder to explore
- Never use query params for versioning: `/users?version=1`
- Maintain old versions until all clients migrate
- Deprecation header: `Sunset: Sat, 31 Dec 2026 23:59:59 GMT`

### Filtering & Sorting
```
GET /users?status=active&role=admin&sort=-created_at&limit=50
```
- `sort=-field` for descending, `sort=field` for ascending
- Return a `Link` header or cursor for next page
- Validate filter fields against allowed set (don't expose internal columns)

## GraphQL Specific

### Naming
- Types: PascalCase (`User`, `OrderItem`)
- Fields: camelCase (`createdAt`, `shippingAddress`)
- Enums: UPPER_SNAKE_CASE (`ORDER_STATUS_PENDING`)
- Mutations: verb + noun (`createOrder`, `cancelSubscription`)

### Schema Design
- Keep queries narrow: expose only what clients need
- Use connections for lists (Relay spec): `edges { node { ... } }` with cursors
- Mutations: input object, output payload type
- No nested mutations: `mutation { order { create(...) } }` — bad
- Errors as part of payload, not GraphQL errors:
```graphql
type CreateOrderPayload {
  order: Order
  errors: [UserError!]!
}
```

### Performance
- Set max depth limits (default 5-7)
- Set query complexity scoring
- Field-level dataloader for N+1 prevention
- Never expose unbounded lists without pagination

## SDK / Library Design

### Entry Point
- One import entry: `import { init } from "my-sdk"`
- Configuration object, not positional args
- Lazy initialization (don't connect on import)

### Error Surface
- Custom error classes: `class ApiError extends Error`
- Include: status code, request ID, retry-after hint
- Don't wrap errors in errors in errors

### Typing
- TypeScript: export types, not interfaces
- Generic for response types: `client.get<User>("/users/42")`
- Narrow return types per endpoint, not one big union

## Anti-Patterns

- **GET with body**: violates HTTP spec, breaks caching
- **200 OK with error in body**: breaks HTTP error handling
- **POST for everything**: PUT and DELETE exist for a reason
- **REST for everything**: gRPC for service-to-service, WebSocket for real-time
- **Deep nesting**: `/users/42/orders/7/items/3/notes/1` — use flat endpoints with filters
- **Unbounded collections**: never `GET /users` without pagination
