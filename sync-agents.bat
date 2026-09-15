@echo off
setlocal EnableExtensions

:: ============================================
::  Sync AGENTS.md from the local opencode branch to:
::    - .config/opencode  -> master branch (AGENTS.md)
::    - .gemini/antigravity -> master branch (AGENTS.md)
::    - .claude           -> claude branch (CLAUDE.md)
::  Each repo returns to the branch it was on when the script started.
::  Push each branch manually with TortoiseGit afterwards.
:: ============================================

set "OPENCODE_DIR=C:\Users\shicheng.chang\.config\opencode"
set "GEMINI_DIR=C:\Users\shicheng.chang\.gemini\antigravity"
set "CLAUDE_DIR=C:\Users\shicheng.chang\.claude"

:: ------------------------------------------------------------
:: [1/4] Update the opencode branch and commit AGENTS.md (source)
:: ------------------------------------------------------------
cd /d "%OPENCODE_DIR%"

:: Remember the current branch so it can be restored later
for /f %%i in ('git rev-parse --abbrev-ref HEAD') do set "ORIG_OPEN=%%i"

git pull origin opencode
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull opencode. Fix conflicts then re-run.
    goto :end
)

:: Commit AGENTS.md to opencode if it changed
git add AGENTS.md
git diff --cached --quiet
if %errorlevel% neq 0 (
    git commit -m "update AGENTS.md"
    echo [OK] AGENTS.md committed to opencode
) else (
    echo [SKIP] No changes in AGENTS.md on opencode
)

:: ------------------------------------------------------------
:: [2/4] Sync AGENTS.md to the master branch of the same repo
:: ------------------------------------------------------------
git checkout master
if %errorlevel% neq 0 goto :end
git pull origin master
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull master. Fix conflicts then re-run.
    goto :end
)

copy /Y "%OPENCODE_DIR%\AGENTS.md" "AGENTS.md" >nul
git add AGENTS.md
git diff --cached --quiet
if %errorlevel% neq 0 (
    git commit -m "sync AGENTS.md from opencode"
    echo [OK] AGENTS.md updated on master
) else (
    echo [SKIP] AGENTS.md already up to date on master
)
git checkout "%ORIG_OPEN%"

:: ------------------------------------------------------------
:: [3/4] Sync AGENTS.md to .gemini/antigravity
:: ------------------------------------------------------------
cd /d "%GEMINI_DIR%"
for /f %%i in ('git rev-parse --abbrev-ref HEAD') do set "ORIG_GEMINI=%%i"

git checkout master
if %errorlevel% neq 0 goto :end
git pull origin master
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull gemini. Fix conflicts then re-run.
    goto :end
)

copy /Y "%OPENCODE_DIR%\AGENTS.md" "AGENTS.md" >nul
git add AGENTS.md
git diff --cached --quiet
if %errorlevel% neq 0 (
    git commit -m "sync AGENTS.md from opencode"
    echo [OK] AGENTS.md updated on gemini
) else (
    echo [SKIP] AGENTS.md already up to date on gemini
)
git checkout "%ORIG_GEMINI%"

:: ------------------------------------------------------------
:: [4/4] Sync AGENTS.md to .claude as CLAUDE.md
:: ------------------------------------------------------------
cd /d "%CLAUDE_DIR%"
for /f %%i in ('git rev-parse --abbrev-ref HEAD') do set "ORIG_CLAUDE=%%i"

git checkout claude
if %errorlevel% neq 0 goto :end
git pull origin claude
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull claude. Fix conflicts then re-run.
    goto :end
)

copy /Y "%OPENCODE_DIR%\AGENTS.md" "CLAUDE.md" >nul
git add CLAUDE.md
git diff --cached --quiet
if %errorlevel% neq 0 (
    git commit -m "sync CLAUDE.md from opencode"
    echo [OK] CLAUDE.md updated
) else (
    echo [SKIP] CLAUDE.md already up to date
)
git checkout "%ORIG_CLAUDE%"

:: ------------------------------------------------------------
::  Done. Push each branch manually with TortoiseGit.
:: ------------------------------------------------------------
cd /d "%OPENCODE_DIR%"
echo.
echo ============================================
echo   Done! Use TortoiseGit to push:
echo     - master
echo     - opencode
echo     - claude
echo ============================================
:end
pause