# Plowth — 프로젝트 완전 핸드오프 문서
# AI 학습 운영체제 앱 | 다른 개발 환경에서 이어가기 위한 전체 컨텍스트

> 생성일: 2026-04-09
> 이 문서 하나로 어떤 AI 개발 환경에서든 Plowth 프로젝트를 이어서 진행할 수 있습니다.

---

# ═══════════════════════════════════════════════════
# PART 1: 프로젝트 요약 + 확정된 의사결정
# ═══════════════════════════════════════════════════

## 1.1 프로젝트 정체성

- **앱 이름:** Plowth (Plus + Growth)
- **슬로건:** "설정 없는 Anki, 얕지 않은 Duolingo, 학습 맥락을 이해하는 AI 튜터"
- **핵심 루프:** Capture → Generate → Review → Analyze → Explain → Insight

## 1.2 확정된 의사결정 (10개)

| # | 항목 | 결정 | 근거 |
|---|------|------|------|
| 1 | 앱 이름 | **Plowth** (Plus + Growth) | 성장을 더하는 학습 도구 |
| 2 | 초기 타겟 도메인 | **1순위: 시험/자격증, 2순위: 언어 학습** | 범용은 프롬프트 품질 흐려짐, 의학은 리스크 큼 |
| 3 | AI 모델 | **멀티모델** (벤더 교체 가능 설계) | PRIMARY/SECONDARY/EMBEDDING 슬롯 |
| 4 | 모바일 프레임워크 | **Flutter 3.x** | 카드 전환 성능 최적, 오프라인 DB(Drift) 성숙 |
| 5 | 배포 환경 | **GCP** | Cloud Run + Cloud SQL + Memorystore + Cloud Storage |
| 6 | 인증: 소셜 로그인 | **Google + Apple** (MVP) | iOS 필수(Apple), Kakao는 한국 런칭 확정 후 |
| 7 | Anki import | **CSV import, Phase 3** | APKG 파싱 복잡, CSV가 Anki 기본 export |
| 8 | 게스트 데이터 보존 | **무기한 (로컬 SQLite)** | 서버 비용 0, 앱 삭제 시 자연 삭제 |
| 9 | 푸시 알림 | **FCM** | Flutter+GCP 생태계, 무료 |
| 10 | 이벤트 분석 | **Firebase Analytics** | Flutter 네이티브 통합, 기본 리텐션/퍼널 |

## 1.3 기술 스택

### 프론트엔드 (모바일)
- **Framework:** Flutter 3.29.2 (Dart 3.7.2)
- **상태관리:** Riverpod + Freezed (예정)
- **로컬 DB:** Drift (SQLite) (예정)
- **네트워킹:** Dio + Retrofit
- **푸시:** Firebase Cloud Messaging
- **현재 의존성:** google_fonts ^6.2.1, dio ^5.7.0, shared_preferences ^2.3.4

### 백엔드
- **API:** FastAPI (Python 3.10.4)
- **DB:** PostgreSQL 16 + pgvector (Cloud SQL)
- **캐시:** Redis 7 (Memorystore)
- **비동기 (사용자 트리거):** Cloud Tasks → Cloud Run
- **비동기 (스케줄 배치):** Cloud Scheduler → Cloud Run Jobs
- **파일:** Cloud Storage
- **인증:** JWT (자체) + Google/Apple 소셜
- **모니터링:** Cloud Logging + Sentry

### AI 오케스트레이션 (멀티모델, 벤더 교체 가능)
```
모델 슬롯:
├── PRIMARY (고성능): 카드 생성, 개념 추출 → MVP: Gemini 2.5 Pro
├── SECONDARY (경량): 설명, 코칭, 오답 분석 → MVP: Gemini 2.0 Flash
└── EMBEDDING: 유사도, 중복 탐지 → MVP: text-embedding-004

추상화 레이어:
├── ModelRouter: 기능별 모델 선택 (config 기반, 코드 변경 없이 교체)
├── PromptManager: 프롬프트 템플릿 관리
├── CostController: 사용량 추적, 캐시, 한도 제어
└── QualityGate: 출력 검증
```

## 1.4 현재 진행 상황

**Phase 1 (Foundation + Onboarding): 대부분 완료**

