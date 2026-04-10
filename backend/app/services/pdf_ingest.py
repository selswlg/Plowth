"""
PDF text extraction for capture uploads.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import fitz


MIN_PDF_TEXT_LENGTH = 30
MAX_PDF_TEXT_LENGTH = 60_000


class PdfIngestError(ValueError):
    """Raised when a PDF cannot be converted into study text."""


@dataclass(frozen=True)
class PdfExtraction:
    filename: str | None
    title: str | None
    text: str
    metadata: dict


def _title_from_filename(filename: str | None) -> str | None:
    if not filename:
        return None
    title = Path(filename).stem.strip()
    return title or None


def extract_text_from_pdf(content: bytes, *, filename: str | None = None) -> PdfExtraction:
    if not content:
        raise PdfIngestError("PDF file is empty.")

    try:
        document = fitz.open(stream=content, filetype="pdf")
    except Exception as exc:
        raise PdfIngestError("PDF file could not be opened.") from exc

    try:
        if document.needs_pass:
            raise PdfIngestError("Password-protected PDFs are not supported.")

        page_texts: list[str] = []
        for page in document:
            text = page.get_text("text").strip()
            if text:
                page_texts.append(text)

        combined_text = "\n\n".join(page_texts).strip()
        if len(combined_text) > MAX_PDF_TEXT_LENGTH:
            combined_text = combined_text[:MAX_PDF_TEXT_LENGTH].rstrip()
        if len(combined_text) < MIN_PDF_TEXT_LENGTH:
            raise PdfIngestError(
                "PDF did not contain enough selectable text. Scanned PDFs need OCR later."
            )

        metadata = document.metadata or {}
        document_title = (metadata.get("title") or "").strip() or None
        title = document_title or _title_from_filename(filename)
        return PdfExtraction(
            filename=filename,
            title=title,
            text=combined_text,
            metadata={
                "filename": filename,
                "page_count": document.page_count,
                "extracted_length": len(combined_text),
                "extraction_method": "pymupdf",
                "title_strategy": "pdf_metadata" if document_title else "filename",
            },
        )
    finally:
        document.close()
