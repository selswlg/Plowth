# Plowth Status Log

> 현황 파악, 리뷰 진행, 진행도 체크, 검증 내역, 의사결정, 리스크를 한곳에서 관리한다.
> 최신 상태는 위쪽에 유지하고, 히스토리는 append-only로 남긴다.

## 관리 규칙

- `Latest Snapshot`은 현재 작업 기준 상태를 짧게 갱신한다.
- `Review Log`는 현황 파악/코드 리뷰/문서 리뷰 결과를 날짜별로 누적한다.
- `Validation Log`는 실행한 테스트와 분석 명령, 결과, 실패 원인을 남긴다.
- `Progress Tracker`는 Phase 단위 완료/진행/대기 상태를 관리한다.
- `Open Items`는 바로 처리 가능한 작업부터 우선순위 순으로 유지한다.
- 이미 있는 사용자 변경사항은 되돌리지 않고, 새 작업은 이 문서에 먼저 흔적을 남긴다.

## Latest Snapshot

**Updated:** 2026-04-11 KST
**Branch:** `main`  
**Workspace:** `D:\REAL`  
**State:** Phase 0/A/B/C/D/E/F/G/H completed for the capture redesign. CSV import, link ingest, text-based PDF ingest, domain metadata generation, domain-specific card editing, concept-level priority signals, Cognitive Update preview/apply, token refresh before study API calls, vocabulary-list text capture, Review tab auto-refresh, and scheduler null-state hardening are implemented.

### Scope

- Backend: FastAPI, SQLAlchemy async, Alembic, PostgreSQL/Redis 설정
- Mobile: Flutter, Dio API 연동, Drift local DB
- Infra: Docker Compose PostgreSQL/Redis
- Docs: README, handoff, sync strategy, status log

### Current Product Progress

- Phase 1 Foundation + Onboarding: 완료
- Phase 2 Core Loop: 핵심 구현 완료
  - auth, text source ingest, async card generation, card CRUD
  - review queue/submission, today's review summary
  - mobile onboarding, home, capture, review flow, local persistence
- Phase 3 Intelligence: 착수 및 일부 구현
  - Insight snapshot API와 mobile Insight tab 추가
  - Tutor endpoint/service와 mobile tutor sheet 추가
  - mistake/profile tracking 일부 추가
- Phase 4 Polish & Launch: 대기

### Current Technical Status

- Backend unit tests pass.
- Flutter tests pass.
- Flutter analyzer currently passes.
- Docker containers `plowth_postgres` and `plowth_redis` were healthy during the latest local check.

## Progress Tracker

| Area | Status | Notes |
|---|---|---|
| Phase 1 Foundation | Done | Backend/mobile skeleton and onboarding in place |
| Phase 2 Core Loop | Done | Text capture to card generation to review flow implemented |
| Phase 2.5 Capture Stabilization | Done | Phase 0/A completed: clean validation, titleless text capture, Home generation status |
| Phase B Input Contract | Done | text/csv/link/pdf endpoint and job ownership contract documented |
| Phase C CSV Import | Done | CSV preview/import API, mobile file picker + mapping UI, backend/mobile parsing tests |
| Phase D Link Ingest | Done | URL input UI, backend validation/fetch/extract, JobRunner handoff, service tests |
| Phase E PDF Ingest | Done | PDF upload API, PyMuPDF extraction, mobile PDF picker, extraction tests |
| Phase F Domain-Adaptive Cards | Done | Heuristic domain_hint, Source.metadata_, Card.tags, review labels, and domain-specific card editor |
| Phase G Concept Tracking | Done | Existing concept review aggregation, weak concepts, Tutor concept context, and mistake priority boost |
| Phase H Cognitive Update | Done | Lexical matching preview/apply API, Card.tags enrichment history, Insight UI; pgvector deferred |
| Insight Snapshot | In Progress | API and mobile tab added; richer analytics still pending |
| Tutor Actions | In Progress | Deterministic/cached tutor responses added; roadmap/docs wording needs sync |
| Mistake Analytics | In Progress | Review signal tracking added; deeper analytics pending |
| Offline Sync | Pending | Strategy exists, implementation incomplete |
| Push/Payment/Launch | Pending | Phase 4 scope |
| Rebrand to Plowth | In Progress | App/package IDs mostly updated; DB/S3 names still use `real_*` defaults |

## Review Log

### 2026-04-11 - Local Capture UX and Vocabulary Card Quality

**Purpose:** Fix local testing issues found during Android emulator Text capture.

**Completed:**

