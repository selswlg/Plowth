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
- [~] Phase 3: Intelligence (Insight 스냅샷, 약점 개념, 코칭 시작)
- [ ] Phase 4: Polish & Launch (동기화, 결제, 최적화)

## 📝 후속 확인 메모

- Source ingest는 현재 런타임 기준 `text` 캡처, `csv` import, `link` ingest, 텍스트 기반 `pdf` ingest를 지원함
- 이미지/OCR, Anki `.apkg`, Share Sheet, Clipboard 자동 감지는 후속 확장으로 보류

## 🎯 타겟 도메인

- 1순위: 시험/자격증 준비
- 2순위: 언어 학습
## 2026-04-11 Update

- Roadmap status: Phase 1 and Phase 2 are implemented in code, and the first Phase 3 Intelligence slice is now landed.
- Backend currently covers auth, text-source ingest, vocabulary-list text capture, CSV preview/import, link ingest, text-based PDF ingest, domain-tagged card generation/edit metadata, card CRUD, review queue/submission, today's review summary, Cognitive Update preview/apply, the Insight snapshot API with mistake/profile tracking, and cached Tutor endpoints for `explain` / `example` / `related`.
- Mobile currently covers onboarding, guest session bootstrap, access-token refresh before study API calls, home snapshot, titleless text capture, CSV file import with column mapping, URL capture, PDF upload, transient capture status feedback, Review tab auto-refresh, domain-aware review labels, domain-specific card editing from Home, Cognitive Update from the Insight tab, home generation status, review flow, local persistence, the Insight tab, and Tutor actions in the review flow.
- Local validation completed:
  - `cd backend && python -m unittest test_phase2_services.py` -> 26 tests passing
  - `cd mobile && flutter test` -> 8 tests passing
  - `cd mobile && flutter analyze` -> no issues found
- Current gaps: scanned PDF/OCR, deeper Phase 3 intelligence features, and Phase 4 launch hardening.
