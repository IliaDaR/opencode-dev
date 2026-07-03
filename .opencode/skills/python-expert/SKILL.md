---
name: python-expert
description: Use when writing Python code, designing Python APIs, optimizing Python performance, handling async Python, or debugging Python-specific issues. Covers modern Python 3.11+ patterns.
---

# Python Expert

## Modern Python Features

### Structural Pattern Matching (3.10+)
```python
match command:
    case {"action": "move", "x": x, "y": y}:
        move(x, y)
    case {"action": "attack", "target": target}:
        attack(target)
    case {"action": "quit"}:
        quit()
    case _:
        print(f"Unknown command: {command}")
```

### Type Hints (use them!)
```python
from typing import TypeVar, Generic, Protocol

T = TypeVar("T")

class Repository(Protocol[T]):
    def get(self, id: str) -> T | None: ...
    def save(self, entity: T) -> None: ...
    def list(self, limit: int = 50) -> list[T]: ...

# Protocol = structural typing (anything with these methods fits)
def process(repo: Repository[User]) -> None:
    user = repo.get("42")
    if user:
        print(user.name)
```

### Data Classes
```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True)  # Immutable!
class Order:
    id: str
    user_id: str
    items: list[str]
    created_at: datetime = field(default_factory=datetime.utcnow)
    status: str = "pending"

# frozen=True → you get __hash__ for free, can use in sets/dicts
```

### Pydantic for Runtime Validation
```python
from pydantic import BaseModel, Field, field_validator

class CreateUserRequest(BaseModel):
    model_config = {"extra": "forbid"}  # Reject unknown fields

    email: str = Field(min_length=5, max_length=254)
    name: str = Field(min_length=1, max_length=100)
    age: int = Field(ge=0, le=150)

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("Invalid email")
        return v.lower()
```

## Error Handling

```python
# Custom exception hierarchy
class AppError(Exception):
    def __init__(self, message: str, code: str):
        self.message = message
        self.code = code
        super().__init__(message)

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str):
        super().__init__(f"{resource} {id} not found", "NOT_FOUND")

class ValidationError(AppError):
    def __init__(self, errors: dict[str, str]):
        super().__init__("Validation failed", "VALIDATION_ERROR")
        self.errors = errors

# Catching specific errors
try:
    user = repo.get(user_id)
    if not user:
        raise NotFoundError("User", user_id)
except NotFoundError as e:
    return {"error": e.code, "message": e.message}, 404
except AppError as e:
    return {"error": e.code, "message": e.message}, 400
# Don't catch Exception unless you truly mean it
```

## Async Python

```python
import asyncio

# Concurrent I/O operations
async def fetch_all(urls: list[str]) -> list[dict]:
    async with aiohttp.ClientSession() as session:
        tasks = [fetch(session, url) for url in urls]
        return await asyncio.gather(*tasks)

async def fetch(session: aiohttp.ClientSession, url: str) -> dict:
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
        return await resp.json()

# DON'T: mix sync blocking calls in async code
# Bad:  data = requests.get(url)  — blocks event loop
# Good: data = await aiohttp_client.get(url)

# Task groups (3.11+): if one fails, all cancel
async def process():
    async with asyncio.TaskGroup() as tg:
        tg.create_task(fetch_x())
        tg.create_task(fetch_y())
        tg.create_task(fetch_z())
    # All completed or all cancelled
```

## Project Structure

```
project/
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── main.py           # Entry point
│       ├── config.py         # Settings, env vars
│       ├── models/           # Data models (Pydantic/SQLAlchemy)
│       ├── services/         # Business logic
│       ├── repositories/     # Data access
│       ├── api/              # FastAPI/Flask routes
│       └── utils/            # Shared utilities
├── tests/
│   ├── conftest.py           # Fixtures
│   ├── test_services/
│   └── test_api/
├── pyproject.toml            # Dependencies, tools config
├── Dockerfile
└── README.md
```

## Dependency Management

```toml
# pyproject.toml (modern standard)
[project]
name = "myapp"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110.0",
    "sqlalchemy[asyncio]>=2.0",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "ruff>=0.3",
    "mypy>=1.8",
]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

## Performance

```python
# Use list comprehensions, not map/filter with lambda
squares = [x**2 for x in range(1000)]  # Fast
squares = list(map(lambda x: x**2, range(1000)))  # Slower

# Use generators for large data
def read_large_file(path: str):
    with open(path) as f:
        for line in f:
            yield line.strip()
# Memory: ~one line at a time, not the whole file

# LRU cache for expensive pure functions
from functools import lru_cache

@lru_cache(maxsize=128)
def expensive_computation(x: int) -> int:
    return x ** x  # Only computed once per unique x
```

## Anti-Patterns

- **Mutable default arguments**: `def f(items=[])` — use `def f(items=None)` + `items = items or []`
- **Bare except**: `except:` catches Ctrl+C, SystemExit — use `except Exception:`
- **Using `assert` for runtime validation**: `assert` is removed with `-O` flag — use explicit `if`/`raise`
- **Checking type with `type()`**: breaks with subclasses — use `isinstance()`
- **String formatting with `%`**: use f-strings: `f"Hello {name}"`
- **`from module import *`**: pollutes namespace, makes code unreadable