- Confirmed `401 Invalid or expired token` was caused by an expired mobile access token, not missing LLM API configuration.
- Added mobile access-token expiry detection and `/auth/refresh` usage before study API calls.
- Removed the persistent Capture "Cards are being prepared" inline card for async text/link/pdf submissions.
- Replaced the persistent preparation state with short SnackBar feedback after submission.
- Added backend vocabulary-list detection for line-based `term : meaning` text input.
- Vocabulary-list text now produces one definition card per row, with `domain_hint=language`, `domain_subtype=vocabulary`, and `input_pattern=vocabulary_list`.
- Added regression coverage for the Chinese number vocabulary sample.
- Review tab now refreshes when entered and after Capture submission, so stale empty queues do not remain behind the Refresh button.
- Review scheduler now normalizes newly created `MemoryState` `None` values before calculating the next interval.
- Added regression coverage for first-review scheduling with uninitialized memory state values.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 26 tests passing
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 8 tests passing

### 2026-04-10 - Phase F Domain Editor Follow-up

**Purpose:** Complete the deferred Phase F edit path using existing `Card.tags` metadata.

**Completed:**

- Added backend `CardUpdate.tags` support so domain editor metadata can be saved without a migration.
- Added mobile `CardEditorScreen` with a generated-card edit entry from Home when generation is done.
- Added domain-aware editor fields for `exam`, `language`, `code`, and `general` cards.
- Editor preserves existing tags and writes domain-specific notes under `Card.tags.domain_fields`.
- Added mobile `StudyCard` metadata helpers and model coverage for domain editor fields.
- Added backend schema coverage for updating domain tags.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 24 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads with 35 routes
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 8 tests passing

### 2026-04-10 - Phase H Cognitive Update

**Purpose:** Add a first usable Cognitive Update loop without DB migrations.

**Completed:**

- Added backend Cognitive Update service with lexical concept similarity, suggested actions, answer merge, and enrichment history helpers.
- Added `POST /insights/cognitive-update/preview` to compare new evidence against user-scoped existing concepts.
- Added `POST /insights/cognitive-update/apply` to enrich a selected card answer and store the audit trail in `Card.tags.enrichment_history`.
- User scope uses `Concept -> SourceChunk -> Source.user_id`; no `Concept.user_id` column added.
- pgvector/embedding migration is explicitly deferred until similarity false positives are measured.
- Mobile repository now parses Cognitive Update matches and can call preview/apply endpoints.
- Insight tab now includes a Cognitive Update panel for concept/evidence entry, match preview, and evidence application.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 23 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads with 35 routes
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 7 tests passing
- `git diff --check` -> no whitespace errors; CRLF warnings only

### 2026-04-10 - Phase G Concept-Level Tracking

**Purpose:** Confirm and complete concept-level tracking using the existing concept graph and review signal models.

**Completed:**

- Confirmed weak concept aggregation already uses Concept -> Card -> Review with Source-scoped user ownership.
- Confirmed Tutor context already loads concept name, description, relations, and sibling questions.
- Added unresolved mistake count into daily review queue priority so weak concepts can pull sibling cards forward without directly changing `MemoryState.next_review_at`.
- Kept `concept_proficiencies` table deferred; current implementation uses existing `MemoryState`, `MistakePattern`, `LearningProfile`, and Insight aggregation.
- Added priority boost unit test.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 20 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads with 33 routes

### 2026-04-10 - Phase F Domain-Adaptive Cards

**Purpose:** Add domain-aware generation metadata without DB migrations.

**Completed:**

- Added heuristic `infer_domain_hint` for `exam`, `language`, `code`, and `general`.
- Card generation now stores `domain_hint` in `Source.metadata_`.
- Generated cards now store `domain_hint`, `domain_subtype`, `source_type`, and keywords in `Card.tags`.
- Existing `card_type` values remain unchanged to avoid schema/API breakage.
- `CardResponse` and review queue responses expose `tags`.
- Mobile review cards show the domain hint in the review label when present.
- Added backend domain detection test and mobile tag parsing test.

**Deferred:**

- Domain-specific edit UI is still a follow-up item.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 19 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads with 33 routes
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 6 tests passing

### 2026-04-10 - Phase E PDF Ingest Implementation

**Purpose:** Implement text-based PDF upload and route extracted content through the existing card generation pipeline.

**Completed:**

- Added backend PDF extraction service using PyMuPDF.
- Added `POST /sources/upload` for `source_type="pdf"` multipart uploads.
- Added file extension/content-type/size validation, password-protected PDF rejection, invalid PDF handling, and scanned/empty PDF text checks.
- PDF metadata now records filename, page count, extracted length, extraction method, and title strategy.
- Mobile Capture now includes PDF mode using the existing file picker and uploads PDFs directly to the backend.
- Added PDF extraction unit tests.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 18 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads with 33 routes
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 5 tests passing

### 2026-04-10 - Phase D Link Ingest Implementation

**Purpose:** Implement public URL capture and connect extracted readable text to the existing card generation job.

