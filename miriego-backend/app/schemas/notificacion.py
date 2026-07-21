"""
Schemas Pydantic para el módulo de Notificaciones.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.models.notificacion import EstadoNotificacion, NotificadoTipo


# ---------------------------------------------------------------------------
# Catálogos
# ---------------------------------------------------------------------------

class TipoNotificacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str


class MedioNotificacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str


# ---------------------------------------------------------------------------
# Notificación
# ---------------------------------------------------------------------------

class NotificacionCreate(BaseModel):
    tipo_notificacion_id: Optional[int] = None
    medio_notificacion_id: Optional[int] = None
    expediente_id: Optional[int] = None

    notificado_tipo: NotificadoTipo = NotificadoTipo.tercero
    notificado_ccpp: Optional[str] = None
    notificado_nombre: Optional[str] = None
    notificado_documento: Optional[str] = None
    notificado_domicilio: Optional[str] = None
    notificado_contacto: Optional[str] = None

    motivo: str
    descripcion: str

    fecha_vencimiento_respuesta: Optional[datetime] = None
    observaciones: Optional[str] = None


class NotificacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo_notificacion: str
    usuario_id: int

    tipo_notificacion_id: Optional[int] = None
    medio_notificacion_id: Optional[int] = None
    expediente_id: Optional[int] = None

    notificado_tipo: NotificadoTipo
    notificado_ccpp: Optional[str] = None
    notificado_nombre: Optional[str] = None
    notificado_documento: Optional[str] = None
    notificado_domicilio: Optional[str] = None
    notificado_contacto: Optional[str] = None

    motivo: str
    descripcion: str

    fecha_emision: Optional[datetime] = None
    fecha_notificacion: Optional[datetime] = None
    fecha_vencimiento_respuesta: Optional[datetime] = None

    estado: EstadoNotificacion
    observaciones: Optional[str] = None

    numero_expediente: Optional[str] = None


class NotificacionUpdate(BaseModel):
    """PATCH parcial: solo se envía lo que se quiere cambiar."""
    estado: Optional[EstadoNotificacion] = None
    tipo_notificacion_id: Optional[int] = None
    medio_notificacion_id: Optional[int] = None
    expediente_id: Optional[int] = None
    notificado_nombre: Optional[str] = None
    notificado_documento: Optional[str] = None
    notificado_domicilio: Optional[str] = None
    notificado_contacto: Optional[str] = None
    motivo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_notificacion: Optional[datetime] = None
    fecha_vencimiento_respuesta: Optional[datetime] = None
    observaciones: Optional[str] = None


class NotificacionDetalleOut(NotificacionOut):
    """Notificación completa para la pantalla de detalle."""
    pass


class PaginatedNotificaciones(BaseModel):
    items: list[NotificacionOut]
    total: int
    page: int
    page_size: int
