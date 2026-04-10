"""
CSV preview and import helpers.

The CSV path intentionally avoids model calls. Users map columns to Q/A fields,
then each valid data row becomes one card.
"""

from __future__ import annotations

import csv
import io
from dataclasses import dataclass


MAX_CSV_IMPORT_ROWS = 500
MAX_CSV_PREVIEW_ROWS = 5


class CsvImportError(ValueError):
    """Raised when a CSV file cannot be previewed or imported."""


@dataclass(frozen=True)
class CsvTable:
    columns: list[str]
    rows: list[dict[str, str]]


@dataclass(frozen=True)
class CsvCardDraft:
    question: str
    answer: str
    tags: list[str]
    source_row: int


def decode_csv_bytes(content: bytes) -> str:
    """Decode common CSV encodings while keeping local imports dependency-free."""
    if not content:
        raise CsvImportError("CSV file is empty.")

    for encoding in ("utf-8-sig", "utf-8", "cp949"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue

    raise CsvImportError("CSV file must be encoded as UTF-8 or CP949.")


def _fallback_column_name(index: int) -> str:
    return f"Column {index + 1}"


def _normalize_columns(header: list[str]) -> list[str]:
    columns: list[str] = []
    seen: dict[str, int] = {}

    for index, raw_name in enumerate(header):
        name = " ".join(raw_name.replace("\ufeff", "").split())
        if not name:
            name = _fallback_column_name(index)

        count = seen.get(name, 0)
        seen[name] = count + 1
        if count:
            name = f"{name} {count + 1}"
        columns.append(name)

    return columns


def parse_csv_table(content: bytes) -> CsvTable:
    text = decode_csv_bytes(content)
    try:
        raw_rows = list(csv.reader(io.StringIO(text)))
    except csv.Error as exc:
        raise CsvImportError(f"CSV could not be parsed: {exc}") from exc

    rows = [row for row in raw_rows if any(cell.strip() for cell in row)]
    if len(rows) < 2:
        raise CsvImportError("CSV must include a header row and at least one data row.")

    columns = _normalize_columns(rows[0])
    if len(columns) < 2:
        raise CsvImportError("CSV must include at least two columns.")

    table_rows: list[dict[str, str]] = []
    for raw_row in rows[1:]:
        normalized = list(raw_row[: len(columns)])
        if len(normalized) < len(columns):
            normalized.extend([""] * (len(columns) - len(normalized)))
        table_rows.append(
            {
                column: normalized[index].strip()
                for index, column in enumerate(columns)
            }
        )

    if not table_rows:
        raise CsvImportError("CSV must include at least one data row.")

    return CsvTable(columns=columns, rows=table_rows)


def build_csv_preview(content: bytes) -> dict:
    table = parse_csv_table(content)
    return {
        "columns": table.columns,
        "sample_rows": table.rows[:MAX_CSV_PREVIEW_ROWS],
        "row_count": len(table.rows),
    }


def validate_column_index(index: int, column_count: int, field_name: str) -> None:
    if index < 0 or index >= column_count:
        raise CsvImportError(f"{field_name} is outside the CSV column range.")


def build_csv_card_drafts(
    content: bytes,
    *,
    question_column: int,
    answer_column: int,
    tag_columns: list[int] | None = None,
    row_limit: int = MAX_CSV_IMPORT_ROWS,
) -> tuple[CsvTable, list[CsvCardDraft], int]:
    table = parse_csv_table(content)
    tag_columns = tag_columns or []

    validate_column_index(question_column, len(table.columns), "question_column")
    validate_column_index(answer_column, len(table.columns), "answer_column")
    if question_column == answer_column:
        raise CsvImportError("question_column and answer_column must be different.")
    for tag_column in tag_columns:
        validate_column_index(tag_column, len(table.columns), "tag_columns")

    drafts: list[CsvCardDraft] = []
    skipped_count = 0
    limited_rows = table.rows[:row_limit]

    for data_index, row in enumerate(limited_rows):
        source_row = data_index + 2
        question = row[table.columns[question_column]].strip()
        answer = row[table.columns[answer_column]].strip()
        if not question or not answer:
            skipped_count += 1
            continue

        tags = [
            row[table.columns[tag_column]].strip()
            for tag_column in tag_columns
            if row[table.columns[tag_column]].strip()
        ]
        drafts.append(
            CsvCardDraft(
                question=question,
                answer=answer,
                tags=tags,
                source_row=source_row,
            )
        )

    skipped_count += max(0, len(table.rows) - row_limit)
    if not drafts:
        raise CsvImportError("CSV did not contain any rows with both question and answer.")

    return table, drafts, skipped_count
