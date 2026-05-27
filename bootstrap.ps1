# bootstrap.ps1 — Windows PowerShell version of bootstrap.sh
#
# Usage:
#   .\bootstrap.ps1 -TargetDir <path> -ProjectName "<Project Name>" [-Description "<desc>"]
#
# Example:
#   .\bootstrap.ps1 -TargetDir ..\my-cool-app -ProjectName "My Cool App" -Description "An app that does cool things."

param(
    [Parameter(Mandatory = $true)][string]$TargetDir,
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [string]$Description = "A new project bootstrapped from claude-discipline-template."
)

$ErrorActionPreference = "Stop"

# ---- compute slug ----
$slug = $ProjectName.ToLower() -replace '[^a-z0-9 _-]', '' -replace '[ _]+', '-' -replace '-+', '-' -replace '^-|-$', ''
if ([string]::IsNullOrEmpty($slug)) {
    Write-Error "Could not derive a valid slug from project name `"$ProjectName`""
    exit 1
}

# ---- locate template/ ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "template"
if (-not (Test-Path $TemplateDir -PathType Container)) {
    Write-Error "template/ not found at $TemplateDir"
    exit 1
}

# ---- validate target ----
if (Test-Path $TargetDir) {
    if ((Get-ChildItem -Force $TargetDir).Count -gt 0) {
        Write-Error "target $TargetDir exists and is not empty."
        exit 1
    }
}
else {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

$TargetAbs = (Resolve-Path $TargetDir).Path

Write-Host "Bootstrapping into: $TargetAbs"
Write-Host "  PROJECT_NAME = $ProjectName"
Write-Host "  PROJECT_NAME_SLUG = $slug"
Write-Host "  PROJECT_DESCRIPTION = $Description"
Write-Host ""

# ---- copy template ----
Write-Host "Copying template files..."
Copy-Item -Recurse -Force "$TemplateDir\*" $TargetAbs
# Copy hidden / dot files (PowerShell Copy-Item with * doesn't grab dot-prefixed by default in some shells; explicit pass):
Get-ChildItem -Path $TemplateDir -Force -Filter ".*" | ForEach-Object {
    if ($_.PSIsContainer) {
        Copy-Item -Recurse -Force $_.FullName -Destination $TargetAbs
    }
    else {
        Copy-Item -Force $_.FullName -Destination $TargetAbs
    }
}

# ---- substitute placeholders ----
Write-Host "Substituting placeholders..."
$EXTS = @('.md', '.json', '.sh', '.ts', '.tsx', '.py', '.js', '.cjs', '.toml', '.yaml', '.yml')
$count = 0
Get-ChildItem -Recurse -File -Path $TargetAbs | Where-Object {
    $EXTS -contains $_.Extension -and ($_.FullName -notlike "*\.git\*")
} | ForEach-Object {
    try {
        $text = Get-Content -Raw -Encoding UTF8 $_.FullName
    }
    catch {
        return
    }
    $orig = $text
    $text = $text -replace '\{\{PROJECT_NAME_SLUG\}\}', $slug
    $text = $text -replace '\{\{PROJECT_NAME\}\}', $ProjectName
    $text = $text -replace '\{\{PROJECT_DESCRIPTION\}\}', $Description
    if ($text -ne $orig) {
        # Out-File adds BOM by default; use UTF8NoBOM via Set-Content
        Set-Content -Path $_.FullName -Value $text -NoNewline -Encoding utf8
        $count++
    }
}
Write-Host "  patched $count files"

# ---- git init ----
Write-Host "Initializing git repo..."
Set-Location $TargetAbs
try { git init -b main *> $null } catch { git init *> $null }

# ---- next steps ----
Write-Host ""
Write-Host "[OK] Bootstrap complete."
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "  cd `"$TargetAbs`""
Write-Host ""
Write-Host "  # 1. Set git identity if needed:"
Write-Host "  git config user.name `"Your Name`""
Write-Host "  git config user.email `"you@example.com`""
Write-Host ""
Write-Host "  # 2. Configure your stack:"
Write-Host "  #    - Replace docs\architecture.md template content with your actual architecture"
Write-Host "  #    - Write ADR-0001 documenting your foundational layer/pattern choice"
Write-Host "  #    - Add language-specific rules to .claude\rules\ (e.g., typescript.md, python.md)"
Write-Host "  #      with 'paths:' frontmatter"
Write-Host "  #    - Wire stack-specific commands in .claude\hooks\post-tool-typecheck.sh,"
Write-Host "  #      post-tool-lint.sh, post-tool-test-changed.sh — they're TODO stubs"
Write-Host "  #    - Wire stack-specific commands in .claude\skills\verify-end-to-end\SKILL.md"
Write-Host ""
Write-Host "  # 3. Install commit hooks (when ready):"
Write-Host "  pnpm install   # or npm/yarn — installs husky's commit-msg + pre-commit"
Write-Host ""
Write-Host "  # 4. First commit:"
Write-Host "  git add -A"
Write-Host "  git commit -m `"chore(release): initial scaffold from claude-discipline-template`""
Write-Host ""
Write-Host "  # 5. Your first feature:"
Write-Host "  #    Open Claude Code in this directory, type `"let's spec out <feature>`""
Write-Host "  #    -> /feature-spec auto-fires (per .claude/skill-rules.json)"
Write-Host ""
