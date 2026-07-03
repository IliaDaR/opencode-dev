---
name: caching-strategies
description: Use when designing caching layers, choosing cache invalidation strategies, optimizing data access patterns, or debugging stale data issues.
---

# Caching Strategies

## The Two Hard Problems
1. Cache invalidation
2. Naming things
3. Off-by-one errors

## Cache Levels (Closest to User First)

```
Browser Cache (HTTP Cache-Control)
  → CDN / Edge Cache
    → Application Cache (Redis, Memcached)
      → Database Query Cache
        → Database
```

Cache as close to the user as possible. Each layer costs more to reach.

## Caching Patterns

### Cache-Aside (Lazy Loading)
```python
def get_user(user_id: str) -> User:
    # 1. Check cache
    cached = cache.get(f"user:{user_id}")
    if cached:
        return cached

    # 2. Cache miss → load from DB
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundError()

    # 3. Store in cache
    cache.set(f"user:{user_id}", user, ttl=3600)
    return user

# Application manages cache — cache doesn't know about DB
# Pros: simple, lazy (only cache what's used)
# Cons: first request is slow, stale data possible
```

### Write-Through
```python
def update_user(user_id: str, data: dict) -> User:
    user = db.update(User, user_id, data)
    cache.set(f"user:{user_id}", user, ttl=3600)  # Update cache immediately
    return user

# Cache always in sync with DB for reads
# Cons: every write touches cache (even for data never read again)
```

### Write-Behind (Write-Back)
```python
def update_user(user_id: str, data: dict) -> User:
    user = db.update(User, user_id, data)
    # Queue cache update for later (async)
    cache_queue.enqueue(f"user:{user_id}", user)
    return user

# Pros: writes are fast
# Cons: cache can be stale, data loss if cache queue crashes
```

### Read-Through
```python
# Cache sits between app and DB — app only talks to cache
cache.get_or_load(f"user:{user_id}", loader=lambda: db.query(User).get(user_id), ttl=3600)

# Pros: app code is simpler
# Cons: cache must understand how to load from DB
```

## Cache Invalidation Strategies

### TTL (Time To Live)
```python
cache.set("key", value, ttl=3600)  # Expires in 1 hour

# Shorter TTL = fresher data, more DB load
# Longer TTL = staler data, less DB load
# Pick TTL based on how often data changes
```

### Explicit Invalidation
```python
def update_user(user_id: str, data: dict):
    user = db.update(User, user_id, data)
    cache.delete(f"user:{user_id}")     # Remove stale entry
    cache.delete(f"user_list:active")   # Remove related caches
    return user
```

### Versioned Keys
```python
# Store version in user record
user.version = 5
cache_key = f"user:{user_id}:v{user.version}"

# Write: increment version → new cache key → old key expires naturally
# Read: look up current version → fetch specific versioned key
# No explicit invalidation needed
```

### Cache-Aside with Stale-While-Revalidate
```python
def get_user(user_id: str) -> User:
    cached, meta = cache.get_with_meta(f"user:{user_id}")

    if cached and not is_expired(meta):
        return cached

    if cached and is_expired(meta):
        # Return stale data immediately
        # Trigger background refresh
        background_refresh(user_id)
        return cached  # Stale but fast

    # Total miss → load from DB
    user = db.query(User).get(user_id)
    cache.set(f"user:{user_id}", user, ttl=3600)
    return user
```

## HTTP Caching

### Response Headers
```
Cache-Control: public, max-age=3600, s-maxage=7200
# public = can be cached by CDN
# max-age = browser cache time (1 hour)
# s-maxage = shared cache time (2 hours — CDN can hold longer)

Cache-Control: no-cache
# Can cache, but must revalidate before use

Cache-Control: no-store
# Don't cache at all (auth responses, sensitive data)

ETag: "abc123"
If-None-Match: "abc123"
# Conditional request: "give me this resource only if it changed"
# Response: 304 Not Modified (no body = fast)
```

### Cache Keys for CDN
```
Cache key: method + host + path + query params (sorted)
Vary: Accept-Encoding  # Different cache for gzip vs brotli
Vary: Authorization    # Different cache per user (careful: fragments cache)
```

## Redis as Application Cache

```python
# String: simple key-value
redis.set("user:42", json.dumps(user), ex=3600)

# Hash: object fields (can update single field)
redis.hset("user:42", mapping={"name": "Alice", "email": "alice@test.com"})
redis.hget("user:42", "name")  # Only get one field

# Set: unique items (online users, tags)
redis.sadd("online_users", "42")
redis.smembers("online_users")

# Sorted set: leaderboard, rate limiting
redis.zadd("leaderboard", {"user:42": 1000})
redis.zrevrange("leaderboard", 0, 9, withscores=True)  # Top 10
```

## Anti-Patterns

- **Caching without invalidation**: stale data forever
- **Caching everything blindly**: cache only what's slow (> 50ms) and frequently read (> 10 req/s)
- **Infinite TTL**: memory fills up, never reflects reality — always set a TTL
- **Cache as primary storage**: cache is ephemeral — data must survive cache flush
- **Thundering herd**: 1000 requests hit cache simultaneously on miss → lock/semaphore the miss path
- **Big cache keys**: storing entire user list as one key → expensive to serialize/deserialize, hard to invalidate partially
- **No cache hit metrics**: you don't know if your cache is actually working
