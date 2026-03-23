#!/usr/bin/env bash
# setup_linux.sh — Bootstrap an Obsidian vault with OSCP/AD templates on Linux.
#
# Usage:
#   chmod +x setup_linux.sh
#   ./setup_linux.sh /path/to/your/vault
#
# What this script does:
#   1. Installs Obsidian (tries: flatpak → snap → AppImage download)
#   2. Creates the target vault directory
#   3. Clones 801labs/OSCP_templates repo contents (no .git history)
#   4. Creates a 'Pentests' folder
#   5. Downloads required community plugins from GitHub releases
#   6. Writes all plugin configuration files from the reference .obsidian setup
#
# Requirements: git, curl, and one of: flatpak, snap, or a writable ~/bin
# Idempotent: safe to re-run; existing files/dirs are not overwritten.

set -euo pipefail

# ─── Color helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}==> $*${RESET}"; }
ok()    { echo -e "  ${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
fail()  { echo -e "\n${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ─── Validate argument ───────────────────────────────────────────────────────
if [[ $# -lt 1 || -z "${1:-}" ]]; then
    fail "WorkspacePath argument is required.

Usage:
  ./setup_linux.sh <workspace-path>

Example:
  ./setup_linux.sh ~/Documents/OSCP_Vault"
fi

VAULT_PATH="$(realpath -m "$1")"
echo "Target vault: $VAULT_PATH"

# ─── Prerequisites ───────────────────────────────────────────────────────────
step "Checking prerequisites"

command -v git  >/dev/null 2>&1 || fail "git is not installed. Install it (e.g. 'sudo apt install git') and re-run."
command -v curl >/dev/null 2>&1 || fail "curl is not installed. Install it (e.g. 'sudo apt install curl') and re-run."

ok "git:  $(git --version)"
ok "curl: $(curl --version | head -1)"

# ─── Install Obsidian ────────────────────────────────────────────────────────
step "Installing Obsidian"

if command -v obsidian >/dev/null 2>&1; then
    ok "Obsidian already in PATH — skipping installation"
else
    INSTALLED=false

    # Attempt 1: flatpak
    if command -v flatpak >/dev/null 2>&1; then
        echo "  Trying flatpak..."
        if flatpak install --noninteractive flathub md.obsidian.Obsidian 2>/dev/null; then
            ok "Obsidian installed via flatpak"
            INSTALLED=true
        else
            warn "flatpak install failed — trying next method"
        fi
    fi

    # Attempt 2: snap
    if [[ "$INSTALLED" == false ]] && command -v snap >/dev/null 2>&1; then
        echo "  Trying snap..."
        if sudo snap install obsidian --classic 2>/dev/null; then
            ok "Obsidian installed via snap"
            INSTALLED=true
        else
            warn "snap install failed — trying next method"
        fi
    fi

    # Attempt 3: .deb download (Debian/Ubuntu)
    if [[ "$INSTALLED" == false ]] && command -v dpkg >/dev/null 2>&1; then
        echo "  Fetching latest Obsidian .deb from GitHub releases..."
        API_URL="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
        DEB_URL=$(curl -fsSL "$API_URL" \
            -H "User-Agent: obsidian-setup-script/1.0" \
            | grep -oP '"browser_download_url":\s*"\K[^"]+\.deb' \
            | head -1)

        if [[ -n "$DEB_URL" ]]; then
            TMP_DEB="$(mktemp /tmp/obsidian-XXXXXX.deb)"
            echo "  Downloading: $DEB_URL"
            curl -fsSL -o "$TMP_DEB" "$DEB_URL"
            sudo dpkg -i "$TMP_DEB" 2>/dev/null || sudo apt-get install -f -y 2>/dev/null || true
            rm -f "$TMP_DEB"
            ok "Obsidian installed via .deb"
            INSTALLED=true
        else
            warn "Could not find a .deb asset"
        fi
    fi

    # Attempt 4: AppImage fallback
    if [[ "$INSTALLED" == false ]]; then
        echo "  Fetching latest Obsidian AppImage from GitHub releases..."
        API_URL="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
        APPIMAGE_URL=$(curl -fsSL "$API_URL" \
            -H "User-Agent: obsidian-setup-script/1.0" \
            | grep -oP '"browser_download_url":\s*"\K[^"]+\.AppImage' \
            | head -1)

        if [[ -n "$APPIMAGE_URL" ]]; then
            mkdir -p "$HOME/bin"
            APPIMAGE_PATH="$HOME/bin/obsidian.AppImage"
            echo "  Downloading AppImage to $APPIMAGE_PATH"
            curl -fsSL -o "$APPIMAGE_PATH" "$APPIMAGE_URL"
            chmod +x "$APPIMAGE_PATH"

            # Create a wrapper so 'obsidian' works from PATH
            cat > "$HOME/bin/obsidian" <<'WRAPPER'
#!/usr/bin/env bash
exec "$HOME/bin/obsidian.AppImage" --no-sandbox "$@"
WRAPPER
            chmod +x "$HOME/bin/obsidian"
            export PATH="$HOME/bin:$PATH"
            ok "Obsidian AppImage installed to $HOME/bin/"
            warn "Add '$HOME/bin' to your PATH if it is not already there."
            INSTALLED=true
        else
            warn "Could not auto-install Obsidian. Download it manually from https://obsidian.md/download"
            warn "All other setup steps will still complete."
        fi
    fi
fi

# ─── Create vault directory ──────────────────────────────────────────────────
step "Creating vault directory"

if [[ ! -d "$VAULT_PATH" ]]; then
    mkdir -p "$VAULT_PATH"
    ok "Created $VAULT_PATH"
else
    ok "Directory already exists — reusing"
fi

# ─── Create .obsidian structure ──────────────────────────────────────────────
step "Writing .obsidian configuration"

OBS_DIR="$VAULT_PATH/.obsidian"
PLUGINS_DIR="$OBS_DIR/plugins"
mkdir -p "$PLUGINS_DIR"

# Helper: write a file only if it does not already exist
write_if_missing() {
    local path="$1"
    local content="$2"
    if [[ ! -f "$path" ]]; then
        printf '%s' "$content" > "$path"
    fi
}

write_if_missing "$OBS_DIR/app.json" '{
  "attachmentFolderPath": "Images",
  "spellcheck": true,
  "strictLineBreaks": false
}'

write_if_missing "$OBS_DIR/appearance.json" '{
  "accentColor": "",
  "baseFontSize": 17
}'

write_if_missing "$OBS_DIR/community-plugins.json" '[
  "templater-obsidian",
  "obsidian-git",
  "obsidian-meta-bind-plugin",
  "vconsole",
  "js-engine",
  "dataview"
]'

write_if_missing "$OBS_DIR/core-plugins.json" '{
  "file-explorer": true,
  "global-search": true,
  "switcher": true,
  "graph": true,
  "backlink": true,
  "canvas": true,
  "outgoing-link": true,
  "tag-pane": true,
  "page-preview": true,
  "daily-notes": true,
  "templates": true,
  "note-composer": true,
  "command-palette": true,
  "slash-command": false,
  "editor-status": true,
  "starred": true,
  "markdown-importer": true,
  "zk-prefixer": false,
  "random-note": false,
  "outline": true,
  "word-count": true,
  "slides": false,
  "audio-recorder": false,
  "workspaces": false,
  "file-recovery": true,
  "publish": false,
  "sync": false,
  "bookmarks": true,
  "properties": true,
  "webviewer": false,
  "footnotes": false,
  "bases": true
}'

