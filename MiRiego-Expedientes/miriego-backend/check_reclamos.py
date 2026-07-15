import traceback
from app.api.routes.reclamos import listar_reclamos
from app.core.database import SessionLocal


db = SessionLocal()
try:
    result = listar_reclamos(db=db)
    print(type(result).__name__, len(result))
except Exception:
    traceback.print_exc()
finally:
    db.close()
