"""
Adapters para resolución de datos externos (Infogov, etc.).

Patrón Strategy: cada adapter implementa una interfaz común.
El adapter real llamaría a una API externa; el stub devuelve None.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class InspeccionInfo:
    inspeccion_nombre: str
    inspector_nombre: str


class CCAdapter(ABC):
    """Interfaz para resolver un código de cauce (CC) a inspección/inspector."""

    @abstractmethod
    def resolver(self, cc: str) -> Optional[InspeccionInfo]:
        """Dado un CC, retorna InspeccionInfo o None si no hay match."""
        ...


class StubCCAdapter(CCAdapter):
    """
    Stub manual: consulta la tabla local canales → inspecciones.
    Reemplazar con adapter real de Infogov cuando esté disponible.
    """

    def __init__(self, session):
        self._db = session

    def resolver(self, cc: str) -> Optional[InspeccionInfo]:
        if not cc or not cc.strip():
            return None

        from sqlalchemy import select
        from app.models.reclamo import Canal, Inspeccion

        canal = self._db.scalar(
            select(Canal).where(Canal.codigo_canal == cc.strip().upper())
        )
        if not canal:
            return None

        inspeccion = self._db.get(Inspeccion, canal.inspeccion_id)
        if not inspeccion:
            return None

        return InspeccionInfo(
            inspeccion_nombre=inspeccion.nombre or "",
            inspector_nombre=inspeccion.inspector or "",
        )
