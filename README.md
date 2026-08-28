# Claude Duo

Open-source Windows tool that opens **two [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions in one window**.

Optional: left pane = your current account, right pane = a **second Claude account** (separate login).

## Requirements

- Windows 10 or 11
- [Windows Terminal](https://aka.ms/terminal)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)

## Install

```bash
git clone https://github.com/mferasatali/claude-duo.git
```

Then double-click **`ClaudeDuo.bat`**.

Or click **Pin to Desktop** in the app.

## Use

1. Pick the project folder(s).
2. Keep **Right pane: second Claude account** checked if you want two logins.
3. Click **Open 2 Claude Code**.
4. Left pane uses your default Claude login. Right pane asks you to sign in once with the second account (saved under `%USERPROFILE%\.claude-account-2`).
5. Click a pane, type a task, press Enter.

Do not type `claude` in a blank Command Prompt. The tool starts it for you.

## Command line

```powershell
powershell -ExecutionPolicy Bypass -File .\ClaudeDuo.ps1 -NoGui -Left "C:\projA" -Right "C:\projB" -Split vertical -Maximized
```

`-Split` is `vertical` (side by side) or `horizontal` (stacked).

## How it works

- Uses Windows Terminal split panes (`wt.exe`).
- Account A runs with your normal Claude config.
- Account B sets `CLAUDE_CONFIG_DIR` so logins do not overwrite each other.

## License

[MIT](LICENSE)
