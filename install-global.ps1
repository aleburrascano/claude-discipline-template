# install-global.ps1 — install global/ overlay into the user's ~/.claude/ (Windows native)
#
# Behavior mirrors install-global.sh:
#   - Missing in ~/.claude/         -> COPY (no prompt). "added".
#   - Identical                     -> SKIP. "identical".
#   - Differs                       -> BACKUP existing -> show diff -> prompt i/s/v/k.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GlobalSrc = Join-Path $ScriptDir "global"

if (-not (Test-Path $GlobalSrc -PathType Container)) {
    Write-Error "$GlobalSrc not found. Run this script from the claude-discipline-template repo root."
    exit 1
}

$Target = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$Timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$BackupDir = Join-Path $Target "backup-$Timestamp"

Write-Host "claude-discipline global install"
Write-Host "  source: $GlobalSrc"
Write-Host "  target: $Target"
Write-Host "  backup: $BackupDir (created on demand)"
Write-Host ""

if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target | Out-Null
}

$Added = @()
$Identical = @()
$Installed = @()
$Skipped = @()
$KeptBoth = @()

function Install-File($src, $rel) {
    $dest = Join-Path $Target $rel

    if (-not (Test-Path $dest)) {
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $src $dest
        $script:Added += $rel
        return
    }

    $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
    $destHash = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($srcHash -eq $destHash) {
        $script:Identical += $rel
        return
    }

    # Differs — show snippets + prompt
    Write-Host "=== DIFFERS: $rel" -ForegroundColor Yellow
    Write-Host "  Source (this repo, lines 1-20):"
    Get-Content $src -TotalCount 20 | ForEach-Object { Write-Host "    | $_" }
    Write-Host ""
    Write-Host "  Your version (lines 1-20):"
    Get-Content $dest -TotalCount 20 | ForEach-Object { Write-Host "    | $_" }
    Write-Host ""

    while ($true) {
        $choice = Read-Host "  [i]nstall (backup first) / [s]kip / [v]iew full diff / [k]eep both as .new"
        switch ($choice.ToLower()) {
            "i" {
                $bdest = Join-Path $BackupDir $rel
                $bdir = Split-Path -Parent $bdest
                if (-not (Test-Path $bdir)) { New-Item -ItemType Directory -Path $bdir -Force | Out-Null }
                Copy-Item $dest $bdest
                Copy-Item -Force $src $dest
                $script:Installed += $rel
                Write-Host "  -> installed; original backed up to $bdest" -ForegroundColor Green
                return
            }
            "s" {
                $script:Skipped += $rel
                Write-Host "  -> skipped"
                return
            }
            "v" {
                Compare-Object (Get-Content $dest) (Get-Content $src) -SyncWindow 5 | Format-Table -AutoSize | Out-Host
                # loop to re-prompt
            }
            "k" {
                Copy-Item -Force $src "$dest.new"
                $script:KeptBoth += "$rel (new at $dest.new)"
                Write-Host "  -> both kept; new version at $dest.new" -ForegroundColor Cyan
                return
            }
            default {
                Write-Host "  (please answer i / s / v / k)"
            }
        }
    }
    Write-Host ""
}

Write-Host "Processing files..."
Write-Host ""

# settings.json.template
$tmpl = Join-Path $GlobalSrc "settings.json.template"
if (Test-Path $tmpl) { Install-File $tmpl "settings.json.template" }

# CLAUDE.md, RTK.md
foreach ($f in @("CLAUDE.md", "RTK.md")) {
    $p = Join-Path $GlobalSrc $f
    if (Test-Path $p) { Install-File $p $f }
}

# hooks/
$hooksDir = Join-Path $GlobalSrc "hooks"
if (Test-Path $hooksDir) {
    Get-ChildItem -File -Recurse $hooksDir | ForEach-Object {
        $rel = $_.FullName.Substring($GlobalSrc.Length + 1).Replace('\', '/')
        Install-File $_.FullName $rel
    }
}

# commands/
$cmdsDir = Join-Path $GlobalSrc "commands"
if (Test-Path $cmdsDir) {
    Get-ChildItem -File -Recurse $cmdsDir | ForEach-Object {
        $rel = $_.FullName.Substring($GlobalSrc.Length + 1).Replace('\', '/')
        Install-File $_.FullName $rel
    }
}

# ---------- report ----------
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Added (didn't exist):        $($Added.Count)"
$Added | ForEach-Object { Write-Host "  + $_" }
Write-Host ""
Write-Host "Installed (overwrote):       $($Installed.Count)"
$Installed | ForEach-Object { Write-Host "  ↻ $_" }
Write-Host ""
Write-Host "Identical (no change):       $($Identical.Count)"
$Identical | ForEach-Object { Write-Host "  = $_" }
Write-Host ""
Write-Host "Skipped (you said no):       $($Skipped.Count)"
$Skipped | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Kept both as .new:           $($KeptBoth.Count)"
$KeptBoth | ForEach-Object { Write-Host "  ± $_" }
Write-Host ""

if ($Installed.Count -gt 0) {
    Write-Host "Backups of overwritten files: $BackupDir"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. If you don't have ~/.claude/settings.json yet:"
Write-Host "       Copy-Item `$env:USERPROFILE\.claude\settings.json.template `$env:USERPROFILE\.claude\settings.json"
Write-Host "     Otherwise: open both, merge the 'hooks' section into your existing settings.json."
Write-Host ""
Write-Host "  2. Validate the hooks (from Git Bash or WSL):"
Write-Host "       bash ~/.claude/hooks/test-claim-audit.sh"
Write-Host "       bash ~/.claude/hooks/test-langcheck.sh"
Write-Host ""
Write-Host "  3. Optional: install the bootstrap plugin:"
Write-Host "       /plugin marketplace add aleburrascano/claude-discipline-template"
Write-Host "       /plugin install bootstrap@aleburrascano/claude-discipline-template"
