#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstraps an Obsidian workspace with OSCP/AD templates and required plugins.

.DESCRIPTION
    This script:
      - Installs Obsidian (via winget if available, else direct GitHub download)
      - Creates the specified vault directory
      - Clones 801labs/OSCP_templates repo contents (no .git history) into the vault
      - Creates a 'Pentests' folder
      - Downloads and installs all required community plugins from GitHub releases
      - Writes all plugin configuration files matching the reference .obsidian setup

.PARAMETER WorkspacePath
    Required. Absolute or relative path where the Obsidian vault will be created.

.EXAMPLE
    .\setup_windows.ps1 -WorkspacePath "C:\Users\YourName\Documents\OSCP_Vault"
    .\setup_windows.ps1 "C:\Users\YourName\Documents\OSCP_Vault"
#>

param(
    [Parameter(Position = 0)]
    [string]$WorkspacePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Helpers ────────────────────────────────────────────────────────────────
function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Fail {
    param([string]$Msg)
    Write-Host "`n[ERROR] $Msg" -ForegroundColor Red
    exit 1
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing `
        -Headers @{ "User-Agent" = "obsidian-setup-script/1.0" }
}

# ─── Validate argument ───────────────────────────────────────────────────────
if (-not $WorkspacePath -or $WorkspacePath.Trim() -eq "") {
    Write-Fail @"
WorkspacePath argument is required.

Usage:
  .\setup_windows.ps1 -WorkspacePath <path>

Example:
  .\setup_windows.ps1 -WorkspacePath "C:\Users\YourName\Documents\OSCP_Vault"
"@
}

# Resolve to absolute path (does not require the path to exist yet)
$WorkspacePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkspacePath)
Write-Host "Target vault: $WorkspacePath" -ForegroundColor White

# ─── Prerequisites ───────────────────────────────────────────────────────────
Write-Step "Checking prerequisites"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail "git is not installed. Install it from https://git-scm.com/ and re-run."
}
Write-OK "git found: $(git --version)"

# ─── Install Obsidian ────────────────────────────────────────────────────────
Write-Step "Installing Obsidian"

$obsidianExePaths = @(
    "$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
    "$env:PROGRAMFILES\Obsidian\Obsidian.exe",
    "${env:PROGRAMFILES(X86)}\Obsidian\Obsidian.exe"
)

$alreadyInstalled = $obsidianExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($alreadyInstalled) {
    Write-OK "Obsidian already installed at $alreadyInstalled — skipping"
} else {
    $installed = $false

    # Attempt 1: winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Trying winget..." -ForegroundColor Gray
        try {
            winget install --id Obsidian.Obsidian --silent `
                --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            Write-OK "Obsidian installed via winget"
            $installed = $true
        } catch {
            Write-Warn "winget failed: $_ — falling back to direct download"
        }
    }

    # Attempt 2: GitHub releases direct download
    if (-not $installed) {
        Write-Host "  Fetching latest Obsidian release from GitHub..." -ForegroundColor Gray
        try {
            $apiUrl  = "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
            $release = Invoke-RestMethod -Uri $apiUrl `
                -Headers @{ "User-Agent" = "obsidian-setup-script/1.0" }
            $asset   = $release.assets |
                       Where-Object { $_.name -match "^Obsidian.*\.exe$" } |
                       Select-Object -First 1

            if (-not $asset) { throw "No Windows .exe asset found in release" }

            $installer = Join-Path $env:TEMP "ObsidianSetup.exe"
            Write-Host "  Downloading $($asset.name)..." -ForegroundColor Gray
            Download-File -Uri $asset.browser_download_url -OutFile $installer

            Write-Host "  Running installer silently..." -ForegroundColor Gray
            Start-Process -FilePath $installer -ArgumentList "/S" -Wait
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
            Write-OK "Obsidian installed"
        } catch {
            Write-Warn @"
Could not auto-install Obsidian: $_
Please install it manually from https://obsidian.md/download, then re-run this script.
The rest of setup (vault creation, plugins, config) will continue.
"@
        }
    }
}

# ─── Create vault directory ──────────────────────────────────────────────────
Write-Step "Creating vault directory"

if (-not (Test-Path $WorkspacePath)) {
    New-Item -ItemType Directory -Path $WorkspacePath -Force | Out-Null
    Write-OK "Created $WorkspacePath"
} else {
    Write-OK "Directory already exists — reusing"
}

# ─── Create .obsidian structure ──────────────────────────────────────────────
Write-Step "Writing .obsidian configuration"

$obsDir     = Join-Path $WorkspacePath ".obsidian"
$pluginsDir = Join-Path $obsDir "plugins"

foreach ($dir in @($obsDir, $pluginsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# app.json
@'
{
  "attachmentFolderPath": "Images",
  "spellcheck": true,
  "strictLineBreaks": false
}
'@ | Set-Content -Path (Join-Path $obsDir "app.json") -Encoding UTF8

# appearance.json
@'
{
  "accentColor": "",
  "baseFontSize": 17
}
'@ | Set-Content -Path (Join-Path $obsDir "appearance.json") -Encoding UTF8

# community-plugins.json  (lists enabled plugins; order matches reference config)
@'
[
  "templater-obsidian",
  "obsidian-git",
  "obsidian-meta-bind-plugin",
  "vconsole",
  "js-engine",
  "dataview"
]
'@ | Set-Content -Path (Join-Path $obsDir "community-plugins.json") -Encoding UTF8

# core-plugins.json
@'
{
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
}
'@ | Set-Content -Path (Join-Path $obsDir "core-plugins.json") -Encoding UTF8

# hotkeys.json  (reproduced from reference vault)
@'
{
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
}
'@ | Set-Content -Path (Join-Path $obsDir "hotkeys.json") -Encoding UTF8

# templates.json  (core Templates plugin folder setting)
@'
{
  "folder": "Templates"
}
'@ | Set-Content -Path (Join-Path $obsDir "templates.json") -Encoding UTF8

Write-OK "All .obsidian config files written"

# ─── Clone repo (no .git metadata) ──────────────────────────────────────────
Write-Step "Cloning 801labs/OSCP_templates (shallow, no .git)"

$repoUrl  = "https://github.com/801labs/OSCP_templates.git"
$tmpClone = Join-Path $env:TEMP "oscp_templates_$(Get-Random)"

try {
    git clone --depth 1 --quiet $repoUrl $tmpClone

    # Copy everything except the .git directory into vault/Templates/
    $templatesDir = Join-Path $WorkspacePath "Templates"
    if (-not (Test-Path $templatesDir)) {
        New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
    }
    Get-ChildItem -Path $tmpClone -Force |
        Where-Object { $_.Name -ne ".git" } |
        ForEach-Object {
            $dest = Join-Path $templatesDir $_.Name
            if ($_.PSIsContainer) {
                Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
            } else {
                Copy-Item -Path $_.FullName -Destination $dest -Force
            }
        }
    Write-OK "Repository content copied to vault/Templates/"
} catch {
    Write-Warn "Could not clone repository: $_`nManually clone https://github.com/801labs/OSCP_templates into $WorkspacePath\Templates"
} finally {
    if (Test-Path $tmpClone) {
        Remove-Item $tmpClone -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ─── Create Pentests folder ──────────────────────────────────────────────────
Write-Step "Creating Pentests folder"

$pentestsDir = Join-Path $WorkspacePath "Pentests"
if (-not (Test-Path $pentestsDir)) {
    New-Item -ItemType Directory -Path $pentestsDir -Force | Out-Null
    Write-OK "Created Pentests/"
} else {
    Write-OK "Pentests/ already exists"
}

# ─── Create Images folder (attachment target) ────────────────────────────────
$imagesDir = Join-Path $WorkspacePath "Images"
if (-not (Test-Path $imagesDir)) {
    New-Item -ItemType Directory -Path $imagesDir -Force | Out-Null
}

# ─── Download and install community plugins ──────────────────────────────────
Write-Step "Downloading community plugins from GitHub releases"

# Each entry: id = Obsidian plugin ID, repo = GitHub owner/repo
$plugins = @(
    [PSCustomObject]@{ id = "templater-obsidian";          repo = "SilentVoid13/Templater" },
    [PSCustomObject]@{ id = "obsidian-git";                repo = "Vinzent03/obsidian-git" },
    [PSCustomObject]@{ id = "obsidian-meta-bind-plugin";   repo = "mProjectsCode/obsidian-meta-bind-plugin" },
    [PSCustomObject]@{ id = "vconsole";                    repo = "zhouhua/obsidian-vconsole" },
    [PSCustomObject]@{ id = "js-engine";                   repo = "mProjectsCode/obsidian-js-engine-plugin" },
    [PSCustomObject]@{ id = "dataview";                    repo = "blacksmithgu/obsidian-dataview" }
)

foreach ($p in $plugins) {
    $pluginDir = Join-Path $pluginsDir $p.id
    if (-not (Test-Path $pluginDir)) {
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
    }

    $base = "https://github.com/$($p.repo)/releases/latest/download"
    Write-Host "  $($p.id) ..." -ForegroundColor Gray

    # main.js — required; abort this plugin if it fails
    try {
        Download-File -Uri "$base/main.js" -OutFile (Join-Path $pluginDir "main.js")
    } catch {
        Write-Warn "  Failed to download main.js for $($p.id) — skipping plugin"
        continue
    }

    # manifest.json — required
    try {
        Download-File -Uri "$base/manifest.json" -OutFile (Join-Path $pluginDir "manifest.json")
    } catch {
        Write-Warn "  Failed to download manifest.json for $($p.id)"
    }

    # styles.css — optional; silently skip 404s
    try {
        Download-File -Uri "$base/styles.css" -OutFile (Join-Path $pluginDir "styles.css") `
            -ErrorAction SilentlyContinue 2>$null
    } catch { <# optional — ignore #> }

    Write-OK $p.id
}

# ─── Write plugin data.json configs ─────────────────────────────────────────
Write-Step "Writing plugin configurations"

# templater-obsidian/data.json
@'
{
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
}
'@ | Set-Content -Path (Join-Path $pluginsDir "templater-obsidian\data.json") -Encoding UTF8
Write-OK "Templater: trigger_on_file_creation=true, folder_templates=[Pentests→Templates/Scope.md]"

# obsidian-git/data.json
@'
{
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
}
'@ | Set-Content -Path (Join-Path $pluginsDir "obsidian-git\data.json") -Encoding UTF8
Write-OK "Git: autoPullOnBoot=true, pullBeforePush=true"

# obsidian-meta-bind-plugin/data.json
@'
{
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
}
'@ | Set-Content -Path (Join-Path $pluginsDir "obsidian-meta-bind-plugin\data.json") -Encoding UTF8
Write-OK "Meta Bind: enableJs=true, enableEditorRightClickMenu=true, enableSyntaxHighlighting=true"

# dataview/data.json
@'
{
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
}
'@ | Set-Content -Path (Join-Path $pluginsDir "dataview\data.json") -Encoding UTF8
Write-OK "Dataview configured"

# js-engine and vconsole have no custom data.json in the reference config

# ─── Done ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Vault ready!" -ForegroundColor Green
Write-Host "  $WorkspacePath" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open Obsidian → 'Open folder as vault' → select the path above" -ForegroundColor Gray
Write-Host "  2. Settings → Community plugins → Enable safe mode OFF, then enable each plugin" -ForegroundColor Gray
Write-Host "  3. To track the vault with git, run 'git init' inside the vault folder" -ForegroundColor Gray
Write-Host "     and set a remote if desired." -ForegroundColor Gray
Write-Host ""