write_if_missing "$OBS_DIR/hotkeys.json" '{
  "templater-obsidian:insert-templater": [
    { "modifiers": ["Alt", "Shift"], "key": "E" }
  ],
  "templater-obsidian:replace-in-file-templater": [
    { "modifiers": ["Alt", "Shift"], "key": "R" }
  ],
  "editor:context-menu": [],
  "app:show-debug-info": [
    { "modifiers": ["Mod", "Shift"], "key": "D" }
  ],
  "open-with-default-app:show": [
    { "modifiers": ["Mod", "Shift"], "key": "E" }
  ],
  "obsidian-git:push": [
    { "modifiers": ["Alt", "Shift"], "key": "A" }
  ],
  "vconsole:toggle-vconsole-panel": [
    { "modifiers": ["Alt", "Mod"], "key": "I" }
  ]
}'

write_if_missing "$OBS_DIR/templates.json" '{
  "folder": "Templates"
}'

ok "All .obsidian config files written"

# ─── Clone repo (no .git metadata) ──────────────────────────────────────────
step "Cloning 801labs/OSCP_templates (shallow, no .git)"

REPO_URL="https://github.com/801labs/OSCP_templates.git"
TMP_CLONE="$(mktemp -d /tmp/oscp_templates_XXXXXX)"

