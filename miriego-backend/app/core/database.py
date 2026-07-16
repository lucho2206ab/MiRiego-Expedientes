"""
Conexión a la base de datos con SQLAlchemy.

Usamos el estilo "sync" (no async) de SQLAlchemy 2.0 porque es más
simple de razonar cuando estás recién arrancando con Python. Si más
adelante necesitamos más performance bajo carga concurrente, se puede
migrar a SQLAlchemy async + asyncpg sin cambiar el resto de la app.
"""

import logging

import psycopg
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

logger = logging.getLogger(__name__)

engine = create_engine(settings.DATABASE_URL, echo=False, future=True, pool_pre_ping=True)

# Cada request de FastAPI va a abrir su propia sesión (ver get_db abajo)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Todos los modelos ORM heredan de esta clase base
Base = declarative_base()


def ensure_database_ready() -> None:
    """Crea la base de datos y las tablas si todavía no existen."""
    parsed = make_url(settings.DATABASE_URL)
    db_name = parsed.database or "postgres"
    admin_params = {
        "host": parsed.host or "localhost",
        "port": parsed.port or 5432,
        "user": parsed.username or "postgres",
        "password": parsed.password or "",
        "dbname": "postgres",
    }

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return
    except OperationalError as exc:
        logger.warning("No se pudo conectar a la base de datos: %s", exc)

    try:
        with psycopg.connect(**admin_params) as conn:
            conn.autocommit = True
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
                exists = cursor.fetchone()
                if not exists:
                    cursor.execute(f'CREATE DATABASE "{db_name}"')
                    logger.info("Base de datos creada: %s", db_name)
    except Exception as exc:  # pragma: no cover - fallback de arranque
        logger.exception("No se pudo crear la base de datos %s: %s", db_name, exc)
        raise

    try:
        with engine.connect() as conn:
            conn.execute(text("CREATE SCHEMA IF NOT EXISTS miriego"))
            Base.metadata.create_all(bind=conn)
            logger.info("Tablas verificadas/creadas para %s", db_name)
    except Exception as exc:  # pragma: no cover - fallback de arranque
        logger.exception("No se pudieron crear las tablas de la base de datos: %s", exc)
        raise


def get_db():
    """
    Dependency de FastAPI: abre una sesión de DB por request y la
    cierra automáticamente al terminar, incluso si hay un error.
    Se usa así en los endpoints: db: Session = Depends(get_db)
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
