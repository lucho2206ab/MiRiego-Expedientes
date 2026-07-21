"""
Endpoints del módulo Dashboard.

Rutas expuestas:
  GET /dashboard/expedientes-vencimientos  -> vencimientos de expedientes por sector
  GET /dashboard/reclamos-vencimientos     -> vencimientos de reclamos por inspección
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

# Estados terminales de expedientes (excluidos de vencimientos)
ESTADOS_TERMINALES_EXP = "('resuelto', 'archivado', 'anulado')"

# Estados terminales de reclamos (excluidos de vencimientos)
ESTADOS_TERMINALES_REC = "('resuelto', 'cerrado', 'rechazado', 'cancelado', 'derivado_expediente')"


# ---------------------------------------------------------------------------
# Expedientes por sector
# ---------------------------------------------------------------------------

@router.get("/expedientes-vencimientos")
def expedientes_vencimientos(
    db: Session = Depends(get_db),
    sector_id: Optional[int] = None,
    estado: str = Query("vencido", regex="^(vencido|por_vencer)$"),
    dias_umbral: int = Query(5, ge=1, le=365),
):
    """
    Vencimientos de expedientes.

    - Sin sector_id: conteo agrupado por sector actual.
    - Con sector_id: listado detallado de expedientes en ese sector.

    "Vencido": fecha_vencimiento < ahora AND estado no terminal.
    "Por vencer": fecha_vencimiento entre ahora y ahora + dias_umbral AND estado no terminal.
    """
    ahora = text("now()")
    umbral = text(f"now() + interval '{dias_umbral} days'")

    if sector_id is None:
        # Conteo agrupado por sector
        sql = text(f"""
            SELECT
                s.id AS sector_id,
                s.nombre AS sector_nombre,
                COUNT(*) AS total
            FROM miriego.expedientes e
            JOIN miriego.sectores s ON s.id = e.sector_actual_id
            LEFT JOIN LATERAL (
                SELECT p.fecha_vencimiento
                FROM miriego.pases p
                WHERE p.expediente_id = e.id
                  AND p.estado != 'rechazado'
                ORDER BY p.fecha_envio DESC
                LIMIT 1
            ) pv ON true
            WHERE e.estado NOT IN {ESTADOS_TERMINALES_EXP}
              AND e.fecha_vencimiento IS NOT NULL
              AND (
                  (pv.fecha_vencimiento IS NOT NULL AND pv.fecha_vencimiento < {ahora})
                  OR e.fecha_vencimiento < {ahora}
              )
            GROUP BY s.id, s.nombre
            ORDER BY total DESC
        """)

        if estado == "por_vencer":
            sql = text(f"""
                SELECT
                    s.id AS sector_id,
                    s.nombre AS sector_nombre,
                    COUNT(*) AS total
                FROM miriego.expedientes e
                JOIN miriego.sectores s ON s.id = e.sector_actual_id
                LEFT JOIN LATERAL (
                    SELECT p.fecha_vencimiento
                    FROM miriego.pases p
                    WHERE p.expediente_id = e.id
                      AND p.estado != 'rechazado'
                    ORDER BY p.fecha_envio DESC
                    LIMIT 1
                ) pv ON true
                WHERE e.estado NOT IN {ESTADOS_TERMINALES_EXP}
                  AND (
                      (pv.fecha_vencimiento IS NOT NULL AND pv.fecha_vencimiento > {ahora} AND pv.fecha_vencimiento < {umbral})
                      OR (e.fecha_vencimiento > {ahora} AND e.fecha_vencimiento < {umbral})
                  )
                GROUP BY s.id, s.nombre
                ORDER BY total DESC
            """)

        rows = db.execute(sql).mappings().all()
        return [{"sector_id": r["sector_id"], "sector_nombre": r["sector_nombre"], "total": r["total"]} for r in rows]

    else:
        # Listado detallado para un sector específico
        sql = text(f"""
            SELECT
                e.id,
                e.numero_expediente,
                e.asunto,
                e.estado::text AS estado,
                e.fecha_vencimiento AS fecha_vencimiento_exp,
                pv.fecha_vencimiento AS fecha_vencimiento_pase,
                GREATEST(e.fecha_vencimiento, pv.fecha_vencimiento) AS fecha_vencimiento_effectiva
            FROM miriego.expedientes e
            LEFT JOIN LATERAL (
                SELECT p.fecha_vencimiento
                FROM miriego.pases p
                WHERE p.expediente_id = e.id
                  AND p.estado != 'rechazado'
                ORDER BY p.fecha_envio DESC
                LIMIT 1
            ) pv ON true
            WHERE e.sector_actual_id = :sector_id
              AND e.estado NOT IN {ESTADOS_TERMINALES_EXP}
        """)

        if estado == "vencido":
            sql = text(f"""
                SELECT
                    e.id,
                    e.numero_expediente,
                    e.asunto,
                    e.estado::text AS estado,
                    e.fecha_vencimiento AS fecha_vencimiento_exp,
                    pv.fecha_vencimiento AS fecha_vencimiento_pase,
                    GREATEST(e.fecha_vencimiento, pv.fecha_vencimiento) AS fecha_vencimiento_effectiva
                FROM miriego.expedientes e
                LEFT JOIN LATERAL (
                    SELECT p.fecha_vencimiento
                    FROM miriego.pases p
                    WHERE p.expediente_id = e.id
                      AND p.estado != 'rechazado'
                    ORDER BY p.fecha_envio DESC
                    LIMIT 1
                ) pv ON true
                WHERE e.sector_actual_id = :sector_id
                  AND e.estado NOT IN {ESTADOS_TERMINALES_EXP}
                  AND (
                      (pv.fecha_vencimiento IS NOT NULL AND pv.fecha_vencimiento < {ahora})
                      OR (e.fecha_vencimiento IS NOT NULL AND e.fecha_vencimiento < {ahora})
                  )
                ORDER BY GREATEST(e.fecha_vencimiento, pv.fecha_vencimiento) ASC
            """)
        else:  # por_vencer
            sql = text(f"""
                SELECT
                    e.id,
                    e.numero_expediente,
                    e.asunto,
                    e.estado::text AS estado,
                    e.fecha_vencimiento AS fecha_vencimiento_exp,
                    pv.fecha_vencimiento AS fecha_vencimiento_pase,
                    GREATEST(e.fecha_vencimiento, pv.fecha_vencimiento) AS fecha_vencimiento_effectiva
                FROM miriego.expedientes e
                LEFT JOIN LATERAL (
                    SELECT p.fecha_vencimiento
                    FROM miriego.pases p
                    WHERE p.expediente_id = e.id
                      AND p.estado != 'rechazado'
                    ORDER BY p.fecha_envio DESC
                    LIMIT 1
                ) pv ON true
                WHERE e.sector_actual_id = :sector_id
                  AND e.estado NOT IN {ESTADOS_TERMINALES_EXP}
                  AND (
                      (pv.fecha_vencimiento IS NOT NULL AND pv.fecha_vencimiento > {ahora} AND pv.fecha_vencimiento < {umbral})
                      OR (e.fecha_vencimiento IS NOT NULL AND e.fecha_vencimiento > {ahora} AND e.fecha_vencimiento < {umbral})
                  )
                ORDER BY GREATEST(e.fecha_vencimiento, pv.fecha_vencimiento) ASC
            """)

        rows = db.execute(sql, {"sector_id": sector_id}).mappings().all()
        return [
            {
                "id": r["id"],
                "numero_expediente": r["numero_expediente"],
                "asunto": r["asunto"],
                "estado": r["estado"],
                "fecha_vencimiento_effectiva": str(r["fecha_vencimiento_effectiva"]) if r["fecha_vencimiento_effectiva"] else None,
            }
            for r in rows
        ]


# ---------------------------------------------------------------------------
# Reclamos por inspección
# ---------------------------------------------------------------------------

@router.get("/reclamos-vencimientos")
def reclamos_vencimientos(
    db: Session = Depends(get_db),
    inspeccion_id: Optional[int] = None,
    estado: str = Query("vencido", regex="^(vencido|por_vencer)$"),
    horas_umbral: int = Query(6, ge=1, le=720),
):
    """
    Vencimientos de reclamos.

    - Sin inspeccion_id: conteo agrupado por inspección.
    - Con inspeccion_id: listado detallado de reclamos en esa inspección.

    "Vencido": fecha_limite_respuesta < ahora AND estado no terminal.
    "Por vencer": fecha_limite_respuesta entre ahora y ahora + horas_umbral AND estado no terminal.
    """
    ahora = text("now()")
    umbral = text(f"now() + interval '{horas_umbral} hours'")

    if inspeccion_id is None:
        # Conteo agrupado por inspección
        sql = text(f"""
            SELECT
                i.id AS inspeccion_id,
                i.nombre AS inspeccion_nombre,
                COUNT(*) AS total
            FROM miriego.reclamos r
            JOIN miriego.inspecciones i ON i.id = r.inspeccion_id
            WHERE r.estado NOT IN {ESTADOS_TERMINALES_REC}
              AND r.fecha_limite_respuesta IS NOT NULL
              AND r.fecha_limite_respuesta < {ahora}
            GROUP BY i.id, i.nombre
            ORDER BY total DESC
        """)

        if estado == "por_vencer":
            sql = text(f"""
                SELECT
                    i.id AS inspeccion_id,
                    i.nombre AS inspeccion_nombre,
                    COUNT(*) AS total
                FROM miriego.reclamos r
                JOIN miriego.inspecciones i ON i.id = r.inspeccion_id
                WHERE r.estado NOT IN {ESTADOS_TERMINALES_REC}
                  AND r.fecha_limite_respuesta IS NOT NULL
                  AND r.fecha_limite_respuesta > {ahora}
                  AND r.fecha_limite_respuesta < {umbral}
                GROUP BY i.id, i.nombre
                ORDER BY total DESC
            """)

        rows = db.execute(sql).mappings().all()
        return [{"inspeccion_id": r["inspeccion_id"], "inspeccion_nombre": r["inspeccion_nombre"], "total": r["total"]} for r in rows]

    else:
        # Listado detallado para una inspección específica
        sql = text(f"""
            SELECT
                r.id,
                r.codigo_reclamo,
                r.titulo,
                r.prioridad::text AS prioridad,
                r.estado::text AS estado,
                r.fecha_limite_respuesta
            FROM miriego.reclamos r
            WHERE r.inspeccion_id = :inspeccion_id
              AND r.estado NOT IN {ESTADOS_TERMINALES_REC}
              AND r.fecha_limite_respuesta IS NOT NULL
              AND r.fecha_limite_respuesta < {ahora}
            ORDER BY r.fecha_limite_respuesta ASC
        """)

        if estado == "por_vencer":
            sql = text(f"""
                SELECT
                    r.id,
                    r.codigo_reclamo,
                    r.titulo,
                    r.prioridad::text AS prioridad,
                    r.estado::text AS estado,
                    r.fecha_limite_respuesta
                FROM miriego.reclamos r
                WHERE r.inspeccion_id = :inspeccion_id
                  AND r.estado NOT IN {ESTADOS_TERMINALES_REC}
                  AND r.fecha_limite_respuesta IS NOT NULL
                  AND r.fecha_limite_respuesta > {ahora}
                  AND r.fecha_limite_respuesta < {umbral}
                ORDER BY r.fecha_limite_respuesta ASC
            """)

        rows = db.execute(sql, {"inspeccion_id": inspeccion_id}).mappings().all()
        return [
            {
                "id": r["id"],
                "codigo_reclamo": r["codigo_reclamo"],
                "titulo": r["titulo"],
                "prioridad": r["prioridad"],
                "estado": r["estado"],
                "fecha_limite_respuesta": str(r["fecha_limite_respuesta"]) if r["fecha_limite_respuesta"] else None,
            }
            for r in rows
        ]
