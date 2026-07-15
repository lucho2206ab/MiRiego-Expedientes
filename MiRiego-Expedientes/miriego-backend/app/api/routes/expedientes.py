"""
Endpoints del módulo de expedientes.

Rutas expuestas:
  GET    /expedientes                       -> listar (con filtros opcionales)
  POST   /expedientes                       -> crear
  GET    /expedientes/{id}                  -> detalle (con pases y notas)
  POST   /expedientes/{id}/pases            -> generar un pase (derivar a otro sector, inmediato)
  POST   /expedientes/{id}/notas            -> agregar una nota
"""

from datetime import datetime, timezone, date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session
from sqlalchemy import select, or_

from app.core.database import get_db
from app.models.expediente import Expediente, Pase, Nota, Sector
from app.models.reclamo import Reclamo
from app.schemas.expediente import (
    ExpedienteCreate,
    ExpedienteUpdate,
    ExpedienteOut,
    ExpedienteDetalleOut,
    PaseCreate,
    PaseOut,
    NotaCreate,
    NotaOut,
)

router = APIRouter(prefix="/expedientes", tags=["expedientes"])


@router.get("", response_model=list[ExpedienteOut])
def listar_expedientes(
    sector_id: Optional[int] = None,
    estado: Optional[str] = None,
    q: Optional[str] = None,
    fecha_desde: Optional[date] = None,
    fecha_hasta: Optional[date] = None,
    db: Session = Depends(get_db),
):
    """
    Lista expedientes. Pensado para alimentar la bandeja de cada sector:
    GET /expedientes?sector_id=3 muestra solo lo que está hoy en ese sector.
    """
    try:
        query = select(Expediente)
        if sector_id is not None:
            query = query.where(Expediente.sector_actual_id == sector_id)
        if estado is not None:
            query = query.where(Expediente.estado == estado)
        if q:
            pattern = f"%{q}%"
            query = query.where(
                or_(
                    Expediente.numero_expediente.ilike(pattern),
                    Expediente.asunto.ilike(pattern),
                    Expediente.iniciador_nombre.ilike(pattern),
                    Expediente.iniciador_dni_cuit.ilike(pattern),
                    Expediente.iniciador_cc.ilike(pattern),
                    Expediente.iniciador_pp.ilike(pattern),
                )
            )
        if fecha_desde is not None:
            query = query.where(Expediente.fecha_inicio >= datetime.combine(fecha_desde, datetime.min.time()))
        if fecha_hasta is not None:
            query = query.where(Expediente.fecha_inicio <= datetime.combine(fecha_hasta, datetime.max.time()))

        query = query.order_by(Expediente.fecha_ultima_actualizacion.desc())
        return db.scalars(query).all()
    except (OperationalError, ProgrammingError):
        return []


@router.post("", response_model=ExpedienteOut, status_code=201)
def crear_expediente(payload: ExpedienteCreate, db: Session = Depends(get_db)):
    existente = db.scalar(
        select(Expediente).where(Expediente.numero_expediente == payload.numero_expediente)
    )
    if existente:
        raise HTTPException(400, "Ya existe un expediente con ese número")

    # Resolver sector: si viene sector_nombre, crear el sector nuevo
    sector_actual_id = payload.sector_actual_id
    if payload.sector_nombre and payload.sector_nombre.strip():
        nombre_sector = payload.sector_nombre.strip().upper()
        existente_sector = db.scalar(
            select(Sector).where(Sector.nombre == nombre_sector)
        )
        if existente_sector:
            sector_actual_id = existente_sector.id
        else:
            nuevo_sector = Sector(nombre=nombre_sector)
            db.add(nuevo_sector)
            db.flush()
            sector_actual_id = nuevo_sector.id

    if not sector_actual_id:
        raise HTTPException(400, "Debés indicar sector_actual_id o sector_nombre")

    sector = db.get(Sector, sector_actual_id)
    if not sector:
        raise HTTPException(400, "El sector indicado no existe")

    data = payload.model_dump()
    reclamo_id = data.pop("reclamo_id", None)
    # Remover campos auxiliares que no van a la tabla
    data.pop("sector_nombre", None)
    data["sector_actual_id"] = sector_actual_id

    # Fecha de inicio: usar la provisita o la actual
    if not data.get("fecha_inicio"):
        data["fecha_inicio"] = datetime.now(timezone.utc)

    nuevo = Expediente(**data)
    db.add(nuevo)
    db.flush()

    if reclamo_id is not None:
        reclamo = db.get(Reclamo, reclamo_id)
        if reclamo:
            reclamo.expediente_id = nuevo.id
            from app.api.routes.reclamos import _registrar_historial
            _registrar_historial(
                db, reclamo.id, "derivacion_expediente",
                estado_anterior=reclamo.estado.value if reclamo.estado else None,
                estado_nuevo="derivado_expediente",
                observacion=f"Expediente vinculado: {nuevo.numero_expediente}",
                usuario_id=reclamo.usuario_id,
            )
            reclamo.estado = "derivado_expediente"

    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.get("/{expediente_id}", response_model=ExpedienteDetalleOut)
