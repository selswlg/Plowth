"""
Plowth - AI Learning OS
Application configuration module.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    APP_NAME: str = "Plowth"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://real_user:real_dev_password@localhost:5432/real_db"
    AUTO_CREATE_TABLES: bool = False

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

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


@lru_cache
def get_settings() -> Settings:
    return Settings()
