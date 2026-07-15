"""
Endpoints del módulo de reclamos.

Rutas expuestas:
  GET    /reclamos                       -> listar (con filtros)
  POST   /reclamos                       -> crear
  GET    /reclamos/{id}                  -> detalle (comentarios, adjuntos, historial)
  PATCH  /reclamos/{id}                  -> cambiar estado / prioridad / asignado_a
  POST   /reclamos/{id}/comentarios      -> agregar comentario
  POST   /reclamos/{id}/adjuntos         -> registrar adjunto
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.core.database import get_db
from app.models.reclamo import (
    Reclamo,
    ReclamoComentario,
    ReclamoAdjunto,
    ReclamoHistorial,
    TipoReclamo,
    Canal,
    Toma,
    Inspeccion,
)
from app.models.expediente import Expediente
from app.schemas.reclamo import (
    ReclamoCreate,
    ReclamoOut,
    ReclamoDetalleOut,
    ReclamoUpdate,
    ReclamoComentarioCreate,
    ReclamoComentarioOut,
    ReclamoAdjuntoCreate,
    ReclamoAdjuntoOut,
)

router = APIRouter(prefix="/reclamos", tags=["reclamos"])


def _resolver_numeros_expediente(db: Session, reclamos: list) -> None:
    """Puebla el campo numero_expediente en cada reclamo usando una sola query."""
    ids_exp = [r.expediente_id for r in reclamos if r.expediente_id is not None]
    if not ids_exp:
        return
    rows = db.execute(
        select(Expediente.id, Expediente.numero_expediente).where(Expediente.id.in_(ids_exp))
    ).all()
    mapa = {row[0]: row[1] for row in rows}
    for r in reclamos:
        if r.expediente_id is not None:
            r.numero_expediente = mapa.get(r.expediente_id)


def _generar_codigo(db: Session) -> str:
    """Genera el próximo código de reclamo: RCL-YYYY-NNNNNN."""
    anio = datetime.now().year
    prefijo = f"RCL-{anio}-"
    ultimo = db.scalar(
        select(Reclamo)
        .where(Reclamo.codigo_reclamo.like(f"{prefijo}%"))
        .order_by(Reclamo.codigo_reclamo.desc())
        .limit(1)
    )
    if ultimo:
        ultimo_numero = int(ultimo.codigo_reclamo.split("-")[-1])
        siguiente = ultimo_numero + 1
    else:
        siguiente = 1
    return f"{prefijo}{siguiente:06d}"


def _registrar_historial(
    db: Session,
    reclamo_id: int,
    accion: str,
    estado_anterior: Optional[str] = None,
    estado_nuevo: Optional[str] = None,
    observacion: Optional[str] = None,
    usuario_id: Optional[int] = None,
):
    """Inserta un registro en reclamo_historial."""
    from sqlalchemy import text
    db.execute(
        text(
            "INSERT INTO miriego.reclamo_historial "
            "(reclamo_id, usuario_id, accion, estado_anterior, estado_nuevo, observacion, fecha) "
            "VALUES (:reclamo_id, :usuario_id, :accion, "
            "NULLIF(:estado_anterior, '')::miriego.estado_reclamo, "
            "NULLIF(:estado_nuevo, '')::miriego.estado_reclamo, "
            "NULLIF(:observacion, ''), now())"
        ),
        {
            "reclamo_id": reclamo_id,
            "usuario_id": usuario_id,
            "accion": accion,
            "estado_anterior": estado_anterior or "",
            "estado_nuevo": estado_nuevo or "",
            "observacion": observacion or "",
        },
    )


# ---------------------------------------------------------------------------
# Listar reclamos
# ---------------------------------------------------------------------------

@router.get("", response_model=list[ReclamoOut])
def listar_reclamos(
    db: Session = Depends(get_db),
    estado: Optional[str] = None,
    canal_id: Optional[int] = None,
    toma_id: Optional[int] = None,
    tipo_id: Optional[int] = None,
    prioridad: Optional[str] = None,
    q: Optional[str] = None,
    fecha_desde: Optional[str] = None,
    fecha_hasta: Optional[str] = None,
):
    from sqlalchemy import or_, func

    try:
        query = select(Reclamo)
        if estado is not None:
            query = query.where(Reclamo.estado == estado)
        if canal_id is not None:
            query = query.where(Reclamo.canal_id == canal_id)
        if toma_id is not None:
            query = query.where(Reclamo.toma_id == toma_id)
        if tipo_id is not None:
            query = query.where(Reclamo.tipo_id == tipo_id)
        if prioridad is not None:
            query = query.where(Reclamo.prioridad == prioridad)

        # Búsqueda de texto libre sobre código, título, nombre, apellido y tipo
        if q and q.strip():
            term = f"%{q.strip()}%"
            query = query.outerjoin(TipoReclamo, Reclamo.tipo_id == TipoReclamo.id).where(
                or_(
                    Reclamo.codigo_reclamo.ilike(term),
                    Reclamo.titulo.ilike(term),
                    Reclamo.reclamante_nombre.ilike(term),
                    Reclamo.reclamante_apellido.ilike(term),
                    func.concat(Reclamo.reclamante_nombre, ' ', Reclamo.reclamante_apellido).ilike(term),
                    TipoReclamo.nombre.ilike(term),
                )
            )

        if fecha_desde:
            from datetime import datetime
            desde = datetime.strptime(fecha_desde, "%Y-%m-%d")
            query = query.where(Reclamo.fecha_creacion >= desde)
        if fecha_hasta:
            from datetime import datetime, timedelta
            hasta = datetime.strptime(fecha_hasta, "%Y-%m-%d") + timedelta(days=1)
            query = query.where(Reclamo.fecha_creacion < hasta)

        query = query.order_by(Reclamo.fecha_creacion.desc())
        reclamos = db.scalars(query).all()
        _resolver_numeros_expediente(db, reclamos)
        return reclamos
    except (OperationalError, ProgrammingError):
        return []


# ---------------------------------------------------------------------------
# Crear reclamo
# ---------------------------------------------------------------------------

@router.post("", response_model=ReclamoOut, status_code=201)
def crear_reclamo(payload: ReclamoCreate, db: Session = Depends(get_db)):
    tipo = db.get(TipoReclamo, payload.tipo_id)
    if not tipo:
        raise HTTPException(400, "El tipo_id indicado no existe")

    data = payload.model_dump()

    # Si es regante y proporcionó CC, buscar canal por código de cauce
    if data.get("es_regante") and data.get("reclamante_cc"):
        canal = db.scalar(
            select(Canal).where(Canal.codigo_canal == data["reclamante_cc"])
        )
        if canal:
            data["canal_id"] = canal.id
            data["inspeccion_id"] = canal.inspeccion_id

    reclamo = Reclamo(
        **data,
        codigo_reclamo=_generar_codigo(db),
    )
    db.add(reclamo)
    db.commit()
    db.refresh(reclamo)
    return reclamo


# ---------------------------------------------------------------------------
# Detalle de reclamo
# ---------------------------------------------------------------------------

@router.get("/{reclamo_id}", response_model=ReclamoDetalleOut)
def detalle_reclamo(reclamo_id: int, db: Session = Depends(get_db)):
    reclamo = db.get(Reclamo, reclamo_id)
    if not reclamo:
        raise HTTPException(404, "Reclamo no encontrado")
    _resolver_numeros_expediente(db, [reclamo])
    return reclamo


# ---------------------------------------------------------------------------
# Actualizar reclamo (PATCH)
# ---------------------------------------------------------------------------

@router.patch("/{reclamo_id}", response_model=ReclamoOut)
def actualizar_reclamo(reclamo_id: int, payload: ReclamoUpdate, db: Session = Depends(get_db)):
    reclamo = db.get(Reclamo, reclamo_id)
    if not reclamo:
        raise HTTPException(404, "Reclamo no encontrado")

    if reclamo.estado and reclamo.estado.value == "derivado_expediente":
        raise HTTPException(400, "Este reclamo fue derivado a expediente y no admite cambios")

    cambios = payload.model_dump(exclude_unset=True)
    estado_anterior = reclamo.estado.value if reclamo.estado else None

    # Extraer campos que no van al modelo directamente
    comentario_estado = cambios.pop("comentario", None)
    sector_actual_id = cambios.pop("sector_actual_id", None)

    if "estado" in cambios and cambios["estado"] != reclamo.estado.value:
        estado_nuevo = cambios["estado"]
        reclamo.estado = estado_nuevo

        ahora = datetime.now(timezone.utc)
        if estado_nuevo == "en_revision" and not reclamo.fecha_primera_respuesta:
            reclamo.fecha_primera_respuesta = ahora
        elif estado_nuevo == "resuelto":
            reclamo.fecha_resolucion = ahora
        elif estado_nuevo == "cerrado":
            reclamo.fecha_cierre = ahora

        # El trigger trg_historial_reclamo registra automáticamente
        # el cambio de estado. Si hay comentario, lo registramos
        # como observación adicional en el historial.
        if comentario_estado and comentario_estado.strip():
            _registrar_historial(
                db, reclamo.id, "comentario_estado",
                estado_anterior=estado_anterior,
                estado_nuevo=estado_nuevo,
                observacion=comentario_estado.strip(),
                usuario_id=reclamo.usuario_id,
            )

    if "expediente_id" in cambios:
        reclamo.expediente_id = cambios["expediente_id"]
        if cambios["expediente_id"] is not None and cambios.get("estado") == "derivado_expediente":
            _registrar_historial(
                db, reclamo.id, "derivacion_expediente",
                estado_anterior=estado_anterior,
                estado_nuevo="derivado_expediente",
                observacion=f"Expediente vinculado: {cambios['expediente_id']}",
                usuario_id=reclamo.usuario_id,
            )

    if "prioridad" in cambios:
        reclamo.prioridad = cambios["prioridad"]

    if "asignado_a" in cambios:
        reclamo.asignado_a = cambios["asignado_a"]
        if cambios["asignado_a"] is not None:
            # La asignación NO es un cambio de estado, así que el trigger
            # no la registra — la insertamos manualmente.
            _registrar_historial(
                db, reclamo.id, "asignacion",
                observacion=f"Asignado a usuario {cambios['asignado_a']}",
                usuario_id=reclamo.usuario_id,
            )

    # Asignación de sector (cuando estado = asignado)
    if sector_actual_id is not None:
        _registrar_historial(
            db, reclamo.id, "asignacion_sector",
            estado_anterior=estado_anterior,
            estado_nuevo=reclamo.estado.value if reclamo.estado else None,
            observacion=f"Sector asignado: {sector_actual_id}",
            usuario_id=reclamo.usuario_id,
        )

    # Campos de datos (corrección de errores de tipado, etc.)
    CAMPOS_DATOS = [
        "titulo", "descripcion",
        "reclamante_nombre", "reclamante_apellido", "reclamante_dni",
        "reclamante_telefono", "reclamante_email", "reclamante_cc",
        "reclamante_pp", "direccion_manual",
    ]
    for campo in CAMPOS_DATOS:
        if campo in cambios:
            setattr(reclamo, campo, cambios[campo])

    db.commit()
    db.refresh(reclamo)
    return reclamo


# ---------------------------------------------------------------------------
# Comentarios
# ---------------------------------------------------------------------------

@router.post("/{reclamo_id}/comentarios", response_model=ReclamoComentarioOut, status_code=201)
def agregar_comentario(reclamo_id: int, payload: ReclamoComentarioCreate, db: Session = Depends(get_db)):
    reclamo = db.get(Reclamo, reclamo_id)
    if not reclamo:
        raise HTTPException(404, "Reclamo no encontrado")

    comentario = ReclamoComentario(reclamo_id=reclamo_id, **payload.model_dump())
    db.add(comentario)
    db.commit()
    db.refresh(comentario)
    return comentario


# ---------------------------------------------------------------------------
# Adjuntos
# ---------------------------------------------------------------------------

@router.post("/{reclamo_id}/adjuntos", response_model=ReclamoAdjuntoOut, status_code=201)
def agregar_adjunto(reclamo_id: int, payload: ReclamoAdjuntoCreate, db: Session = Depends(get_db)):
    reclamo = db.get(Reclamo, reclamo_id)
    if not reclamo:
        raise HTTPException(404, "Reclamo no encontrado")

    adjunto = ReclamoAdjunto(reclamo_id=reclamo_id, **payload.model_dump())
    db.add(adjunto)
    db.commit()
    db.refresh(adjunto)
    return adjunto
