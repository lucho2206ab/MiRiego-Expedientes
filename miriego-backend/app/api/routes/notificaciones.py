"""
Endpoints del módulo de Notificaciones.

Rutas expuestas:
  GET    /notificaciones              -> listar (con filtros)
  POST   /notificaciones              -> crear
  GET    /notificaciones/{id}         -> detalle
  PATCH  /notificaciones/{id}         -> actualizar estado / campos
  POST   /notificaciones/{id}/imprimir -> generar cédula .docx
"""

import io
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session
from sqlalchemy import select, func, or_, text

from app.core.database import get_db
from app.models.notificacion import Notificacion
from app.models.expediente import Expediente
from app.adapters.cc_adapter import StubCCAdapter
from app.schemas.notificacion import (
    NotificacionCreate,
    NotificacionOut,
    NotificacionDetalleOut,
    NotificacionUpdate,
    PaginatedNotificaciones,
)

router = APIRouter(prefix="/notificaciones", tags=["notificaciones"])

_TEMPLATES_DIR = Path(__file__).resolve().parent.parent.parent.parent / "templates"
_TEMPLATE_PATH = _TEMPLATES_DIR / "notificacion_template.docx"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolver_numeros_expediente(db: Session, notificaciones: list) -> None:
    """Puebla numero_expediente usando una sola query."""
    ids_exp = [n.expediente_id for n in notificaciones if n.expediente_id is not None]
    if not ids_exp:
        return
    rows = db.execute(
        select(Expediente.id, Expediente.numero_expediente).where(Expediente.id.in_(ids_exp))
    ).all()
    mapa = {row[0]: row[1] for row in rows}
    for n in notificaciones:
        if n.expediente_id is not None:
            n.numero_expediente = mapa.get(n.expediente_id)


def _resolver_inspeccion_desde_cc(db: Session, cc: str) -> dict:
    """
    Resuelve inspección/inspector a partir del CC usando el adapter.
    Si no hay match, retorna strings vacíos.
    """
    adapter = StubCCAdapter(db)
    info = adapter.resolver(cc)
    if info:
        return {"inspeccion_nombre": info.inspeccion_nombre, "inspector_nombre": info.inspector_nombre}
    return {"inspeccion_nombre": "", "inspector_nombre": ""}


# ---------------------------------------------------------------------------
# Listar notificaciones
# ---------------------------------------------------------------------------

