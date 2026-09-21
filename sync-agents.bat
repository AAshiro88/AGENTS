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

set "OPENCODE_DIR=%USERPROFILE%\.config\opencode"
set "GEMINI_DIR=%USERPROFILE%\.gemini\antigravity"
set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "SNAP=%TEMP%\agents-sync-snapshot.md"

:: ------------------------------------------------------------
:: [1/4] Update the opencode branch and commit AGENTS.md (source)
:: ------------------------------------------------------------
cd /d "%OPENCODE_DIR%"

:: Remember the current branch so it can be restored later
for /f %%i in ('git rev-parse --abbrev-ref HEAD') do set "ORIG_OPEN=%%i"

:: Make sure the source branch is opencode
git checkout opencode
if %errorlevel% neq 0 goto :end

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

:: Create a snapshot from the committed opencode AGENTS.md
git show opencode:AGENTS.md > "%SNAP%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create snapshot.
    goto :end
)

:: ------------------------------------------------------------
:: [2/4] Sync AGENTS.md to the master branch of the same repo
::       Uses a temp worktree so the current branch and working
::       tree are never left behind.
:: ------------------------------------------------------------
set "WT_MASTER=%TEMP%\agents-sync-wt-master"
if exist "%WT_MASTER%" rmdir /S /Q "%WT_MASTER%"
git worktree prune
git worktree add "%WT_MASTER%" master
if %errorlevel% neq 0 goto :end
git -C "%WT_MASTER%" pull origin master
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull master. Fix conflicts then re-run.
    goto :end
)

copy /Y "%SNAP%" "%WT_MASTER%\AGENTS.md" >nul
git -C "%WT_MASTER%" add AGENTS.md
git -C "%WT_MASTER%" diff --cached --quiet
if %errorlevel% neq 0 (
    git -C "%WT_MASTER%" commit -m "sync AGENTS.md from opencode"
    echo [OK] AGENTS.md updated on master
) else (
    echo [SKIP] AGENTS.md already up to date on master
)
git worktree remove --force "%WT_MASTER%"

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

copy /Y "%SNAP%" "AGENTS.md" >nul
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

copy /Y "%SNAP%" "CLAUDE.md" >nul
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
git checkout "%ORIG_OPEN%"
if exist "%SNAP%" del /Q "%SNAP%"
echo.
echo ============================================
echo   Done! Use TortoiseGit to push:
echo     - master
echo     - opencode
echo     - claude
echo ============================================
:end
if exist "%SNAP%" del /Q "%SNAP%"
pause