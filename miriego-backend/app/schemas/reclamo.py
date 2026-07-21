"""
Schemas Pydantic para el módulo de Reclamos.
Siguen la misma convención que expediente.py:
- "...Create": lo que el cliente manda para crear.
- "...Out": lo que la API devuelve.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator

from app.models.reclamo import EstadoReclamo, PrioridadReclamo, RolUsuario


# ---------------------------------------------------------------------------
# Catálogos / jerarquía de riego
# ---------------------------------------------------------------------------

class CuencaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str


class AsociacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    cuenca_id: int


class InspeccionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    inspector: Optional[str] = None
    asociacion_id: int


class CanalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    codigo_canal: str
    nombre: str
    inspeccion_id: int


class TomaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    codigo_toma: str
    nombre: Optional[str] = None
    canal_id: int


class CategoriaReclamoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str


class TipoReclamoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    categoria_id: int
    prioridad_sugerida: PrioridadReclamo


# ---------------------------------------------------------------------------
# Reclamo
# ---------------------------------------------------------------------------

class ReclamoCreate(BaseModel):
    tipo_id: int
    categoria_id: int
    titulo: str
    descripcion: str
    usuario_id: int = 1  # TODO: reemplazar con usuario autenticado en cada lugar donde use este id=1 fijo

    regante_id: Optional[int] = None
    ccpp_id: Optional[int] = None
    toma_id: Optional[int] = None
    canal_id: Optional[int] = None
    inspeccion_id: Optional[int] = None
    asociacion_id: Optional[int] = None
    cuenca_id: Optional[int] = None
    tomero_id: Optional[int] = None

    prioridad: PrioridadReclamo = PrioridadReclamo.media

    latitud: Optional[float] = None
    longitud: Optional[float] = None
    direccion_manual: Optional[str] = None

    es_regante: bool = True
    reclamante_nombre: Optional[str] = None
    reclamante_apellido: Optional[str] = None
    reclamante_dni: Optional[str] = None
    reclamante_telefono: Optional[str] = None
    reclamante_email: Optional[str] = None
    reclamante_cc: Optional[str] = None
    reclamante_pp: Optional[str] = None

    @field_validator("reclamante_email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            import re
            pattern = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
            if not re.match(pattern, v.strip()):
                raise ValueError("El formato del email no es válido")
            return v.strip()
        return v

    @field_validator("reclamante_dni")
    @classmethod
    def validate_dni(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip():
            digits = v.strip()
            if not digits.isdigit():
                raise ValueError("El DNI debe contener solo dígitos")
            if len(digits) < 7 or len(digits) > 8:
                raise ValueError("El DNI debe tener 7 u 8 dígitos")
            return digits
        return v


class ReclamoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo_reclamo: str
    usuario_id: int
    tipo_id: int
    categoria_id: int
    prioridad: PrioridadReclamo
    estado: EstadoReclamo
    titulo: str
    descripcion: str

    regante_id: Optional[int] = None
    ccpp_id: Optional[int] = None
    toma_id: Optional[int] = None
    canal_id: Optional[int] = None
    inspeccion_id: Optional[int] = None
    asociacion_id: Optional[int] = None
    cuenca_id: Optional[int] = None
    tomero_id: Optional[int] = None

    latitud: Optional[float] = None
    longitud: Optional[float] = None
    direccion_manual: Optional[str] = None

    es_regante: bool = True
    reclamante_nombre: Optional[str] = None
    reclamante_apellido: Optional[str] = None
    reclamante_dni: Optional[str] = None
    reclamante_telefono: Optional[str] = None
    reclamante_email: Optional[str] = None
    reclamante_cc: Optional[str] = None
    reclamante_pp: Optional[str] = None

    fecha_creacion: datetime
    fecha_primera_respuesta: Optional[datetime] = None
    fecha_resolucion: Optional[datetime] = None
    fecha_cierre: Optional[datetime] = None
    fecha_limite_respuesta: Optional[datetime] = None

    asignado_a: Optional[int] = None
    expediente_id: Optional[int] = None
    numero_expediente: Optional[str] = None


class ReclamoUpdate(BaseModel):
    """PATCH/PUT parcial: solo se envía lo que se quiere cambiar."""
    estado: Optional[EstadoReclamo] = None
    prioridad: Optional[PrioridadReclamo] = None
    asignado_a: Optional[int] = None
    expediente_id: Optional[int] = None
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    reclamante_nombre: Optional[str] = None
    reclamante_apellido: Optional[str] = None
    reclamante_dni: Optional[str] = None
    reclamante_telefono: Optional[str] = None
    reclamante_email: Optional[str] = None
    reclamante_cc: Optional[str] = None
    reclamante_pp: Optional[str] = None
    direccion_manual: Optional[str] = None
    comentario: Optional[str] = None
    sector_actual_id: Optional[int] = None


# ---------------------------------------------------------------------------
# Comentario
# ---------------------------------------------------------------------------

class ReclamoComentarioCreate(BaseModel):
    usuario_id: int = 1  # TODO: reemplazar con usuario autenticado en cada lugar donde use este id=1 fijo
    rol_usuario: RolUsuario = RolUsuario.administrador
    comentario: str
    es_interno: bool = False


class ReclamoComentarioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reclamo_id: int
    usuario_id: int
    rol_usuario: str
    comentario: str
    es_interno: bool
    fecha: datetime


# ---------------------------------------------------------------------------
# Adjunto
# ---------------------------------------------------------------------------

class ReclamoAdjuntoCreate(BaseModel):
    archivo_url: str
    tipo_archivo: Optional[str] = None
    descripcion: Optional[str] = None


class ReclamoAdjuntoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reclamo_id: int
    archivo_url: str
    tipo_archivo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha: datetime


# ---------------------------------------------------------------------------
# Historial
# ---------------------------------------------------------------------------

class ReclamoHistorialOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reclamo_id: int
    usuario_id: Optional[int] = None
    accion: str
    estado_anterior: Optional[str] = None
    estado_nuevo: Optional[str] = None
    observacion: Optional[str] = None
    fecha: datetime


# ---------------------------------------------------------------------------
# Detalle completo
# ---------------------------------------------------------------------------

class ReclamoDetalleOut(ReclamoOut):
    """Reclamo + comentarios, adjuntos e historial para la pantalla de detalle."""
    comentarios: list[ReclamoComentarioOut] = []
    adjuntos: list[ReclamoAdjuntoOut] = []
    historial: list[ReclamoHistorialOut] = []


# ---------------------------------------------------------------------------
# Respuesta paginada
# ---------------------------------------------------------------------------

class PaginatedReclamos(BaseModel):
    items: list[ReclamoOut]
    total: int
    page: int
    page_size: int
