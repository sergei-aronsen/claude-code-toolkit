---
name: Python Expert
description: Deep expertise in Python - FastAPI/Django, async patterns, Pydantic v2, SQLAlchemy 2.0
---

# Python Expert Skill

This skill provides deep Python expertise including FastAPI/Django patterns, async handling, Pydantic v2 validation, SQLAlchemy 2.0, and security best practices.

---

## Pydantic v2 (IMPORTANT!)

### Always Use v2 Syntax

```python
from pydantic import BaseModel, Field, ConfigDict, EmailStr, field_validator

# ✅ Pydantic v2 syntax
class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    age: int | None = Field(default=None, ge=0, le=150)

class UserResponse(BaseModel):
    id: int
    email: str
    name: str

    model_config = ConfigDict(from_attributes=True)

# ❌ Pydantic v1 syntax (DON'T USE!)
class UserOld(BaseModel):
    class Config:           # Wrong! Use model_config
        orm_mode = True     # Wrong! Use from_attributes
```

### Validation

```python
from pydantic import field_validator, model_validator

class OrderCreate(BaseModel):
    items: list[OrderItem]
    discount_code: str | None = None

    @field_validator('items')
    @classmethod
    def validate_items(cls, v: list[OrderItem]) -> list[OrderItem]:
        if not v:
            raise ValueError('Order must have at least one item')
        return v

    @model_validator(mode='after')
    def validate_order(self) -> 'OrderCreate':
        if self.discount_code and len(self.items) < 3:
            raise ValueError('Discount requires at least 3 items')
        return self
```

---

## Async Patterns

### Always await I/O Operations

```python
# ✅ Correct - async for I/O
async def get_user(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# ✅ Parallel operations
async def get_dashboard_data(db: AsyncSession, user_id: int):
    user, posts, notifications = await asyncio.gather(
        get_user(db, user_id),
        get_user_posts(db, user_id),
        get_notifications(db, user_id),
    )
    return {"user": user, "posts": posts, "notifications": notifications}

# ❌ Sequential when could be parallel
async def get_dashboard_data_slow(db: AsyncSession, user_id: int):
    user = await get_user(db, user_id)
    posts = await get_user_posts(db, user_id)  # Doesn't depend on user
    notifications = await get_notifications(db, user_id)
    return {"user": user, "posts": posts, "notifications": notifications}
```

### Background Tasks

```python
from fastapi import BackgroundTasks

async def send_email(email: str, message: str):
    # Simulate sending
    await asyncio.sleep(1)
    print(f"Email sent to {email}")

@router.post("/users")
async def create_user(
    data: UserCreate,
    background_tasks: BackgroundTasks,
    db: DB,
) -> UserResponse:
    user = await user_service.create(db, data)
    background_tasks.add_task(send_email, user.email, "Welcome!")
    return UserResponse.model_validate(user)
```

---

## SQLAlchemy 2.0 Patterns

### Model Definition

```python
from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from datetime import datetime

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    posts: Mapped[list["Post"]] = relationship(back_populates="author")
```

### N+1 Prevention

```python
from sqlalchemy import select
from sqlalchemy.orm import selectinload, joinedload

# ❌ N+1 problem
async def get_users_with_posts_bad(db: AsyncSession):
    result = await db.execute(select(User))
    users = result.scalars().all()
    for user in users:
        # Each access triggers a query!
        print(user.posts)

# ✅ Eager loading with selectinload
async def get_users_with_posts(db: AsyncSession) -> list[User]:
    result = await db.execute(
        select(User).options(selectinload(User.posts))
    )
    return result.scalars().all()

# ✅ joinedload for single-object relationships
async def get_posts_with_authors(db: AsyncSession) -> list[Post]:
    result = await db.execute(
        select(Post).options(joinedload(Post.author))
    )
    return result.unique().scalars().all()
```

### Repository Pattern

```python
class UserRepository:
    async def get_by_id(self, db: AsyncSession, user_id: int) -> User | None:
        result = await db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_email(self, db: AsyncSession, email: str) -> User | None:
        result = await db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def create(self, db: AsyncSession, data: UserCreate) -> User:
        user = User(**data.model_dump())
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user

    async def update(self, db: AsyncSession, user: User, data: UserUpdate) -> User:
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(user, key, value)
        await db.commit()
        await db.refresh(user)
        return user
```

---

## FastAPI Dependency Injection

### Type Aliases for Dependencies

```python
from fastapi import Depends
from typing import Annotated

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await user_repository.get_by_id(db, payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# Type aliases
DB = Annotated[AsyncSession, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]

# Clean usage
@router.get("/me")
async def get_me(user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(user)

@router.get("/users")
async def list_users(db: DB, user: CurrentUser) -> list[UserResponse]:
    users = await user_repository.get_all(db)
    return [UserResponse.model_validate(u) for u in users]
```

---

## Security Checklist

### Input Validation

```python
# ✅ Always use Pydantic
@router.post("/users")
async def create_user(data: UserCreate) -> UserResponse:  # Validated automatically
    ...

# ✅ Path parameter validation
@router.get("/users/{user_id}")
async def get_user(user_id: int = Path(gt=0)) -> UserResponse:
    ...
```

### SQL Injection Prevention

```python
# ✅ SQLAlchemy ORM (parameterized)
result = await db.execute(select(User).where(User.email == user_input))

# ✅ Raw query with parameters
result = await db.execute(
    text("SELECT * FROM users WHERE email = :email"),
    {"email": user_input}
)

# ❌ NEVER use f-strings in queries
result = await db.execute(text(f"SELECT * FROM users WHERE email = '{user_input}'"))
```

### Password Hashing

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)
```

### Rate Limiting

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/auth/login")
@limiter.limit("5/minute")
async def login(request: Request, data: LoginRequest) -> TokenResponse:
    ...
```

---

## Testing Patterns (pytest)

### Async Test with Fixtures

```python
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSession(engine) as session:
        yield session

@pytest.fixture
async def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_create_user(client: AsyncClient):
    response = await client.post("/api/users", json={"email": "test@example.com", "name": "Test"})
    assert response.status_code == 201
```

---

## Common Commands

```bash
# Development
uv run uvicorn src.main:app --reload

# Testing
uv run pytest
uv run pytest -v --cov=src

# Code Quality
uv run ruff check .
uv run ruff check . --fix
uv run ruff format .
uv run mypy src/

# Dependencies
uv add package
uv add --dev pytest
uv sync
```