**Completed:**

- Added backend link ingest service with URL validation, private/local IP blocking, timeout-aware HTTP fetch, content-type checks, and stdlib HTML text extraction.
- `POST /sources` now accepts `source_type="link"` with `url`, stores extracted text in `Source.raw_content`, preserves link metadata, and schedules the existing `card_generation` JobRunner path.
- Updated card generation metadata merge so link extraction metadata is not overwritten by generation results.
- Added mobile Link mode in Capture with URL validation and `StudyRepository.createLinkSource`.
- Added link ingest service tests for private URL rejection and HTML extraction behavior.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 16 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 5 tests passing

### 2026-04-10 - Phase C CSV Import Implementation

**Purpose:** Implement the Phase C CSV import path after Phase B contract reset.

**Completed:**

- Added backend CSV parsing helpers with UTF-8/UTF-8 BOM/CP949 decode support.
- Added `POST /sources/csv/preview` and `POST /sources/csv/import`.
- CSV import creates a `csv` Source and inserts mapped Q/A rows directly as `definition` cards without a Job.
- Added row/file validation: 2MB upload cap, 500-row synchronous import cap, column index validation, duplicate Q/A column rejection, blank Q/A row skipping.
- Added mobile `file_picker` dependency and Capture CSV mode with file selection, preview table, question/answer dropdowns, optional tag chips, and import submission.
- Added backend CSV unit tests and mobile CSV model parsing tests.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 14 tests passing
- `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` -> app loads
- `cd mobile && flutter analyze` -> no issues found
- `cd mobile && flutter test` -> 5 tests passing
- `git diff --check` -> no whitespace errors; CRLF warnings only

### 2026-04-10 - Phase 0/A Implementation

**Purpose:** 재설정한 Phase 0~H 중 Phase 0과 Phase A를 먼저 구현.

**Completed:**

- Reconciled stale `mobile/lib/features/review_screen.dart` as a compatibility export to `review_session_screen.dart`.
- Updated README/HANDOFF validation counts and Tutor/Insight wording.
- Removed title entry from Capture text flow.
- Removed Capture long polling after text submission.
- `StudyRepository.createTextSource` now accepts optional title and sends `null` when omitted.
- Added deterministic backend title inference for titleless text sources.
- Home now shows the latest generation status and can refresh/retry/start review.

**Validation:**

- `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` -> 11 tests passing
- `cd mobile && flutter test` -> 3 tests passing
- `cd mobile && flutter analyze` -> no issues found

**Remaining from Phase A:**

- Dedicated generated-card edit entry remains deferred. Current Home completion actions are `Start Review`, `Refresh`, and `Add More`.

### 2026-04-10 - Phase B Input Contract Reset

**Purpose:** 입력 확장 전 API/schema/job ownership 계약 확정.

**Decisions:**

- Canonical source types are `text`, `csv`, `link`, and `pdf`.
- `text` and `link` use `POST /sources` JSON requests.
- `pdf` uses `POST /sources/upload` multipart upload.
- `csv` uses dedicated preview/import endpoints:
  - `POST /sources/csv/preview`
  - `POST /sources/csv/import`
- Source creation remains `201 Created`; `202 Accepted` is reserved for future async-only endpoints.
- `text/link/pdf` run through JobRunner async generation.
- Small CSV imports create cards synchronously without a Job; large CSV async import is deferred.
- Backend CSV parsing uses Python stdlib `csv` first. Mobile file picker dependency is added only when Phase C implementation starts.

### 2026-04-10 - Capture Flow Redesign Document Review

**Purpose:** `docs/CAPTURE_FLOW_REDESIGN.md`를 현재 코드베이스와 맞춰 검토.

**Findings:**

- CSV 입력 설계가 현재 `SourceCreate.source_type` 허용값(`text|pdf|link`)과 충돌한다. Phase B1 전에 schema/API/model 계약을 먼저 정해야 한다.
- 문서의 "즉시 홈 복귀/202 응답/홈 처리 중 표시" 플로우는 현재 `POST /sources` 201 응답, CaptureScreen 내부 polling, HomeScreen job 상태 미표시 구조와 맞지 않는다.
- 도메인별 `card_type` 설계가 현재 `CardCreate` regex와 맞지 않는다. `vocabulary`, `grammar`, `syntax`, `cause_effect` 등을 쓰려면 schema와 생성 파이프라인을 같이 확장해야 한다.
- Cognitive Update 예시가 `Concept.user_id`, `Concept.embedding`, `card.metadata`를 전제로 하지만 현재 모델에는 해당 필드가 없다. 현재 구조에서는 `SourceChunk -> Source` join으로 사용자 범위를 제한하거나 concept에 `user_id`를 추가해야 한다.
- Title 자동 생성은 제품 방향은 타당하지만 현재 파이프라인이 deterministic heuristic 기반이므로 LLM 전용 단계로 바로 넣으면 로컬 개발/테스트 안정성이 깨질 수 있다.

