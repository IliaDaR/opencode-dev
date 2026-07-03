---
name: docker-k8s
description: Use when creating Dockerfiles, docker-compose files, Kubernetes manifests, optimizing container builds, or debugging container/kubernetes issues.
---

# Docker & Kubernetes

## Dockerfiles

### Golden Rules
```
1. Multi-stage builds always — separate build from runtime
2. Specific base image tags — never `:latest`
3. COPY before RUN — layer caching works better
4. Least privileged user — never root in production
5. .dockerignore — exclude node_modules, .git, dist except when needed
```

### Optimal Node.js Dockerfile
```dockerfile
# Stage 1: Build
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false
COPY . .
RUN npm run build

# Stage 2: Runtime
FROM node:22-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=builder /app/package.json /app/package-lock.json ./
RUN npm ci --production --ignore-scripts
COPY --from=builder /app/dist ./dist
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

### Optimal Python Dockerfile
```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY pyproject.toml ./
RUN pip install --no-cache-dir .
COPY . .

FROM python:3.12-slim
WORKDIR /app
RUN groupadd -r app && useradd -r -g app app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /app/src ./src
USER app
EXPOSE 8000
CMD ["python", "-m", "src.main"]
```

### Layer Caching
```dockerfile
# BAD: copy everything, then install — any file change busts npm cache
COPY . .
RUN npm ci

# GOOD: copy dependency files first, install, then copy code
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# Code changes don't re-run npm ci
```

### docker-compose
```yaml
version: "3.8"
services:
  app:
    build: .
    ports: ["3000:3000"]
    environment:
      DATABASE_URL: postgres://postgres:pass@db:5432/myapp
    depends_on:
      db:
        condition: service_healthy  # Wait for healthy, not just started
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

## Kubernetes

### Pod → Deployment → Service
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:1.0.0
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 3000
```

### Resource Requests vs Limits
- **requests**: what the pod is guaranteed (scheduler uses this)
- **limits**: max the pod can burst to (throttled if exceeded for CPU, OOMKilled for memory)
- Set requests = limits for predictable workloads; requests < limits for burstable
- CPU: measured in cores (1 = 1 core, 250m = 0.25 core)
- Memory: Mi, Gi — over-limit → OOMKilled

### ConfigMap & Secrets
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  API_TIMEOUT: "30s"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  DATABASE_URL: "postgres://user:pass@host/db"
# Never commit actual secret values to git
# Use sealed-secrets or external-secrets-operator in production
```

## Anti-Patterns

- **`:latest` tag**: unpredictable, breaks reproducibility
- **Root user in container**: if app is compromised, attacker has root
- **`npm install` instead of `npm ci`**: `npm ci` is deterministic, `npm install` may update lockfile
- **Volume mount for node_modules**: overrides the container's node_modules with host's (platform mismatch)
- **One container, many processes**: one process per container; use sidecar pattern for multiple
- **No health checks**: Kubernetes can't know if your app is actually working
- **Hardcoded memory limits without measurement**: too low = OOMKilled, too high = wastes cluster capacity

## Debugging

```bash
# Container won't start?
docker logs <container>
docker inspect <container>
docker run --rm -it --entrypoint /bin/sh <image>  # Shell into it

# Pod crashing?
kubectl describe pod <pod>
kubectl logs <pod> --previous  # Logs from crashed container
kubectl exec -it <pod> -- /bin/sh

# Resource issues?
kubectl top pod
kubectl describe node  # See if node is under pressure
```
