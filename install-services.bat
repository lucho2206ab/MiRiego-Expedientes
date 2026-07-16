@echo off
REM MiRiego - Instalacion de servicios (ejecutar como Admin)
REM Hacer doble clic en este archivo y aceptar UAC

echo === MiRiego - Instalando servicios ===

REM Verificar admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Necesitas ejecutar este archivo como Administrador.
    echo Hacer clic derecho ^> "Ejecutar como administrador"
    pause
    exit /b 1
)

set NSSM=C:\nssm\nssm-2.24\win64\nssm.exe
set VENV_PYTHON=C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-backend\venv\Scripts\python.exe
set BACKEND_DIR=C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-backend
set NODE="C:\Program Files\nodejs\node.exe"
set FRONTEND_DIR=C:\Users\Mesa de Entradas\Documents\miriego-expedientes\miriego-frontend
set CADDY=C:\caddy\caddy_windows_amd64.exe
set CADDY_DIR=C:\caddy
set CADDYFILE=C:\caddy\Caddyfile.txt

echo.
echo [1/5] Limpiando servicios previos...
%NSSM% remove MiRiegoBackend confirm
%NSSM% remove MiRiegoAPI confirm
%NSSM% remove MiRiegoFrontend confirm
%NSSM% remove MiRiegoProxy confirm
timeout /t 3 /nobreak >nul

echo.
echo [2/5] Registrando MiRiegoAPI...
%NSSM% install MiRiegoAPI "%VENV_PYTHON%" "-m uvicorn app.main:app --host 0.0.0.0 --port 8000"
%NSSM% set MiRiegoAPI AppDirectory "%BACKEND_DIR%"
%NSSM% set MiRiegoAPI DisplayName "MiRiego API (FastAPI)"
%NSSM% set MiRiegoAPI Description "API backend de MiRiego - FastAPI + PostgreSQL"
%NSSM% set MiRiegoAPI Start SERVICE_AUTO_START
%NSSM% set MiRiegoAPI AppEnvironmentExtra PYTHONUNBUFFERED=1
%NSSM% set MiRiegoAPI AppEnvironmentExtra PYTHONIOENCODING=utf-8
%NSSM% set MiRiegoAPI AppStdout "C:\MiRiego-Logs\backend-stdout.log"
%NSSM% set MiRiegoAPI AppStderr "C:\MiRiego-Logs\backend-stderr.log"
%NSSM% set MiRiegoAPI AppRotateFiles 1
%NSSM% set MiRiegoAPI AppRotateBytes 10485760
mkdir "C:\MiRiego-Logs" 2>nul
icacls "C:\MiRiego-Logs" /grant Everyone:(OI)(CI)F 2>nul

echo.
echo [3/5] Registrando MiRiegoFrontend...
%NSSM% install MiRiegoFrontend %NODE% "build\index.js"
%NSSM% set MiRiegoFrontend AppDirectory "%FRONTEND_DIR%"
%NSSM% set MiRiegoFrontend DisplayName "MiRiego Frontend (SvelteKit)"
%NSSM% set MiRiegoFrontend Description "Frontend SSR de MiRiego - SvelteKit + adapter-node"
%NSSM% set MiRiegoFrontend Start SERVICE_AUTO_START
%NSSM% set MiRiegoFrontend AppEnvironmentExtra PORT=3000
%NSSM% set MiRiegoFrontend AppStdout "%FRONTEND_DIR%\logs\stdout.log"
%NSSM% set MiRiegoFrontend AppStderr "%FRONTEND_DIR%\logs\stderr.log"
%NSSM% set MiRiegoFrontend AppRotateFiles 1
%NSSM% set MiRiegoFrontend AppRotateBytes 10485760
mkdir "%FRONTEND_DIR%\logs" 2>nul

echo.
echo [4/5] Registrando MiRiegoProxy (Caddy)...
%NSSM% install MiRiegoProxy "%CADDY%" "run --config \"%CADDYFILE%\""
%NSSM% set MiRiegoProxy AppDirectory "%CADDY_DIR%"
%NSSM% set MiRiegoProxy DisplayName "MiRiego Proxy (Caddy)"
%NSSM% set MiRiegoProxy Description "Reverse proxy Caddy - puerto 80"
%NSSM% set MiRiegoProxy Start SERVICE_AUTO_START
%NSSM% set MiRiegoProxy AppStdout "%CADDY_DIR%\logs\stdout.log"
%NSSM% set MiRiegoProxy AppStderr "%CADDY_DIR%\logs\stderr.log"
%NSSM% set MiRiegoProxy AppRotateFiles 1
%NSSM% set MiRiegoProxy AppRotateBytes 10485760
mkdir "%CADDY_DIR%\logs" 2>nul

echo.
echo [5/5] Configurando firewall...
netsh advfirewall firewall show rule name="MiRiego - HTTP (80)" >nul 2>&1
if %errorLevel% neq 0 (
    netsh advfirewall firewall add rule name="MiRiego - HTTP (80)" dir=in action=allow protocol=TCP localport=80 profile=any description="Permitir HTTP para MiRiego"
    echo   Regla de firewall creada.
) else (
    echo   Regla de firewall ya existe.
)

echo.
echo === Iniciando servicios ===
net start MiRiegoAPI
timeout /t 5 /nobreak >nul
net start MiRiegoFrontend
timeout /t 3 /nobreak >nul
net start MiRiegoProxy
timeout /t 5 /nobreak >nul

echo.
echo === VERIFICACION ===
sc query MiRiegoAPI
sc query MiRiegoFrontend
sc query MiRiegoProxy
sc query postgresql-x64-18

echo.
echo === Fin ===
pause
