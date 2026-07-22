"""
Modelos ORM (SQLAlchemy) para el módulo de Notificaciones.
Reflejan las tablas creadas en db/notificaciones_schema.sql.
"""

import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    Sequence,
    String,
    Text,
    DateTime,
    Enum as SAEnum,
)

from app.core.database import Base

SCHEMA = "miriego"


class NotificadoTipo(str, enum.Enum):
    regante = "regante"
    tercero = "tercero"


class EstadoNotificacion(str, enum.Enum):
    emitida = "emitida"
    notificada = "notificada"
    respondida = "respondida"
    vencida = "vencida"
    cumplida = "cumplida"
    cerrada = "cerrada"


class TipoNotificacion(Base):
    __tablename__ = "tipos_notificaciones"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(150), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)


class MedioNotificacion(Base):
    __tablename__ = "medios_notificacion"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(100), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)


class Notificacion(Base):
    __tablename__ = "notificaciones"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    codigo_notificacion = Column(String(30), nullable=False, unique=True)

    tipo_notificacion_id = Column(Integer)
    medio_notificacion_id = Column(Integer)
    expediente_id = Column(Integer)

    notificado_tipo = Column(
        SAEnum(NotificadoTipo, name="notificado_tipo", schema=SCHEMA),
        nullable=False,
        default=NotificadoTipo.tercero,
    )
    cc = Column(String(20))
    pp = Column(String(20))

    notificado_nombre = Column(String(200))
    notificado_documento = Column(String(30))
    notificado_domicilio = Column(Text)
    notificado_contacto = Column(String(150))

    motivo = Column(String(200), nullable=False)
    descripcion = Column(Text, nullable=False)

    fecha_emision = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    fecha_notificacion = Column(DateTime(timezone=True))
    fecha_vencimiento_respuesta = Column(DateTime(timezone=True))

    estado = Column(
        SAEnum(EstadoNotificacion, name="estado_notificacion", schema=SCHEMA),
        nullable=False,
        default=EstadoNotificacion.emitida,
    )

    usuario_id = Column(Integer, nullable=False, default=1)
    observaciones = Column(Text)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
