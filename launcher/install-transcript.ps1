#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Force = $false
foreach ($arg in $args) {
  if ($arg -eq '--force' -or $arg -eq '-Force') {
    $Force = $true
  } else {
    Write-Host "Error: unknown option: $arg" -ForegroundColor Red
    exit 1
  }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptDir
if (Test-Path (Join-Path $WorkspaceRoot 'helper')) {
  $SourceHelper = Join-Path $WorkspaceRoot 'helper'
} else {
  $SourceHelper = Join-Path $WorkspaceRoot 'transcript-helper'
}
$InstallDir = Join-Path $env:LOCALAPPDATA 'ObsidianWebClipperCNTranscript'
$HelperDir = Join-Path $InstallDir 'helper'
$LauncherDir = Join-Path $InstallDir 'launcher'
$BinDir = Join-Path $InstallDir 'bin'
$NativeDir = Join-Path $InstallDir 'native-messaging'
$HostName = 'cn.transcript.generator.launcher'
$ExtensionId = 'nkmploheccefaplolbophdngjnoncani'
$RegistryPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"

if ((Test-Path $InstallDir) -and -not $Force) {
  Write-Host "Error: an existing Transcript Helper installation was found." -ForegroundColor Red
  Write-Host "Run the repository root install.ps1 to confirm an overwrite installation."
  exit 2
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Host "Error: uv is required to prepare the local Helper runtime." -ForegroundColor Red
  exit 1
}

New-Item -ItemType Directory -Force -Path (Join-Path $HelperDir 'src'), $LauncherDir, $BinDir, (Join-Path $InstallDir 'runtime'), (Join-Path $InstallDir 'logs'), $NativeDir | Out-Null
Copy-Item (Join-Path $SourceHelper 'pyproject.toml') (Join-Path $HelperDir 'pyproject.toml') -Force
$UvLock = Join-Path $SourceHelper 'uv.lock'
if (Test-Path $UvLock) { Copy-Item $UvLock (Join-Path $HelperDir 'uv.lock') -Force }
$PackageDir = Join-Path $HelperDir 'src\transcript_helper'
if (Test-Path $PackageDir) { Remove-Item $PackageDir -Recurse -Force }
Copy-Item (Join-Path $SourceHelper 'src\transcript_helper') $PackageDir -Recurse -Force
Copy-Item (Join-Path $ScriptDir 'transcript_launcher.py') (Join-Path $LauncherDir 'transcript_launcher.py') -Force

Push-Location $HelperDir
try {
  uv sync --python 3.11
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

$Python = Join-Path $HelperDir '.venv\Scripts\python.exe'
$NodeDir = ''
$NodeCommand = Get-Command node -ErrorAction SilentlyContinue
if ($NodeCommand) { $NodeDir = Split-Path -Parent $NodeCommand.Source }

$Config = [ordered]@{
  python = $Python
  helperDir = $HelperDir
  nodeDir = $NodeDir
  port = 8484
  idleTimeoutSeconds = 900
} | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $InstallDir 'config.json'), $Config, [System.Text.UTF8Encoding]::new($false))

$LauncherBat = Join-Path $BinDir 'transcript-launcher.bat'
# Keep the batch pure ASCII and derive paths from %~dp0 so non-ASCII
# characters in the user profile path cannot be mangled by the console codepage.
$Batch = "@echo off`r`n`"%~dp0..\helper\.venv\Scripts\python.exe`" `"%~dp0..\launcher\transcript_launcher.py`"`r`n"
[System.IO.File]::WriteAllText($LauncherBat, $Batch, [System.Text.UTF8Encoding]::new($false))

$ManifestPath = Join-Path $NativeDir "$HostName.json"
$Manifest = [ordered]@{
  name = $HostName
  description = 'Transcript Generator on-demand Helper launcher'
  path = $LauncherBat
  type = 'stdio'
  allowed_origins = @("chrome-extension://$ExtensionId/")
} | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($ManifestPath, $Manifest, [System.Text.UTF8Encoding]::new($false))

New-Item -Path $RegistryPath -Force | Out-Null
Set-Item -Path $RegistryPath -Value $ManifestPath

Write-Host "Transcript Helper installed without any startup task."
Write-Host "Native host: $ManifestPath"
Write-Host "Registry: $RegistryPath"
Write-Host "Helper starts only when the browser extension requests it."
