# AGENTS.md

## Project overview

**MiRiego** — internal management system for ASIC Primera Zona de Riego (Godoy Cruz, Mendoza). Replaces a legacy Progress 9.1D app.

Two independent projects in a single repo (no monorepo tooling, no root `package.json`):

| Project | Stack | Dev port | DB |
|---------|-------|----------|----|
| `miriego-backend/` | FastAPI + SQLAlchemy (sync) + psycopg3 + PostgreSQL | `:8000` | `miriego` schema |
| `miriego-frontend/` | SvelteKit 2 + Svelte 4 + TypeScript + Vite + Tailwind CSS v4 + jspdf | `:5174` | — |

## Quick start (development)

```bash
# Backend
cd miriego-backend
python -m venv .venv
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

# 4. Optional migrations (new columns, indexes)
psql -U postgres -d miriego -f miriego-backend/db/fix_iniciador_contacto.sql
psql -U postgres -d miriego -f miriego-backend/db/add_indexes.sql
psql -U postgres -d miriego -f miriego-backend/db/add_inspeccion_id_notificaciones.sql

# 5. Notificaciones + additional migrations
psql -U postgres -d miriego -f miriego-backend/db/notificaciones_schema.sql
psql -U postgres -d miriego -f miriego-backend/db/add_sla_reclamos.sql
psql -U postgres -d miriego -f miriego-backend/db/fix_duplicados_catalogos.sql

# 6. Unified schema (consolidated — use for fresh installs instead of steps 1-5)
psql -U postgres -d miriego -f miriego-backend/db/miriego_schema_unificado.sql
```

SQL files contain PL/pgSQL functions — use `psql -f` or pgAdmin Query Tool, never split by `;`.

**Note:** `miriego_schema_unificado.sql` is a consolidated schema for fresh installs. Steps 1-5 are for incremental updates on existing databases.

## Commands

### Frontend
| Command | Purpose |
|---------|---------|
| `npm run dev` | Dev server (port 5174, exposed on 0.0.0.0) |
| `npm run build` | Production build (adapter-node → `build/index.js`) |
| `npm run check` | **Type-check** via svelte-check — run before committing TS changes |

### Backend
| Command | Purpose |
|---------|---------|
| `uvicorn app.main:app --reload` | Dev server (port 8000) |
| Swagger at `http://localhost:8000/docs` | Interactive API docs |
| `GET /health` | Health check endpoint |

**No linter, formatter, or test suite is configured for either project.**

## Production deployment (Windows services)

The app runs as 4 Windows services on the office PC, surviving reboots without login.

### Architecture

```
Internet/LAN → :80 [Caddy] ─┬─ /api/* → strip prefix → localhost:8000 [FastAPI]
                             └─ /*     → localhost:3000 [SvelteKit SSR]
```

### Services

| Service | Executable | Start type | Port |
|---------|-----------|------------|------|
| `postgresql-x64-18` | (Windows service) | Automatic | 5432 (localhost only) |
| `MiRiegoAPI` | `venv\Scripts\python.exe -m uvicorn` | Automatic | 8000 (localhost only) |
| `MiRiegoFrontend` | `node.exe build\index.js` | Automatic | 3000 (localhost only) |
| `MiRiegoProxy` | `caddy_windows_amd64.exe` | Automatic | 80 (LAN-facing) |

### Service configuration (NSSM)

**NSSM executable:** `C:\nssm\nssm-2.24\win64\nssm.exe` (64-bit)

**MiRiegoAPI:**
- Path: `C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-backend\venv\Scripts\python.exe`
- AppParameters: `-m uvicorn app.main:app --host 0.0.0.0 --port 8000`
- AppDirectory: `C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-backend`
- AppEnvironmentExtra: `PYTHONUNBUFFERED=1`, `PYTHONIOENCODING=utf-8`
- Logs: `C:\MiRiego-Logs\backend-stdout.log`, `C:\MiRiego-Logs\backend-stderr.log`

