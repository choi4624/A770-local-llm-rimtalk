# Windows 로그인 시 LLM 스택 자동 기동 + 시작 프로그램 등록
param(
    [switch]$Register,
    [switch]$Unregister,
    [switch]$Status,
    [switch]$Boot,
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
    Write-Host "시작 프로그램 등록 완료"
    Write-Host "  $LauncherPath"
    Write-Host "  로그: $LogFile"
    Write-Host ""
    Write-Host "해제: .\startup.ps1 -Unregister"
}

function Unregister-LlmStartup {
    if (Test-Path $LauncherPath) {
        Remove-Item $LauncherPath -Force
        Write-Host "시작 프로그램 해제: $LauncherPath"
    } else {
        Write-Host "등록된 시작 프로그램 없음"
    }
}

function Show-LlmStartupStatus {
    if (Test-Path $LauncherPath) {
        Write-Host "등록됨: $LauncherPath"
        Get-Content $LauncherPath
    } else {
        Write-Host "미등록"
    }
    if (Test-Path $LogFile) {
        Write-Host ""
        Write-Host "최근 로그 ($LogFile):"
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
    Write-BootLog "Docker Desktop 대기 ..."
    if (-not (Wait-DockerDaemon)) {
        Write-BootLog "ERROR: Docker가 준비되지 않았습니다."
        exit 1
    }
    Write-BootLog "Docker 준비 완료"
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
        Write-BootLog "ERROR: $($_.Exception.Message)"
        exit 1
    }
    throw
}
