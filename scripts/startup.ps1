# Windows login autostart + LLM stack (Ollama GPU + Docker)
param(
    [switch]$Register,
    [switch]$Unregister,
    [switch]$Status,
    [switch]$Boot,
    [string]$Model = "",
    [switch]$ListModels,
    [switch]$SkipWarmup,
    [switch]$SkipOllama
)

$ErrorActionPreference = "Stop"
$ScriptsDir = $PSScriptRoot
$StartupScript = Join-Path $ScriptsDir "startup.ps1"
$StackScript = Join-Path $ScriptsDir "Start-LlmStack.ps1"
$StartupName = "LLM-Stack"
$LogDir = Join-Path $env:LOCALAPPDATA "LLM-Stack"
$LogFile = Join-Path $LogDir "boot.log"
$StartupFolder = [Environment]::GetFolderPath("Startup")
$LauncherPath = Join-Path $StartupFolder "$StartupName.cmd"

function Write-BootLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if (-not $Boot) { Write-Host $Message }
}

function Wait-DockerDaemon {
    param([int]$TimeoutSec = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Register-LlmStartup {
    $ps1 = (Resolve-Path $StartupScript).Path
    $content = @"
@echo off
rem LLM stack: Ollama (host GPU) + Open WebUI + RimTalk gateway
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$ps1" -Boot
"@
    Set-Content -Path $LauncherPath -Value $content -Encoding ASCII
    Write-Host "[OK] Startup registered"
    Write-Host "  $LauncherPath"
    Write-Host "  Log: $LogFile"
    Write-Host ""
    Write-Host "Unregister: .\startup.ps1 -Unregister"
}

function Unregister-LlmStartup {
    if (Test-Path $LauncherPath) {
        Remove-Item $LauncherPath -Force
        Write-Host "[OK] Startup removed: $LauncherPath"
    } else {
        Write-Host "Not registered"
    }
}

function Show-LlmStartupStatus {
    if (Test-Path $LauncherPath) {
        Write-Host "Registered: $LauncherPath"
        Get-Content $LauncherPath
    } else {
        Write-Host "Not registered"
    }
    if (Test-Path $LogFile) {
        Write-Host ""
        Write-Host "Recent log: $LogFile"
        Get-Content $LogFile -Tail 10
    }
}

if ($Register) {
    Register-LlmStartup
    exit 0
}

if ($Unregister) {
    Unregister-LlmStartup
    exit 0
}

if ($Status) {
    Show-LlmStartupStatus
    exit 0
}

if ($Boot) {
    Write-BootLog "=== boot start ==="
    Write-BootLog "Waiting for Docker Desktop ..."
    if (-not (Wait-DockerDaemon)) {
        Write-BootLog "ERROR: Docker not ready"
        exit 1
    }
    Write-BootLog "Docker ready"
}

try {
    if ($Boot) {
        & $StackScript
        Write-BootLog "=== boot complete ==="
    } else {
        & $StackScript @PSBoundParameters
    }
} catch {
    if ($Boot) {
        Write-BootLog ("ERROR: " + $_.Exception.Message)
        exit 1
    }
    throw
}
