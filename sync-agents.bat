@echo off
setlocal EnableExtensions

:: ============================================
::  Sync AGENTS.md from opencode branch to:
::    - master branch (AGENTS.md)  via worktree
::    - claude branch (CLAUDE.md)  via worktree
::  All in .config/opencode repo.
::  Push manually with TortoiseGit afterwards.
:: ============================================

set "OPENCODE_DIR=%USERPROFILE%\.config\opencode"
set "SNAP=%TEMP%\agents-sync-snapshot.md"

:: ------------------------------------------------------------
:: [1/3] Update the opencode branch and commit AGENTS.md (source)
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
:: [2/3] Sync AGENTS.md to master branch (via worktree)
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
:: [3/3] Sync AGENTS.md to claude branch as CLAUDE.md (via worktree)
:: ------------------------------------------------------------
set "WT_CLAUDE=%TEMP%\agents-sync-wt-claude"
if exist "%WT_CLAUDE%" rmdir /S /Q "%WT_CLAUDE%"
git worktree prune
git worktree add "%WT_CLAUDE%" claude
if %errorlevel% neq 0 goto :end
git -C "%WT_CLAUDE%" pull origin claude
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull claude. Fix conflicts then re-run.
    goto :end
)

copy /Y "%SNAP%" "%WT_CLAUDE%\CLAUDE.md" >nul
git -C "%WT_CLAUDE%" add CLAUDE.md
git -C "%WT_CLAUDE%" diff --cached --quiet
if %errorlevel% neq 0 (
    git -C "%WT_CLAUDE%" commit -m "sync CLAUDE.md from opencode"
    echo [OK] CLAUDE.md updated on claude branch
) else (
    echo [SKIP] CLAUDE.md already up to date on claude branch
)
git worktree remove --force "%WT_CLAUDE%"

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