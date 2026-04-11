# ISS-005: Scanned PDF and OCR ingest are still unsupported

| Field | Value |
|---|---|
| Status | Open |
| Severity | Major |
| Phase | Phase 3 / Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

The current PDF pipeline supports selectable-text PDFs only.
Scanned PDFs and image-based inputs are rejected and have no OCR fallback yet.

## Evidence

- The PDF ingest service explicitly rejects low-text PDFs with `Scanned PDFs need OCR later.` in `backend/app/services/pdf_ingest.py:55-60`.
- Mobile and status docs still list scanned PDF/OCR as a known gap.

## Impact

- A common real-world capture format is unsupported.
- Capture expansion remains incomplete for exam and document-heavy workflows.
- The product promise of “drop material in” is still limited by source format.

## Required Work

- [ ] Choose OCR path for scanned PDF and image ingest
- [ ] Add backend OCR extraction service and failure handling
- [ ] Add mobile image/scanned-document capture or upload surface
- [ ] Define cost, latency, and fallback strategy for OCR jobs
- [ ] Add tests for scanned PDFs and noisy document inputs

## Validation

- [ ] Scanned PDF produces extracted study text and cards
- [ ] OCR failures return clear user-facing messages
- [ ] OCR path is bounded by file-size and runtime limits
