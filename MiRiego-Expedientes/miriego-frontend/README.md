# MiRiego — Frontend (SvelteKit + TypeScript)

## Requisitos
- Node.js 18+
- Backend FastAPI corriendo (ver ../miriego-backend)

## Instalación

```bash
npm install
cp .env.example .env
# Editar .env si el backend no corre en http://localhost:8000

npm run dev
```

La app queda en `http://localhost:5173`.

## Estructura

```
src/
  lib/
    api/
      client.ts        -> wrapper de fetch con manejo de errores
      expedientes.ts    -> llamadas a /expedientes, /pases, /notas
      catalogos.ts       -> llamadas a /catalogos/*
    types/
      expediente.ts      -> tipos TS que reflejan los schemas del backend
  routes/
    +layout.svelte       -> header y navegación general
    +page.svelte         -> home
    expedientes/
      +page.svelte       -> listado (bandeja general)
      +page.ts           -> carga expedientes + sectores desde la API
      nuevo/
        +page.svelte     -> formulario de creación
        +page.ts         -> carga catálogos para los selects
      [id]/
        +page.svelte     -> detalle: estado, pases, notas
        +page.ts         -> carga el expediente puntual
```

## Próximos pasos sugeridos
- Filtrar el listado por sector (bandeja de "lo que me llegó a mí").
- Autenticación: hoy no hay login, cualquiera puede crear/derivar.
- Sumar validación de formularios más robusta (hoy es básica).
- Cuando el módulo de reclamos tenga su propio set de rutas, replicar
  este mismo patrón (lib/api/reclamos.ts, routes/reclamos/...).
