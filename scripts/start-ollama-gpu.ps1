# Ollama GPU mode — Intel Arc A770 (Vulkan)
param(
    [string]$Model = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

. (Join-Path $PSScriptRoot "Set-LlmGpuEnv.ps1")

Set-LlmGpuUserEnv
Set-LlmGpuSessionEnv
Restart-OllamaForGpu

$active = Switch-LlmModel -Selector $(if ($Model) { $Model } else { "" }) -SkipWarmup

Write-Host ""
Write-Host "준비 완료"
Write-Host "  모델 : $($active.Name)"
Write-Host "  API  : http://localhost:11434/v1"
Write-Host "  GPU  : Intel Arc A770 (Vulkan GPU1)"
Write-Host ""
Write-Host "검증: .\measure-tps.ps1 -Model $($active.Name)"
