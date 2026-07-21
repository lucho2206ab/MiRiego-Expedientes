"""
Punto de entrada de la API de MiRiego.

Para correr en desarrollo:
    uvicorn app.main:app --reload

Documentación interactiva automática (Swagger) en:
    http://localhost:8000/docs
"""

import logging

logging.basicConfig(level=logging.INFO)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import catalogos, expedientes, reclamos, notificaciones, dashboard
from app.core.config import settings
from app.core.database import ensure_database_ready

logger = logging.getLogger(__name__)

app = FastAPI(
    title="MiRiego API",
    description="API para gestión de expedientes, notas y reclamos — ASIC Primera Zona de Riego",
    version="0.1.0",
)

# Habilita que el frontend SvelteKit (corriendo en otro puerto en dev)
# pueda llamar a esta API sin que el navegador lo bloquee.
allowed_origins = [
    settings.FRONTEND_ORIGIN,
    "http://localhost:5173",
    "http://localhost:5174",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:5174",
    "http://10.106.96.73:5173",
    "http://10.106.96.73:5174",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}):\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(expedientes.router)
app.include_router(catalogos.router)
app.include_router(reclamos.router)
app.include_router(notificaciones.router)
app.include_router(dashboard.router)


@app.on_event("startup")
def startup_event() -> None:
    try:
        ensure_database_ready()
    except Exception as exc:  # pragma: no cover - protección de arranque
        logger.exception("No se pudo inicializar la base de datos al arrancar: %s", exc)


@app.get("/health")
def health_check():
    """Endpoint simple para verificar que la API está viva."""
    return {"status": "ok"}
