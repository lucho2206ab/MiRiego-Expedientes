"""
Schemas Pydantic: definen qué forma tienen los datos que entran y
salen de la API. Son distintos de los modelos SQLAlchemy (esos
representan la tabla en la base; estos representan el JSON de la API).

Convención usada:
- "...Create": lo que el cliente manda para crear un registro.
- "...Out": lo que la API devuelve al cliente.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.models.expediente import EstadoExpediente, EstadoPase


# ---------------------------------------------------------------------------
# Sector / Tipo (catálogos simples)
# ---------------------------------------------------------------------------

class SectorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: Optional[str] = None


class TipoExpedienteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: Optional[str] = None


# ---------------------------------------------------------------------------
# Expediente
# ---------------------------------------------------------------------------

class ExpedienteCreate(BaseModel):
    numero_expediente: str
    tipo_id: int
    asunto: str
    descripcion: Optional[str] = None
    iniciador_nombre: str
    iniciador_dni_cuit: Optional[str] = None
    iniciador_cc: Optional[str] = None
    iniciador_pp: Optional[str] = None
    regante_id: Optional[int] = None
    inspeccion_id: Optional[int] = None
    sector_actual_id: Optional[int] = None
    sector_nombre: Optional[str] = None
    gde_numero: Optional[str] = None
    infogov_numero: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    fecha_vencimiento: Optional[datetime] = None
    reclamo_id: Optional[int] = None


class ExpedienteUpdate(BaseModel):
    """PUT parcial: solo se envía lo que se quiere corregir."""
    numero_expediente: Optional[str] = None
    asunto: Optional[str] = None
    descripcion: Optional[str] = None
    iniciador_nombre: Optional[str] = None
    iniciador_dni_cuit: Optional[str] = None
    iniciador_cc: Optional[str] = None
    iniciador_pp: Optional[str] = None
    gde_numero: Optional[str] = None
    infogov_numero: Optional[str] = None
    fecha_vencimiento: Optional[datetime] = None


class ExpedienteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    numero_expediente: str
    tipo_id: int
    asunto: str
    descripcion: Optional[str] = None
    iniciador_nombre: str
    iniciador_dni_cuit: Optional[str] = None
    iniciador_cc: Optional[str] = None
    iniciador_pp: Optional[str] = None
    regante_id: Optional[int] = None
    inspeccion_id: Optional[int] = None
    sector_actual_id: int
    estado: EstadoExpediente
    gde_numero: Optional[str] = None
    infogov_numero: Optional[str] = None
    fecha_inicio: datetime
    fecha_ultima_actualizacion: datetime
    fecha_resolucion: Optional[datetime] = None
    fecha_archivo: Optional[datetime] = None
    fecha_vencimiento: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Pase (movimiento entre sectores)
# ---------------------------------------------------------------------------

class PaseCreate(BaseModel):
    sector_destino_id: int
    usuario_id: Optional[int] = None
    motivo: Optional[str] = None
    observaciones: Optional[str] = None
    fecha_vencimiento: Optional[datetime] = None
    inspeccion_id: Optional[int] = None
    subsector_mesa_entradas: Optional[str] = None


class PaseConfirmarRecepcion(BaseModel):
    """
    Sin uso por ahora: el pase se aplica de forma inmediata al crearse
    (ver trigger fn_aplicar_pase). Se deja este schema por si más
    adelante se reintroduce el paso de "confirmación de recepción".
    """
    usuario_id: Optional[int] = None


class PaseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    expediente_id: int
    sector_origen_id: int
    sector_destino_id: int
    usuario_id: Optional[int] = None
    motivo: Optional[str] = None
    observaciones: Optional[str] = None
    inspeccion_id: Optional[int] = None
    subsector_mesa_entradas: Optional[str] = None
    usuario_asignado_id: Optional[int] = None
    estado: EstadoPase
    fecha_envio: datetime
    fecha_recepcion: Optional[datetime] = None
    fecha_vencimiento: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Nota
# ---------------------------------------------------------------------------

class NotaCreate(BaseModel):
    sector_id: int
    usuario_id: Optional[int] = None
    contenido: str
    es_interna: bool = True


class NotaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    expediente_id: int
    sector_id: int
    usuario_id: Optional[int] = None
    contenido: str
    es_interna: bool
    fecha: datetime


class ExpedienteDetalleOut(ExpedienteOut):
    """Expediente + su historial de pases y notas, para la pantalla de detalle."""
    pases: list[PaseOut] = []
    notas: list[NotaOut] = []
