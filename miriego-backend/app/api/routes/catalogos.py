"""
Endpoints de solo lectura para los catálogos que el frontend necesita
para armar selects/dropdowns (sectores, tipos de expediente, jerarquía
de riego para el módulo de reclamos).
"""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.core.database import get_db
from app.models.expediente import Sector, TipoExpediente
from app.models.reclamo import (
    Cuenca,
    Asociacion,
    Inspeccion,
    Canal,
    Toma,
    CategoriaReclamo,
    TipoReclamo,
)
from app.models.notificacion import TipoNotificacion, MedioNotificacion
from app.schemas.expediente import SectorOut, TipoExpedienteOut
from app.schemas.reclamo import (
    CuencaOut,
    AsociacionOut,
    InspeccionOut,
    CanalOut,
    TomaOut,
    CategoriaReclamoOut,
    TipoReclamoOut,
)
from app.schemas.notificacion import TipoNotificacionOut, MedioNotificacionOut

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/catalogos", tags=["catalogos"])


# ---------------------------------------------------------------------------
# Expedientes
# ---------------------------------------------------------------------------

@router.get("/sectores", response_model=list[SectorOut])
def listar_sectores(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(Sector).where(Sector.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/sectores: %s", exc)
        return []


@router.get("/tipos-expediente", response_model=list[TipoExpedienteOut])
def listar_tipos_expediente(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(TipoExpediente).where(TipoExpediente.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/tipos-expediente: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Reclamos — jerarquía de riego
# ---------------------------------------------------------------------------

@router.get("/cuencas", response_model=list[CuencaOut])
def listar_cuencas(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(Cuenca).where(Cuenca.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/cuencas: %s", exc)
        return []


@router.get("/asociaciones", response_model=list[AsociacionOut])
def listar_asociaciones(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(Asociacion).where(Asociacion.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/asociaciones: %s", exc)
        return []


@router.get("/inspecciones", response_model=list[InspeccionOut])
def listar_inspecciones(db: Session = Depends(get_db)):
    try:
        return db.scalars(
            select(Inspeccion).where(Inspeccion.activo.is_(True))
        ).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/inspecciones: %s", exc)
        return []


@router.get("/canales", response_model=list[CanalOut])
def listar_canales(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(Canal).where(Canal.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/canales: %s", exc)
        return []


@router.get("/tomas", response_model=list[TomaOut])
def listar_tomas(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(Toma).where(Toma.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/tomas: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Reclamos — catálogos de clasificación
# ---------------------------------------------------------------------------

@router.get("/categorias-reclamo", response_model=list[CategoriaReclamoOut])
def listar_categorias_reclamo(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(CategoriaReclamo)).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/categorias-reclamo: %s", exc)
        return []


@router.get("/tipos-reclamo", response_model=list[TipoReclamoOut])
def listar_tipos_reclamo(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(TipoReclamo).where(TipoReclamo.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/tipos-reclamo: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Notificaciones
# ---------------------------------------------------------------------------

@router.get("/tipos-notificacion", response_model=list[TipoNotificacionOut])
def listar_tipos_notificacion(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(TipoNotificacion).where(TipoNotificacion.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/tipos-notificacion: %s", exc)
        return []


@router.get("/medios-notificacion", response_model=list[MedioNotificacionOut])
def listar_medios_notificacion(db: Session = Depends(get_db)):
    try:
        return db.scalars(select(MedioNotificacion).where(MedioNotificacion.activo.is_(True))).all()
    except (OperationalError, ProgrammingError) as exc:
        logger.error("Error en /catalogos/medios-notificacion: %s", exc)
        return []
