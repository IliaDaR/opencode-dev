---
name: opencode-internals
description: Use when working with the OpenCode codebase itself — Session V2, Effect services, Drizzle schemas, permissions, tools, providers, or agent system internals. Always load this skill before modifying core OpenCode packages.
---

# OpenCode Internals

This skill covers the internal architecture, patterns, and conventions of the OpenCode codebase. Always reference this BEFORE making changes to core packages.

## Repository Layout

```
packages/
├── opencode/     # Core server: Session V2, tools, permissions, config
├── core/         # Shared library: providers, config helpers, logging
├── tui/          # Terminal UI built with SolidJS
├── app/          # Web application
├── desktop/      # Tauri desktop wrapper
├── console/      # SST Console web app
├── stats/        # Statistics/monitoring
├── sdk/js/       # JavaScript SDK for external consumers
├── slack/        # Slack integration
├── plugin/       # Plugin system + plugin SDK
├── ui/           # Shared UI component library
└── storybook/    # Component stories
```

## Key Technology Stack

- **Runtime**: Bun >= 1.3.14
- **Language**: TypeScript 5.x, strict mode
- **Effect**: effect-smol (Effect v4), managed types, composable services
- **Database**: SQLite via Drizzle ORM
- **UI**: SolidJS with @tanstack/solid-virtual (patched)
- **Infra**: SST (Serverless Stack) on AWS
- **AI**: `ai` + `@ai-sdk/*` providers
- **MCP**: Model Context Protocol support (local/remote)

## Session V2 Architecture

### Core Flow
1. `SessionV2.prompt(...)` admits durable `session_input` row
2. `SessionExecution.wake(sessionID)` schedules the drain
3. Runner loads projected history, resolves model, executes
4. Single `llm.stream(request)` per provider turn
5. Results stored durably; continuation re-loads history

### Key Types
- `SessionV2` — Session admission and management
- `SessionExecution` — Process-global, Session-ID based coordinator
- `SessionRunner` — Location-scoped: model, tools, permissions
- `SessionRunCoordinator` — Joins same-Session resumes
- `EventV2` — Replay and ownership tracking

### Delivery Modes
- `steer` — Default, promotes at next safe boundary
- `queue` — Pending until Session idle, then promotes one

### Critical Rules
- Durable prompt admission SEPARATE from model execution
- Single `llm.stream()` call per provider turn
- Reload projected history before durable continuation
- Agent's provider-turn allowance resets on new user input
- Batch of steers resets allowance once

## File Locations for Config

| What | Where |
|------|-------|
| Project config | `./opencode.json`, `./opencode.jsonc`, `.opencode/opencode.json` |
| Project agents | `.opencode/agent/<name>.md` or `.opencode/agents/<name>.md` |
| Project skills | `.opencode/skills/<name>/SKILL.md` |
| Project plugins | `.opencode/plugins/*.ts` |
| Custom tools | `.opencode/tool/*.ts` |

## Effect Service Patterns

### Service Definition (Do)
```ts
export class MyService extends Effect.Service<MyService>()("MyService", {
  effect: Effect.gen(function* () {
    return {
      doThing: (input: string) =>
        Effect.gen(function* () {
          const dep = yield* OtherService
          const result = yield* dep.process(input)
          return result
        }),
    }
  }),
  dependencies: [OtherService.layer],
}) {}
```

### Schemas (Do)
```ts
class MyError extends Schema.TaggedErrorClass<MyError>()("MyError", {
  message: Schema.String,
}) {}

const MyInput = Schema.Struct({
  id: Schema.brand(Schema.String, "MyID"),
  name: Schema.String,
})
```

### Testing Services
```ts
// Use testEffect from packages/opencode/test/lib/effect.ts
testEffect("does the thing", () =>
  Effect.gen(function* () {
    const result = yield* MyService.doThing("test")
    expect(result).toEqual(expected)
  }).pipe(Effect.provide(MyService.Test.layer))
)
```

### Don't
- Don't `JSON.parse` + `Effect.try` — use `Schema.UnknownFromJsonString`
- Don't cast with `as` or `!` — use schema decoding
- Don't hide layers — keep composition explicit
- Don't use `any` — use `unknown` + narrowing

## Drizzle Patterns (Do)

```ts
const table = sqliteTable("my_table", {
  id: text().primaryKey(),        // no string arg needed
  user_id: text().notNull(),       // snake_case
  created_at: integer().notNull(), // snake_case
})
```

## Testing Rules
- Tests run from package dirs: `bun test` in `packages/opencode`
- Use `testEffect()` for Effect-based tests
- Use `it.live()` for filesystem, git, HTTP, real platform tests
- Avoid mocks; test actual implementation
- No tests from repo root (guard: `do-not-run-tests-from-root`)

## Type Checking
- Run `bun typecheck` from package directory, never `tsc` directly
- From root: `bun turbo typecheck` for all packages

## Permissions Architecture
- Actions: `allow`, `ask`, `deny`
- Per-tool: object with glob patterns
- LAST matching rule wins (put broad first, narrow last)
- Per-agent permissions override top-level
- Plan mode = `edit: deny *` on the plan agent

## Provider System
- Configured inline or via `@ai-sdk/*` plugins
- Each provider has `options.apiKey`, `options.baseURL`
- Whitelist/blacklist control model availability
- Timeout: per-request, header, and chunk-level

## When in Doubt
1. Read the relevant source in `packages/opencode/src/`
2. Check `specs/` directory for design docs
3. Search `effect-smol` reference for Effect API
4. Read `AGENTS.md` for style conventions
5. Read `.opencode/opencode.jsonc` for current config