**Recommended next action:**

1. Phase A와 Phase B를 분리해서 먼저 text-only UX 개선을 구현한다.
2. Phase B 시작 전 `source_type` enum/endpoint/status code/home job state contract를 문서에 명확히 고정한다.
3. Phase C 이후 스키마 변경은 `Card.extra` 신설보다 기존 `Card.tags` 확장 또는 명확한 rename/migration 전략을 먼저 결정한다.

### 2026-04-10 - Initial Status Review

**Purpose:** 요청에 따라 저장소 현황, 진행도, 검증 상태를 먼저 파악.

**Observed changes:**

- Local working tree contains many modified and untracked files.
- Backend changes include Insight API, Tutor service, review intelligence tracking, and schema additions.
- Mobile changes include package rename to `plowth_app`, app ID updates, Insight screen, review session screen, Tutor UI, and new tests.
- Infra container names changed from `real_*` to `plowth_*`, while DB credentials/database name remain `real_*`.
- Documentation was updated for 2026-04-09 status but has a few stale details.

**Findings:**

- Analyzer blocker: `mobile/lib/features/review_screen.dart` is stale and references `_TutorSheet`, but `_TutorSheet` exists only in `mobile/lib/features/review_session_screen.dart`.
- Documentation mismatch: README/HANDOFF mention backend tests as 7 passing, but current backend test suite reports 10 passing.
- Roadmap wording mismatch: docs still list Tutor AI as remaining work, while a deterministic cached Tutor slice has already been implemented.
- Rebrand is partial by design or incomplete: runtime package/bundle IDs are Plowth, but DB and S3 defaults still use `real_*`.

**Recommended next action:**

1. Fix the Flutter analyzer failure by deleting or reconciling the stale `review_screen.dart`.
2. Update README/HANDOFF validation counts and Tutor/Insight status wording.
3. Decide whether `real_user`, `real_db`, and `real-uploads` should remain compatibility defaults or be renamed.

## Validation Log

### 2026-04-11

| Command | Result | Notes |
|---|---:|---|
| `docker ps --filter name=plowth --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` | Pass | `plowth_postgres` and `plowth_redis` healthy |
| `Invoke-RestMethod http://127.0.0.1:8000/health` | Fail | Backend server was not running during first local diagnosis |
| `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` | Pass | 26 tests passed after vocabulary-list and scheduler null-state regressions |
| `cd mobile && flutter analyze` | Pass | No issues after token refresh and Capture UX changes |
| `cd mobile && flutter test` | Pass | 8 tests passing |

### 2026-04-10

| Command | Result | Notes |
|---|---:|---|
| `cd backend && .\venv\Scripts\python.exe -m unittest test_phase2_services.py` | Pass | 24 tests passed after Phase F editor schema coverage |
| `cd backend && .\venv\Scripts\python.exe -c "from app.main import app; print(len(app.routes))"` | Pass | FastAPI app loaded with 35 routes |
| `cd mobile && flutter test` | Pass | 8 tests passed after domain editor metadata parsing test |
| `cd mobile && flutter test test\study_repository_tutor_models_test.dart` | Pass | 6 model parsing tests passed |
| `cd mobile && flutter analyze` | Pass | No issues after Phase F editor follow-up |
| `git diff --check` | Pass | No whitespace errors; CRLF warnings only |
| `docker ps --filter name=plowth --filter name=real` | Pass | No matching running containers |

## Open Items

### P0 - Blocks Clean Validation

- None currently.

### P1 - Documentation Accuracy

- Keep README/HANDOFF validation counts current after each implementation slice.

### P1 - Rebrand Consistency

- Decide whether to rename DB defaults:
  - `real_user`
  - `real_db`
  - `real_dev_password`
  - `real-uploads`
- If renamed, update config, `.env.example`, docker compose, docs, and local migration/setup notes together.

### P2 - Product Roadmap

- Expand Insight analytics beyond the current snapshot.
- Expand Tutor workflow beyond deterministic payloads if live AI responses are required.
- Continue Phase 4 launch hardening: sync, push, payment, signing, production CORS/secrets.

## Decision Log

### 2026-04-10

- Created this status log as the single project management document for current state, reviews, progress checks, and history.
- Keep current history append-only so future reviews can compare what changed between sessions.

## File Index

- Main README: `README.md`
- Backend README: `backend/README.md`
- Mobile README: `mobile/README.md`
- Handoff document: `docs/HANDOFF.md`
- Sync strategy: `docs/sync-strategy.md`
- Status log: `docs/STATUS_LOG.md`
