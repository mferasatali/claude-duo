@echo off
REM Account B: separate Claude login (~/.claude-account-2)
call "%~dp0Run-Claude-Account.cmd" "%USERPROFILE%\.claude-account-2" Work
