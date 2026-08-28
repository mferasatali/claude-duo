@echo off
REM Account B: separate Claude login. First run asks you to sign in.
set "PATH=C:\nodejs;%APPDATA%\npm;%PATH%"
set "CLAUDE_CONFIG_DIR=%USERPROFILE%\.claude-account-2"
if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"
where claude.cmd >nul 2>&1
if %ERRORLEVEL%==0 (
  claude.cmd %*
  goto :eof
)
if exist "C:\nodejs\claude.cmd" (
  "C:\nodejs\claude.cmd" %*
  goto :eof
)
echo Claude Code not found. Install: npm install -g @anthropic-ai/claude-code
pause