### ✅ 완료
- FastAPI 프로젝트 세팅 + Docker Compose
- DB 스키마 17개 테이블 ORM 모델
- Auth API (회원가입, 로그인, JWT 리프레시, 게스트 토큰, 게스트→정식 마이그레이션)
- Source/Card/Review CRUD API
- Flutter 프로젝트 세팅 + 프리미엄 다크 테마 디자인 시스템
- 온보딩 플로우 (가치 제안 → 학습 목표 → 진입 방식)
- 홈 화면 + 5탭 네비게이션
- 동기화 전략 설계 문서
- flutter analyze 통과 (No issues found)

### ⏳ 남은 Phase 1 항목
- Alembic DB 마이그레이션 (Docker 기동 후 실행)
- Drift(SQLite) 로컬 DB 세팅
- Dio API 연동

### ⬜ Phase 2~4 (미착수)
- Phase 2: Core Loop (AI 카드 생성 파이프라인, FSRS 복습, 리뷰 세션 UI)
- Phase 3: Intelligence (AI 설명, 오답 분석, 인사이트)
- Phase 4: Polish & Launch (동기화, 결제, 최적화)

---

# ═══════════════════════════════════════════════════
# PART 2: 프로젝트 구조 + 파일 트리
# ═══════════════════════════════════════════════════

```
Plowth/
├── README.md
├── docs/
│   ├── 어플 상세 초안.md                    # PRD (988줄)
│   └── sync-strategy.md                     # 동기화 전략 설계
│
├── backend/
│   ├── .env / .env.example
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── config.py                        # Pydantic Settings
│       ├── database.py                      # SQLAlchemy async engine
│       ├── dependencies.py                  # JWT 인증 dependency
│       ├── main.py                          # FastAPI entry point
│       ├── api/
│       │   ├── __init__.py
│       │   ├── auth.py                      # register, login, guest, upgrade, refresh, me
│       │   ├── sources.py                   # CRUD for learning materials
│       │   ├── cards.py                     # CRUD for flashcards
│       │   └── reviews.py                   # review queue, submit, history
│       ├── models/
│       │   └── __init__.py                  # 17 SQLAlchemy ORM models
│       ├── schemas/
│       │   └── __init__.py                  # Pydantic request/response schemas
│       └── services/
│           ├── __init__.py
│           └── auth_service.py              # password hashing, JWT, user queries
│
├── mobile/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart                        # App entry + MainShell (5-tab nav)
│       ├── app/theme/
│       │   └── app_theme.dart               # Design system (colors, typography, spacing)
│       └── features/
│           ├── home/
│           │   └── home_screen.dart         # Dashboard with gradient summary card
│           └── onboarding/
│               └── onboarding_screen.dart   # 3-step onboarding flow
│
└── infra/
    └── docker-compose.yml                   # PostgreSQL + Redis
```

---

# ═══════════════════════════════════════════════════
# PART 3: 전체 소스코드
# ═══════════════════════════════════════════════════

## 3.1 Backend

### backend/.env.example
```env
# Database
DATABASE_URL=postgresql+asyncpg://real_user:real_dev_password@localhost:5432/real_db

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET_KEY=your-super-secret-key-change-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30

# AI
GEMINI_API_KEY=your-gemini-api-key

# App
APP_ENV=development
APP_DEBUG=true
APP_NAME=Plowth
```

### backend/requirements.txt
```txt
# Web Framework
fastapi==0.115.12
uvicorn[standard]==0.34.2
python-multipart==0.0.20

# Database
sqlalchemy[asyncio]==2.0.40
asyncpg==0.30.0
alembic==1.15.2
pgvector==0.4.1

# Redis / Celery
redis==5.3.0
celery[redis]==5.5.1

# Auth
python-jose[cryptography]==3.4.0
passlib[bcrypt]==1.7.4
bcrypt==4.3.0

# Validation / Serialization
pydantic==2.11.3
pydantic-settings==2.9.1
email-validator==2.2.0

# AI
google-genai==1.16.1
httpx==0.28.1

# PDF Processing
pymupdf==1.25.5

# Utilities
python-dotenv==1.1.0
structlog==25.4.0
```

### backend/app/__init__.py
```python
# Plowth backend app package
```

