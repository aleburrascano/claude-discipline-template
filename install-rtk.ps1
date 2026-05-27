# install-rtk.ps1 — Windows PowerShell installer for RTK (Rust Token Killer)
#
# What this does (mirrors install-rtk.sh):
#   1. Detects whether the right rtk is on PATH (skips if so).
#   2. Installs via `cargo install --git https://github.com/rtk-ai/rtk`.
#   3. Runs `rtk init -g --auto-patch --hook-only` to wire the PreToolUse:Bash hook.
#   4. Verifies with `rtk gain`.

param(
    [switch]$SkipInit,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$Repo = "https://github.com/rtk-ai/rtk"

function Test-RtkCorrect {
    $cmd = Get-Command rtk -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    try {
        $help = & rtk --help 2>&1
        if ($help -match 'token') { return $true }
        & rtk gain *> $null 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

if ($Uninstall) {
    Write-Host "Uninstalling rtk..."
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        cargo uninstall rtk 2>&1 | Select-Object -First 3
        cargo uninstall rtk-registry 2>&1 | Select-Object -First 3
        cargo uninstall rtk-tui 2>&1 | Select-Object -First 3
    }
    Write-Host "Done. You may still need to manually remove the rtk hook entry from ~/.claude/settings.json."
    exit 0
}

if (Test-RtkCorrect) {
    $version = (rtk --version 2>&1 | Select-Object -First 1)
    Write-Host "[OK] rtk already installed: $version" -ForegroundColor Green
}
else {
    Write-Host "Installing rtk-ai/rtk..."
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        Write-Host "  using: cargo install --git $Repo"
        cargo install --git $Repo --force
    }
    else {
        Write-Error @"
ERROR: cargo not on PATH. Install the Rust toolchain first:
  https://rustup.rs

Then re-run this script. Alternatively, from Git Bash:
  bash install-rtk.sh
"@
        exit 1
    }

    if (-not (Test-RtkCorrect)) {
        Write-Error @"
ERROR: rtk install completed but 'rtk gain' doesn't work. Possible causes:
  - PATH doesn't include `$env:USERPROFILE\.cargo\bin. Add it to your user PATH.
  - Name collision with the Rust Type Kit 'rtk' crate. Run:
      cargo uninstall rtk
      cargo install --git $Repo --force
"@
        exit 1
    }
    Write-Host "[OK] rtk installed: $(rtk --version 2>&1 | Select-Object -First 1)" -ForegroundColor Green
}

if ($SkipInit) {
    Write-Host ""
    Write-Host "Skipping rtk init (-SkipInit). To wire RTK into Claude Code later, run:"
    Write-Host "    rtk init -g                  # full setup"
    Write-Host "    rtk init -g --hook-only      # just the PreToolUse:Bash hook"
    exit 0
}

Write-Host ""
Write-Host "Wiring rtk into ~/.claude/settings.json (PreToolUse:Bash hook)..."
Write-Host "  command: rtk init -g --auto-patch --hook-only"
try {
    rtk init -g --auto-patch --hook-only
    Write-Host "[OK] rtk wired." -ForegroundColor Green
}
catch {
    Write-Warning @"
'rtk init' returned non-zero. The binary works but the hook may not be wired.
You can manually add this to ~/.claude/settings.json under hooks.PreToolUse:
  {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "rtk hook claude"}]
  }
"@
}

Write-Host ""
Write-Host "Verify:"
Write-Host "    rtk gain          # show token-savings analytics"
Write-Host "    rtk gain --history"
