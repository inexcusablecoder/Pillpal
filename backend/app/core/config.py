from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    firebase_project_id: str = "pillpal-ed37e"
    google_application_credentials: str | None = None
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    cors_origins: str = "*"


settings = Settings()
