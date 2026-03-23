#!/usr/bin/env bash
# setup_macos.sh — Bootstrap an Obsidian vault with OSCP/AD templates on macOS.
#
# Usage:
#   chmod +x setup_macos.sh
#   ./setup_macos.sh /path/to/your/vault
#
# What this script does:
#   1. Installs Obsidian (tries: Homebrew cask → DMG download)
#   2. Creates the target vault directory
#   3. Clones 801labs/OSCP_templates repo contents (no .git history)
#   4. Creates a 'Pentests' folder
#   5. Downloads required community plugins from GitHub releases
#   6. Writes all plugin configuration files from the reference .obsidian setup
#
# Requirements: git, curl, and ideally Homebrew (https://brew.sh)
# Idempotent: safe to re-run; existing files are not overwritten.

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
  ./setup_macos.sh <workspace-path>

Example:
  ./setup_macos.sh ~/Documents/OSCP_Vault"
fi

# realpath is not built into older macOS; use python3 as fallback
if command -v realpath >/dev/null 2>&1; then
    VAULT_PATH="$(realpath -m "$1")"
else
    VAULT_PATH="$(python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "$1")"
fi

echo "Target vault: $VAULT_PATH"

# ─── Prerequisites ───────────────────────────────────────────────────────────
step "Checking prerequisites"

command -v git  >/dev/null 2>&1 || fail "git is not installed. Run 'xcode-select --install' and re-run."
command -v curl >/dev/null 2>&1 || fail "curl is not installed. Install it and re-run."

ok "git:  $(git --version)"
ok "curl: $(curl --version | head -1)"

# ─── Install Obsidian ────────────────────────────────────────────────────────
step "Installing Obsidian"

OBSIDIAN_APP="/Applications/Obsidian.app"

if [[ -d "$OBSIDIAN_APP" ]]; then
    ok "Obsidian already installed at $OBSIDIAN_APP — skipping"
else
    INSTALLED=false

    # Attempt 1: Homebrew cask (preferred on macOS)
    if command -v brew >/dev/null 2>&1; then
        echo "  Trying Homebrew..."
        if brew install --cask obsidian 2>/dev/null; then
            ok "Obsidian installed via Homebrew"
            INSTALLED=true
        else
            warn "brew install --cask obsidian failed — trying DMG download"
        fi
    else
        warn "Homebrew not found. Install it from https://brew.sh for easier future setups."
    fi

    # Attempt 2: Download DMG from GitHub releases
    if [[ "$INSTALLED" == false ]]; then
        echo "  Fetching latest Obsidian DMG from GitHub releases..."
        API_URL="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"

        # Extract the macOS .dmg URL (arm64 preferred, then universal/x86_64)
        RELEASE_JSON=$(curl -fsSL "$API_URL" -H "User-Agent: obsidian-setup-script/1.0")
        DMG_URL=$(echo "$RELEASE_JSON" \
            | grep -oE '"browser_download_url":"[^"]+-arm64\.dmg"' \
            | grep -oE 'https://[^"]+' \
            | head -1)

        if [[ -z "$DMG_URL" ]]; then
            DMG_URL=$(echo "$RELEASE_JSON" \
                | grep -oE '"browser_download_url":"[^"]+\.dmg"' \
                | grep -oE 'https://[^"]+' \
                | head -1)
        fi

        if [[ -n "$DMG_URL" ]]; then
            TMP_DMG="$(mktemp /tmp/Obsidian-XXXXXX.dmg)"
            echo "  Downloading: $DMG_URL"
            curl -fsSL -o "$TMP_DMG" "$DMG_URL"

            echo "  Mounting DMG..."
            MOUNT_POINT="$(mktemp -d /tmp/obsidian_mount_XXXXXX)"
            hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -quiet -nobrowse

            echo "  Copying Obsidian.app to /Applications/..."
            cp -R "$MOUNT_POINT/Obsidian.app" /Applications/

            hdiutil detach "$MOUNT_POINT" -quiet
            rm -f "$TMP_DMG"
            rmdir "$MOUNT_POINT" 2>/dev/null || true

            ok "Obsidian installed from DMG"
            INSTALLED=true
        else
            warn "Could not find macOS DMG in latest release."
            warn "Download Obsidian manually from https://obsidian.md/download and re-run."
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

# Helper: write file only if missing
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

# ─── Sparse-clone only the Templates/ folder from repo ───────────────────────
step "Cloning Templates/ folder from 801labs/OSCP_templates"

REPO_URL="https://github.com/801labs/OSCP_templates.git"
TMP_CLONE="$(mktemp -d /tmp/oscp_templates_XXXXXX)"

if git clone --depth 1 --filter=blob:none --sparse --quiet "$REPO_URL" "$TMP_CLONE" 2>/dev/null \
    && git -C "$TMP_CLONE" sparse-checkout set Templates 2>/dev/null; then
    # Copy the Templates/ subdirectory into the vault root as Templates/
    if [[ -d "$TMP_CLONE/Templates" ]]; then
        mkdir -p "$VAULT_PATH/Templates"
        rsync -a "$TMP_CLONE/Templates/" "$VAULT_PATH/Templates/"
        ok "Templates/ copied to vault root"
    else
        warn "Templates/ folder not found in repo after sparse checkout"
    fi
else
    warn "Could not clone repository. Manually copy the Templates/ folder from $REPO_URL into $VAULT_PATH/Templates"
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
