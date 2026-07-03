---
name: context-management
description: Use when the main agent needs to manage its context window, decide what to keep vs discard, or optimize tool usage patterns to maintain context quality over long sessions.
---

# Context Management

## The Context Budget

Your context window is your most valuable resource. Manage it like a budget.

### What Enters Context
```
1. System prompt + agent definition    (fixed, ~5K tokens)
2. Active skills                       (loaded on demand, 0.5K-2K each)
3. User messages                       (variable)
4. Your responses                      (variable, you control this)
5. Tool call definitions               (fixed per session)
6. Tool call outputs                   (variable, largest consumer)
7. Sub-agent task results              (summary, ~0.2K-1K each)
```

### What Exits Context
```
Compaction removes: old tool outputs, old conversation turns
Pruning removes: individual old tool outputs
```

## Context Quality Score

Rate your context health 1-10:
- **1-3**: Mostly irrelevant tool outputs, can't remember early decisions. STOP. Let compaction run. Start fresh mental model.
- **4-6**: Some cruft but core decisions remembered. Consider manual summarization.
- **7-9**: Clean. Relevant info only. Good. Keep working.
- **10**: Perfect. Every line in context serves a purpose. Rare.

## When to Request Compaction

```
Triggers:
- You notice you're re-reading files you already read
- Tool outputs from 5+ turns ago are still verbatim in context
- You can't answer "what did we decide about X?" without re-reading

Action: The system auto-compacts. But you can accelerate it by:
- Finishing the current sub-task
- Summarizing conclusions before moving to next task
- Not reading unnecessary files
```

## Mental State Management

### The "What I Know" Inventory
After every 5-10 tool calls, mentally inventory:
```
1. What problem are we solving? (1 sentence)
2. What files are involved? (list paths)
3. What decisions were made? (key choices)
4. What's blocked? (open questions)
5. What's next? (next action)
```

If you can't answer #1-3 → context is polluted, needs cleanup.

### Session Checkpoints
After major milestones, output a brief checkpoint:
```
## Checkpoint: Auth system refactored
- Changed: auth.ts, session.ts, middleware.ts
- Decision: JWT stored in httpOnly cookie, not localStorage
- Next: Update frontend login flow
```

This serves both user and you. User sees progress. You anchor your context.

## Tool Output Hygiene

### Before Every Read/Grep: The 3-Question Test
```
1. Do I ALREADY have this info in context? → Skip
2. Is there a CHEAPER way to get this info? (grep over read)
3. Will I NEED this info 5 turns from now? (if no → read, use, let it prune)
```

### After Every Read: The 1-Minute Rule
If you haven't referenced a read result within 1 minute (1-2 turns) → you didn't need it. Let it get pruned without guilt.

## Multi-File Work Strategy

### The Scribe Pattern
```
When modifying 5+ files:
1. Explore: grep to find all relevant files (lightweight)
2. Plan: list files + changes needed (lightweight)
3. Execute: one file at a time, don't re-read between edits
4. Verify: typecheck/test at the end

Bad: Read file A → edit A → read file B → edit B → read file C → ...
      (Context fills with obsolete pre-edit versions of files)

Good: grep for pattern → plan all edits → edit A, B, C → verify
      (Context stays lean)
```

### The "Don't Re-Read" Rule
After you edit a file, your edit result IS the current file state. Don't immediately re-read it to check your work. Trust the edit. Verify with typecheck/test.

## Long Session Survival

### Session > 30 minutes
```
- Aggressively prune mental model of early exploration
- Re-derive context from checkpoint summaries, not tool outputs
- Consider: would a fresh session be more efficient?
```

### Session > 60 minutes
```
- You've probably changed context 2-3 times by now
- Early tool outputs are useless (and pruned)
- Your mental model should be: current task + key decisions
```

## Context Anti-Patterns

- **Re-reading**: reading the same file multiple times in one session
- **Over-reading**: reading entire files when you need one function
- **Output hoarding**: keeping old tool outputs "just in case"
- **Conversational fluff**: "Let me look at that for you!" — 7 wasted tokens
- **Undisciplined exploration**: reading random files without a hypothesis
- **Duplicate information**: asking for the same info through different tools
