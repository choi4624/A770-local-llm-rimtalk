# LLM 스택 통합 기동 — 호스트 Ollama(A770) + Docker(Open WebUI + RimTalk gateway)
param(
    [switch]$SkipWarmup,
    [switch]$SkipOllama
)

$ErrorActionPreference = "Stop"

function Get-LlmStackRoot {
    param([string]$ScriptsDir = $PSScriptRoot)
    $gatewayRepo = Resolve-Path (Join-Path $ScriptsDir "..")
    $parentLlm = Join-Path $gatewayRepo ".." | Resolve-Path -ErrorAction SilentlyContinue
    if ($parentLlm -and (Test-Path (Join-Path $parentLlm "docker-compose.yml"))) {
        return $parentLlm.Path
    }
    return $gatewayRepo.Path
}

$Root = Get-LlmStackRoot
Set-Location $Root

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

$gpuEnv = Join-Path $Root "Set-LlmGpuEnv.ps1"
if (-not (Test-Path $gpuEnv)) {
    $gpuEnv = Join-Path $PSScriptRoot "Set-LlmGpuEnv.ps1"
}
. $gpuEnv

function Wait-OllamaApi {
    param([int]$TimeoutSec = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3 | Out-Null
            return $true
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Remove-LegacyDockerProjects {
    $legacyCompose = Join-Path $Root "rimtalk-gateway\docker-compose.yml"
    if ((Split-Path $Root -Leaf) -ne "rimtalk-gateway" -and (Test-Path $legacyCompose)) {
        Write-Host "  legacy rimtalk-gateway 프로젝트 정리 ..."
        docker compose -f $legacyCompose -p rimtalk-gateway down --remove-orphans 2>$null
    }
}

if (-not $SkipOllama) {
    Write-Host "=== [1/4] 호스트 Ollama (A770 Vulkan) ==="
    Set-LlmGpuUserEnv
    Set-LlmGpuSessionEnv
    Restart-OllamaForGpu
    Ensure-Gemma4E4bGpuModel -Root $Root

    Write-Host "  Ollama API 대기 ..."
    if (-not (Wait-OllamaApi)) {
        throw "Ollama API(11434)가 응답하지 않습니다."
    }
    Write-Host "  Ollama 준비 완료"
} else {
    Write-Host "=== [1/4] Ollama 시작 건너뜀 (-SkipOllama) ==="
}

if (-not $SkipWarmup) {
    Write-Host "=== [2/4] 모델 워밍업 (gemma4-e4b-gpu) ==="
    $null = "hi" | ollama run gemma4-e4b-gpu 2>&1
    $ps = ollama ps 2>&1 | Out-String
    if ($ps -notmatch "100% GPU") {
        Write-Host "  경고: GPU 오프로드 미확인 — ollama ps 로 확인하세요"
    } else {
        Write-Host "  GPU 워밍업 완료"
    }
} else {
    Write-Host "=== [2/4] 워밍업 건너뜀 (-SkipWarmup) ==="
}

Write-Host "=== [3/4] Docker 스택 (llm) ==="
Remove-LegacyDockerProjects
docker compose up -d --build --remove-orphans

Write-Host "=== [4/4] 서비스 대기 ==="
$webReady = $false
for ($i = 0; $i -lt 12; $i++) {
    try {
        $code = (Invoke-WebRequest -Uri "http://127.0.0.1:3000" -UseBasicParsing -TimeoutSec 5).StatusCode
        if ($code -eq 200) { $webReady = $true; break }
    } catch { Start-Sleep -Seconds 5 }
}

$gwReady = $false
for ($i = 0; $i -lt 6; $i++) {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:11435/v1/models" -TimeoutSec 5 | Out-Null
        $gwReady = $true
        break
    } catch { Start-Sleep -Seconds 3 }
}

Write-Host ""
if ($webReady -and $gwReady) {
    Write-Host "준비 완료 (프로젝트: llm)"
} else {
    Write-Host "일부 서비스 기동 중 — docker compose -p llm ps"
}
Write-Host "  웹 채팅   : http://localhost:3000"
Write-Host "  Ollama    : http://localhost:11434/v1"
Write-Host "  RimTalk   : http://localhost:11435/v1"
Write-Host "  기본 모델 : gemma4-e4b-gpu"
Write-Host ""
Write-Host "중지: docker compose -p llm down"
