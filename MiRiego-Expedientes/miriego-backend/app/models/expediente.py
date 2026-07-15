"""
Modelos ORM (SQLAlchemy) que reflejan las tablas creadas en
db/miriego_schema_expedientes.sql dentro del schema "miriego".

Cada clase = una tabla. SQLAlchemy nos deja trabajar con estas tablas
como objetos Python en vez de escribir SQL a mano en cada endpoint.
"""

import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    DateTime,
    ForeignKey,
    Enum as SAEnum,
)
from sqlalchemy.orm import relationship

from app.core.database import Base

SCHEMA = "miriego"


class EstadoExpediente(str, enum.Enum):
    iniciado = "iniciado"
    en_tramite = "en_tramite"
    pase_pendiente = "pase_pendiente"
    pendiente_firma = "pendiente_firma"
    observado = "observado"
    resuelto = "resuelto"
    archivado = "archivado"
    anulado = "anulado"


class EstadoPase(str, enum.Enum):
    enviado = "enviado"
    recibido = "recibido"
    rechazado = "rechazado"


class Sector(Base):
    __tablename__ = "sectores"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(150), nullable=False, unique=True)
    descripcion = Column(Text)
    sector_padre_id = Column(Integer, ForeignKey(f"{SCHEMA}.sectores.id"))
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class TipoExpediente(Base):
    __tablename__ = "tipos_expediente"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(150), nullable=False, unique=True)
    descripcion = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)


class Expediente(Base):
    __tablename__ = "expedientes"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    numero_expediente = Column(String(40), nullable=False, unique=True)
    tipo_id = Column(Integer, ForeignKey(f"{SCHEMA}.tipos_expediente.id"), nullable=False)

    asunto = Column(String(250), nullable=False)
    descripcion = Column(Text)

    iniciador_nombre = Column(String(150), nullable=False)
    iniciador_dni_cuit = Column(String(20))
    iniciador_cc = Column(String(20))
    iniciador_pp = Column(String(20))
    regante_id = Column(Integer)  # FK lógica al módulo de reclamos
    inspeccion_id = Column(Integer)  # FK lógica a inspecciones (asignación del expediente a una inspección)

    sector_actual_id = Column(Integer, ForeignKey(f"{SCHEMA}.sectores.id"), nullable=False)
    estado = Column(SAEnum(EstadoExpediente, name="estado_expediente"), default=EstadoExpediente.iniciado)

    gde_numero = Column(String(60))
    infogov_numero = Column(String(60))

    fecha_inicio = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    fecha_ultima_actualizacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    fecha_resolucion = Column(DateTime(timezone=True))
    fecha_archivo = Column(DateTime(timezone=True))
    fecha_vencimiento = Column(DateTime(timezone=True))

    creado_por = Column(Integer)  # FK lógica a usuarios

    sector_actual = relationship("Sector", foreign_keys=[sector_actual_id])
    tipo = relationship("TipoExpediente", foreign_keys=[tipo_id])
    pases = relationship("Pase", back_populates="expediente", order_by="Pase.fecha_envio")
    notas = relationship("Nota", back_populates="expediente", order_by="Nota.fecha")


class Pase(Base):
    __tablename__ = "pases"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    expediente_id = Column(Integer, ForeignKey(f"{SCHEMA}.expedientes.id"), nullable=False)
    sector_origen_id = Column(Integer, ForeignKey(f"{SCHEMA}.sectores.id"), nullable=False)
    sector_destino_id = Column(Integer, ForeignKey(f"{SCHEMA}.sectores.id"), nullable=False)
    usuario_id = Column(Integer)
    motivo = Column(String(250))
    observaciones = Column(Text)
    inspeccion_id = Column(Integer)  # FK logica a inspecciones (requerido solo si sector destino = Inspeccion de Cauces)
    subsector_mesa_entradas = Column(String(50))  # Valores fijos: Casilla de Vencimiento, Notificador, Reserva
    usuario_asignado_id = Column(Integer)  # FK logica a usuarios (para asignar responsable en Mesa de Entradas, uso futuro)
    estado = Column(SAEnum(EstadoPase, name="estado_pase"), default=EstadoPase.enviado)
    fecha_envio = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    fecha_recepcion = Column(DateTime(timezone=True))
    fecha_vencimiento = Column(DateTime(timezone=True))

    expediente = relationship("Expediente", back_populates="pases")
    sector_origen = relationship("Sector", foreign_keys=[sector_origen_id])
    sector_destino = relationship("Sector", foreign_keys=[sector_destino_id])


class Nota(Base):
    __tablename__ = "notas"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    expediente_id = Column(Integer, ForeignKey(f"{SCHEMA}.expedientes.id"), nullable=False)
    sector_id = Column(Integer, ForeignKey(f"{SCHEMA}.sectores.id"), nullable=False)
    usuario_id = Column(Integer)
    contenido = Column(Text, nullable=False)
    es_interna = Column(Boolean, nullable=False, default=True)
    fecha = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    expediente = relationship("Expediente", back_populates="notas")
    sector = relationship("Sector", foreign_keys=[sector_id])
