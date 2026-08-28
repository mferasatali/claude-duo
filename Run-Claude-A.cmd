@echo off
REM Account A: default Claude login
set "PATH=C:\nodejs;%APPDATA%\npm;%PATH%"
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
