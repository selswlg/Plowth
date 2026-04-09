# Plowth — AI 학습 운영체제

> **설정 없는 Anki, 얕지 않은 Duolingo, 학습 맥락을 이해하는 AI 튜터**

AI가 학습 자료를 자동으로 구조화하고, 개인별 기억 곡선과 실수 패턴을 반영해 복습·이해·약점 보완까지 수행하는 학습 운영체제형 앱.

**Plowth = Plus + Growth** — 성장을 더하는 학습 도구.

## 📂 프로젝트 구조

```
Plowth/
├── docs/               # 제품 문서
│   ├── 어플 상세 초안.md
│   └── sync-strategy.md
├── backend/            # FastAPI 백엔드 서버
│   └── app/
│       ├── api/        # API 라우터 (auth, sources, cards, reviews)
│       ├── models/     # SQLAlchemy ORM 모델 (17 tables)
│       ├── schemas/    # Pydantic 요청/응답 스키마
│       └── services/   # 비즈니스 로직
├── mobile/             # Flutter 모바일 앱
│   └── lib/
│       ├── app/theme/  # 디자인 시스템
│       └── features/   # 기능별 화면 (onboarding, home, ...)
├── infra/              # Docker Compose (PostgreSQL, Redis)
└── README.md
```

## 🚀 시작하기

### 인프라 (PostgreSQL + Redis)

```bash
cd infra
docker-compose up -d
```

### 백엔드

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
cp .env.example .env          # 환경변수 설정
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API 문서: http://localhost:8000/docs

### 모바일 (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

## 🛠 기술 스택

| 영역 | 기술 |
|------|------|
| 모바일 | Flutter 3.x + Dart |
| 백엔드 | FastAPI + Python |
| DB | Cloud SQL (PostgreSQL 16 + pgvector) |
| 캐시 | Memorystore (Redis) |
| AI | 멀티모델 (PRIMARY/SECONDARY/EMBEDDING) |
| 비동기 | Cloud Tasks + Cloud Run Jobs |
| 배포 | GCP (Cloud Run) |
| 모니터링 | Cloud Logging + Sentry |
| 분석 | Firebase Analytics |

## 📋 개발 현황

- [x] Phase 1: Foundation + Onboarding
- [x] Phase 2: Core Loop (카드 생성 파이프라인, FSRS 복습, 리뷰 세션)
- [ ] Phase 3: Intelligence (AI 설명, 오답 분석, 인사이트)
- [ ] Phase 4: Polish & Launch (동기화, 결제, 최적화)

## 📝 후속 확인 메모

- Source ingest는 현재 런타임 기준 `text`만 지원함
- `pdf` / `link`는 스키마와 로드맵에 남아 있는 후속 타입이며, Phase 2 안정화 이후 다시 검토 예정

## 🎯 타겟 도메인

- 1순위: 시험/자격증 준비
- 2순위: 언어 학습
