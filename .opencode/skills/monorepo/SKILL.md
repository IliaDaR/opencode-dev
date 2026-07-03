---
name: monorepo
description: Use when working with monorepos — managing multiple packages, shared dependencies, build orchestration, versioning, or migrating to/from a monorepo structure.
---

# Monorepo Patterns

## Why Monorepo

| Pro | Con |
|-----|-----|
| Atomic cross-package changes | Larger clone size |
| Single lint/test/build config | Build tooling complexity |
| Shared types across packages | CI must handle selective builds |
| Easier refactoring | Longer CI times without smart tooling |
| Unified versioning | Coupling risk between unrelated packages |

## Package Structure

```
monorepo/
├── package.json              # Workspace root
├── tsconfig.base.json        # Shared TS config
├── packages/
│   ├── shared/               # Shared utilities, types
│   │   ├── package.json      # "name": "@myorg/shared"
│   │   └── src/
│   ├── api/                  # Backend service
│   │   ├── package.json      # "name": "@myorg/api"
│   │   └── src/
│   ├── web/                  # Frontend app
│   │   ├── package.json      # "name": "@myorg/web"
│   │   └── src/
│   └── cli/                  # CLI tool
│       ├── package.json
│       └── src/
├── tools/                    # Build scripts, generators
└── turbo.json                # Task orchestration
```

## Package Management

### npm/pnpm/yarn Workspaces
```json
// Root package.json
{
  "workspaces": ["packages/*"],
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint"
  }
}
```

### Package Dependencies
```json
// packages/api/package.json
{
  "name": "@myorg/api",
  "dependencies": {
    "@myorg/shared": "workspace:*"  // Always use workspace protocol
  }
}
```

## Task Orchestration (Turborepo)

```json
// turbo.json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],  // Build dependencies first
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "cache": true
    },
    "lint": {
      "cache": true
    },
    "typecheck": {
      "dependsOn": ["^build"]
    }
  }
}
```

## Shared Configurations

```json
// tsconfig.base.json
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}

// packages/shared/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}
```

## Versioning

### Independent vs Fixed
- **Fixed**: all packages versioned together (`v1.0.0` for all) — simple, but bumps everything even if only one package changes
- **Independent**: each package has its own version — precise, but harder to track compatibility

### Changesets (recommended for independent)
```bash
# Add a changeset describing your change
npx changeset
# → Prompts: which packages changed? major/minor/patch? description

# Version packages and update changelogs
npx changeset version

# Publish
npx changeset publish
```

## Dependency Management Rules

1. **Shared code goes to `packages/shared`**, not copy-pasted between packages
2. **External deps declared where used**, not hoisted to root (root = dev tooling only)
3. **Peer dependencies**: if multiple packages use React, make it a peer dep
4. **Check for duplicates**: `npm ls react` or `npx depcheck`
5. **Never depend on a package's internal path**: use `@myorg/foo` not `../../packages/foo/src/thing`

## CI for Monorepos

```yaml
# Only build/test what changed
- uses: actions/checkout@v4
  with:
    fetch-depth: 0  # For change detection

- uses: ./
  with:
    # Only run tasks for changed packages and their dependents
    filter: |
      packages/shared/**
      packages/api/**
```

### Selective Testing
- Run tests only for changed packages
- Run tests for packages that DEPEND on changed packages
- Run full suite on main branch merges

## Migration: Multi-Repo → Monorepo

1. Create new monorepo with workspace config
2. Copy each repo into `packages/<name>`, preserving git history:
   ```bash
   git subtree add --prefix=packages/api https://github.com/org/api.git main
   ```
3. Consolidate tooling: one tsconfig base, one eslint config, one CI workflow
4. Extract shared code into `packages/shared`
5. Update imports from external package names to `@myorg/` names
6. Delete old repos after migration verified

## Anti-Patterns

- **Circular dependencies**: Package A depends on B, B depends on A → impossible to build
- **Barrel-file explosions**: `export * from "./module"` in index.ts → break tree-shaking, slow TypeScript
- **Root package.json with app deps**: root should have dev tools only; app deps in app packages
- **Relative path imports between packages**: `../../packages/shared/` → use `@myorg/shared`
- **No build cache**: rebuilding everything from scratch in CI → use Turborepo/Nx remote caching