### backend/app/config.py
```python
"""
Plowth - AI Learning OS
Application configuration module.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    APP_NAME: str = "Plowth"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://real_user:real_dev_password@localhost:5432/real_db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT
    JWT_SECRET_KEY: str = "dev-secret-key-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # AI
    GEMINI_API_KEY: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

### backend/app/database.py
```python
"""
Database session and engine configuration.
"""

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.APP_DEBUG,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""
    pass


async def get_db() -> AsyncSession:
    """FastAPI dependency that provides a database session."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
```

### backend/app/dependencies.py
```python
"""
FastAPI dependency for extracting the current authenticated user from JWT.
"""

from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.services.auth_service import decode_token, get_user_by_id

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extract and validate the current user from the Authorization header."""
    payload = decode_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    token_type = payload.get("type")
    if token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID in token",
        )

    user = await get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )

    return user
```

### backend/app/main.py
```python
"""
Plowth - AI Learning OS
FastAPI application entry point.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine, Base
from app.api import auth, sources, cards, reviews

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: create tables on startup."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=f"{settings.APP_NAME} API",
    description="AI-powered learning operating system — API server",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS — allow mobile app and web admin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(sources.router, prefix="/api/v1")
app.include_router(cards.router, prefix="/api/v1")
app.include_router(reviews.router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": "0.1.0"}
```

### backend/app/services/auth_service.py
```python
"""
Authentication service: password hashing, JWT token creation/verification.
"""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models import User

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "type": "access",
        "exp": expire,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "exp": expire,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict | None:
    """Decode and validate a JWT token. Returns payload or None if invalid."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def create_user(db: AsyncSession, email: str, password: str, name: str | None = None) -> User:
    user = User(
        email=email,
        hashed_password=hash_password(password),
        name=name,
    )
    db.add(user)
    await db.flush()
    return user


async def authenticate_user(db: AsyncSession, email: str, password: str) -> User | None:
    user = await get_user_by_email(db, email)
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user
```

### backend/app/api/__init__.py
```python
# API routes package
```

### backend/app/api/auth.py
```python
"""
Authentication API endpoints: register, login, refresh, guest, upgrade, profile.
"""

