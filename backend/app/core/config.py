from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: Literal["development", "staging", "production"] = "development"

    database_url: str = "postgresql://postgres:postgres@localhost:5432/pillpal"
    jwt_secret: str = "change-me-change-me-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days
    dose_grace_minutes: int = 60
    api_v1_prefix: str = "/api/v1"
    
    # Twilio (Voice Calls)
    twilio_account_sid: str | None = None
    twilio_auth_token: str | None = None
    twilio_number: str | None = None
    groq_api_key: str | None = None

    # Comma-separated origins, or "*" for all. Wildcard disables credentials (browser CORS rules).
    cors_origins: str = "*"

    @model_validator(mode="after")
    def reject_default_jwt_in_production(self) -> "Settings":
        if self.environment == "production" and self.jwt_secret == "change-me-change-me-change-me":
            raise ValueError("JWT_SECRET must be set to a strong secret when ENVIRONMENT=production")
        return self

    def cors_origin_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]


settings = Settings()
