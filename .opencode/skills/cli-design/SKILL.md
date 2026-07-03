---
name: cli-design
description: Use when designing CLI tools, command-line interfaces, or terminal applications. Covers argument parsing, output formatting, UX patterns, and shell integration.
---

# CLI Design

## Principles

### Do One Thing Well
A CLI tool should have one clear purpose. If you need `--mode` or `--action` flags, you probably need separate commands.

### Be a Good Unix Citizen
- Read from stdin, write to stdout, errors to stderr
- Exit 0 on success, non-zero on failure
- Support pipes: `cat data.json | mycli process | jq .`
- Signal handling: SIGINT (Ctrl+C) = graceful shutdown

## Argument Design

### Named vs Positional
```bash
# Positional: required, no flag
mycli deploy production

# Named: optional, has flag
mycli deploy --env=production

# Flags: boolean
mycli deploy --force --dry-run

# Rule: positional for required core arguments, flags for options
```

### Command Structure
```bash
mycli <noun> <verb> [options]
mycli user create --name="Alice" --email="alice@example.com"
mycli user list --status=active
mycli user delete 42

# Avoid: mycli create-user (flat namespace, doesn't scale)
```

### Naming
- Commands: short verbs (`create`, `list`, `delete`, `deploy`, `logs`)
- Flags: descriptive, kebab-case (`--dry-run`, `--output-format`)
- Never: cryptic single letters for primary flags (`-x`)
- Short aliases for common flags only: `-h` for help, `-v` for version, `-f` for force

## Output Design

### Default Output: Human-Readable
```
$ mycli user list
ID    NAME       EMAIL              STATUS
42    Alice      alice@example.com  active
43    Bob        bob@test.com       pending
```

### Machine-Readable Output: `--json`
```bash
mycli user list --json | jq '.[] | select(.status == "active")'
```

### Verbosity: `--verbose` / `-v`
- No flag: essential info only (names, status)
- `-v`: operational details (timing, counts)
- `-vv`: debug info (full requests, raw responses)
- Never print debug info by default

### Colors
- Don't overdo it. 3-4 colors max.
- Green = success, red = error, yellow = warning, cyan = info
- Always support `--no-color` (honor `NO_COLOR` env var)
- Use colors for emphasis, not as the only information carrier (accessibility)

### Progress Indicators
```bash
# For operations > 2 seconds, show progress
⠋ Deploying... [2/5] uploading assets
⠙ Deploying... [3/5] configuring DNS
✔ Deployed successfully (12.3s)

# Let users disable: --no-progress (for CI)
```

## Error Handling

### Error Messages
```bash
# Bad
$ mycli deploy
Error: ECONNREFUSED

# Good
$ mycli deploy
Error: Cannot connect to api.example.com:443
  Connection refused — is the server running?
  Check: https://status.example.com

# Always include:
# 1. What went wrong
# 2. Why it might have happened
# 3. What the user can do about it
```

### Exit Codes
```
0 — Success
1 — General error
2 — Misuse (wrong arguments)
3 — Network error (can't connect)
4 — Authentication error
5 — Data error (bad format, missing field)
```

## Confirmation & Safety

### Destructive Operations
```bash
# Require confirmation for destructive actions
$ mycli user delete 42
Are you sure you want to delete user "Alice" (ID: 42)? [y/N]

# --force / --yes skips confirmation
$ mycli user delete 42 --force
Delete: user "Alice" (ID: 42) — deleted

# Dry run
$ mycli user delete 42 --dry-run
Would delete: user "Alice" (ID: 42)
```

## Configuration

### Config Sources (Order of Precedence)
1. CLI flags (highest)
2. Environment variables: `MYCLI_API_KEY`
3. Config file: `~/.myclirc`, `.myclirc.json`, `mycli.config.js`
4. Defaults (lowest)

```bash
mycli deploy --env=staging --region=eu-west-1
# CLI flag wins over everything
```

### Environment Variables
- UPPER_SNAKE_CASE with prefix: `MYCLI_API_KEY`, `MYCLI_LOG_LEVEL`
- Document all env vars
- Validate at startup, not lazily

## Help & Documentation

```bash
mycli --help                    # Top-level help
mycli user --help               # Command-specific help
mycli user create --help        # Sub-command help

# Help should show:
# - Usage line
# - Arguments and options
# - Examples (realistic, not contrived)
# - Link to full docs

# Examples:
mycli user create --name="Alice" --email="alice@example.com"

# Add an interactive onboarding step:
mycli --interactive
# Guides user through setup
```

## Framework Choice

- **Node**: Commander, Cliffy, yargs
- **Python**: Click, Typer, argparse (stdlib)
- **Go**: Cobra, urfave/cli
- **Rust**: Clap

Use a library. Don't write argument parsing yourself.

## Release

- Version: `mycli --version` — always works
- Update notification: check for new version on run (cache result for 24h)
- Single binary if possible: Go/Rust compile to one file; Node can use pkg/nexe/bun
- Package managers: npm (Node), pip (Python), Homebrew (macOS), apt (Linux)