**MiRiegoFrontend:**
- Path: `C:\Program Files\nodejs\node.exe`
- AppParameters: `build\index.js`
- AppDirectory: `C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-frontend`
- AppEnvironmentExtra: `PORT=3000`
- Logs: `...\miriego-frontend\logs\stdout.log`, `...\miriego-frontend\logs\stderr.log`

**MiRiegoProxy:**
- Path: `C:\caddy\caddy_windows_amd64.exe`
- AppParameters: `run --config "C:\caddy\Caddyfile.txt"`
- AppDirectory: `C:\caddy`
- Logs: `C:\caddy\logs\stdout.log`, `C:\caddy\logs\stderr.log`

### Caddyfile

Location: `C:\caddy\Caddyfile.txt`

```
:80 {
    handle /api/* {
        uri strip_prefix /api
        reverse_proxy localhost:8000
    }

    handle {
        reverse_proxy localhost:3000
    }
}
```

### Firewall

Rule: `MiRiego - HTTP (80)` — Inbound, TCP port 80, Allow, all profiles.

### Install/reinstall script

`install-services.bat` in the repo root. Must be run **as Administrator**. Cleans up existing services, creates fresh ones, starts them, and creates the firewall rule.

### Rebuilding after code changes

```bash
# After any frontend change:
cd miriego-frontend
npm run build
net stop MiRiegoFrontend && net start MiRiegoFrontend

# After any backend change:
net stop MiRiegoAPI && net start MiRiegoAPI
# (No rebuild needed — Python runs from source)
```

### Resilience test (PC reboot)

```powershell
# From PowerShell Admin:
Restart-Computer -Force

# After 2-3 minutes (without logging in), from another PC on the LAN:
# Open http://<this-PC-IP>/ in a browser

# Or after logging in, verify services:
Get-Service postgresql-x64-18,MiRiegoAPI,MiRiegoFrontend,MiRiegoProxy | Format-Table Name,Status,StartType
```

All 4 must show `Running` / `Automatic`.

## Architecture

### Backend (`miriego-backend/`)
- **Entry point:** `app/main.py` — creates FastAPI app, mounts CORS, calls `ensure_database_ready()` on startup
- **Routes:** `app/api/routes/expedientes.py` (CRUD + pases + notas), `app/api/routes/reclamos.py` (CRUD + comentarios + historial), `app/api/routes/catalogos.py` (read-only catalog endpoints), `app/api/routes/notificaciones.py` (CRUD), `app/api/routes/dashboard.py` (vencimientos endpoints)
- **Models:** `app/models/expediente.py`, `app/models/reclamo.py`, `app/models/notificacion.py` — SQLAlchemy ORM in `miriego` schema
- **Schemas:** `app/schemas/expediente.py`, `app/schemas/reclamo.py`, `app/schemas/notificacion.py` — Pydantic v2
- **Config:** `app/core/config.py` — pydantic-settings loads from `.env`
- **DB:** `app/core/database.py` — **sync** SQLAlchemy engine (`postgresql+psycopg://`), not async
- **CORS:** hardcoded list + regex in `main.py` (covers localhost, 127.0.0.1, 10.x, 192.168.x on ports 5173/5174)
- **SQL migrations:** `db/` — 2 schema files + 9 migration/fix files (apply in order, see above)