def detalle_expediente(expediente_id: int, db: Session = Depends(get_db)):
    expediente = db.get(Expediente, expediente_id)
    if not expediente:
        raise HTTPException(404, "Expediente no encontrado")
    return expediente


@router.put("/{expediente_id}", response_model=ExpedienteOut)
def actualizar_expediente(expediente_id: int, payload: ExpedienteUpdate, db: Session = Depends(get_db)):
    """Editar datos de un expediente (corregir errores de tipado, etc.)."""
    expediente = db.get(Expediente, expediente_id)
    if not expediente:
        raise HTTPException(404, "Expediente no encontrado")

    cambios = payload.model_dump(exclude_unset=True)
    if not cambios:
        raise HTTPException(400, "No se enviaron campos para actualizar")

    if "numero_expediente" in cambios:
        existente = db.scalar(
            select(Expediente).where(
                Expediente.numero_expediente == cambios["numero_expediente"],
                Expediente.id != expediente_id,
            )
        )
        if existente:
            raise HTTPException(400, "Ya existe otro expediente con ese número")

    for campo, valor in cambios.items():
        setattr(expediente, campo, valor)

    expediente.fecha_ultima_actualizacion = datetime.now(timezone.utc)
    db.commit()
    db.refresh(expediente)
    return expediente


SECTOR_INSPECCION_CAUCES = "Inspección de Cauces"
SECTOR_MESA_ENTRADAS = "Mesa de Entradas"
SUBSECTORES_MESA_ENTRADAS_PERMITIDOS = {
    "Casilla de Vencimiento",
    "Notificador",
    "Reserva",
    "Archivo Mesa de Entradas",
    "Archivo Deposito",
}


@router.post("/{expediente_id}/pases", response_model=PaseOut, status_code=201)
def generar_pase(expediente_id: int, payload: PaseCreate, db: Session = Depends(get_db)):
    """
    Deriva el expediente a otro sector. El sector_origen se toma
    automaticamente del sector_actual_id vigente del expediente
    (no hace falta que el cliente lo mande).

    El pase se aplica de forma inmediata: se asume que el destinatario
    ya tiene el expediente en el momento en que se registra el pase.
    No hay un paso de "confirmacion de recepcion" por ahora (se puede
    agregar mas adelante si el organismo decide manejarlo asi).
    """
    expediente = db.get(Expediente, expediente_id)
    if not expediente:
        raise HTTPException(404, "Expediente no encontrado")

    destino = db.get(Sector, payload.sector_destino_id)
    if not destino:
        raise HTTPException(400, "El sector_destino_id indicado no existe")

    if payload.sector_destino_id == expediente.sector_actual_id:
        raise HTTPException(400, "El expediente ya esta en ese sector")

    # Validaciones condicionales segun sector destino
    if destino.nombre == SECTOR_INSPECCION_CAUCES:
        if payload.inspeccion_id is None:
            raise HTTPException(
                400,
                f"Al derivar a \"{SECTOR_INSPECCION_CAUCES}\", "
                "el campo inspeccion_id es obligatorio",
            )
    elif destino.nombre == SECTOR_MESA_ENTRADAS:
        if payload.subsector_mesa_entradas is None:
            raise HTTPException(
                400,
                f"Al derivar a \"{SECTOR_MESA_ENTRADAS}\", "
                "el campo subsector_mesa_entradas es obligatorio",
            )
        if payload.subsector_mesa_entradas not in SUBSECTORES_MESA_ENTRADAS_PERMITIDOS:
            raise HTTPException(
                400,
                f"subsector_mesa_entradas debe ser uno de: "
                f"{', '.join(sorted(SUBSECTORES_MESA_ENTRADAS_PERMITIDOS))}",
            )
    else:
        # Para cualquier otro sector, ignorar campos condicionales
        if payload.inspeccion_id is not None:
            payload.inspeccion_id = None
        if payload.subsector_mesa_entradas is not None:
            payload.subsector_mesa_entradas = None

    pase = Pase(
        expediente_id=expediente_id,
        sector_origen_id=expediente.sector_actual_id,
        sector_destino_id=payload.sector_destino_id,
        usuario_id=payload.usuario_id,
        motivo=payload.motivo,
        observaciones=payload.observaciones,
        inspeccion_id=payload.inspeccion_id,
        subsector_mesa_entradas=payload.subsector_mesa_entradas,
        fecha_vencimiento=payload.fecha_vencimiento,
    )
    db.add(pase)
    db.commit()
    db.refresh(pase)
    # El trigger trg_aplicar_pase en la base ya actualizo sector_actual_id
    # y el estado del expediente a "en_tramite"; no hace falta hacerlo aca.
    return pase


@router.post("/{expediente_id}/notas", response_model=NotaOut, status_code=201)
def agregar_nota(expediente_id: int, payload: NotaCreate, db: Session = Depends(get_db)):
    expediente = db.get(Expediente, expediente_id)
    if not expediente:
        raise HTTPException(404, "Expediente no encontrado")

    nota = Nota(expediente_id=expediente_id, **payload.model_dump())
    db.add(nota)
    db.commit()
    db.refresh(nota)
    return nota
