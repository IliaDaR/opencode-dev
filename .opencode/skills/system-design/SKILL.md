---
name: system-design
description: Use when designing system architecture, choosing between architectural patterns, planning service boundaries, or evaluating trade-offs in distributed systems. Use for new system design, architecture reviews, or scalability planning.
---

# System Design

## Core Principles

### Start with the data model
Design the data model first. Everything else — APIs, services, databases — flows from what data you need and how it relates. A bad data model forces bad code. Spend 70% of design time on the data model.

### Optimize for change
The only constant is change. Prefer architectures where one change affects exactly one module. Avoid "a small change requires touching 5 services."

### Constraints drive architecture
Real architecture is choosing which constraints to violate. You cannot have consistency, availability, and partition tolerance simultaneously (CAP). You cannot have perfect latency, throughput, and cost. Make explicit which constraint you're relaxing.

## Pattern Selection

### Monolith → Modular Monolith → Services
Never start with microservices. Start with a well-structured monolith. Extract services only when you have a concrete reason: independent scaling, team boundaries, different release cadences, or isolation requirements.

### Request-Driven vs Event-Driven
| Pattern | Use when |
|---------|----------|
| Request/Response (REST/gRPC) | Synchronous operations, immediate consistency required, simple CRUD |
| Event-Driven (pub/sub) | Async operations, eventual consistency acceptable, multiple consumers of same event |
| CQRS | Read and write patterns are fundamentally different, need independent scaling |
| Saga | Distributed transactions across services |

### Database per Service? Ask first:
- Do these services scale independently? → Separate DB
- Do they need different query patterns? → Separate DB
- Are they owned by different teams? → Separate DB
- Otherwise → Shared DB is simpler and often correct

## Decision Framework

For each architectural decision, document:
1. **Context**: What constraints exist (team size, latency budget, consistency requirements)
2. **Options considered**: At least 2 alternatives
3. **Decision**: What you chose and why
4. **Consequences**: What becomes easier, what becomes harder

## Anti-Patterns to Flag

- **Distributed monolith**: Services that must be deployed together — you paid the microservices tax without getting the benefit
- **Shared database as integration point**: Multiple services writing to same tables → schema conflicts
- **Sync calls over async boundaries**: Using HTTP between services that should communicate via events
- **Premature abstraction**: Generic "reusable" service that serves one use case poorly
- **Gratuitous technology diversity**: 3 databases, 4 languages, 2 message brokers for a 5-person team

## When Not to Over-Engineer

- Team < 5 people → monolith
- < 1000 req/s → single database, add read replicas later
- MVP / validating idea → optimize for speed of iteration, not scale
- Internal tool → simplicity over scalability

## Key Questions to Ask

1. What happens when this service is down? (Failure modes, not happy path)
2. How do we deploy this independently? (If you can't → not a separate service)
3. What's the data consistency requirement? Real-time? Minutes? Hours?
4. How does this decision affect on-call? (More services = more things that can break)
5. Can a single developer understand the full request path?
