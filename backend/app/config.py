"""
Plowth - AI Learning OS
Application configuration module.
"""

import json
from functools import lru_cache
from typing import Annotated

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    APP_NAME: str = "Plowth"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True

    # API / CORS
    CORS_ALLOW_ORIGINS: Annotated[
        list[str],
        NoDecode,
    ] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ]

    # Database
    DATABASE_URL: str = (
        "postgresql+asyncpg://real_user:real_dev_password@localhost:5432/real_db"
    )
    AUTO_CREATE_TABLES: bool = False

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    JOB_EXECUTION_MODE: str = "in_process"

    # JWT Auth
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # AI
    GEMINI_API_KEY: str = ""
    AI_MODEL_HIGH: str = "gemini-2.5-pro"
    AI_MODEL_LOW: str = "gemini-2.0-flash"

    # S3
    S3_ENDPOINT: str = ""
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""
    S3_BUCKET: str = "real-uploads"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": True,
    }

    @property
    def is_production(self) -> bool:
        return self.APP_ENV.lower() == "production"

    @field_validator("CORS_ALLOW_ORIGINS", mode="before")
    @classmethod
    def _parse_cors_allow_origins(cls, value):
        if value is None:
            return []
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                parsed = json.loads(stripped)
                if not isinstance(parsed, list):
                    raise ValueError("CORS_ALLOW_ORIGINS JSON must decode to a list.")
                return [str(item).strip() for item in parsed if str(item).strip()]
            return [item.strip() for item in stripped.split(",") if item.strip()]
        if isinstance(value, (list, tuple, set)):
            return [str(item).strip() for item in value if str(item).strip()]
        raise ValueError("CORS_ALLOW_ORIGINS must be a list, JSON array, or comma string.")

    @field_validator("JOB_EXECUTION_MODE")
    @classmethod
    def _validate_job_execution_mode(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"in_process", "external"}:
            raise ValueError("JOB_EXECUTION_MODE must be 'in_process' or 'external'.")
        return normalized

    @model_validator(mode="after")
    def _validate_production_safety(self):
        if not self.is_production:
            return self

        if self.APP_DEBUG:
            raise ValueError("APP_DEBUG must be false when APP_ENV=production.")
        if self.JWT_SECRET_KEY.startswith("change-me-in-production"):
            raise ValueError("Set a real JWT_SECRET_KEY before using production mode.")
        if not self.CORS_ALLOW_ORIGINS:
            raise ValueError(
                "Set explicit CORS_ALLOW_ORIGINS before using production mode."
            )
        if "*" in self.CORS_ALLOW_ORIGINS:
            raise ValueError("Wildcard CORS origins are not allowed in production mode.")

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
