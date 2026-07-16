# MiRiego — Backend (FastAPI)

## Requisitos
- Python 3.11+
- PostgreSQL corriendo localmente

## Instalación

```bash
# 1. Crear entorno virtual
python -m venv venv
source venv/bin/activate        # en Windows: venv\Scripts\activate

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Configurar variables de entorno
cp .env.example .env
# Editar .env con tu DATABASE_URL real

# 4. Crear la base y correr el schema
createdb miriego
psql -U postgres -d miriego -f db/miriego_schema_expedientes.sql
# (el schema de reclamos se corre por separado, con el archivo que ya tenés)

# 5. Levantar el servidor de desarrollo
uvicorn app.main:app --reload
```

La API queda en `http://localhost:8000`, con documentación interactiva
en `http://localhost:8000/docs` (Swagger — muy útil para probar los
endpoints sin todavía tener el frontend listo).

## Estructura del proyecto

```
app/
  core/
    config.py       -> lectura de variables de entorno
    database.py     -> conexión a PostgreSQL con SQLAlchemy
  models/
    expediente.py   -> tablas como clases Python (ORM)
  schemas/
    expediente.py   -> validación de entrada/salida de la API (Pydantic)
  api/routes/
    expedientes.py  -> endpoints de expedientes, pases y notas
    catalogos.py    -> endpoints de sectores y tipos de expediente
  main.py           -> arranque de la app y configuración de CORS
db/
  miriego_schema_expedientes.sql  -> schema SQL del módulo
```

## Próximos pasos sugeridos
- Agregar autenticación (JWT) antes de exponer esto fuera de tu PC.
- Migrar a Alembic para versionar cambios de schema en vez de correr
  el .sql a mano cada vez (ya está en requirements.txt, falta configurar).
- Sumar el módulo de reclamos (mismo patrón: models + schemas + routes).
