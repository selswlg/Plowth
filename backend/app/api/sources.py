"""
Sources API: CRUD for learning materials and capture imports.
"""

from pathlib import Path
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
    status,
)
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Card, Job, Source, User
from app.schemas import (
    CsvImportResponse,
    CsvPreviewResponse,
    SourceCreate,
    SourceCreateResponse,
    SourceDetail,
    SourceResponse,
)
from app.services.csv_import import (
    CsvImportError,
    build_csv_card_drafts,
    build_csv_preview,
)
from app.services.link_ingest import LinkIngestError, fetch_link_content
from app.services.pdf_ingest import PdfIngestError, extract_text_from_pdf

router = APIRouter(prefix="/sources", tags=["Sources"])
MAX_CSV_FILE_BYTES = 2 * 1024 * 1024
MAX_PDF_FILE_BYTES = 10 * 1024 * 1024


@router.post("", response_model=SourceCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_source(
    body: SourceCreate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a new learning material."""
    if body.source_type not in {"text", "link"}:
        if body.source_type == "csv":
            detail = "CSV sources must use /sources/csv/preview and /sources/csv/import."
        elif body.source_type == "pdf":
            detail = "PDF upload is planned for /sources/upload."
        else:
            detail = "Unsupported source type."
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        )

    source_title = body.title.strip() if body.title and body.title.strip() else None
    source_url = body.url
    raw_content = body.raw_content.strip() if body.raw_content else None
    source_metadata: dict | None = None

    if body.source_type == "text" and not raw_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="raw_content is required for text sources",
        )

    if body.source_type == "link":
        if not body.url:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="url is required for link sources",
            )
        try:
            extraction = await fetch_link_content(body.url)
        except LinkIngestError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc

        raw_content = extraction.text
        source_url = extraction.url
        if source_title is None:
            source_title = extraction.title
        source_metadata = {
            **extraction.metadata,
            "title_strategy": (
                "provided"
                if body.title and body.title.strip()
                else "html_title"
                if extraction.title
                else "heuristic"
            ),
        }

    existing_result = await db.execute(
        select(Source, Job)
        .join(
            Job,
            and_(
                Job.source_id == Source.id,
                Job.job_type == "card_generation",
            ),
        )
        .where(
            Source.user_id == current_user.id,
            Source.source_type == body.source_type,
            Source.title == source_title,
            Source.raw_content == raw_content,
            Source.url == source_url,
            Job.status.in_(("pending", "running")),
        )
        .order_by(Job.created_at.desc())
        .limit(1)
    )
    existing = existing_result.first()
    if existing is not None:
        source, job = existing
        await request.app.state.job_runner.schedule(job.id)
        return SourceCreateResponse(
            id=source.id,
            title=source.title,
            source_type=source.source_type,
            status=source.status,
            created_at=source.created_at,
            updated_at=source.updated_at,
            job_id=job.id,
        )

    source = Source(
        user_id=current_user.id,
        title=source_title,
        source_type=body.source_type,
        raw_content=raw_content,
        url=source_url,
        status="analyzing",
        metadata_=source_metadata,
    )
    db.add(source)
    await db.flush()

    job = Job(
        user_id=current_user.id,
        job_type="card_generation",
        status="pending",
        source_id=source.id,
        result_summary={
            "phase": "phase_d_link" if body.source_type == "link" else "phase2",
            "source_type": body.source_type,
        },
    )
    db.add(job)
    await db.flush()
    await db.commit()
    await request.app.state.job_runner.schedule(job.id)

    return SourceCreateResponse(
        id=source.id,
        title=source.title,
        source_type=source.source_type,
        status=source.status,
        created_at=source.created_at,
        updated_at=source.updated_at,
        job_id=job.id,
    )


async def _read_csv_upload(file: UploadFile) -> bytes:
    if file.filename and not file.filename.lower().endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a .csv file.",
        )

    content = await file.read()
    if len(content) > MAX_CSV_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="CSV file is too large for synchronous import.",
        )
    return content


def _parse_tag_columns(value: str | None) -> list[int]:
    if value is None or not value.strip():
        return []
    try:
        return [int(part.strip()) for part in value.split(",") if part.strip()]
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="tag_columns must be a comma-separated list of column indexes.",
        ) from exc


def _csv_title(filename: str | None) -> str:
    if not filename:
        return "CSV import"
    stem = Path(filename).stem.strip()
    return stem or "CSV import"


async def _read_pdf_upload(file: UploadFile) -> bytes:
    if file.filename and not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a .pdf file.",
        )

    if file.content_type and file.content_type not in {
        "application/pdf",
        "application/octet-stream",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PDF upload must use application/pdf content.",
        )

    content = await file.read()
    if len(content) > MAX_PDF_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PDF file is too large for this import path.",
        )
    return content


@router.post("/upload", response_model=SourceCreateResponse, status_code=status.HTTP_201_CREATED)
async def upload_source_file(
    request: Request,
    source_type: str = Form("pdf"),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a file-backed source. Phase E supports text-based PDFs."""
    if source_type != "pdf":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF upload is supported by this endpoint.",
        )

    content = await _read_pdf_upload(file)
    try:
        extraction = extract_text_from_pdf(content, filename=file.filename)
    except PdfIngestError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    source = Source(
        user_id=current_user.id,
        title=extraction.title,
        source_type="pdf",
        raw_content=extraction.text,
        file_path=file.filename,
        status="analyzing",
        metadata_=extraction.metadata,
    )
    db.add(source)
    await db.flush()

    job = Job(
        user_id=current_user.id,
        job_type="card_generation",
        status="pending",
        source_id=source.id,
        result_summary={"phase": "phase_e_pdf", "source_type": "pdf"},
    )
    db.add(job)
    await db.flush()
    await db.commit()
    await request.app.state.job_runner.schedule(job.id)

    return SourceCreateResponse(
        id=source.id,
        title=source.title,
        source_type=source.source_type,
        status=source.status,
        created_at=source.created_at,
        updated_at=source.updated_at,
        job_id=job.id,
    )


@router.post("/csv/preview", response_model=CsvPreviewResponse)
async def preview_csv_source(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Preview CSV columns and sample rows before importing cards."""
    _ = current_user
    content = await _read_csv_upload(file)
    try:
        return build_csv_preview(content)
    except CsvImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post(
    "/csv/import",
    response_model=CsvImportResponse,
    status_code=status.HTTP_201_CREATED,
)
async def import_csv_source(
    file: UploadFile = File(...),
    question_column: int = Form(...),
    answer_column: int = Form(...),
    tag_columns: str | None = Form(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Import mapped CSV rows as cards without running the AI generation job."""
    content = await _read_csv_upload(file)
    try:
        table, drafts, skipped_count = build_csv_card_drafts(
            content,
            question_column=question_column,
            answer_column=answer_column,
            tag_columns=_parse_tag_columns(tag_columns),
        )
    except CsvImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    source = Source(
        user_id=current_user.id,
        title=_csv_title(file.filename),
        source_type="csv",
        status="done",
        metadata_={
            "filename": file.filename,
            "row_count": len(table.rows),
            "column_count": len(table.columns),
            "columns": table.columns,
            "card_count": len(drafts),
            "skipped_count": skipped_count,
            "importer": "csv-import-v1",
        },
    )
    db.add(source)
    await db.flush()

    for draft in drafts:
        db.add(
            Card(
                user_id=current_user.id,
                source_id=source.id,
                card_type="definition",
                question=draft.question,
                answer=draft.answer,
                difficulty=3,
                tags={
                    "csv_tags": draft.tags,
                    "source_row": draft.source_row,
                },
            )
        )

    await db.flush()
    return CsvImportResponse(
        source_id=source.id,
        title=source.title,
        source_type=source.source_type,
        status=source.status,
        card_count=len(drafts),
        skipped_count=skipped_count,
        row_count=len(table.rows),
        columns=table.columns,
    )


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
