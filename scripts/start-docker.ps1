# Open WebUI + RimTalk gateway (Docker)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

. (Join-Path $PSScriptRoot "Set-LlmGpuEnv.ps1")

Write-Host "=== [1/3] Ollama A770 GPU ==="
Set-LlmGpuUserEnv
Set-LlmGpuSessionEnv
Restart-OllamaForGpu
Ensure-Gemma4E4bGpuModel

Write-Host "=== [2/3] Docker (Open WebUI + RimTalk gateway) ==="
docker compose up -d --build

Write-Host "=== [3/3] Waiting for Open WebUI (up to 60s) ==="
$ready = $false
for ($i = 0; $i -lt 12; $i++) {
    try {
        $code = (Invoke-WebRequest -Uri "http://127.0.0.1:3000" -UseBasicParsing -TimeoutSec 5).StatusCode
        if ($code -eq 200) { $ready = $true; break }
    } catch { Start-Sleep -Seconds 5 }
}

Write-Host ""
if ($ready) { Write-Host "Ready." } else { Write-Host "Open WebUI still starting — docker logs gemma-webui -f" }
Write-Host "  Web UI    : http://localhost:3000"
Write-Host "  Ollama    : http://localhost:11434/v1"
Write-Host "  RimTalk   : http://localhost:11435/v1"
