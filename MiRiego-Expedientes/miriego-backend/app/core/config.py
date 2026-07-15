"""
Configuración central de la aplicación.

Lee las variables de entorno desde el archivo .env (ver .env.example).
Python es un lenguaje incipiente para vos, así que dejo comentado el
"por qué" de cada parte, no solo el "qué".
"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_ROOT = Path(__file__).resolve().parents[2]
ENV_FILE = BACKEND_ROOT / ".env"


class Settings(BaseSettings):
    # pydantic-settings lee automáticamente estas variables desde el
    # archivo .env o desde variables de entorno del sistema operativo.
    DATABASE_URL: str
    FRONTEND_ORIGIN: str = "http://localhost:5173"

    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Se instancia una sola vez y se importa desde el resto de la app.
settings = Settings()