import uuid as uuid_mod

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Subscription, LearningProfile
from app.schemas import (
    UserRegister, UserLogin, TokenResponse, TokenRefresh, UserResponse,
    GuestRequest, GuestUpgradeRequest,
)
from app.services.auth_service import (
    create_user, authenticate_user, get_user_by_email,
    create_access_token, create_refresh_token, decode_token,
    hash_password,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(body: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user account."""
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user = await create_user(db, email=body.email, password=body.password, name=body.name)

    # Create default subscription (free tier)
    subscription = Subscription(user_id=user.id, plan="free")
    db.add(subscription)

    # Create empty learning profile
    profile = LearningProfile(user_id=user.id)
    db.add(profile)

    await db.flush()

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: UserLogin, db: AsyncSession = Depends(get_db)):
    """Authenticate user and return tokens."""
    user = await authenticate_user(db, body.email, body.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/guest", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def guest_login(body: GuestRequest, db: AsyncSession = Depends(get_db)):
    """Create a guest session. No email/password required."""
    result = await db.execute(
        select(User).where(User.device_id == body.device_id, User.is_guest == True)
    )
    existing_guest = result.scalar_one_or_none()

    if existing_guest:
        return TokenResponse(
            access_token=create_access_token(existing_guest.id),
            refresh_token=create_refresh_token(existing_guest.id),
        )

    guest = User(
        is_guest=True,
        auth_provider="guest",
        device_id=body.device_id,
        preferences={"learning_goal": body.learning_goal} if body.learning_goal else {},
    )
    db.add(guest)
    await db.flush()

    return TokenResponse(
        access_token=create_access_token(guest.id),
        refresh_token=create_refresh_token(guest.id),
    )


@router.post("/upgrade", response_model=TokenResponse)
async def upgrade_guest(
    body: GuestUpgradeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upgrade a guest account to a full registered account."""
    if not current_user.is_guest:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is already registered",
        )

    existing = await get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    current_user.email = body.email
    current_user.hashed_password = hash_password(body.password)
    current_user.name = body.name
    current_user.is_guest = False
    current_user.auth_provider = "email"

    if not current_user.subscription:
        db.add(Subscription(user_id=current_user.id, plan="free"))
    if not current_user.learning_profile:
        db.add(LearningProfile(user_id=current_user.id))

    await db.flush()

    return TokenResponse(
        access_token=create_access_token(current_user.id),
        refresh_token=create_refresh_token(current_user.id),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(body: TokenRefresh, db: AsyncSession = Depends(get_db)):
    """Refresh an access token using a valid refresh token."""
    payload = decode_token(body.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = uuid_mod.UUID(payload["sub"])

    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


@router.get("/me", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Get current user's profile."""
    return current_user
```

### backend/app/api/sources.py
```python
"""
Sources API: CRUD for learning materials (text, PDF, links).
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Source
from app.schemas import SourceCreate, SourceResponse, SourceDetail

router = APIRouter(prefix="/sources", tags=["Sources"])


@router.post("", response_model=SourceResponse, status_code=status.HTTP_201_CREATED)
async def create_source(
    body: SourceCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a new learning material."""
    if body.source_type == "text" and not body.raw_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="raw_content is required for text sources",
        )
    if body.source_type == "link" and not body.url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="url is required for link sources",
        )

    source = Source(
        user_id=current_user.id,
        title=body.title,
        source_type=body.source_type,
        raw_content=body.raw_content,
        url=body.url,
        status="uploaded",
    )
    db.add(source)
    await db.flush()

    # TODO: Phase 2 — trigger async card generation job here

    return source


@router.get("", response_model=list[SourceResponse])
async def list_sources(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List user's learning materials."""
    result = await db.execute(
        select(Source)
        .where(Source.user_id == current_user.id)
        .order_by(Source.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/{source_id}", response_model=SourceDetail)
async def get_source(
    source_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get details of a specific source."""
    result = await db.execute(
        select(Source).where(Source.id == source_id, Source.user_id == current_user.id)
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Source not found")
    return source


@router.delete("/{source_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_source(
    source_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a source and its associated cards."""
    result = await db.execute(
        select(Source).where(Source.id == source_id, Source.user_id == current_user.id)
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Source not found")

    await db.delete(source)
```

### backend/app/api/cards.py
```python
"""
Cards API: CRUD for flashcards.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Card
from app.schemas import CardCreate, CardUpdate, CardResponse

router = APIRouter(prefix="/cards", tags=["Cards"])


@router.post("", response_model=CardResponse, status_code=status.HTTP_201_CREATED)
async def create_card(
    body: CardCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a manual flashcard."""
    card = Card(
        user_id=current_user.id,
        source_id=body.source_id,
        concept_id=body.concept_id,
        card_type=body.card_type,
        question=body.question,
        answer=body.answer,
        difficulty=body.difficulty,
    )
    db.add(card)
    await db.flush()
    return card


@router.get("", response_model=list[CardResponse])
async def list_cards(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    source_id: UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    active_only: bool = True,
):
    """List user's flashcards, optionally filtered by source."""
    query = select(Card).where(Card.user_id == current_user.id)

    if source_id:
        query = query.where(Card.source_id == source_id)
    if active_only:
        query = query.where(Card.is_active == True)

    query = query.order_by(Card.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific card."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")
    return card


@router.patch("/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: UUID,
    body: CardUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a card's content."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(card, field, value)

    await db.flush()
    return card


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_card(
    card_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a card."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")

    await db.delete(card)
```

### backend/app/api/reviews.py
```python
"""
Reviews API: submit reviews and get review queue.
"""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Card, Review, MemoryState
from app.schemas import ReviewCreate, ReviewResponse, ReviewSessionSummary

router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.get("/queue")
async def get_review_queue(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
):
    """Get today's review queue — cards due for review."""
    now = datetime.now(timezone.utc)

    result = await db.execute(
        select(Card)
        .join(MemoryState, MemoryState.card_id == Card.id, isouter=True)
        .where(
            Card.user_id == current_user.id,
            Card.is_active == True,
        )
        .where(
            (MemoryState.next_review_at <= now) | (MemoryState.id == None)
        )
        .order_by(
            MemoryState.next_review_at.asc().nulls_first()
        )
        .limit(limit)
    )
    cards = result.scalars().all()

    return [
        {
            "id": str(card.id),
            "question": card.question,
            "answer": card.answer,
            "card_type": card.card_type,
            "difficulty": card.difficulty,
        }
        for card in cards
    ]


@router.post("", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def submit_review(
    body: ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit a review for a card (append-only)."""
    card_result = await db.execute(
        select(Card).where(Card.id == body.card_id, Card.user_id == current_user.id)
    )
    card = card_result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")

    # Idempotent check
    if body.client_id:
        existing = await db.execute(
            select(Review).where(
                Review.client_id == body.client_id,
                Review.user_id == current_user.id,
            )
        )
        existing_review = existing.scalar_one_or_none()
        if existing_review:
            return existing_review

    review = Review(
        user_id=current_user.id,
        card_id=body.card_id,
        rating=body.rating,
        response_time_ms=body.response_time_ms,
        client_id=body.client_id,
    )
    db.add(review)

    # Update or create memory state (placeholder for FSRS)
    # TODO: Phase 2 — replace with full FSRS calculation
    ms_result = await db.execute(
        select(MemoryState).where(
            MemoryState.user_id == current_user.id,
            MemoryState.card_id == body.card_id,
        )
    )
    memory_state = ms_result.scalar_one_or_none()

    if not memory_state:
        memory_state = MemoryState(
            user_id=current_user.id,
            card_id=body.card_id,
        )
        db.add(memory_state)

    # Simple interval mapping (placeholder for FSRS)
    from datetime import timedelta
    interval_map = {
        "again": timedelta(minutes=1),
        "hard": timedelta(hours=6),
        "good": timedelta(days=1),
        "easy": timedelta(days=4),
    }

    now = datetime.now(timezone.utc)
    memory_state.reps += 1
    memory_state.last_review_at = now
    memory_state.next_review_at = now + interval_map[body.rating]

    if body.rating == "again":
        memory_state.lapses += 1
        memory_state.state = "relearning"
    elif memory_state.state == "new":
        memory_state.state = "learning"
    else:
        memory_state.state = "review"

    await db.flush()
    return review


@router.get("/history", response_model=list[ReviewResponse])
async def get_review_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    card_id: UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
):
    """Get review history, optionally filtered by card."""
    query = select(Review).where(Review.user_id == current_user.id)

    if card_id:
        query = query.where(Review.card_id == card_id)

    query = query.order_by(Review.reviewed_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
```

### backend/app/models/__init__.py
> ⚠️ 이 파일은 372줄입니다. 17개 ORM 테이블을 포함합니다.
> 전체 코드는 d:\REAL\backend\app\models\__init__.py 파일을 직접 참조하세요.
> 테이블 목록: users, sources, source_chunks, concepts, concept_relations,
> cards, reviews, memory_states, daily_review_queue, mistake_patterns,
> learning_profiles, interventions, jobs, subscriptions, sync_events,
> ai_cache, ai_usage_log

### backend/app/schemas/__init__.py
> ⚠️ 이 파일은 172줄입니다. 전체 Pydantic 스키마를 포함합니다.
> 주요 스키마: UserRegister, UserLogin, TokenResponse, TokenRefresh,
> GuestRequest, GuestUpgradeRequest, UserResponse,
> SourceCreate, SourceResponse, SourceDetail,
> CardCreate, CardUpdate, CardResponse,
> ReviewCreate, ReviewResponse, ReviewSessionSummary,
> JobResponse, DailyInsight, WeakConcept

---

## 3.2 Infrastructure

### infra/docker-compose.yml
```yaml
version: "3.9"

services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: real_postgres
    environment:
      POSTGRES_USER: real_user
      POSTGRES_PASSWORD: real_dev_password
      POSTGRES_DB: real_db
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U real_user -d real_db"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: real_redis
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
  redisdata:
```

---

## 3.3 Mobile (Flutter)

### mobile/pubspec.yaml
```yaml
name: real_app
description: "AI-powered learning operating system"
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.7.2

dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
  dio: ^5.7.0
  shared_preferences: ^2.3.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

### mobile/lib/main.dart
> 앱 엔트리 포인트 + MainShell (5탭 네비게이션)
> 전체 코드: d:\REAL\mobile\lib\main.dart (112줄)

### mobile/lib/app/theme/app_theme.dart
> 프리미엄 다크 테마 디자인 시스템 (175줄)
> AppColors, AppTypography (Outfit + Inter), AppSpacing, AppRadius, AppShadows

### mobile/lib/features/home/home_screen.dart
> 홈 대시보드 (215줄)
> 그라디언트 요약 카드, 빠른 액션 버튼

### mobile/lib/features/onboarding/onboarding_screen.dart
> 3단계 온보딩 플로우 (380줄)
> 가치 제안 3장 스와이프 → 학습 목표 선택 → 진입 방식 선택

> ⚠️ Flutter 파일 전체 코드는 각 파일 경로에서 직접 참조하세요.
> 위 4개 파일이 전체 Flutter 개발 파일입니다.

---

# ═══════════════════════════════════════════════════
# PART 4: 다음 단계 상세 로드맵
# ═══════════════════════════════════════════════════

## Phase 2: Core Loop + AI Pipeline (4주)

> 목표: Capture → AI Generate → Review 핵심 루프 완성

### 백엔드
1. AI Orchestrator 서비스 레이어 (ModelRouter, PromptManager, CostController)
2. Card Generation Pipeline v2
   - Chunking → 개념 추출 + 관계 추출 → 클러스터링 → 카드 생성 → 후처리 검증
   - Cloud Tasks 비동기 + 상태 폴링 API
3. concept_relations 테이블 활용
4. FSRS 복습 스케줄러 구현 (py-fsrs 기반)
   - 응답 시간 가중치, 개념 네트워크 연쇄 urgency
5. daily_review_queue 배치 생성 (Cloud Scheduler)
6. ai_usage_log 기록 시작

### 프론트엔드
1. Capture 화면 (텍스트 입력 → 분석 상태 → 카드 미리보기)
2. 카드 미리보기/편집 화면 (품질 경고 표시)
3. Review 세션 화면 (카드 플립, Again/Hard/Good/Easy, 응답 시간 측정)
4. 세션 완료 요약 화면
5. API 연동

## Phase 3: Intelligence (3주)
- Tutor AI (Why/Example/Related) + ai_cache 활용
- Mistake Analytics Engine
- Proactive Coaching Layer
- Insight 탭 (기억 강도, 약점, 히트맵, 스트릭)

## Phase 4: Polish & Launch (3주)
- 오프라인 동기화 (sync_events 기반)
- 결제/구독 (Stripe + 인앱결제)
- 푸시 알림 (FCM)
- 성능 최적화 + 앱 스토어 제출

---

# ═══════════════════════════════════════════════════
# PART 5: 핵심 설계 문서 참조
# ═══════════════════════════════════════════════════

## 참조 문서 목록
1. **PRD (제품 요구사항):** d:\REAL\docs\어플 상세 초안.md (988줄)
2. **동기화 전략:** d:\REAL\docs\sync-strategy.md
3. **구현 계획서 v4:** 이 문서의 PART 1 참조

## 주의사항
- Flutter 3.7+ 호환성: `withOpacity` 대신 `withValues(alpha: x)` 사용 필수
- DB 컨테이너 이름은 아직 `real_postgres` / `real_redis` (Plowth로 변경 필요)
- pubspec.yaml의 `name: real_app`도 `plowth_app`으로 변경 필요
- 패키지 ID (com.xxx.plowth)는 아직 미설정

---
## 2026-04-09 Status Update

- Phase 1 and the core Phase 2 flow are implemented in the current codebase.
- Backend scope now includes auth, text-source ingest, async card generation, card CRUD, review queue/submission, and today's review summary.
- Mobile scope now includes onboarding, guest session bootstrap, home snapshot, text capture, generation polling, review flow, and local persistence.
- Local validation completed on 2026-04-09:
  - `cd backend && python -m unittest test_phase2_services.py` -> 5 tests passing
  - `cd mobile && flutter test test/local_database_repository_test.dart` -> 2 tests passing
  - `cd mobile && flutter analyze` -> no issues found
- Remaining roadmap focus: Phase 3 Intelligence, Phase 4 Polish & Launch, `pdf`/`link` ingest, and production hardening.

END OF HANDOFF DOCUMENT
