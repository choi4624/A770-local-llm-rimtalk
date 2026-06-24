# LLM 스택 통합 기동 — 호스트 Ollama(A770) + Docker(Open WebUI + RimTalk gateway)
param(
    [string]$Model = "",
    [switch]$ListModels,
    [switch]$SkipWarmup,
    [switch]$SkipOllama
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "LlmModels.ps1")

$Root = Get-LlmStackRoot
Set-Location $Root

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

$gpuEnv = Join-Path $Root "Set-LlmGpuEnv.ps1"
if (-not (Test-Path $gpuEnv)) {
    $gpuEnv = Join-Path $PSScriptRoot "Set-LlmGpuEnv.ps1"
}
. $gpuEnv

if ($ListModels) {
    Show-LlmModels
    exit 0
}

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
        Write-Host "  legacy rimtalk-gateway cleanup ..."
        Invoke-DockerCompose @("-f", $legacyCompose, "-p", "rimtalk-gateway", "down", "--remove-orphans")
    }
}

$selected = $null
$envChanged = $false

if (-not $SkipOllama) {
    Write-Host "=== [1/4] 호스트 Ollama (A770 Vulkan) ==="
    Set-LlmGpuUserEnv
    Set-LlmGpuSessionEnv
    Restart-OllamaForGpu

    Write-Host "  Ollama API 대기 ..."
    if (-not (Wait-OllamaApi)) {
        throw "Ollama API(11434)가 응답하지 않습니다."
    }
    Write-Host "  Ollama 준비 완료"
} else {
    Write-Host "=== [1/4] Ollama 시작 건너뜀 (-SkipOllama) ==="
    if (-not (Wait-OllamaApi -TimeoutSec 5)) {
        throw "Ollama가 실행 중이 아닙니다. -SkipOllama 없이 실행하세요."
    }
}

Write-Host "=== [2/4] 모델 선택 · 전환 ==="
$prev = try { Get-LlmActiveModel } catch { $null }
if ($Model) {
    $selected = Switch-LlmModel -Selector $Model -SkipWarmup:$SkipWarmup
    if ($prev -and $prev.Name -ne $selected.Name) {
        Write-Host "  전환: $($prev.Name) -> $($selected.Name)"
    }
} elseif ($SkipWarmup) {
    $selected = if ($prev) { $prev } else { Resolve-LlmModel (Get-LlmModelCatalog).default }
    Set-LlmDeviceEnv $selected.Device
    Ensure-LlmModel $selected
    $envChanged = Sync-LlmDockerEnv $selected
} else {
    $selector = if ($prev) { $prev.Alias } else { (Get-LlmModelCatalog).default }
    $selected = Switch-LlmModel -Selector $selector -SkipWarmup:$false
}

if (-not $selected) {
    $selected = Resolve-LlmModel $(if ($Model) { $Model } else { (Get-LlmModelCatalog).default })
}

Write-Host "  활성: $($selected.Name) ($($selected.Label))"

Write-Host "=== [3/4] Docker stack (llm) ==="
Remove-LegacyDockerProjects
if (-not $envChanged) {
    $envChanged = Sync-LlmDockerEnv $selected
}
if ($envChanged) {
    Invoke-DockerCompose @("up", "-d", "--build", "--remove-orphans", "--force-recreate", "open-webui")
    Invoke-DockerCompose @("up", "-d", "--build", "--remove-orphans")
} else {
    Invoke-DockerCompose @("up", "-d", "--build", "--remove-orphans")
}

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
Write-Host "  활성 모델 : $($selected.Name)"
Write-Host ""
Write-Host "모델 변경: .\startup.ps1 -Model <별칭>   (예: e2b, 12b, 26b, qwen3-8b)"
Write-Host "목록     : .\startup.ps1 -ListModels"
Write-Host "중지     : docker compose -p llm down"
