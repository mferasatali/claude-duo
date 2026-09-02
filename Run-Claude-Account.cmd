@echo off
REM Universal Claude Code launcher with isolated config directory per account.
REM Usage: Run-Claude-Account.cmd [configDir|default] [label]
setlocal EnableDelayedExpansion

set "PATH=C:\nodejs;%APPDATA%\npm;%PATH%"
set "ACCOUNT_DIR=%~1"
set "ACCOUNT_LABEL=%~2"
if "%ACCOUNT_LABEL%"=="" set "ACCOUNT_LABEL=Claude"

if /I "%ACCOUNT_DIR%"=="default" (
  set "CLAUDE_CONFIG_DIR="
) else if not "%ACCOUNT_DIR%"=="" (
  set "CLAUDE_CONFIG_DIR=%ACCOUNT_DIR%"
  if not exist "!CLAUDE_CONFIG_DIR!" mkdir "!CLAUDE_CONFIG_DIR!"
) else (
  set "CLAUDE_CONFIG_DIR="
)

title Claude-!ACCOUNT_LABEL!
echo.
echo  Claude Duo - Account: !ACCOUNT_LABEL!
if defined CLAUDE_CONFIG_DIR (
  echo  Config dir: !CLAUDE_CONFIG_DIR!
) else (
  echo  Config dir: %USERPROFILE%\.claude ^(default^)
)
echo  First time on this account? Type /login inside Claude Code.
echo.

where claude.cmd >nul 2>&1
if %ERRORLEVEL%==0 (
  call claude.cmd
  goto :done
)

if exist "C:\nodejs\claude.cmd" (
  call "C:\nodejs\claude.cmd"
  goto :done
)

if exist "%APPDATA%\npm\claude.cmd" (
  call "%APPDATA%\npm\claude.cmd"
  goto :done
)

echo Claude Code not found. Install: npm install -g @anthropic-ai/claude-code
pause

:done
endlocal
