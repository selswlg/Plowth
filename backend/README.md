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
