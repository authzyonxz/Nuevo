@echo off
setlocal
cd /d "%~dp0"

echo.
echo ==============================================
echo  3105 - pareamento do iPhone (Windows)
echo ==============================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pair-3105.ps1"

if errorlevel 1 (
  echo.
  echo O script terminou com erro. Leia a mensagem acima.
  pause
)
endlocal