clone_ok=false
if git clone --depth 1 --quiet "$REPO_URL" "$TMP_CLONE" 2>/dev/null; then
    # Copy into vault/Templates/ (no .git)
    mkdir -p "$VAULT_PATH/Templates"
    rsync -a --exclude='.git' "$TMP_CLONE/" "$VAULT_PATH/Templates/" 2>/dev/null \
        || { cp -r "$TMP_CLONE"/. "$VAULT_PATH/Templates/"; rm -rf "$VAULT_PATH/Templates/.git" 2>/dev/null || true; }
    clone_ok=true
    ok "Repository content copied to vault/Templates/"
else
    warn "Could not clone repository. Manually clone $REPO_URL into $VAULT_PATH/Templates"
fi
rm -rf "$TMP_CLONE"

# ─── Create Pentests folder ──────────────────────────────────────────────────
step "Creating Pentests folder"

if [[ ! -d "$VAULT_PATH/Pentests" ]]; then
    mkdir -p "$VAULT_PATH/Pentests"
    ok "Created Pentests/"
else
    ok "Pentests/ already exists"
fi

# Create Images folder (attachment target per app.json)
mkdir -p "$VAULT_PATH/Images"

# ─── Download community plugins ──────────────────────────────────────────────
step "Downloading community plugins from GitHub releases"

download_plugin() {
    local id="$1"
    local repo="$2"
    local dir="$PLUGINS_DIR/$id"
    local base="https://github.com/$repo/releases/latest/download"

    mkdir -p "$dir"
    echo "  $id ..."

    # main.js — required
    if ! curl -fsSL -o "$dir/main.js" "$base/main.js" 2>/dev/null; then
        warn "Failed to download main.js for $id — skipping"
        return
    fi

    # manifest.json — required
    curl -fsSL -o "$dir/manifest.json" "$base/manifest.json" 2>/dev/null \
        || warn "Failed to download manifest.json for $id"

    # styles.css — optional
    curl -fsSL -o "$dir/styles.css" "$base/styles.css" 2>/dev/null || rm -f "$dir/styles.css"

    ok "$id"
}

download_plugin "templater-obsidian"        "SilentVoid13/Templater"
download_plugin "obsidian-git"              "Vinzent03/obsidian-git"
download_plugin "obsidian-meta-bind-plugin" "mProjectsCode/obsidian-meta-bind-plugin"
download_plugin "vconsole"                  "zhouhua/obsidian-vconsole"
download_plugin "js-engine"                 "mProjectsCode/obsidian-js-engine-plugin"
download_plugin "dataview"                  "blacksmithgu/obsidian-dataview"

# ─── Write plugin data.json configs ─────────────────────────────────────────
step "Writing plugin configurations"

# Single-quoted heredoc: no variable expansion; {{date}} written literally.

write_if_missing "$PLUGINS_DIR/templater-obsidian/data.json" '{
  "command_timeout": 5,
  "templates_folder": "Templates",
  "templates_pairs": [["", ""]],
  "trigger_on_file_creation": true,
  "auto_jump_to_cursor": false,
  "enable_system_commands": false,
  "shell_path": "",
  "user_scripts_folder": "",
  "enable_folder_templates": true,
  "folder_templates": [
    {
      "folder": "Pentests",
      "template": "Templates/Scope.md"
    }
  ],
  "syntax_highlighting": true,
  "enabled_templates_hotkeys": [""],
  "startup_templates": [""],
  "enable_ribbon_icon": true
}'
ok "Templater: trigger_on_file_creation=true, folder_templates=[Pentests→Templates/Scope.md]"

