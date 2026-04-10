# Plowth 캡처 플로우 & 학습 파이프라인 재설계 명세서

> **작성일:** 2026-04-10
> **상태:** Phase/Task 재정렬 완료 · Phase 0/A 우선 구현 대기
> **근거 문서:** `어플 상세 초안.md` (PRD), `HANDOFF.md` (기술 현황)
> **참고 레포:** `RoundTable02/tutor-skills`, `EESJGong/scholar-skill`

---

## 목차

1. [문제 정의](#1-문제-정의)
2. [설계 원칙](#2-설계-원칙)
3. [캡처 플로우 재설계](#3-캡처-플로우-재설계)
4. [입력 유형별 구현 명세](#4-입력-유형별-구현-명세)
5. [Source/Card 혼동 해소](#5-sourcecard-혼동-해소)
6. [도메인 자동 감지 & 맞춤 카드](#6-도메인-자동-감지--맞춤-카드)
7. [개념 단위 추적 시스템](#7-개념-단위-추적-시스템)
8. [Cognitive Update 시스템](#8-cognitive-update-시스템)
9. [전체 파이프라인 아키텍처](#9-전체-파이프라인-아키텍처)
10. [참고 레포 차용 매핑](#10-참고-레포-차용-매핑)
11. [구현 순서 & 우선순위](#11-구현-순서--우선순위)
12. [미래 확장 (확인만 해둔 것)](#12-미래-확장-확인만-해둔-것)

---

## 1. 문제 정의

### 1.1 PRD 비전 vs 현재 구현

PRD(어플 상세 초안.md) Section 6.A, Line 104에 명시된 핵심 원칙:

> **"사용자는 자료만 넣는다."**
> **"사용자는 카드 제작자가 아니라 학습 감독자가 된다."**

현재 구현은 이 원칙과 정반대로 작동하고 있다.

| 항목 | PRD 비전 | 현재 구현 | 괴리 |
|------|----------|----------|------|
| 입력 진입점 | 다양한 자료 드롭 | Title + Notes 폼 제출 | 🔴 심각 |
| 입력 유형 | text, PDF, 링크, 붙여넣기 인식 | text only | 🔴 심각 |
| 제목 생성 | 자동 생성 (PRD 6.A.5) | 수동 입력 필수 | 🟡 중간 |
| 처리 방식 | 비동기 백그라운드 (PRD 7절) | 동기 폴링 (최대 20초 대기) | 🟡 중간 |
| 결과 확인 | 요약 + 즉시 학습 선택 | 전체 카드 목록 스크롤 | 🟡 중간 |
| 개념 추적 | 카드 + 개념 네트워크 (PRD 3.3) | 카드 단위만 | 🟡 중간 |
| 지식 진화 | 입력할수록 정확해짐 | 입력할수록 중복 증가 | 🔴 심각 |

### 1.2 현재 유저 여정의 마찰 분석

```
현재 (7단계, ~2-3분):
  ① 앱 열기
  ② Capture 탭 이동
  ③ Title 수동 입력             ← 불필요한 마찰
  ④ Notes에 텍스트 수동 붙여넣기  ← 텍스트만 가능
  ⑤ "Generate Review Set" 클릭
  ⑥ 20초 대기 (화면 동결)        ← 유저 시간 낭비
  ⑦ 카드 목록 스크롤 확인         ← 강제 확인
  ⑧ Start Review

목표 (3단계, ~15초):
  ① 자료 던지기 (어떤 형식이든)
  ② 홈으로 즉시 복귀
  ③ (나중에) 알림 확인 → 학습 시작
```

### 1.3 Source/Card 개념 혼동 문제

현재 캡처 화면에서 유저에게 노출되는 라벨:

```
[Title     ]  ← 유저 오해: "이게 Question?"
[Notes     ]  ← 유저 오해: "이게 Answer?"
```

실제 데이터 구조:
- `Title` → Source(원본 자료)의 이름
- `Notes` → AI에게 보낼 원본 텍스트
- 생성된 카드의 `question`/`answer`는 별도 필드

**유저에게 Source라는 개념 자체를 노출할 필요가 없다.**

---

## 2. 설계 원칙

이 재설계 전체를 관통하는 원칙:

### P1. 드롭 패러다임

유저의 행동은 "던지기" 하나로 끝나야 한다. 폼 작성이 아니라 파일/텍스트를 앱에 떨어뜨리는 것.

### P2. 제로 설정

Title, 태그, 카테고리, 카드 유형 등 모든 메타데이터는 AI가 자동 생성한다. 유저는 나중에 수정만 가능.

### P3. 백그라운드 처리

무거운 작업은 유저 시야 밖에서 일어나야 한다. 유저가 대기 화면을 보는 것은 설계 실패.

### P4. 내용 기반 적응

학습 도메인, 카드 유형, 편집 UI는 입력 자료의 내용을 분석해서 시스템이 결정한다.

### P5. 지식 진화

새 자료가 들어오면 기존 지식이 "추가"가 아니라 "진화"해야 한다.

### P6. 개념 중심

학습 추적, 약점 분석, Tutor 개입의 단위는 카드가 아니라 **개념**.

---

## 3. 캡처 플로우 재설계

### 3.1 현재 플로우 (폐기 대상)

```
CaptureScreen
├── Material 카드
│   ├── TextField: Title ("Optional topic label")
│   ├── TextField: Notes (maxLines: 10, "Paste the material...")
│   └── ElevatedButton: "Generate Review Set"
├── StatusCard (source/job 상태 표시)
├── ErrorMessage (인라인)
└── Generated Cards 목록 (전체 카드 스크롤)
```

파일: `mobile/lib/features/capture_screen.dart` (657줄)
- `_titleController`, `_contentController` → 두 개의 텍스트 필드
- `_pollGeneration()` → 최대 20초 동기 폴링
- `_buildComposerCard()` → "Title" + "Notes" + "Generate" 버튼

### 3.2 개선된 플로우

#### 3.2.1 진입점

유저가 캡처를 시작하는 모든 경로:

```
진입점 A: 메인 화면 FAB "+"
  → 입력 방식 선택 Bottom Sheet
  → [텍스트 입력] [파일 선택] [링크 입력]

진입점 B: (미래) Share Sheet
  → 다른 앱에서 "공유 → Plowth"
  → 자동 수신 → 백그라운드 처리

진입점 C: (미래) 클립보드 감지
  → 앱 진입 시 클립보드 텍스트 감지
  → "이 내용으로 카드 만들까요?" 토스트
```

#### 3.2.2 입력 방식 선택 Bottom Sheet

```
┌──────────────────────────────────────┐
│  📝 학습 자료 추가                     │
│                                      │
│  ┌──────────┐  ┌──────────┐          │
│  │ 📄 텍스트  │  │ 📎 파일   │          │
│  │  직접 입력 │  │ PDF/CSV  │          │
│  └──────────┘  └──────────┘          │
│  ┌──────────┐                        │
│  │ 🔗 링크   │                        │
│  │  URL 입력 │                        │
│  └──────────┘                        │
└──────────────────────────────────────┘
```

#### 3.2.3 텍스트 입력 화면

```
┌──────────────────────────────────────┐
│  ← 뒤로                              │
│                                      │
│  학습할 내용을 넣어주세요               │
│                                      │
│  ┌──────────────────────────────────┐│
│  │                                  ││
│  │  (빈 텍스트 영역)                 ││
│  │  placeholder: "노트, 강의 내용,   ││
│  │  교재 일부를 붙여넣거나 직접       ││
│  │  입력하세요"                      ││
│  │                                  ││
│  │                                  ││
│  │                                  ││
│  │                                  ││
│  └──────────────────────────────────┘│
│                                      │
│  ┌──────────────────────────────────┐│
│  │         카드 만들기               ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

**변경 사항:**
- Title 필드 **제거** → LLM이 자동 생성
- "Notes" 라벨 **제거** → 용도가 명확한 placeholder 텍스트
- "Generate Review Set" → **"카드 만들기"** (유저 언어로)
- 하단 설명 텍스트("Phase 2 pipeline will chunk...") **제거** → 내부 용어 노출 금지

#### 3.2.4 URL 입력 화면

```
┌──────────────────────────────────────┐
│  ← 뒤로                              │
│                                      │
│  학습할 페이지의 URL을 입력하세요        │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ https://                          ││
│  └──────────────────────────────────┘│
│                                      │
│  ┌──────────────────────────────────┐│
│  │         카드 만들기               ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

#### 3.2.5 파일 선택 플로우

```
"파일" 선택 → OS 파일 피커 (필터: .pdf, .csv)
  → PDF 선택 시: source_type="pdf" → 백엔드 업로드 → 텍스트 추출 → 카드 생성
  → CSV 선택 시: source_type="csv" → 컬럼 매핑 화면 → 직접 카드 생성
```

#### 3.2.6 제출 후 플로우

```
카드 만들기 버튼 클릭
  → API 호출: POST /sources (source_type, content/file/url)
  → 즉시 응답: { source_id, job_id, status: "pending" }
  → 화면 전환: 홈으로 자동 복귀
  → 홈 화면에 "처리 중" 인디케이터 표시

백그라운드에서:
  → JobRunner가 처리
  → 완료 시 홈 화면에 결과 요약 표시

  ┌──────────────────────────────────────┐
  │  ✅ 유기화학 작용기 반응              │
  │  12장 생성 · 4개 개념 · 난이도 평균 3.1 │
  │                                      │
  │  [바로 학습]  [카드 편집]              │
  └──────────────────────────────────────┘
```

**핵심:** "카드 만들기" 누르는 순간 유저의 할 일은 끝. 나머지는 시스템 책임.

---

## 4. 입력 유형별 구현 명세

### 4.1 구현 순서

개발 난이도 기준 오름차순:

```
1. text  → ✅ 이미 구현됨
2. csv   → AI 호출 불필요, 필드 매핑만
3. link  → 텍스트 추출 + 기존 파이프라인 재사용
4. pdf   → 파일 업로드 + 텍스트 추출 + 기존 파이프라인 재사용
```

> **image, anki(.apkg)는 확장 가능성만 인지. 이번 구현 범위에서 제외.**

---

### 4.2 source_type: `text` (구현 완료)

**현재 상태:** 동작하지만 UX 개선 필요 (Title 제거, 라벨 변경).

**백엔드:**
- Endpoint: `POST /sources` with `{ source_type: "text", title: null, raw_content: "..." }`
- 처리: `card_generation.py` → chunk → concept 추출 → card 생성

**프론트엔드 변경:**
- `_titleController` 제거
- `_contentController`의 라벨/힌트 텍스트 변경
- `_pollGeneration` → 백그라운드 전환 (홈 복귀)

**Title 자동 생성:**
- Card Generation Pipeline의 첫 단계에 `title_extraction` 추가
- LLM에 raw_content 전달 → `{ "title": "유기화학 작용기 반응" }` 반환
- Source.title 필드에 저장
- 유저는 나중에 수정 가능

---

### 4.3 source_type: `csv`

**개요:** AI 호출 없이 CSV의 컬럼을 Q/A로 매핑하여 직접 Card를 생성.

**백엔드:**

```
Endpoint: POST /sources/csv (multipart/form-data)
  ├── file: CSV 파일
  ├── question_column: int (0-indexed)
  ├── answer_column: int (0-indexed)
  └── tag_columns: list[int] (선택)

처리 흐름:
  1. CSV 파싱 (csv.DictReader 또는 pandas)
  2. 첫 5행 미리보기 반환 → 프론트엔드에서 컬럼 매핑
  3. 매핑 확정 후 → 각 행을 Card로 직접 INSERT
  4. Source.title = CSV 파일명 (유저 수정 가능)
  5. Source.metadata = { "row_count": N, "columns": [...] }
```

**프론트엔드:**

```
파일 선택 → CSV 감지 → 컬럼 매핑 화면:

┌──────────────────────────────────────────┐
│  📊 CSV 컬럼 매핑                         │
│                                          │
│  미리보기 (첫 3행):                        │
│  ┌────────────┬────────────┬──────────┐  │
│  │ Column A   │ Column B   │ Column C │  │
│  ├────────────┼────────────┼──────────┤  │
│  │ Osmosis    │ Movement.. │ Biology  │  │
│  │ Diffusion  │ Passive..  │ Biology  │  │
│  └────────────┴────────────┴──────────┘  │
│                                          │
│  Question: [Column A ▼]                  │
│  Answer:   [Column B ▼]                  │
│                                          │
│  [카드 만들기]                             │
└──────────────────────────────────────────┘
```

**특이 사항:**
- LLM 호출 0회 → 비용 0, 속도 즉시
- Source.source_type = "csv"
- Job 생성 불필요 (동기 처리 가능)
- 대량 데이터 대응: 500행 이상 시 비동기 처리로 전환

---

### 4.4 source_type: `link`

**개요:** URL을 받아 웹페이지 본문을 추출한 후, 기존 text 파이프라인에 태운다.

**백엔드:**

```
Endpoint: POST /sources with { source_type: "link", url: "https://..." }

처리 흐름:
  1. URL 유효성 검사 (형식, 접근 가능 여부)
  2. HTTP GET 요청 (timeout: 10s, User-Agent 설정)
  3. HTML → 본문 텍스트 추출
     - 라이브러리: trafilatura (추천) 또는 beautifulsoup4 + readability
     - trafilatura가 뉴스/블로그/문서에 최적화되어 있음
  4. 추출된 텍스트를 raw_content로 저장
  5. Source.title = <title> 태그 또는 LLM 자동 생성
  6. Source.metadata = { "url": "...", "extracted_length": N }
  7. 이후 기존 text 파이프라인과 동일:
     chunking → concept 추출 → card 생성
```

**프론트엔드:**
- URL 입력 필드 하나
- "카드 만들기" 클릭
- 즉시 홈 복귀 → 백그라운드 처리

**예외 처리:**
- 접근 불가 URL: "이 페이지에 접속할 수 없습니다" 에러
- 텍스트 추출 실패: "이 페이지에서 학습 내용을 추출하지 못했습니다" 에러
- 추출된 텍스트가 30자 미만: "추출된 내용이 너무 적습니다" 에러
- 로그인 필요 페이지: 감지 불가, 추출된 텍스트가 로그인 폼이면 최소 길이 검사에서 걸림

**의존성:** `trafilatura>=1.6` (pip)

---

### 4.5 source_type: `pdf`

**개요:** PDF 파일을 업로드받아 텍스트를 추출한 후, 기존 text 파이프라인에 태운다.

**백엔드:**

```
Endpoint: POST /sources/upload (multipart/form-data)
  ├── file: PDF 파일
  └── source_type: "pdf"

처리 흐름:
  1. 파일 업로드 수신 → 임시 저장 (또는 GCS/S3)
  2. PDF → 텍스트 추출
     - 라이브러리: pymupdf (>=1.23, fitz) — 가장 빠름
     - Fallback: pdfplumber — 테이블 추출에 강점
  3. 페이지별 텍스트 연결
  4. 추출된 텍스트를 raw_content로 저장
  5. Source.title = PDF 파일명 (확장자 제외) 또는 LLM 자동 생성
  6. Source.metadata = {
       "filename": "...",
       "page_count": N,
       "extracted_length": N,
       "extraction_method": "pymupdf"
     }
  7. 이후 기존 text 파이프라인과 동일
```

**프론트엔드:**
- 파일 피커에서 PDF 선택
- 업로드 프로그레스 표시 (파일 크기에 따라)
- 업로드 완료 → 즉시 홈 복귀 → 백그라운드 처리

**예외 처리:**
- 비밀번호 보호 PDF: "이 PDF는 비밀번호로 보호되어 있습니다" 에러
- 스캔 PDF (이미지 기반): 텍스트 추출 결과가 거의 없음 → "이 PDF에서 텍스트를 추출하지 못했습니다. 텍스트 기반 PDF를 사용해주세요" 에러
  - (미래: image 입력 지원 시 OCR로 fallback)
- 파일 크기 제한: 무료 사용자 10MB, 유료 사용자 50MB

**의존성:** `pymupdf>=1.23` (pip)

---

## 5. Source/Card 혼동 해소

### 5.1 문제

현재 CaptureScreen에서 유저가 보는 필드:
- `Title` → Source.title (원본 자료의 이름)
- `Notes` → Source.raw_content (AI에 보낼 원본 텍스트)

생성된 카드의 필드:
- `card.question` → 카드의 질문
- `card.answer` → 카드의 답변

**두 레이어가 같은 화면에서 혼재되어 유저가 Title=Question, Notes=Answer로 오해.**

### 5.2 해결 방안

#### 원칙: Source는 내부 개념으로 숨긴다.

유저에게 보이는 것:

```
입력 → 카드(Q&A)
```

유저에게 보이지 않는 것:

```
Source, raw_content, source_type, chunking, concept extraction
```

#### UI 변경

| 현재 | 변경 후 |
|------|---------|
| TextField "Title" | **제거** |
| TextField "Notes" (label) | **라벨 제거**, placeholder만 |
| "Generate Review Set" 버튼 | **"카드 만들기"** |
| "Generated Cards" 섹션 제목 | **삭제** (홈에서 결과 표시) |
| "Source: analyzing • Job: pending" | **"분석 중…"** (내부 용어 삭제) |
| _PreviewCard에 card.question/answer 표시 | 유지 (이건 Card 레이어이므로 Q/A가 맞음) |

#### 데이터 구조 변경

Source 모델 자체는 변경 없음. 변경되는 것은 **API 인터페이스**:

```python
# 현재: 유저가 title을 직접 전달
POST /sources { "title": "유기화학", "raw_content": "..." }

# 변경: title은 선택적, 없으면 LLM이 자동 생성
POST /sources { "raw_content": "..." }
# → 백엔드에서 title이 없으면 LLM 자동 생성
```

---

## 6. 도메인 자동 감지 & 맞춤 카드

### 6.1 도메인 감지 방식

**결정: 자료 분석 시 자동 감지** (온보딩에서 물어보지 않음)

Card Generation Pipeline에서 concept 추출 시, LLM에게 도메인 분류도 함께 요청:

```python
# Card Generation 프롬프트에 추가:
"domain_hint 필드를 반드시 포함하세요:
 - 'exam': 시험/자격증/학술 개념 (정의, 원리, 공식)
 - 'language': 언어 학습 (단어, 문법, 표현)
 - 'code': 프로그래밍/기술 (코드, 알고리즘, API)
 - 'general': 위에 해당하지 않는 일반 지식"
```

LLM 응답 예시:
```json
{
  "title": "유기화학 작용기 반응",
  "domain_hint": "exam",
  "concepts": [...],
  "cards": [...]
}
```

Source.metadata에 `domain_hint` 저장.

### 6.2 도메인별 카드 생성 차이

#### exam (시험/자격증)

```
카드 유형: definition, principle, comparison, application
프롬프트 강조: 정확한 정의, 핵심 키워드, 비교-대조, 함정 포인트

생성 예시:
  Q: "SN1 반응과 SN2 반응의 차이는?"
  A: "SN1은 2단계 메커니즘(carbocation 중간체), SN2는 1단계 역전 메커니즘..."
  card_type: "comparison"
  tags: ["organic_chemistry", "exam_trap"]
```

#### language (언어 학습)

```
카드 유형: vocabulary, grammar, expression, context
프롬프트 강조: 예문 포함, 발음/읽기, 유사 표현 비교, 문맥

생성 예시:
  Q: "断る (ことわる)"
  A: "거절하다"
  extra: {
    "example": "友達の誘いを断った",
    "pronunciation": "ことわる",
    "similar": "拒否する (더 격식체)",
    "context": "일상 대화에서 정중하게 거절할 때"
  }
  card_type: "vocabulary"
```

#### code (프로그래밍)

```
카드 유형: concept, syntax, pattern, debug
프롬프트 강조: 코드 예시 포함, 실행 결과, 관련 패턴

생성 예시:
  Q: "Python에서 decorator의 역할은?"
  A: "함수를 감싸서 동작을 확장하는 패턴"
  extra: {
    "code_example": "@my_decorator\ndef hello():\n    print('hello')",
    "output": "Decorator가 감싼 결과...",
    "related_pattern": "Higher-order function"
  }
  card_type: "concept"
```

#### general (일반 지식)

```
카드 유형: definition, relationship, timeline, cause_effect
프롬프트 강조: 연결 관계, 인과관계, 비교

생성 예시:
  Q: "제2차 세계대전의 직접적 원인은?"
  A: "독일의 폴란드 침공 (1939.09.01)"
  card_type: "cause_effect"
```

### 6.3 도메인별 편집 UI 차이

Card의 `domain_hint`와 `card_type`에 따라 편집 Bottom Sheet에서 다른 위젯 렌더링:

| 도메인 | 편집 UI 구성 |
|--------|-------------|
| exam | Question(TextField), Answer(TextField), 키워드 하이라이트(Chip), 난이도(SegmentedButton) |
| language | 단어/표현(TextField), 뜻(TextField), 예문(TextField), 발음(TextField), 유사 표현(TextField) |
| code | Question(TextField), Answer(TextField), 코드 블록(Monospace TextField), 실행 결과(TextField) |
| general | Question(TextField), Answer(TextField), 관련 개념(Chip 추가) |

### 6.4 도메인별 리뷰 UI 차이

| 도메인 | 리뷰 카드 표시 |
|--------|--------------|
| exam | Question → (탭) → Answer + 키워드 볼드 |
| language | 단어/표현 → (탭) → 뜻 + 예문 + 발음 |
| code | Question → (탭) → Answer + 코드 블록 (syntax highlighted) |
| general | Question → (탭) → Answer |

### 6.5 DB 변경

```sql
-- Card 테이블에 추가:
ALTER TABLE cards ADD COLUMN domain_hint VARCHAR(20) DEFAULT 'general';
ALTER TABLE cards ADD COLUMN extra JSONB DEFAULT '{}';
-- extra는 도메인별 추가 필드를 유연하게 저장
-- exam: { "keywords": [...], "exam_trap": "..." }
-- language: { "example": "...", "pronunciation": "...", "similar": "..." }
-- code: { "code_example": "...", "output": "...", "related_pattern": "..." }

-- Source 테이블에 추가:
ALTER TABLE sources ADD COLUMN domain_hint VARCHAR(20) DEFAULT NULL;
-- NULL이면 아직 감지 안 됨, 감지 후 업데이트
```

---

## 7. 개념 단위 추적 시스템

### 7.1 현재: 카드 단위 추적

```
MemoryState 테이블 (현재 존재):
  - card_id (FK → cards)
  - stability
  - difficulty
  - last_review
  - next_review
  - reps
  - lapses
```

**한계:** Card C1("삼투란?")과 Card C3("삼투 vs 확산")이 같은 개념인지 시스템이 모른다.

### 7.2 개선: 개념 단위 집계 레이어

현재 `concepts` 테이블은 이미 존재하지만, 학습 추적에는 사용되지 않고 있다. 이것을 활용.

#### 개념 숙련도 모델

```
ConceptProficiency (신규 테이블):
  - concept_id (FK → concepts)
  - user_id (FK → users)
  - proficiency_score: float (0.0 ~ 1.0)
  - total_attempts: int
  - correct_attempts: int
  - streak: int (연속 정답 수)
  - weakness_pattern: text (nullable, "확산과 혼동" 등)
  - last_tested_at: timestamp
  - status: enum ("new", "learning", "reviewing", "mastered", "weak")
```

#### 숙련도 계산

```python
def update_concept_proficiency(concept_id, user_id):
    # 해당 개념에 연결된 모든 카드의 MemoryState 가져오기
    cards = get_cards_by_concept(concept_id)
    memory_states = [get_memory_state(c.id, user_id) for c in cards]
    
    # 숙련도 = 각 카드의 안정도 가중 평균
    total_stability = sum(ms.stability for ms in memory_states)
    max_possible = sum(target_stability for _ in memory_states)
    proficiency = total_stability / max_possible if max_possible > 0 else 0
    
    # 약점 패턴 감지
    recent_reviews = get_recent_reviews(concept_id, user_id, days=14)
    failure_rate = count_failures(recent_reviews) / len(recent_reviews)
    
    # 상태 결정
    if proficiency >= 0.85 and failure_rate < 0.1:
        status = "mastered"
    elif proficiency >= 0.6:
        status = "reviewing"
    elif proficiency >= 0.3:
        status = "learning"
    elif failure_rate > 0.5:
        status = "weak"
    else:
        status = "new"
    
    # 저장
    upsert_concept_proficiency(concept_id, user_id, proficiency, status)
```

#### 개념→카드 연쇄 스케줄링

**현재:** C3을 틀리면 C3만 재스케줄.
**개선:** C3을 틀리면 같은 concept에 속한 C1, C2도 우선순위 상승.

```python
def on_review_failure(card_id, user_id):
    # 1. 기존 로직: 해당 카드 MemoryState 업데이트
    update_memory_state(card_id, rating="again")
    
    # 2. 신규 로직: 개념 레벨 파급
    concept = get_concept_for_card(card_id)
    if concept:
        # 같은 개념의 다른 카드들 가져오기
        sibling_cards = get_cards_by_concept(concept.id)
        for sibling in sibling_cards:
            if sibling.id != card_id:
                # 형제 카드의 다음 복습 일정을 앞당김 (boost factor)
                boost_review_priority(sibling.id, user_id, factor=0.7)
        
        # 3. 개념 숙련도 재계산
        update_concept_proficiency(concept.id, user_id)
```

### 7.3 실제 예시: "삼투" 개념

#### 카드 구성

```
Concept: "삼투" (concept_id: 42)
├── Card C1: "삼투란 무엇인가?" (difficulty: 2)
├── Card C2: "삼투압이 세포에 미치는 영향은?" (difficulty: 3)
└── Card C3: "삼투와 확산의 차이는?" (difficulty: 4)
```

#### 리뷰 시나리오

```
Day 1: C1 정답(easy), C2 정답(good), C3 오답(again)
  → 카드 단위: C1↑ C2→ C3↓
  → 개념 단위: "삼투" 숙련도 = 0.55 (C3 실패로 전체 하락)
  → 연쇄 효과: C1, C2도 다음 복습에서 우선순위 약간 상승
  → 약점 패턴 갱신: "확산과 혼동"

Day 3: C3 재출제 → 정답(good)
  → 카드 단위: C3↑
  → 개념 단위: "삼투" 숙련도 = 0.72 (개선)
  → 연쇄 효과: C1, C2 우선순위 정상 복귀

Day 7: C1, C2, C3 모두 정답
  → 개념 단위: "삼투" 숙련도 = 0.88 → status: "mastered" 🏆
```

#### Insight 탭 표시

```
카드 단위 표시 (현재):
  "300장 중 45장이 약합니다"
  → 유저: "어떤 45장이 약한지 하나하나 봐야 하나?"

개념 단위 표시 (개선):
  "약한 개념: 삼투 (55%), 화학 평형 (42%), 유전자 발현 (38%)"
  → 유저: "삼투를 집중적으로 복습하자"
  → [삼투 집중 학습] 버튼 → 삼투 관련 카드만 세션 구성
```

#### Tutor 개입 차이

```
카드 단위 (현재):
  "이 카드를 3번 연속 틀렸습니다."

개념 단위 (개선):
  "삼투 개념에서 확산과의 차이를 자주 헷갈리고 있어요.
   핵심 차이: 삼투는 반투막 필요, 확산은 필요 없음.
   [삼투 vs 확산 집중 복습]"
```

### 7.4 DB 스키마 변경

```sql
-- 신규 테이블
CREATE TABLE concept_proficiencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proficiency_score REAL NOT NULL DEFAULT 0.0,
    total_attempts INTEGER NOT NULL DEFAULT 0,
    correct_attempts INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    weakness_pattern TEXT,
    last_tested_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (concept_id, user_id)
);

CREATE INDEX idx_cp_user_status ON concept_proficiencies(user_id, status);
CREATE INDEX idx_cp_user_proficiency ON concept_proficiencies(user_id, proficiency_score);
```

---

## 8. Cognitive Update 시스템

### 8.1 정의

> **같은 개념에 대해 새 자료가 들어오면, 기존 카드를 "추가"가 아니라 "진화"시키는 것.**

기존: Source를 넣을 때마다 독립적으로 카드 생성 → 중복 누적
개선: 새 Source의 개념이 기존 개념과 겹치면 → 보강/병합 제안

### 8.2 처리 흐름

```
1. 새 Source 입력
2. Card Generation Pipeline 시작
3. 개념 추출 (concepts 리스트)
4. ★ Concept Matching (신규 단계)
   │
   ├── 각 추출된 concept에 대해:
   │   ├── 해당 concept의 embedding 생성
   │   ├── 기존 concepts 테이블에서 코사인 유사도 검색 (pgvector)
   │   ├── 유사도 > 0.85 → "같은 개념" 판정
   │   └── 유사도 0.7~0.85 → "관련 개념" 판정
   │
   ├── 같은 개념이 발견된 경우:
   │   ├── 해당 개념에 연결된 기존 카드(들) 조회
   │   ├── 기존 카드의 answer + 새 자료의 관련 텍스트를 LLM에 전달
   │   ├── LLM이 "보강된 답변" 생성
   │   └── 유저에게 선택지 제안 (아래 8.3)
   │
   └── 같은 개념이 없는 경우:
       └── 기존 파이프라인대로 새 카드 생성
```

### 8.3 유저 선택지

개념 겹침이 감지되면 유저에게 3가지 선택지를 제안:

```
┌────────────────────────────────────────────────────┐
│  🔄 업데이트 감지: "삼투"                            │
│                                                    │
│  기존 카드 1장과 새 자료의 내용이 겹칩니다.            │
│                                                    │
│  기존 답변:                                         │
│  "반투막을 통해 용매가 저농도에서 고농도로 이동"        │
│                                                    │
│  새 자료에서 발견된 추가 내용:                         │
│  "삼투압 공식 π = iMRT, 등장/저장/고장액 구분"         │
│                                                    │
│  ┌────────────────────────────────────────────────┐│
│  │ [보강] 기존 카드의 답변을 더 상세하게 업데이트      ││
│  │        + 새 하위 카드 2장 추가                    ││
│  ├────────────────────────────────────────────────┤│
│  │ [유지] 기존 카드는 그대로, 새 카드만 추가           ││
│  ├────────────────────────────────────────────────┤│
│  │ [건너뛰기] 겹치는 내용은 카드로 만들지 않음         ││
│  └────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────┘
```

### 8.4 각 선택지의 결과

#### [보강]

```python
# 1. 기존 카드의 answer를 LLM에게 보강 요청
merged_answer = llm.merge_answers(
    existing_answer="반투막을 통해 용매가 이동하는 현상",
    new_content="삼투압은 π = iMRT로 계산되며, 등장액/저장액/고장액에 따라...",
    instruction="기존 답변을 유지하면서 새 정보로 보강하세요. 간결하게."
)
# → "반투막을 통해 용매가 저농도에서 고농도로 이동하는 현상.
#    삼투압은 π = iMRT로 계산. 등장액에서는 삼투 평형 도달."

# 2. 기존 Card UPDATE
card.answer = merged_answer
card.updated_at = now()
card.metadata["enriched_from"] = [new_source_id]

# 3. 겹치지 않는 새 하위 카드는 정상 생성
# C7: "삼투압 공식은?"
# C8: "등장액이란?"
```

#### [유지]

```python
# 기존 카드 변경 없음
# 새 카드만 전부 INSERT (중복 포함 가능)
```

#### [건너뛰기]

```python
# 겹치는 개념의 카드는 생성하지 않음
# 겹치지 않는 개념의 카드만 생성
```

### 8.5 기술 구현 세부

#### Embedding 기반 개념 매칭

```python
from pgvector.sqlalchemy import Vector

async def find_matching_concepts(
    new_concepts: list[str],
    user_id: str,
    threshold: float = 0.85
) -> dict[str, list[Concept]]:
    """새 개념들과 기존 개념 간 매칭 결과 반환"""
    matches = {}
    
    for concept_name in new_concepts:
        # 새 개념의 임베딩 생성
        embedding = await generate_embedding(concept_name)
        
        # pgvector로 유사 개념 검색
        results = await db.execute(
            select(Concept)
            .where(Concept.user_id == user_id)
            .order_by(Concept.embedding.cosine_distance(embedding))
            .limit(5)
        )
        
        similar = [
            c for c in results.scalars()
            if cosine_similarity(c.embedding, embedding) > threshold
        ]
        
        if similar:
            matches[concept_name] = similar
    
    return matches
```

#### 답변 병합 프롬프트

```python
MERGE_PROMPT = """
기존 카드의 답변과 새 자료를 비교하여 보강된 답변을 작성하세요.

규칙:
1. 기존 답변의 핵심 내용을 유지하세요.
2. 새 자료에서 추가된 정보만 자연스럽게 통합하세요.
3. 전체 답변 길이는 기존의 1.5배를 넘지 마세요.
4. 모순되는 정보가 있으면 새 자료를 우선하되, 기존 내용도 언급하세요.

기존 답변: {existing_answer}
새 자료 관련 부분: {new_content}

보강된 답변:
"""
```

### 8.6 DB 변경

```sql
-- Card 테이블에 enrichment 이력 추가
ALTER TABLE cards ADD COLUMN enrichment_history JSONB DEFAULT '[]';
-- 예: [
--   { "source_id": "...", "type": "merged", "date": "2026-04-15", "diff": "삼투압 공식 추가" }
-- ]

-- concepts 테이블에 embedding 컬럼 확인 (이미 존재하면 스킵)
-- ALTER TABLE concepts ADD COLUMN embedding vector(768);
-- CREATE INDEX idx_concepts_embedding ON concepts USING ivfflat (embedding vector_cosine_ops);
```

---

## 9. 전체 파이프라인 아키텍처

### 9.1 개선된 전체 플로우

```
┌─────────────────────────────────────────────────────────────┐
│                         1. DROP                              │
│                                                              │
│  text        csv         link         pdf                    │
│   │           │           │            │                     │
│   │           │      trafilatura    pymupdf                  │
│   │           │       (크롤링)      (텍스트 추출)              │
│   │           │           │            │                     │
│   ▼           ▼           ▼            ▼                     │
│  ┌─────────────────────────────────────┐                     │
│  │    POST /sources                    │                     │
│  │    → Source 생성                     │                     │
│  │    → Job 생성 (csv 제외)             │                     │
│  │    → 즉시 202 응답                   │                     │
│  └──────────────┬──────────────────────┘                     │
│                 │                                            │
│    ┌────────────┴────────────────────┐                       │
│    │   유저: 홈으로 즉시 복귀          │                       │
│    │   홈에서 "처리 중..." 표시        │                       │
│    └─────────────────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
                  │
                  ▼ (백그라운드 - JobRunner)
┌─────────────────────────────────────────────────────────────┐
│                      2. ANALYZE                              │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  2a. Title 자동 생성 (title이 없는 경우)                │  │
│  │      LLM(raw_content) → "유기화학 작용기 반응"          │  │
│  │      → Source.title UPDATE                             │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  2b. Chunking                                          │  │
│  │      raw_content → paragraphs → source_chunks          │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  2c. 도메인 감지                                        │  │
│  │      LLM(chunks sample) → domain_hint: "exam"          │  │
│  │      → Source.domain_hint UPDATE                        │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  2d. 개념 추출                                          │  │
│  │      LLM(chunks) → concepts: ["삼투", "확산", ...]     │  │
│  │      → concepts 테이블 INSERT + embedding 생성          │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  2e. ★ Concept Matching (Cognitive Update)              │  │
│  │      새 concepts ↔ 기존 concepts 임베딩 유사도 비교      │  │
│  │      → 겹침 발견 시: update_suggestions 생성             │  │
│  │      → 겹침 없으면: 정상 진행                            │  │
│  └────────────────────────┬───────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      3. GENERATE                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  3a. 카드 생성                                          │  │
│  │      concept + domain_hint → 도메인별 프롬프트 선택      │  │
│  │      LLM → cards (question, answer, card_type, extra)  │  │
│  │      → cards 테이블 INSERT                              │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  3b. 카드 후처리                                        │  │
│  │      중복 제거, 질문 길이 검사, 답변 적정 길이 검사       │  │
│  │      품질 경고 태깅 (너무 넓은 Q, 너무 긴 A, 모호함)     │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  3c. MemoryState 초기화                                 │  │
│  │      각 카드별 초기 MemoryState 생성                     │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  3d. ConceptProficiency 초기화                           │  │
│  │      각 개념별 초기 proficiency 생성 (status: "new")     │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  3e. Job 완료 처리                                      │  │
│  │      Job.status = "completed"                           │  │
│  │      Source.status = "done"                              │  │
│  │      Source.metadata.card_count = N                      │  │
│  └────────────────────────┬───────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      4. NOTIFY                               │
│                                                              │
│  홈 화면에 결과 카드 표시:                                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  ✅ 유기화학 작용기 반응                                │  │
│  │  12장 생성 · 4개 개념 · 난이도 평균 3.1                  │  │
│  │                                                        │  │
│  │  ⚠️ 개념 업데이트 1건 (삼투)  ← Cognitive Update 있을 때 │  │
│  │                                                        │  │
│  │  [바로 학습]  [카드 편집]  [업데이트 확인]                │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      5. REVIEW & EDIT                        │
│                                                              │
│  5a. 리뷰: 도메인별 리뷰 UI로 학습                             │
│      → 오답 시: 카드 MemoryState 업데이트                       │
│      → 오답 시: 같은 concept의 형제 카드 우선순위 boost          │
│      → 오답 시: ConceptProficiency 재계산                       │
│      → 오답 시: Tutor 개입 판단 (개념 단위)                     │
│                                                              │
│  5b. 편집: 도메인별 편집 UI로 카드 수정                          │
│      → exam: 키워드, 난이도                                    │
│      → language: 예문, 발음, 유사                              │
│      → code: 코드, 결과                                       │
│      → general: 관련 개념                                     │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      6. EVOLVE                               │
│                                                              │
│  6a. ConceptProficiency 지속 갱신                               │
│      → 각 리뷰 후 개념 숙련도 재계산                              │
│      → status 변화: new → learning → reviewing → mastered      │
│                                                              │
│  6b. Insight 탭: 개념 단위 약점 시각화                            │
│      → "약한 개념 3개: 삼투(55%), 화학평형(42%), 유전발현(38%)"   │
│      → [집중 복습] 버튼                                        │
│                                                              │
│  6c. Cognitive Update (새 자료 입력 시)                          │
│      → 기존 개념 감지 → 보강/유지/건너뛰기 제안                    │
│      → 선택에 따라 기존 카드 UPDATE 또는 새 카드 INSERT           │
│      → enrichment_history 기록                                 │
│                                                              │
│  6d. Tutor 개입 (개념 단위)                                     │
│      → "삼투를 확산과 헷갈리고 있어. 핵심 차이를 짚어볼까?"         │
│      → 같은 개념의 오답을 새 맥락으로 재출제                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. 참고 레포 차용 매핑

### 10.1 tutor-skills (RoundTable02) — 차용 항목

| # | tutor-skills 기능 | Plowth 적용 | 적용 위치 |
|---|-------------------|-------------|----------|
| T1 | 소스 자동 탐지 (확장자/빌드파일 기반 모드 결정) | source_type 자동 감지: 확장자 기반 + 내용 기반 fallback | §4 입력 유형 |
| T2 | 개념 추출 → 비교 테이블, ASCII 다이어그램 | 비교형 카드 생성 (card_type: comparison), 다이어그램 설명 | §6 도메인별 카드 |
| T3 | Practice Q → Active Recall (fold callout) | 리뷰 UI: 답 숨기기 → 탭하여 공개 | §6.4 리뷰 UI |
| T4 | MOC (Map of Content) + Quick Reference | Insight 탭 → 학습 개념 지도 시각화 | §9 파이프라인 6단계 |
| T5 | Exam Traps (시험 함정 포인트) | card.tags에 "exam_trap" 자동 태깅 | §6.2 exam 도메인 |
| T6 | Concept-level proficiency tracking | ConceptProficiency 테이블 + 개념 숙련도 | §7 전체 |
| T7 | 오답 시 다른 맥락으로 재출제 | Tutor가 약점 개념을 새 문맥의 Q로 재생성 | §9 6d단계 |

### 10.2 scholar-skill (EESJGong) — 차용 항목

| # | scholar-skill 기능 | Plowth 적용 | 적용 위치 |
|---|-------------------|-------------|----------|
| S1 | 3종 메모리 (semantic/episodic/procedural) | 개념당 "무엇(정의)/어떻게(절차)/왜(원리)" 다축 카드 생성 | §6.2 카드 생성 프롬프트 |
| S2 | Knowledge Linking (새 자료 → 기존 개념 연결) | Source 간 concept 중복 탐지 → 연관 카드 자동 연결 | §8 Cognitive Update |
| S3 | Cognitive Update (새 증거 → 기존 이해 수정) | 임베딩 유사도 매칭 → 보강/유지/건너뛰기 제안 | §8 전체 |
| S4 | 비판적 사고 프롬프트 (비교, 증거 검증) | Tutor의 related 기능을 "비교/대조" 수준으로 강화 | §9 6d단계 |
| S5 | MOC 자동 생성 | 여러 Source에서 추출된 개념 자동 그룹핑 → 학습 지도 | §9 6b단계 |
| S6 | 점진적 지식 진화 | enrichment_history로 카드 변천 이력 추적 | §8.6 DB 변경 |

---

## 11. 재설정된 구현 순서 & 우선순위

이 섹션은 현재 코드베이스 리뷰 결과를 반영해 다시 정렬한 실행 순서다.

### 재정렬 원칙

- 검증 가능한 작은 단계부터 진행한다.
- UI 개선과 API/DB 계약 변경을 섞지 않는다.
- `text` 캡처 UX를 먼저 안정화한 뒤 `csv/link/pdf`를 확장한다.
- 도메인 적응과 Cognitive Update는 schema contract가 정리된 뒤 진행한다.
- 각 Phase는 Gate를 통과해야 다음 Phase로 넘어간다.

---

### Phase 0: 기준선 안정화

**목표:** 현재 작업 트리의 검증 실패를 제거하고, 이후 캡처 UX 변경을 안전하게 시작한다.

```
0.1. [x] stale `mobile/lib/features/review_screen.dart` 정리
       - 삭제하거나 `review_session_screen.dart`와 역할을 명확히 분리
       - `flutter analyze`의 `_TutorSheet` undefined 오류 제거

0.2. [x] README/HANDOFF 검증 내역 최신화
       - backend test count: 7 → 10
       - Tutor/Insight 상태를 현재 구현 기준으로 수정

0.3. [x] 현재 검증 명령 재실행
       - backend: python -m unittest test_phase2_services.py
       - mobile: flutter test
       - mobile: flutter analyze

0.4. [x] `docs/STATUS_LOG.md`에 안정화 결과 기록
```

**Gate:**
- backend unit tests pass
- flutter tests pass
- flutter analyze pass
- STATUS_LOG 최신화 완료

---

### Phase A: Text Capture UX 정상화

**목표:** DB migration 없이 현재 `text` 파이프라인의 사용자 경험을 PRD 방향에 맞춘다.

```
A1. [x] CaptureScreen에서 Title 필드 제거
       - `_titleController` 제거
       - 사용자는 원문만 입력

A2. [x] Source/Card 내부 용어 제거
       - "Title", "Notes", "Source", "Job", "Phase 2 pipeline" 같은 내부 표현 제거
       - CTA는 "카드 만들기"로 정리

A3. [x] `StudyRepository.createTextSource`에서 title을 optional/null로 전송
       - rawContent만 필수
       - 기존 API shape은 유지

A4. [x] deterministic title fallback 추가
       - LLM 호출 전제 없이 raw_content 첫 문장/키워드 기반 제목 생성
       - 나중에 LLM title extraction으로 교체 가능한 helper 형태

A5. [x] 제출 후 CaptureScreen 내부 장기 polling 제거
       - 생성 요청 성공 시 홈으로 이동
       - 중복 생성 방지는 기존 active job 조회 로직 재사용

A6. [x] HomeScreen에 active generation 상태 카드 추가
       - pending/running: "처리 중"
       - completed: 생성 수/개념 수 요약 + [바로 학습] [카드 편집]
       - failed: 실패 메시지 + [다시 시도]

A7. [~] 완료된 source의 카드 편집 진입점 정리
       - CaptureScreen에 전체 카드 목록을 계속 둘지
       - 별도 card review/edit 화면으로 이동할지 결정
       - 현재 결정: CaptureScreen 목록은 제거, Home 완료 카드에서는 [Start Review]/[Add More]만 제공
```

**Gate:**
- text 입력 → 홈 복귀 → 처리 중 표시 → 완료 요약 → 리뷰 시작이 끊기지 않음
- 기존 text card generation 테스트 유지
- flutter analyze pass

---

### Phase B: 입력 확장 API 계약 정리

**목표:** `csv/link/pdf`를 구현하기 전에 endpoint, schema, job ownership를 고정한다.

```
B1. [x] source_type 계약 재정의
       - canonical source types: text|csv|link|pdf
       - CSV도 Source로 기록하되, 생성 방식은 AI pipeline이 아닌 import pipeline

B2. [x] endpoint 계약 확정
       - text: POST /sources
       - link: POST /sources
       - pdf: POST /sources/upload
       - csv preview/import: POST /sources/csv/preview, POST /sources/csv/import

B3. [x] 응답 코드/응답 body 정리
       - Source가 생성되면 201 Created 유지
       - 장기 async-only 작업을 별도 endpoint로 뺄 때만 202 Accepted 사용
       - SourceCreateResponse에 `id`, `job_id`, `status`, `source_type` 포함 유지

B4. [x] job ownership 규칙 확정
       - text/link/pdf: JobRunner 기반 async
       - csv 소량: sync import 가능
       - csv 대량: async job 전환

B5. [x] 의존성 추가 기준 확정
       - mobile file picker package는 Phase C 시작 시 추가
       - backend link extractor는 Phase D 시작 시 추가
       - backend csv parser는 stdlib `csv` 우선
```

**Gate:**
- OpenAPI/docs와 실제 Pydantic schema가 일치
- mobile repository method contract가 확정
- STATUS_LOG에 API 계약 결정 기록

#### Phase B 확정 계약

| 입력 | Endpoint | Request | 처리 | Response |
|---|---|---|---|---|
| text | `POST /sources` | JSON `{source_type:"text", raw_content}` | Source + Job 생성, JobRunner async | `201 SourceCreateResponse` |
| link | `POST /sources` | JSON `{source_type:"link", url}` | URL 추출 후 Source + Job 생성, JobRunner async | `201 SourceCreateResponse` |
| pdf | `POST /sources/upload` | multipart `{source_type:"pdf", file}` | 파일 검증/추출 후 Source + Job 생성, JobRunner async | `201 SourceCreateResponse` |
| csv preview | `POST /sources/csv/preview` | multipart `{file}` | 첫 행/컬럼/샘플만 파싱 | `200 CsvPreviewResponse` |
| csv import | `POST /sources/csv/import` | multipart `{file, question_column, answer_column, tag_columns?}` | Source 생성 + Card 직접 INSERT | `201 CsvImportResponse` |

Phase C 시작 시 실제 코드 계약은 다음 순서로 맞춘다.

1. `SourceCreate.source_type` regex를 `^(text|csv|pdf|link)$`로 확장한다.
2. CSV 전용 Pydantic schema를 추가한다.
3. CSV import 결과는 `source_id`, `card_count`, `skipped_count`, `status`를 반환한다.
4. CSV 소량 import는 `Job`을 만들지 않는다.
5. CSV 대량 async 전환은 Phase C 이후 별도 작업으로 남긴다.

---

### Phase C: CSV Import

**목표:** AI 비용 없이 Q/A 컬럼 매핑으로 빠른 카드 import를 제공한다.

```
C1. [x] CSV 파일 선택 UI 추가
C2. [x] CSV preview endpoint 구현
       - 첫 3~5행, column list 반환
C3. [x] 컬럼 매핑 UI 구현
       - question column
       - answer column
       - optional tag columns
C4. [x] import endpoint 구현
       - Source 생성
       - Card 직접 INSERT
       - MemoryState 초기화는 생략: review queue가 MemoryState 없는 새 카드를 new로 수집
C5. [x] row limit/validation/error handling 추가
       - synchronous import limit: 500 data rows
       - upload size limit: 2MB
       - UTF-8/UTF-8 BOM/CP949 decode 지원
C6. [x] CSV import 단위 테스트 및 mobile parsing/widget smoke test 추가
       - backend csv_import unit tests 추가
       - mobile CsvPreview/CsvImportResult parsing tests 추가
```

**Gate:**
- CSV 2~3행 sample import 성공
- 중복/빈 행/잘못된 column index validation 통과
- backend/mobile 검증 통과

---

### Phase D: Link Ingest

**목표:** URL 본문 추출 후 기존 text generation pipeline을 재사용한다.

```
D1. [x] URL 입력 UI 추가
D2. [x] URL validation 추가
       - scheme, length, timeout, blocked/private network policy
D3. [x] HTML fetch + 본문 추출 service 추가
       - stdlib HTMLParser + httpx 우선 적용
D4. [x] 추출 결과를 Source.raw_content에 저장
D5. [x] 기존 card_generation job으로 연결
D6. [x] 접근 실패/본문 부족/비텍스트 content-type/private URL 에러 처리
D7. [x] link ingest service tests 추가
```

**Gate:**
- 공개 문서 URL → source 생성 → job 완료 → cards 생성
- 실패 케이스가 사용자 문구로 반환됨
- backend/mobile 검증 통과

---

### Phase E: PDF Ingest

**목표:** PDF 업로드와 텍스트 추출을 기존 generation pipeline에 연결한다.

```
E1. [x] PDF file picker + upload UI 추가
E2. [x] POST /sources/upload 구현
E3. [x] file size/content-type validation 추가
E4. [x] pymupdf 기반 텍스트 추출 service 추가
E5. [x] password/scanned/empty PDF 에러 처리
E6. [x] 추출 metadata 저장
       - filename
       - page_count
       - extracted_length
       - extraction_method
E7. [x] 기존 card_generation job으로 연결
E8. [x] PDF extraction tests 추가
```

**Gate:**
- 텍스트 기반 PDF → cards 생성
- password/empty PDF validation 통과
- backend/mobile 검증 통과

---

### Phase F: 도메인 적응 카드

**목표:** schema migration을 최소화하며 domain-aware generation을 먼저 실험한다.

```
F1. [x] domain_hint 감지 helper 추가
       - exam/language/code/general
       - 초기 버전은 heuristic + metadata 저장

F2. [x] Source.metadata_에 domain_hint 저장
       - 당장 sources.domain_hint 컬럼 추가는 보류

F3. [x] Card.tags에 domain_subtype/extra metadata 저장
       - 기존 card_type enum은 유지
       - 예: card_type="definition", tags={"domain": "language", "subtype": "vocabulary"}

F4. [x] 도메인별 card generation branch 추가
       - 기존 schema에 들어갈 수 있는 card_type으로 normalize

F5. [~] 도메인별 review/edit UI는 metadata 기반으로 점진 적용
       - review label에 domain_hint 노출
       - edit UI의 도메인별 세부 편집은 후속 작업

F6. [x] 실제 사용 후 `Card.extra`, `Source.domain_hint` 컬럼 migration 여부 결정
       - 현재 결정: migration 없이 Source.metadata_와 Card.tags 사용
```

**Gate:**
- 기존 CardCreate regex와 충돌 없음
- domain metadata가 cards/list/review UI에서 깨지지 않음
- regression tests 통과

---

### Phase G: 개념 단위 추적

**목표:** 이미 존재하는 `concepts`, `cards.concept_id`, `mistake_patterns`, `learning_profiles`를 먼저 활용하고, 별도 테이블은 필요가 확인된 뒤 추가한다.

```
G1. [x] 개념별 review aggregation query 정리
       - Concept -> SourceChunk -> Source로 user scope 제한

G2. [x] Insight weak concepts를 concept-level score로 확장

G3. [x] review failure 시 sibling cards priority boost 설계
       - daily_review_queue priority에만 반영할지
       - MemoryState next_review_at을 직접 당길지 결정

G4. [x] Tutor intervention을 concept_id 기준으로 확장

G5. [x] concept_proficiencies 테이블 필요성 재평가
       - 필요 시 Alembic migration 추가
       - 현재 결정: 기존 MemoryState/MistakePattern/LearningProfile 집계 유지
```

**Gate:**
- 사용자별 concept aggregation이 source join으로 안전하게 제한됨
- Insight/Tutor가 concept 기준으로 일관된 결과를 냄

---

### Phase H: Cognitive Update

**목표:** 새 자료가 기존 개념을 보강/유지/건너뛰기 할 수 있도록 장기 지식 진화 레이어를 추가한다.

```
H1. [x] embedding 저장 위치 결정
       - Concept.embedding 추가
       - 별도 concept_embeddings 테이블
       - 또는 source_chunks embedding 우선
       - 현재 결정: migration 없이 lexical matcher 우선, embedding 저장은 후속 고도화

H2. [x] pgvector extension/migration 추가
       - vector dimension 확정
       - ivfflat/hnsw index 전략 확정
       - 현재 결정: 이번 구현에서는 migration 없음. pgvector는 false-positive 평가 후 별도 migration

H3. [x] user scope 결정
       - Concept.user_id 추가
       - 또는 Concept -> SourceChunk -> Source.user_id join 유지
       - 현재 결정: Concept -> SourceChunk -> Source.user_id join 유지

H4. [x] concept matching service 구현

H5. [x] update suggestion model/API 추가
       - reinforce
       - keep separate
       - skip duplicate

H6. [x] merge answer prompt/service 구현

H7. [x] enrichment history 저장 전략 결정
       - Card.tags 확장
       - Card.enrichment_history 컬럼 추가
       - 별도 enrichment_events 테이블
       - 현재 결정: Card.tags.enrichment_history 사용, 최근 10개 유지

H8. [x] 유저 선택 UI 구현

H9. [x] end-to-end tests 추가
       - backend service tests + mobile model/UI compile validation
```

**Gate:**
- 기존 카드가 의도치 않게 덮어써지지 않음
- 모든 merge/update는 audit history를 남김
- similarity threshold와 false positive 대응이 테스트됨

---

### 명시적으로 보류

```
Z1. [ ] image/OCR ingest
Z2. [ ] Anki .apkg import
Z3. [ ] Share Sheet 통합
Z4. [ ] Clipboard 자동 감지
Z5. [ ] live LLM-only title/domain extraction
```

---

## 12. 미래 확장 (확인만 해둔 것)

아래 항목들은 이번 구현 범위에 포함되지 않지만, 설계 시 확장 가능성을 고려해야 한다.

### 12.1 source_type: `image`

- 카메라/갤러리에서 이미지 선택 → OCR → text 파이프라인
- OCR 옵션: Gemini Vision API (품질 최상), Tesseract (오프라인, 품질 중간)
- 스캔 PDF fallback으로도 활용 가능

### 12.2 source_type: `anki` (.apkg)

- .apkg = ZIP(SQLite DB)
- notes.flds 파싱 → Q/A 추출 (기본)
- models 읽어서 Front/Back 자동 매핑 (중급)
- revlog 이식 → MemoryState 초기화 (고급, 킬러 기능)
- Anki → Plowth 전환의 핵심 유인

### 12.3 Share Sheet 통합

- 다른 앱에서 "공유 → Plowth" → 이미지/텍스트/URL 자동 수신
- Flutter: `receive_sharing_intent` 패키지
- 백그라운드에서 source_type 자동 감지 → 파이프라인 투입

### 12.4 클립보드 감지

- 앱 진입 시 클립보드 내용 감지 → 텍스트/URL 판별
- "이 내용으로 카드 만들까요?" 토스트 표시
- 개인정보 고려: 최초 1회만 물어보기, 설정에서 비활성화 옵션

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-04-10 | Phase H Cognitive Update implemented with lexical preview/apply API, Card.tags enrichment history, and Insight UI. |
| 2026-04-10 | Phase G concept tracking completed using existing concept/review/mistake models and weakness priority boost. |
| 2026-04-10 | Phase F domain-adaptive cards implemented with heuristic domain_hint, Card.tags metadata, and review labels. |
| 2026-04-10 | Phase E PDF ingest implementation completed: upload API, PyMuPDF extraction, mobile PDF picker, tests. |
| 2026-04-10 | Phase D Link ingest implementation completed: URL input UI, backend fetch/extract service, JobRunner handoff, tests. |
| 2026-04-10 | Phase C CSV import implementation completed: preview/import API, mobile file picker + mapping UI, tests. |
| 2026-04-10 | 현재 코드 리뷰 결과를 반영해 Phase 0~H로 구현 순서 재설정. |
| 2026-04-10 | 초안 작성. 전체 논의 내용 통합. |
