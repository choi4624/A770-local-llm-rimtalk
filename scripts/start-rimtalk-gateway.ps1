# RimTalk gateway only (Docker)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

docker compose up -d --build rimtalk-gateway

Write-Host ""
Write-Host "RimTalk gateway: http://127.0.0.1:11435/v1"
Write-Host "Config: config/rimtalk-gateway.json"
Write-Host "Logs  : docker logs rimtalk-gateway -f"
