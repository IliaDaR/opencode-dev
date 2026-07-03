---
name: testing
description: Use when writing tests, designing test strategies, choosing between test types, or improving test coverage. Covers unit, integration, e2e, and property-based testing patterns.
---

# Testing

## Test Pyramid

```
       ╱ E2E ╲          Few: critical user journeys
      ╱────────╲
     ╱Integration╲      Some: service boundaries, DB, APIs
    ╱──────────────╲
   ╱   Unit Tests   ╲   Many: pure logic, utilities, components
  ╱──────────────────╲
```

Don't invert the pyramid. If you have more E2E tests than unit tests, you have a problem.

## Test Types

### Unit Tests
- Test one unit (function, class, component) in isolation
- Fast (< 5ms each), no I/O, no network
- 70% of your tests should be unit tests

### Integration Tests
- Test how units work together (DB queries, API handlers, service composition)
- Require real or emulated infrastructure
- 20% of your tests

### E2E Tests
- Test complete user flows through the full stack
- Slow, flaky, expensive to maintain
- 10% of your tests — only the most critical paths

## What to Test

### Always Test
- Business logic (calculations, validation, state transitions)
- API contracts (given X input → expect Y output + Z side effects)
- Error handling (what happens when the database is down?)
- Edge cases (empty input, max values, null, concurrent access)
- Security-critical paths (auth, authorization, input sanitization)

### Never Test
- Framework internals (React renders components — don't test that)
- Library code (don't test that lodash's map works)
- Trivial getters/setters (no logic = nothing to test)
- Implementation details (test behavior, not private methods)

## Writing Good Tests

### AAA Pattern
```typescript
test("transfers money between accounts", () => {
  // Arrange: set up the test state
  const from = new Account({ balance: 100 })
  const to = new Account({ balance: 0 })

  // Act: do the thing
  transfer(from, to, 50)

  // Assert: check the outcome
  expect(from.balance).toBe(50)
  expect(to.balance).toBe(50)
})
```

### One Assertion Concept Per Test
```typescript
// Bad: testing multiple things
test("transfer", () => {
  transfer(from, to, 50)
  expect(from.balance).toBe(50)
  expect(to.balance).toBe(50)
  expect(ledger.entries).toHaveLength(1)
  expect(notification.sent).toBe(true)
})

// Good: focused tests
test("deducts from source account", () => {
  transfer(from, to, 50)
  expect(from.balance).toBe(50)
})

test("credits destination account", () => {
  transfer(from, to, 50)
  expect(to.balance).toBe(50)
})
```

### Descriptive Names
```typescript
// Bad
test("test1", ...)
test("transfer works", ...)

// Good: "it [behavior] when [condition]"
test("throws when source account has insufficient funds", ...)
test("returns cached result on second call with same key", ...)
test("emits OrderCreated event after successful checkout", ...)
```

## Tests Per Technology

### Database Tests
```typescript
// Use a test database, not mocks
beforeEach(async () => {
  await db.migrate.latest()
  await db.seed.run()
})

afterEach(async () => {
  await db.rollback()  // Or truncate
})

test("finds user by email", async () => {
  await db.insert(users).values({ email: "alice@test.com" })
  const result = await findUserByEmail("alice@test.com")
  expect(result).not.toBeNull()
})
```

### API Tests
```typescript
test("POST /users returns 201 with valid data", async () => {
  const response = await request(app)
    .post("/users")
    .send({ email: "alice@test.com", name: "Alice" })
    .expect(201)

  expect(response.body).toMatchObject({
    id: expect.any(String),
    email: "alice@test.com",
  })
})

test("POST /users returns 422 with invalid email", async () => {
  const response = await request(app)
    .post("/users")
    .send({ email: "notanemail", name: "Alice" })
    .expect(422)

  expect(response.body.error.code).toBe("VALIDATION_ERROR")
})
```

### Async Tests
```typescript
// Always await or return the promise
test("async operation", async () => {
  const result = await fetchData()
  expect(result).toBeDefined()
})

// Or return the promise (test runner handles it)
test("async operation", () => {
  return fetchData().then(result => {
    expect(result).toBeDefined()
  })
})

// DON'T: test ends before promise resolves
test("async operation", () => {
  fetchData().then(result => {
    expect(result).toBeDefined()  // Never runs if test already ended
  })
})
```

### Property-Based Testing
```typescript
// Instead of hand-picking test values, generate them
test("serialize -> deserialize returns original value", () => {
  fc.assert(
    fc.property(fc.record({
      name: fc.string(),
      age: fc.integer({ min: 0, max: 150 }),
      email: fc.string().map(s => `${s}@example.com`),
    }), (input) => {
      const deserialized = deserialize(serialize(input))
      expect(deserialized).toEqual(input)
    })
  )
})
// Finds edge cases you wouldn't think of: empty strings, unicode, huge numbers
```

## Test Doubles

### Prefer Real Over Fake
1. Use the real thing when it's fast and deterministic
2. Use a test implementation (in-memory DB, fake filesystem) before mocking
3. Mock only when the real thing is slow, flaky, or external

### Stub vs Mock
```typescript
// Stub: returns canned answer (state verification)
const paymentStub = { charge: () => ({ status: "ok" }) }

// Mock: records calls (behavior verification)
const paymentMock = {
  charge: jest.fn().mockReturnValue({ status: "ok" })
}
// Then: expect(paymentMock.charge).toHaveBeenCalledWith(amount)
```

## Flaky Tests

A test that sometimes passes and sometimes fails without code changes IS BROKEN. Fix it immediately.

Common causes:
- Shared mutable state between tests (run in isolation!)
- Time-dependent assertions (use fake timers!)
- Random data without seed (use fixed seed!)
- Race conditions in async code (use proper awaits!)
- Test order dependency (tests must be independent!)

## Coverage

Coverage is a metric, not a goal. 100% coverage of trash code is still trash.

Targets:
- Critical business logic: 90%+
- UI components: 70%+
- Config/glue code: low coverage is fine

Don't write tests just to hit a coverage number. Write tests for confidence.
