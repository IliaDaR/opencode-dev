# OpenCode Agent Instructions

## Token Discipline (ALWAYS ACTIVE)

Every token costs money. Be surgical.

- **grep before read**: grep finds the line, read confirms context. grep is 7x cheaper.
- **parallelize**: independent reads, greps, bash commands → one parallel call, not sequential.
- **delegate complex work**: >8 tool calls → sub-agent. Saves 5000+ tokens via context isolation.
- **no fluff**: never "Let me look into that!", "Great question!", "I hope this helps!". Output result. Stop.
- **don't re-read**: after editing a file, you know its state. Trust your edit.
- **batch edits**: 3 changes in one file → one edit call, not three.

## Agent Delegation

| Task | Agent | Why |
|------|-------|-----|
| Plan feature / design system | architect | Architecture expert |
| Write code (>50 lines) | scribe | Production code in any language |
| Code review | reviewer | Style, bugs, anti-patterns |
| Find bug root cause | debugger | Trace analysis |
| Complex TypeScript types / Effect | typesmith | Type-level expert |
| Restructure / rename / clean | refactor | Safe, verified refactoring |
| Simple known bug fix | quick-fix | Minimal overhead |
| Explore codebase / find files | explore | Built-in fast search |

**Delegate in parallel** when tasks are independent. One task per agent. Be specific: give file paths, expected output, constraints.

**Never delegate**: single-line edits, questions answerable from context, tasks needing real-time user interaction.

## Autopilot Mode

When user gives a high-level goal, drive autonomously:

1. **Plan**: Quick mental plan (simple) or delegate to architect (complex)
2. **Implement**: Delegate to scribe/typesmith
3. **Verify**: Run typecheck, tests, lint
4. **Fix**: Delegate failures to quick-fix/debugger
5. **Report**: Summary of what was done

If 3 attempts fail → tell user what's blocking. Don't loop. Report progress at milestones.

## Error Recovery

- Read the error carefully. Don't guess.
- Simple fix → do it. Unclear → debugger. Architecture issue → architect.
- Never retry the same thing expecting different results.
- Never ignore errors and continue.

## Output Rules

- Be concise. Answer in 1-3 lines unless detail requested.
- No preamble ("I'll help with that"), no postamble ("let me know if you need anything").
- Yes/no questions → one word answer when appropriate.
- Code output → code + 1-line explanation only if non-obvious.

## This Repository (OpenCode)

- Default branch: dev. Local main may not exist; use dev or origin/dev.
- Regenerate JS SDK: `./packages/sdk/js/script/build.ts`.
- Tests run from package dirs (e.g. `packages/opencode`), never from root.
- Typecheck: `bun typecheck` from package dir, never `tsc` directly.

## Branch Names

Short, ≤3 words, hyphen-separated. No slashes, no type prefixes.
Examples: `session-recovery`, `fix-scroll-state`, `regenerate-sdk`.

## Commits & PR Titles

`type(scope): summary` — types: feat, fix, docs, chore, refactor, test.
Examples: `fix(tui): simplify thinking toggle styling`, `chore(sdk): regenerate types`.

## Style Guide (TypeScript)

- No try/catch unless unavoidable. No any type. No else — use early returns.
- Prefer const, ternaries, functional array methods.
- Use Bun APIs when possible (Bun.file(), Bun.write()).
- No import aliasing, no star imports. Rely on type inference.
- Inline single-use values. Avoid unnecessary destructuring — use dot notation.
- Keep things in one function unless composable/reusable.
- Helpers below the main export, not above. Don't extract single-use helpers.
- Comments for non-obvious constraints only, not obvious code.

### Effect Patterns
- Use Effect.gen(function*(){}) for multi-step workflows.
- Use Schema.TaggedErrorClass for domain errors.
- Use Schema.UnknownFromJsonString over JSON.parse + Effect.try.
- Keep layer composition explicit. No hidden provisioning.

### Drizzle Schemas
- snake_case column names, no string redefinitions:
```ts
const table = sqliteTable("session", {
  id: text().primaryKey(),
  project_id: text().notNull(),
  created_at: integer().notNull(),
})
```

## Testing
- Avoid mocks. Test actual implementation. No tests from repo root.
- Use testEffect() for Effect tests, it.live() for platform tests.

## V2 Session Core
- SessionV2.prompt(...) admits durable session_input. SessionExecution.wake(sessionID) schedules drain.
- Single llm.stream(request) per provider turn. Reload projected history before continuation.
- SessionExecution is process-global, Session-ID based. SessionRunner is Location-scoped.
- Steer by default. Queue promotes at idle boundary. New user input resets provider-turn allowance.
- System Context algebra lives in src/system-context. Context Sources with their observed domains.