### Frontend (`miriego-frontend/`)
- **CSS:** Tailwind CSS v4 via `@tailwindcss/vite` plugin — no `postcss.config.js` or `tailwind.config.js` needed; theme tokens in `src/app.css` via `@theme {}`
- **Adapter:** `@sveltejs/adapter-node` — builds to `build/index.js` for production SSR
- **Vite config:** `vite.config.js` (plain JS, not TS)
- **API client:** `src/lib/api/client.ts` — `apiFetch<T>()` wrapper around fetch. Uses `PUBLIC_API_URL` env var (default `/api` in production, proxied through Caddy)
- **API modules:** `src/lib/api/expedientes.ts`, `src/lib/api/reclamos.ts`, `src/lib/api/catalogos.ts`, `src/lib/api/notificaciones.ts`, `src/lib/api/dashboard.ts`
- **Types:** `src/lib/types/expediente.ts`, `src/lib/types/reclamo.ts`, `src/lib/types/notificacion.ts`, `src/lib/types/dashboard.ts` — include `PaginatedResponse<T>` interface
- **Components:** `src/lib/components/Paginacion.svelte` — reusable pagination control (← Anterior / Página X de Y / Siguiente →)
- **Routes:** `src/routes/dashboard/`, `src/routes/expedientes/` (list, `[id]`, `nuevo`), `src/routes/reclamos/` (list, `[id]`, `nuevo`), `src/routes/notificaciones/` (list, `[id]`, `nuevo`)
- **SvelteKit conventions:** load functions in `+page.ts`, components in `+page.svelte`
- **Pagination:** Backend returns `{items, total, page, page_size}`. Frontend reads `page` from URL params, passes to API, and renders `Paginacion` component. Filters reset to page 1.

## Gotchas

- **Git repo is at `MiRiego-Expedientes/` root** — covers both backend and frontend. Single `.gitignore` at root.
- **Two separate venvs exist:** `.venv/` at root (Python 3.14.5) and `miriego-backend/venv/` (Python 3.13.14). Use `miriego-backend/venv/` for backend work.
- **No root-level orchestration** — start backend and frontend independently in separate terminals.
- **Frontend dev server is on port 5174** (not SvelteKit's default 5173). Backend CORS is configured for both.
- **Backend auto-creates DB on startup:** `ensure_database_ready()` in `database.py` will create the database and `miriego` schema if they don't exist. However, it only runs `Base.metadata.create_all()` — it does NOT apply PL/pgSQL functions, triggers, or seed data. Use the SQL files for that.
- **`miriego_schema_expedientes.sql` does NOT have `CREATE SCHEMA`** — `miriego_schema_reclamos.sql` must run first or the schema must be created manually.
- **SQLAlchemy is sync, not async** — uses `psycopg` (psycopg3) driver, not `asyncpg`. Simple but not ideal for high-concurrency.
- **`usuario_id: 1` is hardcoded** in `src/lib/api/reclamos.ts` (comentarios) and in `app/api/routes/notificaciones.py` (crear_notificacion) — marked as TODO for when auth is added.
- **Alembic** is in `requirements.txt` but no `alembic.ini` or migrations directory exists yet — schema changes are still manual SQL files.
- **SQL enum gotchas:** `estado_expediente` uses `pase_pendiente` (not `pase`); `estado_reclamo` includes `derivado_expediente`; `reclamos.expediente_id` was added after initial schema via `fix_expedientes_schema.sql`.
- **No auth yet** — both READMEs list it as next step.
- **`.env.example` in backend** has `FRONTEND_ORIGIN=http://localhost:5175` — update to `5174` when copying.
- **NSSM + uvicorn.exe + spaces in path:** NSSM cannot launch `uvicorn.exe` directly when the path contains spaces (e.g., "Mesa de Entradas"). Always use `python.exe -m uvicorn` as the backend service executable instead.
- **PUBLIC_API_URL is baked at build time** — `$env/static/public` in SvelteKit. In dev, Vite proxies `/api/*` → `localhost:8000` (see `vite.config.js`). In production, Caddy does the same. Always use `/api` as the value.
- **No print blob through apiFetch** — `imprimirNotificacion` uses raw `fetch()` because it returns a `.docx` blob, not JSON. Still uses `PUBLIC_API_URL` for the base URL.
- **Frontend port in production is 3000** (set via `PORT` env var), not 5174. The 5174 port is only for `npm run dev`.
- **Caddy strips `/api` prefix** before proxying to the backend, so FastAPI receives routes like `/expedientes` (without the prefix).