write_if_missing "$PLUGINS_DIR/obsidian-git/data.json" '{
  "commitMessage": "vault backup: {{date}}",
  "autoCommitMessage": "vault backup: {{date}}",
  "commitDateFormat": "YYYY-MM-DD HH:mm:ss",
  "autoSaveInterval": 0,
  "autoPushInterval": 0,
  "autoPullInterval": 0,
  "autoPullOnBoot": true,
  "disablePush": false,
  "pullBeforePush": true,
  "disablePopups": false,
  "listChangedFilesInMessageBody": false,
  "showStatusBar": true,
  "updateSubmodules": true,
  "syncMethod": "merge",
  "customMessageOnAutoBackup": false,
  "autoBackupAfterFileChange": false,
  "treeStructure": false,
  "refreshSourceControl": true,
  "basePath": "",
  "differentIntervalCommitAndPush": false,
  "changedFilesInStatusBar": false,
  "showedMobileNotice": true,
  "refreshSourceControlTimer": 7000,
  "showBranchStatusBar": true,
  "setLastSaveToLastCommit": false
}'
ok "Git: autoPullOnBoot=true, pullBeforePush=true"

write_if_missing "$PLUGINS_DIR/obsidian-meta-bind-plugin/data.json" '{
  "devMode": false,
  "ignoreCodeBlockRestrictions": false,
  "preferredDateFormat": "YYYY-MM-DD",
  "firstWeekday": {
    "index": 1,
    "name": "Monday",
    "shortName": "Mo"
  },
  "syncInterval": 200,
  "enableJs": true,
  "viewFieldDisplayNullAsEmpty": false,
  "enableSyntaxHighlighting": true,
  "enableEditorRightClickMenu": true,
  "inputFieldTemplates": [],
  "buttonTemplates": [],
  "excludedFolders": ["templates"]
}'
ok "Meta Bind: enableJs=true, enableEditorRightClickMenu=true, enableSyntaxHighlighting=true"

write_if_missing "$PLUGINS_DIR/dataview/data.json" '{
  "renderNullAs": "\\-",
  "taskCompletionTracking": false,
  "taskCompletionUseEmojiShorthand": false,
  "taskCompletionText": "completion",
  "taskCompletionDateFormat": "yyyy-MM-dd",
  "recursiveSubTaskCompletion": false,
  "warnOnEmptyResult": true,
  "refreshEnabled": true,
  "refreshInterval": 2500,
  "defaultDateFormat": "MMMM dd, yyyy",
  "defaultDateTimeFormat": "h:mm a - MMMM dd, yyyy",
  "maxRecursiveRenderDepth": 4,
  "tableIdColumnName": "File",
  "tableGroupColumnName": "Group",
  "showResultCount": true,
  "allowHtml": true,
  "inlineQueryPrefix": "=",
  "inlineJsQueryPrefix": "$=",
  "inlineQueriesInCodeblocks": true,
  "enableInlineDataview": true,
  "enableDataviewJs": true,
  "enableInlineDataviewJs": true,
  "prettyRenderInlineFields": true,
  "prettyRenderInlineFieldsInLivePreview": true,
  "dataviewJsKeyword": "dataviewjs"
}'
ok "Dataview configured"

# js-engine and vconsole: no custom data.json in reference config

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  Vault ready!${RESET}"
echo -e "${GREEN}  $VAULT_PATH${RESET}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "Next steps:"
echo "  1. Open Obsidian → 'Open folder as vault' → select the path above"
echo "  2. Settings → Community plugins → disable 'Safe mode', then enable each plugin"
echo "  3. To track the vault with git, run 'git init' inside the vault folder"
echo "     and configure a remote if desired."
echo ""
