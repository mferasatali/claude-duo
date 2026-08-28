#!/usr/bin/env node
'use strict'

const { spawn } = require('child_process')
const path = require('path')

if (process.platform !== 'win32') {
  console.error('claude-duo is a Windows tool (Windows Terminal + Claude Code).')
  process.exit(1)
}

const ps1 = path.join(__dirname, '..', 'ClaudeDuo.ps1')
const child = spawn(
  'powershell.exe',
  ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, ...process.argv.slice(2)],
  { stdio: 'inherit', windowsHide: false }
)

child.on('exit', (code, signal) => {
  if (signal) process.kill(process.pid, signal)
  process.exit(code == null ? 1 : code)
})
