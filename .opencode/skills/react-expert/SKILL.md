---
name: react-expert
description: Use when building React applications, designing components, managing state, handling performance, or debugging React-specific issues. Covers React 18/19 patterns, hooks, and architecture.
---

# React Expert

## Mental Model

React re-renders when state changes. A re-render runs the component function and React diffs the output. Your job is to control WHEN re-renders happen and WHAT runs inside them.

## Component Design

### One Responsibility Per Component
```tsx
// Bad: component does data fetching AND rendering
function UserPage({ userId }) {
  const [user, setUser] = useState(null)
  useEffect(() => { fetchUser(userId).then(setUser) }, [userId])
  if (!user) return <Spinner />
  return <div>{user.name}</div>
}

// Good: separate concerns
function UserPage({ userId }) {
  return (
    <UserFetcher userId={userId}>
      {user => <UserProfile user={user} />}
    </UserFetcher>
  )
}
// Or with a data-fetching library:
function UserPage({ userId }) {
  const { data: user, isLoading } = useQuery(["user", userId], () => fetchUser(userId))
  if (isLoading) return <Spinner />
  return <UserProfile user={user} />
}
```

### Props: Data Down, Events Up
```tsx
// Parent owns state, passes it down
function Parent() {
  const [count, setCount] = useState(0)
  return <Child count={count} onIncrement={() => setCount(c => c + 1)} />
}

// Child is pure render
function Child({ count, onIncrement }: { count: number; onIncrement: () => void }) {
  return <button onClick={onIncrement}>Count: {count}</button>
}
```

## Hooks

### useState
```tsx
// Functional update when new state depends on old
setCount(c => c + 1)  // Safe
setCount(count + 1)   // Unsafe if queued

// Lazy initializer for expensive initial state
const [data] = useState(() => parseLargeJSON(raw))  // Runs once
const [data] = useState(parseLargeJSON(raw))          // Runs every render!
```

### useEffect
```tsx
// Every useEffect should have a cleanup IF it creates a subscription
useEffect(() => {
  const sub = api.subscribe(topic)
  return () => sub.unsubscribe()  // CRITICAL
}, [topic])

// Don't use useEffect for derived state
// Bad:
useEffect(() => setFullName(first + " " + last), [first, last])
// Good:
const fullName = first + " " + last  // Just compute it
```

### useMemo / useCallback
```tsx
// Use for expensive computations or referential stability
const sorted = useMemo(() => data.sort(expensiveCompare), [data])

// useCallback is useMemo for functions
const handleClick = useCallback(() => {
  doSomething(id)
}, [id])

// Don't memoize cheap operations — the memoization itself has a cost
const doubled = useMemo(() => count * 2, [count])  // Overkill
const doubled = count * 2  // Just right
```

### useRef
```tsx
// For mutable values that don't trigger re-render
const countRef = useRef(0)
countRef.current++  // Doesn't re-render

// For DOM access
const inputRef = useRef<HTMLInputElement>(null)
useEffect(() => { inputRef.current?.focus() }, [])
```

### Custom Hooks
```tsx
// Extract reusable logic, not just reusable UI
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(id)
  }, [value, delay])
  return debounced
}

// Naming convention: always start with "use"
```

## Data Fetching

### Use a Library (React Query / SWR)
```tsx
// Don't write this:
const [data, setData] = useState(null)
const [loading, setLoading] = useState(true)
useEffect(() => {
  fetch("/api/users").then(r => r.json()).then(d => {
    setData(d)
    setLoading(false)
  })
}, [])

// Use this instead:
const { data, isLoading, error } = useQuery({
  queryKey: ["users"],
  queryFn: () => fetch("/api/users").then(r => r.json()),
  staleTime: 5 * 60 * 1000,  // 5 min cache
})
```

### Server State vs Client State
- **Server state** (user list, settings): React Query — it handles caching, refetching, optimistic updates
- **Client state** (modal open, form draft): useState / useReducer

## Performance

### React.memo
```tsx
// Only re-render if props changed (shallow comparison)
const ExpensiveChild = React.memo(function ExpensiveChild({ data }) {
  return <HeavyComponent data={data} />
})

// Custom comparison:
const Child = React.memo(Component, (prev, next) => prev.id === next.id)
```

### List Keys
```tsx
// NEVER use index as key (causes bugs with reordering/deletion)
items.map(item => <Item key={item.id} {...item} />)  // Good: stable ID
items.map((item, i) => <Item key={i} {...item} />)   // Bad: index key

// Only exception: static lists that never reorder
```

## Forms

```tsx
// Controlled: React owns the value
function Controlled() {
  const [value, setValue] = useState("")
  return <input value={value} onChange={e => setValue(e.target.value)} />
}

// Uncontrolled: DOM owns the value (use ref + FormData for submission)
function Uncontrolled() {
  const ref = useRef<HTMLInputElement>(null)
  const submit = () => console.log(ref.current?.value)
  return <input ref={ref} defaultValue="hello" />
}

// For complex forms: use React Hook Form or Formik
```

## Anti-Patterns

- **useEffect for initialization**: `useEffect(() => { init() }, [])` — if it's truly init, do it outside React or in a parent
- **Context for frequent updates**: triggers re-render of ALL consumers — use Zustand for high-frequency state
- **Huge component trees without memo**: one state change re-renders everything
- **Derived state in useEffect**: compute it, don't setState
- **Missing keys in lists**: causes identity confusion and bugs
- **Mixing controlled/uncontrolled**: input goes from uncontrolled to controlled → React throws
- **State that should be URL**: filters, pagination, tabs → put in URL, not useState
