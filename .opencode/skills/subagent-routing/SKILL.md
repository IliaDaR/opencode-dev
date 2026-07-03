---
name: subagent-routing
description: Use to decide which sub-agent to delegate to. Critical for efficient multi-agent orchestration. The main agent should consult this whenever a task could be delegated.
---

# Sub-Agent Routing

## Decision Matrix

| Task Type | Delegate To | Why |
|-----------|------------|-----|
| Plan a feature / design system | **architect** | Specialized in architecture, knows codebase map |
| Code review / style check | **reviewer** | Systematic reviewer with AGENTS.md knowledge |
| Find bug root cause | **debugger** | Tracing specialist, stack trace analysis |
| Write complex types / schemas | **typesmith** | TypeScript + Effect pattern expert |
| Restructure / rename / clean up | **refactor** | Safe refactoring with auto-verification |
| Write production code | **scribe** | Fast, accurate code writer for any language |
| Quick bug patch (simple) | **quick-fix** | Lightweight, fast turnaround |
| Explore codebase / find files | **explore** (built-in) | Fast file/pattern search |
| Long research / multi-step | **general** (built-in) | General purpose complex tasks |

## Routing Rules

### Always Delegate
- Code generation of > 50 lines → **scribe**
- Architecture decision needed → **architect**
- Bug exists, don't know cause → **debugger**
- PR needs review → **reviewer**
- Complex TypeScript type error → **typesmith**

### Never Delegate
- Single-line edit → do it yourself
- User asked a question you can answer from context → answer directly
- Decision that requires real-time user input → stay in main context

### Consider Delegating
- Task would take > 5 tool calls → delegate (context isolation)
- Task is self-contained (clear input, expected output) → delegate
- You're doing similar work in parallel on different files → delegate to multiple agents

## Parallel Delegation

```
Multiple independent tasks → Launch sub-agents in PARALLEL

Example:
User: "Add tests for auth.ts, refactor user.ts, and review the API design"
→ Launch 3 agents simultaneously:
  1. scribe: "Write tests for auth.ts covering login, logout, token refresh"
  2. refactor: "Refactor user.ts: extract validation, simplify control flow"
  3. architect: "Review API design in routes/ — suggest improvements"

Each agent works independently. You get 3 results. You integrate.
```

## Task Description Template

When delegating, be precise to avoid agent confusion (which wastes tokens):

```markdown
## Task
<one sentence what to do>

## Files
- src/auth/login.ts — main file to modify
- src/auth/types.ts — type definitions (read, don't edit)

## Context
- We decided to use JWT in cookies (decision from earlier)
- The bug is: users get logged out after 5 minutes (should be 7 days)
- The existing pattern for error handling is in src/utils/errors.ts

## Expected Output
<exactly what you want back: code? analysis? file list?>

## Constraints
- Don't modify types.ts
- Follow AGENTS.md style guide
- Return only the changed code, not the whole file
```

Bad delegation:
```
"Fix the auth bug" (agent has to discover everything → wasted tokens)
"Look at the code and tell me what you think" (ambiguous → wasted tokens)
```

Good delegation:
```
"src/auth/login.ts:42 — set cookie maxAge to 7*24*60*60*1000 instead of 5*60*1000"
(Specific → agent does exactly this → minimal tokens)
```

## Agent Selection by Language

| Language | Best Agent | Notes |
|----------|-----------|-------|
| TypeScript/JavaScript | scribe, typesmith | Primary language of this project |
| Python | scribe | scribe handles all languages |
| SQL | scribe + sql-expert skill | Load skill before delegation |
| Rust/Go/C++ | scribe | scribe is universal code writer |
| HTML/CSS | scribe | Simple markup |
| Shell/Bash | main agent | Short scripts, do yourself |

## Cost Efficiency

```
Estimate before delegating:

DIY cost:    (tool calls × 300 avg tokens) + (output × 200 avg tokens)
Delegate cost: 500 agent overhead + (agent result × 500 avg tokens)

If DIY > Delegate → delegate
If DIY < Delegate → do it yourself

Rule of thumb:
  < 3 tool calls → DIY
  3-8 tool calls → either, preference for DIY if you have context
  > 8 tool calls → delegate
```

## Anti-Patterns

- Delegate a 1-line fix to scribe (overhead > benefit)
- Delegate without providing file paths (agent wastes tokens exploring)
- Not reading agent results (what was the point?)
- Sequential delegation when parallel is possible
- Delegating to architect when you need code (architect plans, doesn't write)
- Delegating to debugger when you already know the fix (just fix it)
