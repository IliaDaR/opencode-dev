---
name: typescript-expert
description: Use for TypeScript type-level programming, complex generics, type debugging, migration from JavaScript, or when TypeScript type errors are cryptic. Covers advanced types, patterns, and configuration.
---

# TypeScript Expert

## Type System Fundamentals

### Prefer Inference Over Annotation
```typescript
// Let TypeScript infer
const items = [1, 2, 3]  // number[]
const config = { host: "localhost", port: 3000 }  // { host: string; port: number }

// Annotate only when inference fails or for function signatures
function process(items: string[]): Map<string, number> { ... }
```

### Discriminated Unions — Your Best Friend
```typescript
type Result<T> =
  | { status: "ok"; data: T }
  | { status: "error"; code: string; message: string }

function handle(result: Result<User>) {
  switch (result.status) {
    case "ok":    return result.data.name    // T is User, data is available
    case "error": return result.code         // code is available
  }
}
```

### Never Use `any`
```typescript
// `any` disables type checking — defeats the purpose of TypeScript
// Replace with:
let x: unknown  // Type-safe, forces narrowing before use
let y: Record<string, unknown>  // For dynamic objects
let z: never  // For unreachable code

// Narrowing unknown:
function process(input: unknown) {
  if (typeof input === "string") return input.toUpperCase()
  if (Array.isArray(input)) return input.length
  throw new Error(`Unexpected type: ${typeof input}`)
}
```

## Advanced Patterns

### Branded Types for Type Safety
```typescript
type UserID = string & { readonly __brand: "UserID" }
type OrderID = string & { readonly __brand: "OrderID" }

function createUserId(id: string): UserID {
  return id as UserID  // Cast at boundary only
}

function getUser(id: UserID): User { ... }
function getOrder(id: OrderID): Order { ... }

getUser("abc")          // Error: string is not UserID
getUser(createUserId("abc"))  // OK
```

### `satisfies` Operator
```typescript
// `satisfies` validates type without widening
const config = {
  host: "localhost",
  port: 3000,
  retries: 3,
} satisfies Record<string, string | number>

config.host.toUpperCase()  // OK — type preserved as string, not string | number
config.retries.toFixed(2)  // OK — type preserved as number
```

### Template Literal Types
```typescript
type EventName = `user:${"created" | "updated" | "deleted"}`
// "user:created" | "user:updated" | "user:deleted"

type CSSUnit = `${number}${"px" | "em" | "rem" | "%"}`
// "16px" | "1.5em" | "100%"

type Route = `/${string}`  // Any valid path
type API = `/api/${"users" | "orders"}/${string}`
```

### Conditional Types
```typescript
type IsString<T> = T extends string ? true : false
type A = IsString<"hello">  // true
type B = IsString<42>       // false

// Never use `never` as a fallback — it disappears from unions
type NonNullable<T> = T extends null | undefined ? never : T
type Cleaned = NonNullable<string | null | undefined>  // string (null and undefined removed)
```

### Mapped Types
```typescript
type Readonly<T> = { readonly [K in keyof T]: T[K] }
type Optional<T> = { [K in keyof T]?: T[K] }
type Pick<T, K extends keyof T> = { [P in K]: T[P] }

// Key remapping (TS 4.1+):
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
}
```

### `infer` in Conditional Types
```typescript
type UnwrapPromise<T> = T extends Promise<infer U> ? U : T
type Awaited = UnwrapPromise<Promise<string>>  // string

type ReturnOf<T> = T extends (...args: any[]) => infer R ? R : never
type Fn = (x: number) => string
type R = ReturnOf<Fn>  // string

type ArrayElement<T> = T extends (infer E)[] ? E : never
type Elem = ArrayElement<string[]>  // string
```

## Configuration (tsconfig.json)

```json
{
  "compilerOptions": {
    "strict": true,                    // Enables all strict checks
    "noUncheckedIndexedAccess": true,  // Array/object access may be undefined
    "noImplicitReturns": true,         // All code paths must return
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true, // { x?: string } → x can be string | undefined, not undefined
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "isolatedModules": true,           // Required for transpilers like esbuild/swc
    "moduleResolution": "bundler",     // Modern: supports package.json exports
    "paths": {                         // Only use when you actually need aliases
      "@app/*": ["./src/*"]
    }
  }
}
```

## Type vs Interface

```typescript
// Use `type` by default. Use `interface` only when you need declaration merging.
// Type: unions, intersections, mapped types, conditional types
type Status = "active" | "inactive" | "pending"

// Interface: objects, extends, declaration merging
interface User {
  id: string
  name: string
}
interface Admin extends User {
  permissions: string[]
}
```

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Object is possibly 'undefined'` | Indexed access without check | Add guard or `noUncheckedIndexedAccess: false` (not recommended) |
| `Property does not exist on type` | Union type, property not on all members | Discriminate union with `switch`/`if` |
| `Type 'X' is not assignable to type 'Y'` | Missing properties, type mismatch | Check missing props, use `satisfies` |
| `Cannot find module` | Wrong path, missing .js extension | Check path, enable `allowImportingTsExtensions` |
| `Unused variable` warning | Actually unused or false positive | Remove if unused, prefix with `_` if needed for destructuring |

## When NOT to Use TypeScript

- Throwaway scripts you'll run once
- Config files that don't benefit from types
- Quick prototyping where speed > safety (then add types later)
- Projects where the team doesn't know TypeScript and there's no time to learn
