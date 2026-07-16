from sqlalchemy import create_engine, text
from app.core.config import settings

engine = create_engine(settings.DATABASE_URL)
with engine.connect() as conn:
    for rel in ['miriego.reclamos','miriego.tipos_reclamo','miriego.tomas','miriego.canales','miriego.inspecciones','miriego.cuencas']:
        print(rel, '=>', conn.execute(text(f"SELECT to_regclass('{rel}')")).scalar())
