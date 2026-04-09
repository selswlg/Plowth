# Plowth — 오프라인 동기화 전략 설계 문서

> Phase 4에서 구현할 동기화 시스템의 설계를 Phase 1에서 확정합니다.
> 이 문서는 구현 시 참조되는 기술 스펙입니다.

---

## 1. 설계 원칙

1. **오프라인 우선 (Offline-First):** 리뷰 세션은 네트워크 없이 완전히 동작해야 한다.
2. **Append-Only:** 리뷰 데이터는 절대 수정/삭제하지 않는다 (이벤트 로그).
3. **Idempotent:** 동일 이벤트가 두 번 전송되어도 서버에 중복 생성되지 않는다.
4. **Eventually Consistent:** 오프라인 작업은 네트워크 복구 시 자동 동기화된다.

---

## 2. 동기화 대상

| 데이터 | 방향 | 충돌 전략 |
|--------|------|-----------|
| Reviews | Client → Server | 자동 병합 (append-only, no conflict) |
| Cards 생성 | Server → Client | 서버에서 생성 후 Pull |
| Cards 편집 | 양방향 | Last-Writer-Wins (timestamp) |
| Memory States | Server → Client | Server-Authoritative (서버가 재계산) |
| User Preferences | 양방향 | Last-Writer-Wins |
| Sources | Client → Server | Push only |

---

## 3. 클라이언트 로컬 저장 (Drift/SQLite)

### 로컬 전용 테이블

```
pending_sync_events:
  id              TEXT PRIMARY KEY
  event_type      TEXT     -- review, card_edit, settings_update
  event_payload   TEXT     -- JSON
  created_at      INTEGER  -- Unix timestamp
  retry_count     INTEGER  -- 재시도 횟수
  last_error      TEXT?    -- 마지막 에러 메시지
```

### 동기화 메타데이터

```
sync_metadata:
  key             TEXT PRIMARY KEY
  value           TEXT
  
  -- 예:
  -- last_sync_at: "2024-03-15T10:30:00Z"
  -- device_id: "uuid-device-123"
```

---

## 4. 동기화 플로우

### 4.1 Push (클라이언트 → 서버)

```
1. 앱이 네트워크 상태 감지 (Connectivity 플러그인)
2. pending_sync_events에 미전송 이벤트가 있으면:
   a. 시간순 정렬
   b. Batch 전송: POST /api/v1/sync/push
      Body: { events: [...], device_id: "..." }
   c. 서버 응답:
      - 200: 성공 → pending에서 삭제
      - 409: 이미 처리됨 (idempotent) → pending에서 삭제
      - 500: 실패 → retry_count 증가, 30초 후 재시도
   d. 최대 5회 재시도 후 포기 → 사용자에게 알림
```

### 4.2 Pull (서버 → 클라이언트)

```
1. Push 완료 후 실행
2. GET /api/v1/sync/pull?since={last_sync_at}&device_id={...}
3. 서버 응답:
   - updated_cards: 수정된 카드 목록
   - new_memory_states: 갱신된 기억 상태
   - updated_settings: 변경된 설정
   - server_timestamp: 이 시점 이후로 다시 Pull
4. 로컬 DB 갱신
5. last_sync_at = server_timestamp
```

### 4.3 리뷰 이벤트 생성 (오프라인)

```
사용자가 리뷰 제출 시:
1. 로컬 reviews 테이블에 즉시 저장 (synced = false)
2. 로컬 memory_state 임시 계산 (FSRS 로컬 실행)
3. pending_sync_events에 review 이벤트 추가
4. 네트워크 사용 가능하면 즉시 Push 트리거
5. Push 성공 후: synced = true, 서버 memory_state로 덮어쓰기
```

---

## 5. 충돌 해결 시나리오

### 5.1 카드 편집 충돌

```
시나리오: 기기 A에서 질문 수정, 기기 B에서 답변 수정 (오프라인)

해결:
- 각 수정은 updated_at 타임스탬프를 포함
- 서버는 필드별 Last-Writer-Wins 적용
- 기기 A의 question 수정이 먼저, 기기 B의 answer 수정이 나중이면:
  → 최종: 기기 A의 question + 기기 B의 answer
- 동일 필드 충돌 시:
  → 나중 timestamp가 승리
  → 이전 버전은 card_edit_history에 보관 (선택적)
```

### 5.2 동일 카드 동시 리뷰

```
시나리오: 기기 A와 B에서 같은 카드를 오프라인으로 리뷰

해결:
- 리뷰는 append-only → 두 리뷰 모두 저장
- Memory State는 서버가 모든 리뷰를 시간순 정렬 후 재계산
- 클라이언트에는 서버 계산 결과를 반영
```

---

## 6. API 스펙

### POST /api/v1/sync/push

```json
// Request
{
  "device_id": "uuid-device-123",
  "events": [
    {
      "client_event_id": "evt-uuid-1",
      "event_type": "review",
      "event_payload": {
        "card_id": "card-uuid",
        "rating": "good",
        "response_time_ms": 3200
      },
      "client_timestamp": "2024-03-15T10:30:00Z"
    }
  ]
}

// Response 200
{
  "processed": 1,
  "skipped": 0,
  "errors": [],
  "updated_memory_states": [
    {
      "card_id": "card-uuid",
      "stability": 14.5,
      "difficulty": 0.3,
      "next_review_at": "2024-03-29T10:30:00Z"
    }
  ]
}
```

### GET /api/v1/sync/pull

```json
// Response 200
{
  "server_timestamp": "2024-03-15T10:31:00Z",
  "changes": {
    "cards": [
      { "id": "...", "question": "...", "updated_at": "..." }
    ],
    "memory_states": [...],
    "preferences": { "learning_goal": "exam" }
  }
}
```

---

## 7. 구현 체크리스트 (Phase 4)

- [ ] 서버: sync_events 테이블 CRUD
- [ ] 서버: POST /sync/push — idempotent 이벤트 수신
- [ ] 서버: GET /sync/pull — 변경분 반환
- [ ] 서버: Memory State 재계산 로직
- [ ] Flutter: pending_sync_events 로컬 테이블
- [ ] Flutter: Connectivity 감지 + 자동 Push
- [ ] Flutter: Pull 후 로컬 DB 갱신
- [ ] Flutter: 동기화 상태 인디케이터 UI
- [ ] 테스트: 오프라인 5건 리뷰 → 온라인 복귀 → 자동 동기화 검증
