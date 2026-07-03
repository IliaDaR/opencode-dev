---
name: state-management
description: Use when designing state management for web applications, choosing between state management libraries, or debugging state-related bugs in React/Vue/Solid apps.
---

# State Management

## State Categories

| Category | Examples | Where to Store | Tool |
|----------|----------|---------------|------|
| Server cache | User list, blog posts | Cached, synchronized | React Query, SWR, Apollo |
| URL state | Current page, filters, sort | URL params/search | Router |
| Form state | Input values, validation | Component-local | useState, React Hook Form |
| UI state | Modal open, tab selected | Component tree | useState, Context |
| Global app | Auth, theme, locale | App-wide | Zustand, Context |
| Derived state | Computed from other state | No storage — compute | useMemo, selectors |

## The Golden Rule

**If state can be derived from existing state, don't store it.**

```typescript
// Bad: storing derived state
const [items, setItems] = useState([])
const [itemCount, setItemCount] = useState(0)
useEffect(() => setItemCount(items.length), [items])

// Good: derive it
const [items, setItems] = useState([])
const itemCount = items.length
```

## State by Use Case

### Server State → React Query
```typescript
const { data, isLoading, error } = useQuery({
  queryKey: ["user", userId],
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60 * 1000,
})

// Automatic: caching, refetching, background updates, retry
// No need for: useState, useEffect, loading/error flags, cache invalidation
```

### URL State → Router
```typescript
// Put filters, pagination, search in URL
const [searchParams, setSearchParams] = useSearchParams()
const page = parseInt(searchParams.get("page") || "1")
const filter = searchParams.get("filter") || "all"

// Benefits:
// - Shareable: copy URL and someone sees the same state
// - Browser back/forward works
// - Bookmarkable
```

### Global App State → Zustand
```typescript
import { create } from "zustand"

const useStore = create((set) => ({
  user: null,
  theme: "light",
  login: (user) => set({ user }),
  toggleTheme: () => set((s) => ({ theme: s.theme === "light" ? "dark" : "light" })),
}))

function Component() {
  const user = useStore(s => s.user)  // Only re-renders when user changes
  const login = useStore(s => s.login)
  // ...
}
```

### Server + Client Hybrid
```typescript
// React Query for server data, Zustand for client-only state
function ShoppingCart() {
  const { data: cart } = useQuery({ queryKey: ["cart"] })  // Server
  const couponCode = useStore(s => s.couponCode)            // Client
  const setCouponCode = useStore(s => s.setCouponCode)
  // ...
}
```

## Context vs Store

### Use Context When:
- Value rarely changes (theme, locale, auth user)
- Value is needed by many components at different depths
- You have fewer than 5 consumers

### Use Store (Zustand) When:
- Value changes frequently (form state, canvas state)
- You need fine-grained subscriptions (re-render only on specific field change)
- Context would cause excessive re-renders

## Immutability

```typescript
// Always create new references when updating
// Array: spread, not push/splice
setItems(prev => [...prev, newItem])   // Good
setItems(prev => prev.filter(i => i.id !== id))  // Good

// Object: spread, not direct mutation
setUser(prev => ({ ...prev, name: "New" }))  // Good
prev.name = "New"; setUser(prev)  // BAD: mutation

// Nested: consider normalizing your state
// Instead of: { user: { profile: { name: "Alice" } } }
// Use: { users: { "1": { id: "1", name: "Alice" } } }
```

## State Architecture Anti-Patterns

- **Prop drilling > 3 levels**: use composition, context, or store
- **Lifting state too high**: a modal's open state doesn't need to be in Redux
- **Storing server state in Redux**: use React Query — it handles cache, loading, errors
- **Multiple sources of truth**: same user data in Redux AND React Query AND local state
- **Giant store objects**: every change re-renders everything — split into domains
- **Using Context for high-frequency updates**: every consumer re-renders on every change
- **Synchronous setState in a loop**: each call triggers a re-render in React < 18
