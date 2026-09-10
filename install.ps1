#Requires -Version 5.1
param(
  [Alias('y')]
  [switch]$Yes
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
  Write-Host "Error: this installer only supports Windows. On macOS run bash install.sh instead." -ForegroundColor Red
  exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:LOCALAPPDATA 'ObsidianWebClipperCNTranscript'
$WhisperModel = 'skip'

foreach ($commandName in @('node', 'uv')) {
  if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
    Write-Host "Error: $commandName is required." -ForegroundColor Red
    exit 1
  }
}

# Avoid embedded quotes here: PowerShell 5.1 mangles them when invoking native commands.
$NodeVersion = (node --version)
$NodeMajor = [int]($NodeVersion.TrimStart('v').Split('.')[0])
if ($NodeMajor -lt 18) {
  Write-Host "Error: Node.js 18 or newer is required. Current version: $NodeVersion" -ForegroundColor Red
  exit 1
}

$HasExtensionSource = Test-Path (Join-Path $ScriptDir 'extension\package.json')
if ($HasExtensionSource -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host "Error: npm is required to build the Chrome extension from source." -ForegroundColor Red
  exit 1
}
if (-not $HasExtensionSource -and -not (Test-Path (Join-Path $ScriptDir 'extension\dist\manifest.json'))) {
  Write-Host "Error: Chrome extension source or a prebuilt extension/dist directory is required." -ForegroundColor Red
  exit 1
}

if (Test-Path $InstallDir) {
  Write-Host "Existing Transcript Helper installation detected: $InstallDir"
  Write-Host "The Helper and Launcher program files will be overwritten."
  Write-Host "Browser settings, Cookies, templates, local models, and transcript cache will be preserved."
  if (-not $Yes) {
    if ([Console]::IsInputRedirected) {
      Write-Host "Error: interactive confirmation is required. Rerun with -Yes to confirm." -ForegroundColor Red
      exit 1
    }
    $reply = Read-Host "Continue with overwrite installation? [y/N]"
    if ($reply -notmatch '^(y|Y|yes|YES)$') {
      Write-Host "Installation cancelled."
      exit 0
    }
  }
}

function Choose-WhisperModel {
  if ($Yes -or [Console]::IsInputRedirected) {
    Write-Host "Skipping Whisper model download. You can download a model later in the extension settings."
    $script:WhisperModel = 'skip'
    return
  }

  Write-Host ""
  Write-Host "Choose a Faster Whisper model to download now:"
  Write-Host "  1) tiny (recommended; extension default)"
  Write-Host "  2) Skip (download later in the extension settings)"
  Write-Host "  3) base"
  Write-Host "  4) small"
  Write-Host "  5) medium"
  Write-Host "  6) large-v3"
  Write-Host "  7) large-v3-turbo"
  while ($true) {
    $choice = Read-Host "Select [1-7, default 1]"
    switch ($choice) {
      { $_ -in @('', '1') } { $script:WhisperModel = 'tiny'; return }
      '2' { $script:WhisperModel = 'skip'; return }
      '3' { $script:WhisperModel = 'base'; return }
      '4' { $script:WhisperModel = 'small'; return }
      '5' { $script:WhisperModel = 'medium'; return }
      '6' { $script:WhisperModel = 'large-v3'; return }
      '7' { $script:WhisperModel = 'large-v3-turbo'; return }
      default { Write-Host "Please enter a number from 1 to 7." }
    }
  }
}

Choose-WhisperModel

if ($HasExtensionSource) {
  Write-Host "Building the Chrome extension..."
  Push-Location (Join-Path $ScriptDir 'extension')
  try {
    npm install
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    npm run build:chrome
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
} else {
  Write-Host "Using the prebuilt Chrome extension from extension/dist."
}

Write-Host "Installing the on-demand Transcript Helper..."
& (Join-Path $ScriptDir 'launcher\install-transcript.ps1') -Force
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($WhisperModel -ne 'skip') {
  Write-Host "Downloading Faster Whisper model: $WhisperModel"
  $HelperPython = Join-Path $InstallDir 'helper\.venv\Scripts\python.exe'
  & $HelperPython -c "from pathlib import Path; import sys; from transcript_helper.models import WhisperModelManager; WhisperModelManager(Path.home() / '.cache' / 'obsidian-web-clipper-cn-transcript' / 'models').download(sys.argv[1])" $WhisperModel
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Faster Whisper model installed: $WhisperModel"
    Write-Host "After loading the extension, select the same model in Settings > Transcript Generator."
  } else {
    Write-Host "Warning: model download failed. The extension and Helper are installed; retry from the extension settings." -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Obsidian Web Clipper CN - Transcript installation completed."
Write-Host "Chrome extension directory: $ScriptDir\extension\dist"
Write-Host "Open chrome://extensions and load or reload that directory."
Write-Host "No startup task was created. The Helper starts only when requested by the extension."
