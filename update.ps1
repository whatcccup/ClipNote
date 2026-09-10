#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$RepositoryRoot = $null
try {
  $RepositoryRoot = (git -C $ScriptDir rev-parse --show-toplevel 2>$null).Trim().Replace('/', '\')
} catch {}
if (-not $RepositoryRoot -or $RepositoryRoot -ne $ScriptDir) {
  Write-Host "Error: update.ps1 must be run from a Git clone of Obsidian Web Clipper CN - Transcript." -ForegroundColor Red
  Write-Host "Download or clone the latest source, then run .\install.ps1 -Yes."
  exit 1
}

$LocalChanges = git -C $ScriptDir status --porcelain
if ($LocalChanges) {
  Write-Host "Error: local source changes were found. Commit or remove them before updating." -ForegroundColor Red
  exit 1
}

Write-Host "Downloading the latest Obsidian Web Clipper CN - Transcript source..."
git -C $ScriptDir pull --ff-only
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Installing the updated extension and Helper..."
& (Join-Path $ScriptDir 'install.ps1') -Yes
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Obsidian Web Clipper CN - Transcript update completed."
Write-Host "Open chrome://extensions and click Reload on the existing extension."
