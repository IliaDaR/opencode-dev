---
name: refactoring
description: Use when refactoring code — restructuring without changing behavior. Covers safe refactoring techniques, code smells, and when to refactor vs when to leave it alone.
---

# Refactoring

## Definition
Refactoring: changing the structure of code WITHOUT changing its external behavior. If you're adding a feature while refactoring, you're not refactoring — you're rewriting.

## When to Refactor

### Good Reasons
- Adding a feature is hard because the code is messy → refactor first
- Same logic exists in 3+ places → extract and deduplicate
- A function/method has grown too large to understand at a glance
- Tests are hard to write because of tight coupling
- You're the third person to say "what does this do?"

### Bad Reasons
- "I don't like the style" (different from "it's inconsistent")
- "I would have done it differently" (but it works and is tested)
- "This technology is old" (but maintained and secure)
- Boredom

## Safe Refactoring Process

1. **Ensure tests exist** for the code you're changing. If not, write characterization tests first.
2. **Run tests** — they must all pass before you start.
3. **Make one small change**.
4. **Run tests** — if they fail, fix immediately.
5. **Commit** (small, atomic commits).
6. **Repeat**.

Never refactor without tests. You WILL break something.

## Common Refactorings

### Extract Function
```javascript
// Before: long function doing multiple things
function processOrder(order) {
  // 20 lines of validation
  if (!order.items) throw ...
  if (order.items.length === 0) throw ...
  if (!order.userId) throw ...
  for (const item of order.items) {
    if (item.quantity <= 0) throw ...
  }

  // 10 lines of total calculation
  let total = 0
  for (const item of order.items) {
    total += item.price * item.quantity
  }
  // ... tax, shipping ...
}

// After: extract helpers
function processOrder(order) {
  validateOrder(order)
  const total = calculateTotal(order)
  // ...
}

function validateOrder(order) {
  if (!order.items?.length) throw new ValidationError("Order must have items")
  if (!order.userId) throw new ValidationError("Order must have a user")
  // ...
}
```

### Replace Conditional with Polymorphism
```javascript
// Before: switch on type
function getShippingCost(order) {
  switch (order.type) {
    case "standard": return 5.00
    case "express": return 15.00
    case "overnight": return 30.00
    default: throw new Error("Unknown shipping type")
  }
}

// After: strategy pattern
const shippingStrategies = {
  standard: () => 5.00,
  express: () => 15.00,
  overnight: () => 30.00,
}

function getShippingCost(order) {
  const strategy = shippingStrategies[order.type]
  if (!strategy) throw new Error(`Unknown shipping type: ${order.type}`)
  return strategy()
}
```

### Inline Variable
```javascript
// Before: variable used once, name adds no clarity
const userName = user.name
return `Hello, ${userName}`

// After: inline
return `Hello, ${user.name}`
```

### Simplify Conditional
```javascript
// Before: redundant boolean
if (isValid === true) { ... }

// After:
if (isValid) { ... }

// Before: double negative
if (!isNotAllowed) { ... }

// After:
if (isAllowed) { ... }

// Before: complex boolean expression
if (user.age >= 18 && user.country === "US" && !user.banned) { ... }

// After: extract to named function
function canPurchase(user) {
  return user.age >= 18 && user.country === "US" && !user.banned
}
if (canPurchase(user)) { ... }
```

## Code Smells

| Smell | Refactoring |
|-------|-------------|
| Long function (> 50 lines) | Extract function |
| Long parameter list (> 4) | Introduce parameter object |
| Duplicated code | Extract function/module |
| Feature envy (method uses another class's data more than its own) | Move method |
| Switch statement on type | Replace with polymorphism / strategy |
| Magic number | Replace with named constant |
| Comments explaining WHAT code does | Rename to make code self-documenting |
| Dead code | Delete it |
| Mutable global state | Encapsulate, pass as parameter |
| Shotgun surgery (one change touches many files) | Co-locate related code |

## When NOT to Refactor

- **No tests**: write tests first, then refactor
- **Close to deadline**: refactoring risk > reward
- **Code that will be replaced soon**: don't polish a sinking ship
- **It's a prototype that might be thrown away**: wait until you decide to keep it
- **Performance-critical code without profiling**: you might make it slower
- **You don't understand what it does**: understand first, refactor second

## Refactoring vs Rewriting

Refactoring: small, safe, step-by-step, with tests.
Rewriting: throw it away, start over.

Default to refactoring. Rewriting takes 3x longer than you think and introduces new bugs that the old code had already fixed.

Rewrite only when:
- The technology is fundamentally wrong (PHP → anything else may qualify)
- The code is so tangled that even small changes take days
- The original authors are gone and nobody understands it
- You can run old and new systems in parallel during migration
