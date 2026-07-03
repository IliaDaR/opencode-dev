---
name: project-bootstrap
description: Use when starting new projects, choosing a tech stack, setting up project scaffolding, or deciding on project structure and tooling.
---

# Project Bootstrap

## Quick Start Decision Tree

```
What are you building?
├── Web app (interactive UI)
│   ├── SPA needed? → React/Vue/Svelte + Vite
│   ├── SSR needed? → Next.js / Nuxt / SvelteKit
│   └── Static content? → Astro / 11ty
├── API server
│   ├── TypeScript? → Fastify or Hono + Drizzle + PostgreSQL
│   ├── Python? → FastAPI + SQLAlchemy + PostgreSQL
│   └── Go? → Chi or Echo + sqlc + PostgreSQL
├── CLI tool
│   ├── Node → Commander or Cliffy
│   ├── Python → Click or Typer
│   └── Rust → Clap
├── Mobile app
│   ├── Cross-platform → React Native / Flutter
│   └── Native → SwiftUI (iOS) / Jetpack Compose (Android)
└── Library / SDK
    └── Language-native stack, zero external deps if possible
```

## Project Structure Template

```
my-project/
├── src/
│   ├── index.ts          # Entry point
│   ├── config.ts         # Environment, settings
│   ├── lib/              # Shared utilities
│   └── modules/          # Feature modules
│       └── users/
│           ├── users.model.ts
│           ├── users.service.ts
│           └── users.test.ts
├── tests/                # Integration/E2E tests
├── scripts/              # Build, deploy, migration scripts
├── docs/                 # Documentation
├── package.json
├── tsconfig.json         # Or pyproject.toml, Cargo.toml, etc.
├── .env.example          # Template for required env vars
├── .gitignore
├── Dockerfile
├── docker-compose.yml    # For local dev dependencies
└── README.md
```

## Configuration Files Checklist

### Every project should have:
- [ ] `.gitignore` — specific to your tech stack
- [ ] `.editorconfig` — consistent formatting across editors
- [ ] Linting config (eslint, ruff, etc.)
- [ ] Formatting config (prettier, black, etc.)
- [ ] CI/CD pipeline file
- [ ] `.env.example` (never commit `.env`!)

### TypeScript/Node specific:
- [ ] `tsconfig.json` with `strict: true`
- [ ] `package.json` with `"type": "module"`
- [ ] Lockfile committed (`package-lock.json`, `pnpm-lock.yaml`)

### Python specific:
- [ ] `pyproject.toml` with dependencies and tool configs
- [ ] Lockfile or `requirements.txt` with pinned versions

## Dependency Selection

### How to Choose a Dependency
1. Is it actively maintained? (last commit < 6 months)
2. Bundle size / cost? (check with bundlephobia for npm)
3. How many dependencies does IT have? (fewer = better)
4. License compatible with your project?
5. Can you implement the needed part yourself in < 1 day? If yes, do that.

### Minimum Viable Dependencies
Start with zero. Add only when:
- The implementation would take > 1 week
- The domain is complex (crypto, date/time, DB drivers)
- Security-critical (use audited library, not DIY auth)

## README Template

```markdown
# Project Name

One sentence description.

## Quick Start
```bash
git clone ...
cd project
npm install
cp .env.example .env  # Fill in required values
npm run dev
```

## Architecture
Brief description of how the system is structured.

## Development
- `npm run dev` — start dev server
- `npm test` — run tests
- `npm run lint` — check code style
- `npm run build` — production build

## Deployment
How to deploy this thing.

## Environment Variables
| Variable | Required | Description |
|----------|----------|-------------|
| DATABASE_URL | Yes | PostgreSQL connection string |
| LOG_LEVEL | No | Default: info |
```

## Anti-Patterns When Bootstrapping

- **Choosing tech before understanding the problem**: "We'll use Kubernetes" — for a 2-person prototype
- **Over-configuration**: 15 config files before a single line of business logic
- **Premature optimization**: sharding the database before you have users
- **No .gitignore**: committing node_modules, .env, IDE files on first commit
- **Mega-starters**: `create-t3-app` with everything enabled when you need 20% of it
- **Not running the thing immediately**: get `npm run dev` working before ANYTHING else
