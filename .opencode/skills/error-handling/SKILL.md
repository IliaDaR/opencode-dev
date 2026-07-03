---
name: error-handling
description: Use when designing error handling strategies, reviewing error paths, implementing retry logic, or creating custom error types. Covers error propagation, logging, and user-facing error patterns.
---

# Error Handling

## Core Principles

### Fail Fast, Fail Explicitly
The worst error is a silent one. If something is wrong, throw immediately close to the source. Don't return null, don't return a default, don't log and continue with bad state.

### Errors Are for Programmers, Messages Are for Users
```typescript
// The Error type: for code to handle
class PaymentFailedError extends Error {
  constructor(
    public readonly paymentId: string,
    public readonly reason: "insufficient_funds" | "network_error" | "fraud_block"
  ) {
    super(`Payment ${paymentId} failed: ${reason}`)
  }
}

// The user message: for display
function getUserMessage(error: PaymentFailedError): string {
  switch (error.reason) {
    case "insufficient_funds": return "Your card was declined. Try another card."
    case "network_error": return "Payment processor unavailable. Please try again."
    case "fraud_block": return "Transaction blocked. Contact your bank."
  }
}
```

## Error Type Hierarchy

```
Error
├── ValidationError — bad input from user
├── NotFoundError — resource doesn't exist
├── UnauthorizedError — not logged in
├── ForbiddenError — logged in but not allowed
├── ConflictError — duplicate, stale version
├── RateLimitError — too many requests
├── ServiceUnavailableError — downstream down
└── InternalError — our bug (never expose details to client)
```

### Error Properties Every Error Should Have
```typescript
class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,           // Machine-readable: "VALIDATION_ERROR"
    public readonly statusCode: number,     // HTTP status
    public readonly details?: unknown,      // Structured error details
    public readonly cause?: Error           // Original error (for debugging)
  ) {
    super(message)
    this.name = this.constructor.name
  }
}
```

## Handling Patterns

### Never Swallow Errors
```python
# Bad: empty except
try:
    process()
except:
    pass  # WHAT HAPPENED? Nobody knows.

# Good: catch what you expect
try:
    process()
except TransientError as e:
    logger.warning("Transient error, retrying", extra={"error": str(e)})
    retry()
# Other errors propagate up — they need attention

# If you truly must catch all:
except Exception as e:
    logger.exception("Unexpected error in process()")  # Log full traceback
    raise  # Re-raise unless you have a recovery strategy
```

### Retry with Backoff
```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  options: { maxRetries: number; baseDelayMs: number }
): Promise<T> {
  for (let attempt = 0; attempt <= options.maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      if (attempt === options.maxRetries) throw error
      if (!isTransient(error)) throw error  // Don't retry permanent errors

      const delay = options.baseDelayMs * 2 ** attempt  // Exponential backoff
      const jitter = delay * (0.5 + Math.random() * 0.5) // Add jitter
      await sleep(jitter)
    }
  }
  throw new Error("Unreachable")
}

function isTransient(error: unknown): boolean {
  return error instanceof NetworkError || error.statusCode === 429
}
```

### Graceful Degradation
```typescript
async function getUserProfile(userId: string): Promise<UserProfile> {
  const [user, posts, activity] = await Promise.allSettled([
    fetchUser(userId),
    fetchPosts(userId),
    fetchActivity(userId),
  ])

  return {
    user: unwrapOrThrow(user),           // Core data — must succeed
    posts: unwrapOr(posts, []),          // Nice to have — empty list if fails
    activity: unwrapOr(activity, null),  // Optional — null if fails
  }
}
```

### Context Propagation
```typescript
// Every layer adds context
async function checkout(cart: Cart) {
  try {
    const payment = await processPayment(cart.total)
    return await createOrder(cart, payment)
  } catch (error) {
    throw new CheckoutError("Checkout failed", {
      cartId: cart.id,
      userId: cart.userId,
      cause: error
    })
  }
}
// Result: "Checkout failed: PaymentFailedError: Insufficient funds"
// The context chain tells you exactly what went wrong where
```

## Logging Errors

### What to Log
- **Error**: What failed (message + code)
- **Context**: Request ID, user ID, relevant IDs
- **Stack**: For debugging (not in production for security? Actually yes — obfuscate secrets)
- **Severity**: ERROR for our bugs, WARNING for client errors, INFO for expected failures

### What NOT to Log
- Passwords, tokens, secrets (even in error messages)
- Full request bodies (may contain PII, credit cards)
- Stack traces to the client (HTTP 500 response)

## API Error Responses

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contained invalid parameters",
    "details": [
      {
        "field": "email",
        "issue": "invalid_format",
        "received": "notanemail"
      }
    ],
    "request_id": "req_K8x9L2mN"
  }
}
```

Key properties:
- `code`: Stable machine-readable identifier (don't change it, clients depend on it)
- `message`: Human-readable, can change, may be localized
- `details`: Structured, machine-readable error data
- `request_id`: Correlates client error with server logs

## Assertions and Invariants

```typescript
// Document assumptions with assertions
function transfer(from: Account, to: Account, amount: number) {
  console.assert(amount > 0, "Amount must be positive")
  console.assert(from.id !== to.id, "Cannot transfer to same account")
  console.assert(from.balance >= amount, "Insufficient funds")
  // If any assertion fails → this is a bug, not a runtime error
}

// For runtime validation:
function transfer(from: Account, to: Account, amount: number) {
  if (amount <= 0) throw new ValidationError("Amount must be positive")
  if (from.id === to.id) throw new ValidationError("Cannot transfer to same account")
}
```

## Anti-Patterns

- **Throwing strings**: `throw "error"` — no stack trace, no type discrimination
- **Returning error codes**: `return { ok: false, error: "bad" }` — use exceptions for exceptional cases
- **Promise.all without catching**: one failure aborts all, no partial results
- **Catching and wrapping without cause**: `throw new Error("failed")` — loses original error
- **Logging and throwing**: `catch(e) { log(e); throw e }` — let the top-level handler log once
- **Error messages that don't help**: "An error occurred" — say what, where, why
- **Checking `error.message`**: fragile, messages change — use error codes/types
