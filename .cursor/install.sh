#!/usr/bin/env bash
# Idempotent Cloud Agent setup for claude-duo.
#
# claude-duo is a Windows-only tool (package.json declares "os": ["win32"]).
# On the Linux Cloud Agent VM the tool itself cannot run, but we still make the
# repo workable: install Node deps and PowerShell so the core ClaudeDuo.ps1 can
# be syntax-checked and worked on.
set -euo pipefail

cd "$(dirname "$0")/.."

# PowerShell lets us lint/parse the ClaudeDuo.ps1 core script on Linux.
if ! command -v pwsh >/dev/null 2>&1; then
  echo "Installing PowerShell..."
  source /etc/os-release
  tmp_deb="$(mktemp --suffix=.deb)"
  curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -o "$tmp_deb"
  sudo dpkg -i "$tmp_deb"
  rm -f "$tmp_deb"
  sudo apt-get update -qq
  sudo apt-get install -y -qq powershell
else
  echo "PowerShell already installed: $(pwsh --version)"
fi

# --force is required: the package declares "os": ["win32"], so a plain
# `npm install` aborts with EBADPLATFORM on Linux. There are no runtime
# dependencies, so this just validates package.json and installs any future deps.
echo "Installing npm dependencies..."
npm install --force

echo "claude-duo dev environment ready."
