"""
Modelos ORM (SQLAlchemy) para el módulo de Reclamos.
Reflejan las tablas creadas en db/miriego_schema_reclamos.sql.
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
    Numeric,
    ForeignKey,
    Enum as SAEnum,
)
from sqlalchemy.orm import relationship

from app.core.database import Base

SCHEMA = "miriego"


class EstadoReclamo(str, enum.Enum):
    nuevo = "nuevo"
    recibido = "recibido"
    en_revision = "en_revision"
    asignado = "asignado"
    en_proceso = "en_proceso"
    resuelto = "resuelto"
    cerrado = "cerrado"
    rechazado = "rechazado"
    derivado = "derivado"
    derivado_expediente = "derivado_expediente"
    pendiente_informacion = "pendiente_informacion"
    cancelado = "cancelado"
    reabierto = "reabierto"


class PrioridadReclamo(str, enum.Enum):
    baja = "baja"
    media = "media"
    alta = "alta"
    critica = "critica"


# ---------------------------------------------------------------------------
# Tablas jerárquicas de riego
# ---------------------------------------------------------------------------

class Cuenca(Base):
    __tablename__ = "cuencas"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Asociacion(Base):
    __tablename__ = "asociaciones"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    cuenca_id = Column(Integer, ForeignKey(f"{SCHEMA}.cuencas.id"), nullable=False)
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    cuenca = relationship("Cuenca", foreign_keys=[cuenca_id])


class Inspeccion(Base):
    __tablename__ = "inspecciones"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    asociacion_id = Column(Integer, ForeignKey(f"{SCHEMA}.asociaciones.id"), nullable=False)
    nombre = Column(String(150), nullable=False)
    inspector = Column(String(150))
    descripcion = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    asociacion = relationship("Asociacion", foreign_keys=[asociacion_id])


class Canal(Base):
    __tablename__ = "canales"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    inspeccion_id = Column(Integer, ForeignKey(f"{SCHEMA}.inspecciones.id"), nullable=False)
    codigo_canal = Column(String(20), nullable=False, unique=True)
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    inspeccion = relationship("Inspeccion", foreign_keys=[inspeccion_id])


class Toma(Base):
    __tablename__ = "tomas"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    canal_id = Column(Integer, ForeignKey(f"{SCHEMA}.canales.id"), nullable=False)
    codigo_toma = Column(String(30), nullable=False, unique=True)
    nombre = Column(String(150))
    latitud = Column(Numeric(10, 7))
    longitud = Column(Numeric(10, 7))
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    canal = relationship("Canal", foreign_keys=[canal_id])


class Ccpp(Base):
    __tablename__ = "ccpp"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    codigo_ccpp = Column(String(30), nullable=False, unique=True)
    regante_id = Column(Integer, ForeignKey(f"{SCHEMA}.regantes.id"), nullable=False)
    toma_id = Column(Integer, ForeignKey(f"{SCHEMA}.tomas.id"), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    regante = relationship("Regante", foreign_keys=[regante_id])
    toma = relationship("Toma", foreign_keys=[toma_id])


class Regante(Base):
    __tablename__ = "regantes"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    dni_cuit = Column(String(20))
    telefono = Column(String(30))
    email = Column(String(150))
    activo = Column(Boolean, nullable=False, default=True)
    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


# ---------------------------------------------------------------------------
# Catálogos de reclamo
# ---------------------------------------------------------------------------

class CategoriaReclamo(Base):
    __tablename__ = "categorias_reclamo"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    nombre = Column(String(100), nullable=False, unique=True)


class TipoReclamo(Base):
    __tablename__ = "tipos_reclamo"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    categoria_id = Column(Integer, ForeignKey(f"{SCHEMA}.categorias_reclamo.id"), nullable=False)
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text)
    prioridad_sugerida = Column(
        SAEnum(PrioridadReclamo, name="prioridad_reclamo"),
        nullable=False,
        default=PrioridadReclamo.media,
    )
    activo = Column(Boolean, nullable=False, default=True)

    categoria = relationship("CategoriaReclamo", foreign_keys=[categoria_id])


# ---------------------------------------------------------------------------
# Reclamo principal
# ---------------------------------------------------------------------------

class Reclamo(Base):
    __tablename__ = "reclamos"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    codigo_reclamo = Column(String(30), nullable=False, unique=True)

    usuario_id = Column(Integer, nullable=False)

    regante_id = Column(Integer)
    ccpp_id = Column(Integer)
    toma_id = Column(Integer, ForeignKey(f"{SCHEMA}.tomas.id"))
    canal_id = Column(Integer, ForeignKey(f"{SCHEMA}.canales.id"))
    inspeccion_id = Column(Integer, ForeignKey(f"{SCHEMA}.inspecciones.id"))
    asociacion_id = Column(Integer, ForeignKey(f"{SCHEMA}.asociaciones.id"))
    cuenca_id = Column(Integer, ForeignKey(f"{SCHEMA}.cuencas.id"))
    tomero_id = Column(Integer)

    tipo_id = Column(Integer, ForeignKey(f"{SCHEMA}.tipos_reclamo.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey(f"{SCHEMA}.categorias_reclamo.id"), nullable=False)
    prioridad = Column(
        SAEnum(PrioridadReclamo, name="prioridad_reclamo"),
        nullable=False,
        default=PrioridadReclamo.media,
    )
    estado = Column(
        SAEnum(EstadoReclamo, name="estado_reclamo"),
        nullable=False,
        default=EstadoReclamo.nuevo,
    )

    titulo = Column(String(200), nullable=False)
    descripcion = Column(Text, nullable=False)
    latitud = Column(Numeric(10, 7))
    longitud = Column(Numeric(10, 7))
    direccion_manual = Column(Text)

    es_regante = Column(Boolean, nullable=False, default=True)
    reclamante_nombre = Column(String(150))
    reclamante_apellido = Column(String(100))
    reclamante_dni = Column(String(20))
    reclamante_telefono = Column(String(30))
    reclamante_email = Column(String(150))
    reclamante_cc = Column(String(20))
    reclamante_pp = Column(String(20))

    fecha_creacion = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    fecha_primera_respuesta = Column(DateTime(timezone=True))
    fecha_resolucion = Column(DateTime(timezone=True))
    fecha_cierre = Column(DateTime(timezone=True))

    asignado_a = Column(Integer)
    expediente_id = Column(Integer)  # FK lógica al módulo de expedientes, sin constraint forzada

    tipo = relationship("TipoReclamo", foreign_keys=[tipo_id])
    categoria = relationship("CategoriaReclamo", foreign_keys=[categoria_id])
    canal = relationship("Canal", foreign_keys=[canal_id])
    inspeccion = relationship("Inspeccion", foreign_keys=[inspeccion_id])
    asociacion = relationship("Asociacion", foreign_keys=[asociacion_id])
    cuenca = relationship("Cuenca", foreign_keys=[cuenca_id])
    comentarios = relationship(
        "ReclamoComentario", back_populates="reclamo", order_by="ReclamoComentario.fecha"
    )
    adjuntos = relationship(
        "ReclamoAdjunto", back_populates="reclamo", order_by="ReclamoAdjunto.fecha"
    )
    historial = relationship(
        "ReclamoHistorial", back_populates="reclamo", order_by="ReclamoHistorial.fecha"
    )


# ---------------------------------------------------------------------------
# Comentarios, adjuntos, historial
# ---------------------------------------------------------------------------

class RolUsuario(str, enum.Enum):
    regante = "regante"
    tomero = "tomero"
    inspector = "inspector"
    administrador = "administrador"
    asociacion = "asociacion"
    vecino = "vecino"


class ReclamoComentario(Base):
    __tablename__ = "reclamo_comentarios"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    reclamo_id = Column(
        Integer, ForeignKey(f"{SCHEMA}.reclamos.id", ondelete="CASCADE"), nullable=False
    )
    usuario_id = Column(Integer, nullable=False)
    rol_usuario = Column(
        SAEnum(RolUsuario, name="rol_usuario", schema=SCHEMA),
        nullable=False,
    )
    comentario = Column(Text, nullable=False)
    es_interno = Column(Boolean, nullable=False, default=False)
    fecha = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    reclamo = relationship("Reclamo", back_populates="comentarios")


class ReclamoAdjunto(Base):
    __tablename__ = "reclamo_adjuntos"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    reclamo_id = Column(
        Integer, ForeignKey(f"{SCHEMA}.reclamos.id", ondelete="CASCADE"), nullable=False
    )
    archivo_url = Column(Text, nullable=False)
    tipo_archivo = Column(String(50))
    descripcion = Column(String(255))
    fecha = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    reclamo = relationship("Reclamo", back_populates="adjuntos")


class ReclamoHistorial(Base):
    __tablename__ = "reclamo_historial"
    __table_args__ = {"schema": SCHEMA}

    id = Column(Integer, primary_key=True)
    reclamo_id = Column(
        Integer, ForeignKey(f"{SCHEMA}.reclamos.id", ondelete="CASCADE"), nullable=False
    )
    usuario_id = Column(Integer)
    accion = Column(String(100), nullable=False)
    estado_anterior = Column(String(30))
    estado_nuevo = Column(String(30))
    observacion = Column(Text)
    fecha = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    reclamo = relationship("Reclamo", back_populates="historial")
