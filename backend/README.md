# Backend Development

## Setup

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger UI is available at `http://localhost:8000/docs`.

## Database workflow

Apply the current schema:

```powershell
alembic upgrade head
```

Create a new migration after model changes:

```powershell
alembic revision --autogenerate -m "describe change"
```

If you need throwaway local tables without running migrations first, set `AUTO_CREATE_TABLES=true` in `.env`.

## Production-oriented config

- `CORS_ALLOW_ORIGINS` accepts a comma-separated list or JSON array. In production, wildcard CORS is rejected at startup.
- `JOB_EXECUTION_MODE=in_process` keeps the current local background runner. Set `JOB_EXECUTION_MODE=external` when a real queue/worker system is responsible for pending jobs.
- `APP_ENV=production` now requires `APP_DEBUG=false`, a non-placeholder `JWT_SECRET_KEY`, and explicit `CORS_ALLOW_ORIGINS`.
