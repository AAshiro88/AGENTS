@echo off
setlocal EnableExtensions
title Ollama to opencode config sync

set "OLLAMA_URL=http://localhost:11434"
set "CONFIG=%USERPROFILE%\.config\opencode\opencode.jsonc"
set "REQUIRE_TOOLS=1"
set "MIN_CONTEXT=65536"
set "SCRIPT_FILE=%USERPROFILE%\.config\opencode\sync_ollama_models.ps1"

if not exist "%CONFIG%" (
  echo [ERROR] Config file not found: %CONFIG%
  exit /b 1
)

if not exist "%SCRIPT_FILE%" (
  echo [ERROR] Sync script not found: %SCRIPT_FILE%
  exit /b 1
)

curl.exe -s -o NUL --max-time 5 "%OLLAMA_URL%/" >NUL 2>&1
if errorlevel 1 (
  echo [ERROR] Ollama service is not reachable at %OLLAMA_URL%
  echo [INFO] Please start Ollama service first: ollama serve
  exit /b 1
)

echo [INFO] Syncing Ollama models to opencode config...
set "OLLAMA_URL=%OLLAMA_URL%"
set "CONFIG=%CONFIG%"
set "REQUIRE_TOOLS=%REQUIRE_TOOLS%"
set "MIN_CONTEXT=%MIN_CONTEXT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_FILE%"
if errorlevel 1 (
  echo [ERROR] Sync failed
  exit /b 1
)

pause
