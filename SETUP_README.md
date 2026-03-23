# Obsidian Workspace Setup Scripts

Bootstrap a ready-to-use Obsidian vault with OSCP/AD templates and all required plugins
configured from the reference `.obsidian` setup.

---

## What the scripts do

1. Install Obsidian (if not already present)
2. Create the target vault directory
3. Clone `801labs/OSCP_templates` into the vault (no `.git` metadata)
4. Create a `Pentests/` folder at the vault root
5. Download and install community plugins from GitHub releases
6. Write all plugin `data.json` configs matching the reference setup

**Plugins installed:** Templater, Git, Meta Bind, JS Engine, vConsole, Dataview

---

## Usage

### Windows (PowerShell)

```powershell
# Allow script execution if needed (run once as admin)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\setup_windows.ps1 -WorkspacePath "C:\Users\YourName\Documents\OSCP_Vault"
```

### Linux (Bash)

```bash
chmod +x setup_linux.sh
./setup_linux.sh ~/Documents/OSCP_Vault
```

### macOS (Bash)

```bash
chmod +x setup_macos.sh
./setup_macos.sh ~/Documents/OSCP_Vault
```

**All three scripts fail with a clear error if the workspace path argument is omitted.**

---

## Required dependencies

| Dependency | Windows | Linux | macOS |
|---|---|---|---|
| `git` | git-scm.com | `sudo apt install git` | `xcode-select --install` |
| `curl` | Built into Win10+ | `sudo apt install curl` | Built in |
| PowerShell 5.1+ | Built into Windows | — | — |
| Homebrew (optional) | — | — | Preferred; brew.sh |
| winget (optional) | Preferred; built into Win11 | — | — |
| flatpak or snap (optional) | — | Preferred | — |

---

## Obsidian installation methods (by platform)

| Platform | Priority order |
|---|---|
| Windows | winget → GitHub .exe download |
| Linux | flatpak → snap → .deb download → AppImage |
| macOS | `brew install --cask obsidian` → DMG download |

If auto-installation fails, the script warns you and continues setting up the vault.
Install Obsidian manually and re-run — the script is idempotent.

---

## Plugin configuration applied

Settings are sourced directly from the reference `.obsidian` folder and embedded verbatim.

### Templater
- `trigger_on_file_creation`: `true`
- `enable_folder_templates`: `true`
- Folder template: `Pentests` → `Templates/Scope.md`
- Templates folder: `Templates`

### Meta Bind
- `enableJs`: `true`
- `enableEditorRightClickMenu`: `true`
- `enableSyntaxHighlighting`: `true`
- `excludedFolders`: `["templates"]`

### Git
- `autoPullOnBoot`: `true`
- `pullBeforePush`: `true`
- Commit format: `vault backup: {{date}}`
- Sync method: `merge`

### Dataview
- `enableDataviewJs`: `true`
- `enableInlineDataviewJs`: `true`
- `allowHtml`: `true`

### JS Engine / vConsole
No custom `data.json` — default settings match reference config.

---

## Hotkeys configured

| Action | Shortcut |
|---|---|
| Templater: Insert template | `Alt+Shift+E` |
| Templater: Replace in file | `Alt+Shift+R` |
| Git: Push | `Alt+Shift+A` |
| vConsole: Toggle panel | `Alt+Ctrl+I` |
| Debug info | `Ctrl+Shift+D` |

---

## Steps that cannot be fully automated

These require manual action inside Obsidian after first launch:

1. **Enable community plugins** — Obsidian's security model requires you to go to
   `Settings → Community plugins`, turn off Safe mode, and click **Enable** on each plugin.
   The config files are already written; this is just a UI confirmation step.

2. **Git remote configuration** — The vault is not initialized as a git repo by default.
   If you want the Obsidian Git plugin to sync to a remote:
   ```bash
   cd /path/to/your/vault
   git init
   git remote add origin <your-repo-url>
   git add .
   git commit -m "initial vault"
   git push -u origin main
   ```

3. **Obsidian account / Sync / Publish** — Not configured. These require manual login.

4. **Vault registration in Obsidian** — Obsidian maintains its own list of known vaults
   (`obsidian.json` in the app data directory). The first time you open a new vault,
   Obsidian will prompt you to trust it. This cannot be scripted reliably cross-platform.

---

## Assumptions

- The `Templates/Scope.md` file comes from the `801labs/OSCP_templates` repo.
  If the repo structure changes, the Templater folder-template mapping may need updating.
- Plugin download URLs follow the standard GitHub releases pattern:
  `https://github.com/<owner>/<repo>/releases/latest/download/main.js`
  If a plugin moves repos, update the `repo` entries in the script.
- The `dataview` plugin is included because it is present and enabled in the reference config,
  even though it was not in the explicit plugin list.
- The scripts write config files only if they don't already exist (idempotent).
  To force a fresh config, delete `.obsidian/` from the vault before re-running.
