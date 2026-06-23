# Measure generation TPS via Ollama native API
param(
    [string]$Model = "gemma4-e4b-gpu",
    [string]$Prompt = "한국어로 인공지능에 대해 3문장으로 설명해 주세요.",
    [int]$Runs = 3,
    [switch]$SkipWarmup
)

$ErrorActionPreference = "Stop"

function Invoke-OllamaGenerate([string]$text) {
    $body = @{
        model  = $Model
        prompt = $text
        stream = $false
        options = @{}
    } | ConvertTo-Json -Depth 3

    return Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
        -Method Post -Body $body -ContentType "application/json"
}

function Format-Tps([long]$tokens, [long]$durationNs) {
    if ($durationNs -le 0) { return 0.0 }
    return [math]::Round($tokens / ($durationNs / 1e9), 2)
}

Write-Host "Model : $Model"
Write-Host "Prompt: $Prompt"
Write-Host "Runs  : $Runs"
Write-Host ""

if (-not $SkipWarmup) {
    Write-Host "[warmup] ..."
    $warm = Invoke-OllamaGenerate "hi"
    Write-Host "  gen TPS: $(Format-Tps $warm.eval_count $warm.eval_duration)"
    Write-Host ""
}

$genTpsList = @()
for ($i = 1; $i -le $Runs; $i++) {
    $r = Invoke-OllamaGenerate $Prompt
    $genTps = Format-Tps $r.eval_count $r.eval_duration
    $genTpsList += $genTps
    Write-Host "[run $i/$Runs] gen: ${genTps} tok/s | out: $($r.eval_count)"
}

$avg = [math]::Round(($genTpsList | Measure-Object -Average).Average, 2)
Write-Host ""
Write-Host "Average gen TPS: $avg"
