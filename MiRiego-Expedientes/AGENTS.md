# AGENTS.md

## Project overview

**MiRiego** — internal management system for ASIC Primera Zona de Riego (Godoy Cruz, Mendoza). Replaces a legacy Progress 9.1D app.

Two independent projects in a single repo (no monorepo tooling, no root `package.json`):

| Project | Stack | Dev port | DB |
|---------|-------|----------|----|
| `miriego-backend/` | FastAPI + SQLAlchemy (sync) + psycopg3 + PostgreSQL | `:8000` | `miriego` schema |
| `miriego-frontend/` | SvelteKit 2 + Svelte 4 + TypeScript + Vite + Tailwind CSS v4 | `:5174` | — |

## Quick start

```bash
# Backend
cd miriego-backend
python -m venv 
venv\Scripts\activate   # Python 3.13+
pip install -r requirements.txt
cp .env.example .env
# Set up PostgreSQL DB + schema (see Database setup below)
uvicorn app.main:app --reload

# Frontend (separate terminal)
cd miriego-frontend
npm install
cp .env.example .env
npm run dev
```

## Database setup

The `miriego` schema must exist before the backend works. Apply SQL files **in order**:

```bash
# Fresh start — drop everything first
psql -U postgres -d miriego -c "DROP SCHEMA IF EXISTS miriego CASCADE;"

# 1. reclamos schema FIRST (contains CREATE SCHEMA IF NOT EXISTS miriego)
psql -U postgres -d miriego -f miriego-backend/db/miriego_schema_reclamos.sql

# 2. expedientes schema (does NOT create the schema itself)
psql -U postgres -d miriego -f miriego-backend/db/miriego_schema_expedientes.sql

# 3. Post-initial migrations (added columns, triggers, seed data)
psql -U postgres -d miriego -f miriego-backend/db/fix_expedientes_schema.sql
psql -U postgres -d miriego -f miriego-backend/db/fix_pases_condicional.sql
psql -U postgres -d miriego -f miriego-backend/db/fix_triggers.sql
psql -U postgres -d miriego -f miriego-backend/db/miriego_reclamos_v2.sql
psql -U postgres -d miriego -f miriego-backend/db/reclamos_v3_cc_pp.sql
```

SQL files contain PL/pgSQL functions — use `psql -f` or pgAdmin Query Tool, never split by `;`.

## Commands

### Frontend
| Command | Purpose |
|---------|---------|
| `npm run dev` | Dev server (port 5174, exposed on 0.0.0.0) |
| `npm run build` | Production build |
| `npm run check` | **Type-check** via svelte-check — run before committing TS changes |

### Backend
| Command | Purpose |
|---------|---------|
| `uvicorn app.main:app --reload` | Dev server (port 8000) |
| Swagger at `http://localhost:8000/docs` | Interactive API docs |
| `GET /health` | Health check endpoint |

**No linter, formatter, or test suite is configured for either project.**

## Architecture

### Backend (`miriego-backend/`)
- **Entry point:** `app/main.py` — creates FastAPI app, mounts CORS, calls `ensure_database_ready()` on startup
- **Routes:** `app/api/routes/expedientes.py` (CRUD + pases + notas), `app/api/routes/reclamos.py` (CRUD + comentarios + historial), `app/api/routes/catalogos.py` (read-only catalog endpoints)
- **Models:** `app/models/expediente.py`, `app/models/reclamo.py` — SQLAlchemy ORM in `miriego` schema
- **Schemas:** `app/schemas/expediente.py`, `app/schemas/reclamo.py` — Pydantic v2
- **Config:** `app/core/config.py` — pydantic-settings loads from `.env`
- **DB:** `app/core/database.py` — **sync** SQLAlchemy engine (`postgresql+psycopg://`), not async
- **CORS:** hardcoded list + regex in `main.py` (covers localhost, 127.0.0.1, 10.x, 192.168.x on ports 5173/5174)
- **SQL migrations:** `db/` — 2 schema files + 5 migration/fix files (apply in order, see above)

### Frontend (`miriego-frontend/`)
- **CSS:** Tailwind CSS v4 via `@tailwindcss/vite` plugin — no `postcss.config.js` or `tailwind.config.js` needed; theme tokens in `src/app.css` via `@theme {}`
- **Vite config:** `vite.config.js` (plain JS, not TS)
- **API client:** `src/lib/api/client.ts` — `apiFetch<T>()` wrapper around fetch
- **API modules:** `src/lib/api/expedientes.ts`, `src/lib/api/reclamos.ts`, `src/lib/api/catalogos.ts`
- **Types:** `src/lib/types/expediente.ts`, `src/lib/types/reclamo.ts`
- **Routes:** `src/routes/expedientes/` (list, `[id]`, `nuevo`), `src/routes/reclamos/` (list, `[id]`, `nuevo`)
- **API URL:** `PUBLIC_API_URL` env var (default `http://localhost:8000`)
- **SvelteKit conventions:** load functions in `+page.ts`, components in `+page.svelte`

## Gotchas

- **Git repo is at `MiRiego-Expedientes/` root** — covers both backend and frontend. Single `.gitignore` at root.
- **Two separate venvs exist:** `.venv/` at root (Python 3.14.5) and `miriego-backend/venv/` (Python 3.13.14). Use `miriego-backend/venv/` for backend work.
- **No root-level orchestration** — start backend and frontend independently in separate terminals.
- **Frontend dev server is on port 5174** (not SvelteKit's default 5173). Backend CORS is configured for both.
- **Backend auto-creates DB on startup:** `ensure_database_ready()` in `database.py` will create the database and `miriego` schema if they don't exist. However, it only runs `Base.metadata.create_all()` — it does NOT apply PL/pgSQL functions, triggers, or seed data. Use the SQL files for that.
- **`miriego_schema_expedientes.sql` does NOT have `CREATE SCHEMA`** — `miriego_schema_reclamos.sql` must run first or the schema must be created manually.
- **SQLAlchemy is sync, not async** — uses `psycopg` (psycopg3) driver, not `asyncpg`. Simple but not ideal for high-concurrency.
- **`usuario_id: 1` is hardcoded** in `src/lib/api/reclamos.ts` (comentarios) — marked as TODO for when auth is added.
- **Alembic** is in `requirements.txt` but no `alembic.ini` or migrations directory exists yet — schema changes are still manual SQL files.
- **SQL enum gotchas:** `estado_expediente` uses `pase_pendiente` (not `pase`); `estado_reclamo` includes `derivado_expediente`; `reclamos.expediente_id` was added after initial schema via `fix_expedientes_schema.sql`.
- **No auth yet** — both READMEs list it as next step.
- **`.env.example` in backend** has `FRONTEND_ORIGIN=http://localhost:5175` — update to `5174` when copying.
