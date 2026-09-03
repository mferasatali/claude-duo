# Claude Duo

Open-source Windows tool that opens **two [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions in one window**.

Optional: left pane = your current account, right pane = a **second Claude account** (separate login).

## Requirements

- Windows 10 or 11
- [Windows Terminal](https://aka.ms/terminal)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)

## Install (npm)

```bash
npm install -g claude-duo
claude-duo
```

One-shot, no install:

```bash
npx claude-duo
```

Needs Windows 10/11, [Windows Terminal](https://aka.ms/terminal), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

### GitHub Packages

Shows on the profile **Packages** tab:

```bash
npm install -g @mferasatali/claude-duo --registry=https://npm.pkg.github.com
```

Most people should still use `npx claude-duo` from [npmjs](https://www.npmjs.com/package/claude-duo).

### From GitHub (source, no registry)

```bash
git clone https://github.com/mferasatali/claude-duo.git
```

Double-click **`ClaudeDuo.bat`**, or **Pin to Desktop** in the app.

## Use

1. Pick the project folder(s).
2. Choose **Left pane account** and **Right pane account** (must be different).
3. Click **Open 2 Claude Code**.
4. Left pane uses `~/.claude` (Personal). Right pane uses its own folder (e.g. `~/.claude-account-2` for Work).
5. Each pane tab title shows the **logged-in Claude email** (after `/login`).
6. **First time per account:** in that pane type `/login` once. Logins stay saved in that account's config folder.
7. If you `/exit` Claude, the pane **keeps the same account**. Press `R` to restart, or `cd` to another project and type `claude` again.
8. Use **Open left/right account only** to switch to a single account in a new window.

Do not type `claude` in a blank Command Prompt. The tool starts it for you.

## Command line

```powershell
powershell -ExecutionPolicy Bypass -File .\ClaudeDuo.ps1 -NoGui -Left "C:\projA" -Right "C:\projB" -Split vertical -Maximized
```

`-Split` is `vertical` (side by side) or `horizontal` (stacked).

## How it works

- Uses Windows Terminal split panes (`wt.exe`).
- Each pane sets `CLAUDE_CONFIG_DIR` to an isolated folder so logins, history, and settings never mix.
- Pane titles show the account email from `oauthAccount.emailAddress`.
- After Claude exits, `CLAUDE_CONFIG_DIR` stays in that pane so `claude` does not fall back to the global login.
- Settings (folders, accounts, layout) auto-save to `%APPDATA%\ClaudeDuo\config.json`.

## License

[MIT](LICENSE)
