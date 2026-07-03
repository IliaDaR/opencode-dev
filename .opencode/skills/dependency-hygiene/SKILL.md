---
name: dependency-hygiene
description: Use when managing project dependencies, auditing for vulnerabilities, reducing bundle size, upgrading packages, or resolving dependency conflicts.
---

# Dependency Hygiene

## Adding a Dependency

### Before You Install
1. Can I write this in < 1 hour myself? → Do that instead
2. Is the package maintained? Check:
   - Last commit < 3 months
   - Open issues < 50 (for popular packages) or < 10 (for niche ones)
   - Bus factor: > 1 maintainer
   - Download count not the only metric (some good packages are niche)
3. How many sub-dependencies does it bring? `npm info <pkg> dependencies`
4. Bundle size? `bundlephobia.com` for npm packages
5. License: MIT/Apache/BSD = safe. GPL = check with legal.

### Install It Right
```bash
# npm: always use a specific flag
npm install lodash         # production dependency
npm install -D vitest      # dev dependency
npm install -g pnpm        # global (rarely)

# Check what you're actually installing
npm info lodash            # metadata
npm info lodash@4.17.21    # specific version
```

## Security Auditing

```bash
# npm audit — quick check
npm audit                  # Known vulnerabilities

# npm audit fix — careful!
npm audit fix              # Auto-update to non-breaking patches
# NEVER: npm audit fix --force  (can break everything)

# Better: use a specialized tool
npx snyk test              # Deeper analysis

# GitHub: Dependabot alerts, auto-PRs for vulns
# GitLab: Dependency Scanning in CI
```

## Keeping Dependencies Updated

### Strategy
- **Patch versions** (1.2.3 → 1.2.4): auto-merge if CI passes
- **Minor versions** (1.2.3 → 1.3.0): review changelog, merge if safe
- **Major versions** (1.2.3 → 2.0.0): plan separately, read migration guide

### Tools
```bash
# Check what's outdated
npm outdated

# Interactive update
npx npm-check-updates -i

# Automated minor/patch PRs
# GitHub: Dependabot
# Renovate: more configurable
```

### Renovate Config
```json
{
  "extends": ["config:base"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true
    },
    {
      "matchUpdateTypes": ["minor"],
      "matchPackagePatterns": ["^@types/"],
      "automerge": true
    },
    {
      "matchPackagePatterns": ["^react", "^@types/react"],
      "groupName": "react",
      "enabled": false
    }
  ]
}
```

## Reducing Dependencies

### Find Unused Dependencies
```bash
npx depcheck
# Finds: unused deps, missing deps, phantom deps

# Manual check: grep for import
rg "from ['\"]package-name" src/
# No results → probably unused
```

### Find Heavy Dependencies
```bash
npx bundle-phobia-cli <package>
# Shows: size, gzip size, download time

# Analyze your bundle
npx webpack-bundle-analyzer stats.json
# Or: npx source-map-explorer dist/**/*.js
```

### Replace Heavy Dependencies
```javascript
// Replace moment.js (70KB) with native:
// Bad: import moment from "moment"
moment().format("YYYY-MM-DD")

// Good: native Intl
new Date().toISOString().split("T")[0]

// Replace lodash (72KB full) with native:
// Bad: import _ from "lodash"
_.groupBy(items, "category")

// Good: Object.groupBy (ES2024) or reduce
Object.groupBy(items, ({ category }) => category)

// If you need lodash, import only what you use:
import groupBy from "lodash/groupBy"  // Not: import _ from "lodash"
```

## Dependency Conflicts

```
npm ERR! ERESOLVE unable to resolve dependency tree
```

### Resolution
```bash
# 1. Understand the conflict
npm ls conflicting-package

# 2. Options:
# a) Override (force specific version):
# package.json → "overrides": { "foo": "2.0.0" }  (npm)
# package.json → "resolutions": { "foo": "2.0.0" }  (yarn)

# b) Dedupe:
npm dedupe

# c) Check if you need both versions — maybe you can drop one dependency
```

## Lockfile

- **Always commit** your lockfile (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`)
- Lockfile ensures everyone installs the exact same versions
- Regenerate on conflict: delete lockfile + node_modules, reinstall

## Production Dependencies

```bash
# Install only production deps (smaller Docker image)
npm ci --production
# But: build tools may be needed for build step → use multi-stage Docker

# Audit production deps separately (ignore dev vulns)
npm audit --production
```

## Anti-Patterns

- **`*` wildcard version**: `"lodash": "*"` — installs latest, breaks whenever lodash releases
- **`latest` tag**: `npm install package@latest` — same problem
- **Committing node_modules**: bloats repo, platform-specific binaries
- **Never updating**: 2-year-old dependencies with known vulns
- **Updating everything at once**: one breaking change hides another
- **Duplicate dependencies**: same package at 3 different versions — wasted bytes
