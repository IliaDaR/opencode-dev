---
name: cicd-pipelines
description: Use when designing CI/CD pipelines, writing GitHub Actions workflows, setting up deployment automation, or troubleshooting build/release failures.
---

# CI/CD Pipelines

## Design Principles

### Pipeline as Code
Everything in version control. No manual steps in the UI. If the build server disappears, you can reproduce the pipeline from the repo alone.

### Fast Feedback
```
Lint (30s) → Typecheck (1min) → Unit Tests (3min) → Build (2min) → Integration (5min) → E2E (10min) → Deploy
```
Fail fast. Put the cheapest checks first. Don't run 10-min E2E tests if linting fails.

### Deterministic Builds
Same commit → same artifact. Lock all versions. Use lockfiles. Pin Docker base image hashes.

## GitHub Actions

### Workflow Structure
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel previous runs on same branch

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: "npm"
      - run: npm ci
      - run: npm run lint

  test:
    needs: lint  # Don't test if lint fails
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shard: [1, 2, 3]  # Parallelize tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: "npm"
      - run: npm ci
      - run: npm test -- --shard=${{ matrix.shard }}/${{ strategy.job-total }}
```

### Caching
```yaml
# Node modules
- uses: actions/setup-node@v4
  with:
    cache: "npm"  # Auto-caches ~/.npm

# Docker layers
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Custom cache
- uses: actions/cache@v4
  with:
    path: ~/.cache/my-tool
    key: ${{ runner.os }}-my-tool-${{ hashFiles('lockfile') }}
```

### Secrets & Environments
```yaml
deploy:
  needs: [lint, test, build]
  runs-on: ubuntu-latest
  environment: production  # Requires approval, shows in UI
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}  # From environment
  steps:
    - run: ./deploy.sh
```

### PR Checks
```yaml
name: PR Standards
on:
  pull_request:
    types: [opened, edited, synchronize]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check PR title format
        run: |
          echo "${{ github.event.pull_request.title }}" | grep -qE '^(feat|fix|docs|chore|refactor|test)(\(.+\))?: '
      - name: Check branch name
        run: |
          echo "${{ github.head_ref }}" | grep -qE '^[a-z]+(-[a-z]+)*$'
```

## Deployment Strategies

### Rolling Update
Replace instances one at a time. Zero downtime. Old and new versions coexist briefly — must be compatible.

### Blue-Green
Two identical environments. Deploy to inactive, switch traffic. Instant rollback. Costs double infrastructure during deploy.

### Canary
Send small % of traffic to new version. Increase gradually. Requires traffic splitting at load balancer.

### Which to Use?
| Strategy | Best for | Cost |
|----------|----------|------|
| Rolling | Most apps | Free |
| Blue-Green | Critical apps, zero-downtime requirement | 2x infra during deploy |
| Canary | High-risk changes, need real-traffic validation | Load balancer support |

## Pipeline Anti-Patterns

- **Secrets in logs**: `echo $SECRET` in a step → exposed in Actions log
- **No timeout**: job hangs for 6 hours → set `timeout-minutes: 30`
- **Sequential independent jobs**: lint → typecheck → test → build → deploy all in one job; split into parallel jobs
- **Hardcoded versions**: `node-version: 18` in 50 workflow files; use `.nvmrc` or repo variable
- **Rebuilding same thing**: build in one job, upload artifact, download in deploy — don't rebuild
- **No cleanup**: old artifacts, old Docker images, old deployments accumulate

## Docker Build in CI

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: |
      ghcr.io/${{ github.repository }}:${{ github.sha }}
      ghcr.io/${{ github.repository }}:latest
    cache-from: type=gha
    cache-to: type=gha,mode=max
    provenance: false  # Unless you need SLSA attestation
```

## Release Automation

```yaml
release:
  needs: [deploy-staging]
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: google-github-actions/release-please-action@v4
      with:
        release-type: node
        # Auto-creates release PR, changelog, git tag
```

## Monitoring Deployments

After deploy, verify:
- Health check endpoint returns 200
- Error rate doesn't spike (compare to pre-deploy baseline)
- Latency p95 doesn't degrade
- No new error logs with higher severity

Auto-rollback if any metric regresses beyond threshold.
