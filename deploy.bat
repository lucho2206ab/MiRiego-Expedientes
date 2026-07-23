@echo off
REM MiRiego - Deploy en la PC de oficina
REM Ejecutar como Administrador (clic derecho > Ejecutar como administrador)
REM
REM Este script:
REM   1. Hace git pull
REM   2. Aplica migraciones SQL pendientes
REM   3. Actualiza dependencias del frontend
REM   4. Reconstruye el frontend
REM   5. Reinicia los servicios

echo ============================================
echo   MiRiego - Deploy
echo ============================================

REM Verificar admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Necesitas ejecutar este archivo como Administrador.
    pause
    exit /b 1
)

set PROJECT_DIR=C:\Users\Mesa de Entradas\Documents\miriego-expedientes
set BACKEND_DIR=%PROJECT_DIR%\miriego-backend
set FRONTEND_DIR=%PROJECT_DIR%\miriego-frontend
set DB_NAME=miriego
set DB_USER=postgres

echo.
echo [1/5] Git pull...
cd /d "%PROJECT_DIR%"
git pull
if %errorLevel% neq 0 (
    echo ERROR: git pull fallo. Revisa la conexion y credenciales.
    pause
    exit /b 1
)

echo.
echo [2/5] Aplicando migraciones SQL...
echo   Ejecutando add_inspeccion_id_notificaciones.sql...
psql -U %DB_USER% -d %DB_NAME% -f "%BACKEND_DIR%\db\add_inspeccion_id_notificaciones.sql"
if %errorLevel% neq 0 (
    echo ADVERTENCIA: La migracion pudo haber fallado. Verificar manualmente.
    echo   Si la columna ya existe, el error "column already exists" es normal.
)
echo   Migraciones aplicadas.

echo.
echo [3/5] Actualizando dependencias del frontend...
cd /d "%FRONTEND_DIR%"
call npm install
if %errorLevel% neq 0 (
    echo ERROR: npm install fallo.
    pause
    exit /b 1
)

echo.
echo [4/5] Reconstruyendo frontend...
call npm run build
if %errorLevel% neq 0 (
    echo ERROR: npm run build fallo.
    pause
    exit /b 1
)

echo.
echo [5/5] Reiniciando servicios...
net stop MiRiegoAPI
timeout /t 2 /nobreak >nul
net start MiRiegoAPI
timeout /t 5 /nobreak >nul

net stop MiRiegoFrontend
timeout /t 2 /nobreak >nul
net start MiRiegoFrontend
timeout /t 3 /nobreak >nul

net stop MiRiegoProxy
timeout /t 2 /nobreak >nul
net start MiRiegoProxy
timeout /t 3 /nobreak >nul

echo.
echo === Verificando servicios ===
sc query MiRiegoAPI | findstr STATE
sc query MiRiegoFrontend | findstr STATE
sc query MiRiegoProxy | findstr STATE
sc query postgresql-x64-18 | findstr STATE

echo.
echo === Deploy completado ===
echo Abrir http://localhost/ para verificar que funciona.
pause