@router.get("", response_model=PaginatedNotificaciones)
def listar_notificaciones(
    db: Session = Depends(get_db),
    estado: Optional[str] = None,
    notificado_tipo: Optional[str] = None,
    q: Optional[str] = None,
    fecha_desde: Optional[str] = None,
    fecha_hasta: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    try:
        query = select(Notificacion)
        if estado is not None:
            query = query.where(Notificacion.estado == estado)
        if notificado_tipo is not None:
            query = query.where(Notificacion.notificado_tipo == notificado_tipo)

        if q and q.strip():
            term = f"%{q.strip()}%"
            query = query.where(
                or_(
                    Notificacion.codigo_notificacion.ilike(term),
                    Notificacion.notificado_nombre.ilike(term),
                    Notificacion.motivo.ilike(term),
                )
            )

        if fecha_desde:
            desde = datetime.strptime(fecha_desde, "%Y-%m-%d")
            query = query.where(Notificacion.fecha_emision >= desde)
        if fecha_hasta:
            hasta = datetime.strptime(fecha_hasta, "%Y-%m-%d").replace(hour=23, minute=59, second=59)
            query = query.where(Notificacion.fecha_emision <= hasta)

        total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
        query = query.order_by(Notificacion.fecha_emision.desc())
        query = query.offset((page - 1) * page_size).limit(page_size)
        notificaciones = db.scalars(query).all()
        _resolver_numeros_expediente(db, notificaciones)
        return {"items": notificaciones, "total": total, "page": page, "page_size": page_size}
    except (OperationalError, ProgrammingError):
        return {"items": [], "total": 0, "page": page, "page_size": page_size}


# ---------------------------------------------------------------------------
# Crear notificación
# ---------------------------------------------------------------------------

@router.post("", response_model=NotificacionOut, status_code=201)
def crear_notificacion(payload: NotificacionCreate, db: Session = Depends(get_db)):
    ahora = datetime.now(timezone.utc)
    seq_val = db.execute(text("SELECT nextval('miriego.seq_codigo_notificacion')")).scalar()
    codigo = f"CE-{seq_val:04d}"
    notificacion = Notificacion(
        **payload.model_dump(),
        codigo_notificacion=codigo,
        fecha_emision=ahora,
        usuario_id=1,  # TODO: reemplazar con usuario autenticado
    )
    db.add(notificacion)
    db.flush()
    db.refresh(notificacion)
    db.commit()
    db.refresh(notificacion)
    return notificacion


# ---------------------------------------------------------------------------
# Detalle
# ---------------------------------------------------------------------------

@router.get("/{notificacion_id}", response_model=NotificacionDetalleOut)
def detalle_notificacion(notificacion_id: int, db: Session = Depends(get_db)):
    notificacion = db.get(Notificacion, notificacion_id)
    if not notificacion:
        raise HTTPException(404, "Notificación no encontrada")
    _resolver_numeros_expediente(db, [notificacion])
    return notificacion


# ---------------------------------------------------------------------------
# Actualizar (PATCH)
# ---------------------------------------------------------------------------

@router.patch("/{notificacion_id}", response_model=NotificacionOut)
def actualizar_notificacion(notificacion_id: int, payload: NotificacionUpdate, db: Session = Depends(get_db)):
    notificacion = db.get(Notificacion, notificacion_id)
    if not notificacion:
        raise HTTPException(404, "Notificación no encontrada")

    cambios = payload.model_dump(exclude_unset=True)

    if "estado" in cambios:
        notificacion.estado = cambios["estado"]

    CAMPOS = [
        "tipo_notificacion_id", "medio_notificacion_id", "expediente_id",
        "notificado_nombre", "notificado_documento", "notificado_domicilio",
        "notificado_contacto", "motivo", "descripcion",
        "fecha_notificacion", "fecha_vencimiento_respuesta", "observaciones",
        "cc", "pp",
    ]
    for campo in CAMPOS:
        if campo in cambios:
            setattr(notificacion, campo, cambios[campo])

    notificacion.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(notificacion)
    return notificacion


# ---------------------------------------------------------------------------
# Imprimir cédula (genera .docx con docxtpl)
# ---------------------------------------------------------------------------

@router.post("/{notificacion_id}/imprimir")
def imprimir_cedula(notificacion_id: int, db: Session = Depends(get_db)):
    notificacion = db.get(Notificacion, notificacion_id)
    if not notificacion:
        raise HTTPException(404, "Notificación no encontrada")

    if not _TEMPLATE_PATH.exists():
        raise HTTPException(500, "Plantilla de notificación no encontrada en el servidor")

    # Resolver inspección/inspector desde CC
    ctx_cc = _resolver_inspeccion_desde_cc(db, notificacion.cc)

    context = {
        "nombre": notificacion.notificado_nombre or "",
        "cc": notificacion.cc or "",
        "pp": notificacion.pp or "",
        "codigo": notificacion.codigo_notificacion or "",
        "domicilio": notificacion.notificado_domicilio or "",
        "descripcion": notificacion.descripcion or "",
        "inspeccion_nombre": ctx_cc["inspeccion_nombre"],
        "inspector_nombre": ctx_cc["inspector_nombre"],
    }

    from docxtpl import DocxTemplate

    doc = DocxTemplate(str(_TEMPLATE_PATH))
    doc.render(context)

    buf = io.BytesIO()
    doc.save(buf)
    buf.seek(0)

    filename = f"cedula_{notificacion.codigo_notificacion}.docx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
