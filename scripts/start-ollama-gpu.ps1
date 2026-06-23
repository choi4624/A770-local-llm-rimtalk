# Start Ollama on Intel Arc A770 (Vulkan)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

. (Join-Path $PSScriptRoot "Set-LlmGpuEnv.ps1")
Set-LlmGpuUserEnv
Set-LlmGpuSessionEnv

Write-Host "Restarting Ollama (A770 Vulkan, GPU index 1) ..."
Restart-OllamaForGpu
Ensure-Gemma4E4bGpuModel

Write-Host ""
Write-Host "Ready"
Write-Host "  Model : gemma4-e4b-gpu"
Write-Host "  API   : http://localhost:11434/v1"
Write-Host "  RimTalk gateway: run scripts/start-docker.ps1 then use :11435/v1"
