---
name: token-efficiency
description: Use ALWAYS when working with DeepSeek models. Minimizes token waste, maximizes useful context. Critical for cost-effective operation. The agent MUST follow these rules to be economically viable while outperforming competitors.
---

# Token Efficiency for DeepSeek

## The Golden Rule
**Every token costs money. Every useless token is money wasted. Be surgical, not conversational.**

## Context Window Strategy (128K for DeepSeek V4)

### Allocation Budget
```
Total: 128K tokens
├── System prompt + agent config:   ~5K  (fixed overhead)
├── Skills loaded:                  ~15K  (30 skills × ~500 tokens each avg)
├── Conversation history:           ~60K  (dynamic, managed by compaction)
├── Tool outputs:                   ~30K  (dynamic, managed by pruning)
└── Headroom for response:          ~18K  (available for generation)
```

### When Context Hits 80% → Compaction Triggers
Compaction preserves: most recent `tail_turns` + high-value earlier context. After compaction, older tool outputs are summarized, not verbatim.

## Reading Strategy (Biggest Token Saver)

```
Decision tree for finding information:

1. Do I already know the answer from session context? → Don't search
2. Am I guessing? → grep FIRST, read SECOND
3. Need specific function? → grep for "function name" or "export.*name"
4. Need file overview? → read with limit=50 (first 50 lines)
5. Need full file? → Is it < 300 lines? read all. > 300? read in chunks.
6. Need across many files? → Task subagent to explore, get summary back

NEVER: read a 2000-line file from top to bottom
NEVER: read a file you just read 3 turns ago (use your context)
NEVER: read node_modules, dist, lockfiles, generated code
```

### Search Before Read (Token Math)
```
grep search:    ~100 tokens in, ~200 tokens out = 300 tokens
read file:      ~50 tokens in, ~2000 tokens out = 2050 tokens

grep is 7x cheaper. Always grep first.
```

## Delegation Strategy (Context Isolation)

### When to Delegate to Sub-Agent
```
Task is self-contained AND has clear input/output → DELEGATE
Task requires full codebase context → DO IT YOURSELF
Task is quick (< 3 tool calls) → DO IT YOURSELF (delegation overhead > savings)
Task is complex (> 8 tool calls) → DELEGATE (isolates context pollution)
```

### Delegation Cost Analysis
```
Sub-agent call: ~500 tokens overhead (task description + result)
Context saved:  ~5000 tokens (sub-agent's internal work doesn't enter your context)
Net savings:    ~4500 tokens per delegation
```

### When NOT to Delegate
- Tiny task (1-2 edits) → overhead > benefit
- Need real-time interaction with user → stay in main context
- Task depends on what you just learned → you'd have to repeat context
- Sub-agent would need > 20 tool calls → might hit its step limit

## Writing Strategy

### Two-Pass Code Writing
```
Pass 1: Write minimal skeleton (function signatures, types, structure)
        → Show user, get confirmation if complex
Pass 2: Fill in implementation
        → This prevents rewriting whole blocks on feedback

Bad: Write 200 lines, user says "wrong approach" → 200 lines of wasted tokens
Good: Write 30 lines of structure, user confirms → then write 170 lines
```

### Edit vs Write
```
Single change in existing file → EDIT (cheapest, ~100 tokens)
New file or complete rewrite → WRITE (only option)
Multiple small changes in one file → Batch EDITS in parallel
```

## Output Efficiency

### Responses
```
User asked a yes/no? → "Yes" (1 token), not "Based on my analysis..." (30 tokens)
User asked for code? → Code + 1 line explanation if non-obvious
User asked for explanation? → Be thorough but dense. No fluff.
```

### Never Do This
```
❌ "I'll help you with that! Let me look into it..."
❌ "Based on my thorough analysis of the codebase..."
❌ "Great question! Here's what I found..."
❌ Summarizing what you're about to do before doing it
❌ Repeating the user's request back to them
❌ "I hope this helps!" or any other pleasantries

Just do the work. Output the result. Stop.
```

## Tool Call Optimization

### Parallelize Everything
```
Read 3 files? → One call with 3 reads
grep 3 patterns? → One call with 3 greps
Independent bash commands? → Parallel calls

Every sequential round-trip costs tokens for the full context re-evaluation.
```

### Batch Edits
```
3 changes in the same file? → Do them in ONE edit call, not 3
3 changes in 3 different files? → 3 parallel edit calls
```

## Context Pruning Hygiene

### After Every Major Step
```
- Check: do I still need the output from tool call #3? (10 turns ago)
- If no: mentally discard, let compaction prune it
- If yes: reference it explicitly so compaction preserves it
```

### What to Keep in Context
```
✅ Architecture decisions made in this session
✅ User's explicit preferences and constraints  
✅ Error messages and their resolutions
✅ Key file paths discovered
❌ Verbose tool outputs from exploration
❌ Failed attempts (keep the conclusion, drop the attempt)
❌ Irrelevant file contents accidentally read
```

## DeepSeek-Specific Optimizations

### Chain-of-Thought
DeepSeek V4 thinks in tokens. You're already using chain-of-thought.
- Dense thinking: no repetition, no verbal wandering
- State facts, evaluate options, decide, act
- Don't debate yourself for 500 tokens on a trivial decision

### Temperature Settings
```
Code generation:  temp=0.0-0.2  (deterministic, cheaper re-rolls)
Analysis/planning: temp=0.3-0.4  (some creativity needed)
Debugging:         temp=0.2-0.3  (systematic but flexible)
```

### Caching
DeepSeek caches repeated prefix tokens. Structure your prompts so:
- System context is stable (same skills loaded each time)
- Tool definitions don't change between calls
- This means: the first chunk of every request is cached → cheaper

## Cost Tracking Mental Model
```
Assume $X per 1M tokens.

Every 1000 tokens wasted on pleasantries = $ wasted
Every unnecessary file read (2000 tokens) = 2x waste
Every un-delegated complex task = 5000 tokens wasted on context pollution

Over 1000 sessions:
  Saving 5000 tokens/session = 5M tokens saved = real money
```
