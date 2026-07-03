---
name: component-arch
description: Use when designing UI component architecture, choosing between component patterns, planning component libraries, or making decisions about state placement, composition, and reusability in React/Vue/Solid.
---

# Component Architecture

## The Hierarchy Rule

Components should form a tree where data flows down and events bubble up. Every component has exactly one responsibility. If you can't describe what a component does in 5 words, split it.

## Component Categories

### Presentational (Dumb) Components
- Receive data via props, render UI
- No side effects, no API calls, no context access beyond theme
- Easy to test, easy to reuse, easy to storybook
- Should be 80% of your components

### Container (Smart) Components
- Fetch data, manage state, handle side effects
- Compose presentational components
- One per feature/route typically
- Should be 15% of your components

### Layout Components
- Handle positioning: `<Sidebar>`, `<Stack>`, `<Grid>`
- Do not fetch data, do not contain business logic
- Should be 5% of your components

## Prop Design

### The 3-Prop Rule
A component with > 3 required props is doing too much. Split it or group related props.

```tsx
// Bad: too many props
<UserCard name email avatarUrl companyName companyRole joinDate status />

// Good: grouped logically
<UserCard user={user} company={company} status={status} />
```

### Props vs Composition
```tsx
// Props for DATA, children for LAYOUT
// Bad: prop-driven layout
<Card title="Hello" body="Content" footer={<Button />} />

// Good: composition
<Card>
  <Card.Title>Hello</Card.Title>
  <Card.Body>Content</Card.Body>
  <Card.Footer><Button /></Card.Footer>
</Card>
```

### Prop Types (TypeScript)
```tsx
// Prefer discriminated unions over optional props
type ButtonProps =
  | { variant: "primary"; size?: "sm" | "md" }
  | { variant: "link"; href: string }
  | { variant: "icon"; icon: ReactNode; label: string }

// Not: variant?: "primary" | "link"; href?: string; icon?: ReactNode;
```

## State Placement

### "Lift state to the nearest common ancestor"
1. Is this state used by only this component? → useState here
2. Is this state used by this component AND its children? → useState here, pass down
3. Is this state used by sibling components? → Lift to parent
4. Is this state used across unrelated trees? → Context or state manager
5. Is this state server cache? → React Query / SWR, not store

### State Categories
| Type | Tool | Example |
|------|------|---------|
| Server cache | React Query, SWR | User list, settings |
| URL state | Router params | Current page, filters |
| UI state | useState, useReducer | Modal open, tab selected |
| Form state | React Hook Form, Formik | Input values, validation |
| Global app state | Zustand, Jotai | Auth, theme, locale |

## Composition Patterns

### Compound Components
```tsx
// Group related components that work together
<Tabs value={tab} onChange={setTab}>
  <Tabs.List>
    <Tabs.Trigger value="tab1">First</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="tab1">Content</Tabs.Panel>
</Tabs>
```

### Render Props (when hooks won't work)
```tsx
<DataFetcher url="/api/users">
  {({ data, loading, error }) => (
    loading ? <Skeleton /> : <UserList users={data} />
  )}
</DataFetcher>
```

### Slots (Vue/Angular pattern for React)
```tsx
<List items={users}>
  <List.Header>Users</List.Header>
  <List.Empty>No users found</List.Empty>
</List>
```

## File Structure

```
components/
├── Button/
│   ├── Button.tsx
│   ├── Button.test.tsx
│   ├── Button.stories.tsx
│   └── index.ts
├── UserCard/
│   ├── UserCard.tsx
│   ├── UserCardSkeleton.tsx
│   └── index.ts
```

Each component in its own folder. Colocate tests and stories. Barrel export from `index.ts`.

## Reusability Checklist

Before extracting a reusable component:
1. Is it used in 3+ places? (2 is coincidence, 3 is pattern)
2. Are the use cases truly similar? (same behavior, not just same visuals)
3. Is the abstraction cost worth it? (more props = harder to understand)
4. Can you name it without "General" or "Common"? (bad names = bad abstraction)

## Anti-Patterns

- **Prop drilling > 3 levels**: Use context or composition
- **Context for everything**: Context triggers re-render of all consumers
- **useEffect for derived state**: `const fullName = firstName + lastName` not `useEffect(() => setFullName(firstName + lastName))`
- **Controlled + uncontrolled mixing**: Pick one per component instance
- **Huge component files**: > 200 lines = split
- **Inline styles everywhere**: Use CSS modules, Tailwind, or styled-components
