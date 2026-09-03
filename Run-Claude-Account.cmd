@echo off
REM Universal Claude Code launcher with isolated config directory per account.
REM Usage: Run-Claude-Account.cmd [configDir|default] [label] [email]
REM IMPORTANT: no setlocal — CLAUDE_CONFIG_DIR must stay in this pane after Claude exits.

set "PATH=C:\nodejs;%APPDATA%\npm;%PATH%"
set "ACCOUNT_DIR=%~1"
set "ACCOUNT_LABEL=%~2"
set "ACCOUNT_EMAIL=%~3"
if "%ACCOUNT_LABEL%"=="" set "ACCOUNT_LABEL=Claude"
if "%ACCOUNT_EMAIL%"=="" set "ACCOUNT_EMAIL=%ACCOUNT_LABEL%"

if /I "%ACCOUNT_DIR%"=="default" (
  rem Default Claude account: do NOT set CLAUDE_CONFIG_DIR (uses ~/.claude + ~/.claude.json)
  set "CLAUDE_CONFIG_DIR="
) else if not "%ACCOUNT_DIR%"=="" (
  set "CLAUDE_CONFIG_DIR=%ACCOUNT_DIR%"
  if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"
) else (
  set "CLAUDE_CONFIG_DIR="
)

REM Email is passed in as arg 3 from ClaudeDuo.ps1.
REM Do not inline PowerShell here: cmd.exe treats ) inside for /f as the end of the command.

:set_title
title %ACCOUNT_EMAIL%

echo.
echo ============================================================
echo   Claude Duo pane
echo   Account email : %ACCOUNT_EMAIL%
echo   Label         : %ACCOUNT_LABEL%
if defined CLAUDE_CONFIG_DIR (
  echo   Config dir    : %CLAUDE_CONFIG_DIR%
) else (
  echo   Config dir    : %USERPROFILE%\.claude  ^(default / global^)
)
echo ============================================================
echo   Tip: after /exit, this pane KEEPS the same account.
echo   Then: cd to another project and type  claude
echo   Or press R to restart Claude here.
echo ============================================================
echo.

:run_claude
where claude.cmd >nul 2>&1
if %ERRORLEVEL%==0 (
  call claude.cmd
  goto :after_claude
)

if exist "C:\nodejs\claude.cmd" (
  call "C:\nodejs\claude.cmd"
  goto :after_claude
)

if exist "%APPDATA%\npm\claude.cmd" (
  call "%APPDATA%\npm\claude.cmd"
  goto :after_claude
)

echo Claude Code not found. Install: npm install -g @anthropic-ai/claude-code
pause
goto :eof

:after_claude
title %ACCOUNT_EMAIL%
echo.
echo ------------------------------------------------------------
echo   Claude closed — account is still: %ACCOUNT_EMAIL%
if defined CLAUDE_CONFIG_DIR (
  echo   CLAUDE_CONFIG_DIR=%CLAUDE_CONFIG_DIR%
) else (
  echo   Using default ~/.claude account
)
echo.
echo   [R] Restart Claude with this same account
echo   [Enter] Stay at prompt ^(type claude / cd to change project^)
echo ------------------------------------------------------------
set "REPLY="
set /p REPLY="Choice: "
if /I "%REPLY%"=="R" goto :run_claude
if /I "%REPLY%"=="r" goto :run_claude

echo.
echo Ready on account %ACCOUNT_EMAIL%.
echo   claude              - start again ^(same login^)
echo   cd /d C:\path\proj  - switch project, then claude
echo.
