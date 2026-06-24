# 모델 카탈로그 · 선택 · 전환 (config/models.json)
$ErrorActionPreference = "Stop"

function Get-LlmGatewayRepo {
    param([string]$ScriptsDir = $PSScriptRoot)
    return (Resolve-Path (Join-Path $ScriptsDir "..")).Path
}

function Get-LlmStackRoot {
    param([string]$ScriptsDir = $PSScriptRoot)
    $gatewayRepo = Get-LlmGatewayRepo -ScriptsDir $ScriptsDir
    $parentLlm = Join-Path $gatewayRepo ".." | Resolve-Path -ErrorAction SilentlyContinue
    if ($parentLlm -and (Test-Path (Join-Path $parentLlm.Path "docker-compose.yml"))) {
        return $parentLlm.Path
    }
    return $gatewayRepo
}

function Get-LlmModelsConfigPath {
    return Join-Path (Get-LlmGatewayRepo) "config\models.json"
}

function Get-LlmActiveModelPath {
    $local = Join-Path (Get-LlmGatewayRepo) "config\active-model.local.json"
    if (Test-Path $local) { return $local }
    return Join-Path (Get-LlmGatewayRepo) "config\active-model.json"
}

function Get-LlmModelfilesDir {
    $dir = Join-Path (Get-LlmGatewayRepo) "modelfiles"
    if (Test-Path $dir) { return $dir }
    return (Get-LlmStackRoot)
}

function Get-LlmModelCatalog {
    $path = Get-LlmModelsConfigPath
    if (-not (Test-Path $path)) {
        throw "models.json 없음: $path"
    }
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-LlmModel {
    param([string]$Selector)
    $catalog = Get-LlmModelCatalog
    if (-not $Selector) {
        $Selector = $catalog.default
    }
    $key = $Selector.Trim()
    if ($catalog.models.PSObject.Properties.Name -contains $key) {
        $entry = $catalog.models.$key
        return [pscustomobject]@{
            Alias      = $key
            Name       = $entry.name
            Label      = $entry.label
            Pull       = $entry.pull
            Modelfile  = $entry.modelfile
            Device     = $entry.device
            RimTalk    = [bool]$entry.rimtalk
            Entry      = $entry
        }
    }
    foreach ($prop in $catalog.models.PSObject.Properties) {
        $m = $prop.Value
        if ($m.name -eq $key -or "$($m.name):latest" -eq $key) {
            return [pscustomobject]@{
                Alias      = $prop.Name
                Name       = $m.name
                Label      = $m.label
                Pull       = $m.pull
                Modelfile  = $m.modelfile
                Device     = $m.device
                RimTalk    = [bool]$m.rimtalk
                Entry      = $m
            }
        }
    }
    $names = ($catalog.models.PSObject.Properties | ForEach-Object {
        "$($_.Name) ($($_.Value.name))"
    }) -join ", "
    throw "알 수 없는 모델: $Selector`n사용 가능: $names"
}

function Get-LlmActiveModel {
    $path = Get-LlmActiveModelPath
    if (Test-Path $path) {
        $saved = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($saved.alias) { return Resolve-LlmModel $saved.alias }
        if ($saved.name) { return Resolve-LlmModel $saved.name }
    }
    return Resolve-LlmModel (Get-LlmModelCatalog).default
}

function Set-LlmActiveModel {
    param($Model)
    $path = Join-Path (Get-LlmGatewayRepo) "config\active-model.local.json"
    $payload = @{
        alias = $Model.Alias
        name  = $Model.Name
        saved_at = (Get-Date).ToString("o")
    }
    $payload | ConvertTo-Json | Set-Content $path -Encoding UTF8
}

function Show-LlmModels {
    $catalog = Get-LlmModelCatalog
    $active = try { Get-LlmActiveModel } catch { $null }
    $loaded = Get-LlmLoadedModelNames

    Write-Host ""
    Write-Host "별칭       Ollama 이름              장치  RimTalk  설명"
    Write-Host "--------  ----------------------  ----  -------  ----"
    foreach ($prop in $catalog.models.PSObject.Properties) {
        $m = $prop.Value
        $mark = ""
        if ($active -and $active.Alias -eq $prop.Name) { $mark += "*" }
        if ($loaded -contains $m.name) { $mark += " [loaded]" }
        $rt = if ($m.rimtalk) { "yes" } else { "no" }
        Write-Host ("{0,-8}  {1,-22}  {2,-4}  {3,-7}  {4}{5}" -f `
            $prop.Name, $m.name, $m.device, $rt, $m.label, $mark)
    }
    Write-Host ""
    Write-Host "* = 마지막 선택 · [loaded] = VRAM/RAM에 로드됨"
    Write-Host "사용: .\startup.ps1 -Model 12b"
}

function Get-LlmLoadedModelNames {
  try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/ps" -TimeoutSec 3
        if (-not $resp.models) { return @() }
        return @($resp.models | ForEach-Object { ($_.name -replace ':latest$', '') })
    } catch {
        return @()
    }
}

function Get-OllamaInstalledNames {
    try {
        $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
        if (-not $tags.models) { return @() }
        return @($tags.models | ForEach-Object { ($_.name -replace ':latest$', '') })
    } catch {
        return @()
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $FilePath @ArgumentList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    foreach ($line in @($output)) {
        $text = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.ToString() } else { "$line" }
        if ($text) { Write-Host $text }
    }
    if ($code -ne 0) {
        throw "$FilePath failed (exit $code)"
    }
}

function Invoke-DockerCompose {
    param([Parameter(Mandatory)][string[]]$ComposeArgs)
    Invoke-NativeCommand -FilePath "docker" -ArgumentList (@("compose") + $ComposeArgs)
}

function Invoke-OllamaCli {
    param([Parameter(Mandatory)][string[]]$CliArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & ollama @CliArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) {
        $msg = ($output | Out-String).Trim()
        throw "ollama $($CliArgs[0]) failed (exit $code): $msg"
    }
    return $output
}

function Invoke-LlmWarmup {
    param(
        [string]$ModelName,
        [int]$TimeoutSec = 600
    )
    $body = @{
        model   = $ModelName
        prompt  = "hi"
        stream  = $false
        options = @{ num_predict = 8 }
    } | ConvertTo-Json -Depth 4

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" `
        -Method Post -Body $body -ContentType "application/json" `
        -TimeoutSec $TimeoutSec | Out-Null
    $sw.Stop()
    Write-Host ("  warmup done ({0:n1}s)" -f $sw.Elapsed.TotalSeconds)
}

function Test-LlmModelOnGpu {
    param([string]$ModelName)
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/ps" -TimeoutSec 5
        foreach ($m in @($resp.models)) {
            $n = ($m.name -replace ':latest$', '')
            if ($n -ne $ModelName) { continue }
            if ($m.size_vram -and $m.size_vram -gt 0) { return $true }
        }
    } catch { }
    $text = Invoke-OllamaCli -CliArgs @("ps") | Out-String
    return $text -match "100% GPU"
}

function Stop-LlmLoadedModels {
    $loaded = Get-LlmLoadedModelNames
    foreach ($name in $loaded) {
        Write-Host "  unload: $name"
        Invoke-OllamaCli -CliArgs @("stop", $name) | Out-Null
    }
    if ($loaded.Count -gt 0) {
        Start-Sleep -Seconds 2
    }
}

function Set-LlmDeviceEnv {
    param([string]$Device)
    if ($Device -eq "cpu") {
        $env:OLLAMA_NUM_GPU = "0"
    } else {
        Remove-Item Env:OLLAMA_NUM_GPU -ErrorAction SilentlyContinue
    }
}

function Ensure-LlmModel {
    param($Model)
    $threads = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    if (-not $threads) { $threads = 8 }

    $installed = Get-OllamaInstalledNames
    $installedText = ($installed -join " ")

    if ($installedText -notmatch [regex]::Escape($Model.Pull)) {
        Write-Host "  pull $($Model.Pull) ..."
        Invoke-OllamaCli -CliArgs @("pull", $Model.Pull) | Out-Null
    }

    if ($installedText -notmatch [regex]::Escape($Model.Name)) {
        $mfPath = Join-Path (Get-LlmModelfilesDir) $Model.Modelfile
        if (-not (Test-Path $mfPath)) {
            throw "Modelfile 없음: $mfPath"
        }
        $tmp = Join-Path $env:TEMP "ollama-create-$($Model.Name).modelfile"
        (Get-Content $mfPath -Raw -Encoding UTF8) -replace "num_thread \d+", "num_thread $threads" |
            Set-Content $tmp -NoNewline -Encoding UTF8
        Write-Host "  create $($Model.Name) ..."
        Invoke-OllamaCli -CliArgs @("create", $Model.Name, "-f", $tmp) | Out-Null
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Switch-LlmModel {
    param(
        [string]$Selector,
        [switch]$SkipWarmup
    )
    $target = if ($Selector) { Resolve-LlmModel $Selector } else { Get-LlmActiveModel }
    $loaded = Get-LlmLoadedModelNames
    $already = $loaded -contains $target.Name

    if ($already -and $loaded.Count -eq 1) {
        $prev = Get-LlmActiveModel
        if ($prev.Name -eq $target.Name) {
            Write-Host "  이미 로드됨: $($target.Name)"
            return $target
        }
    }

    if ($loaded.Count -gt 0) {
        Write-Host "  기존 모델 언로드 ..."
        Stop-LlmLoadedModels
    }

    Set-LlmDeviceEnv $target.Device
    Ensure-LlmModel $target
    Set-LlmActiveModel $target
    Sync-LlmDockerEnv $target

    if (-not $SkipWarmup) {
        Write-Host "  warmup: $($target.Name) ..."
        Invoke-LlmWarmup -ModelName $target.Name
        if ($target.Device -eq "gpu" -and -not (Test-LlmModelOnGpu $target.Name)) {
            Write-Host "  warn: GPU offload not confirmed - check: ollama ps"
        }
    }

    return $target
}

function Sync-LlmDockerEnv {
    param($Model)
    $stackRoot = Get-LlmStackRoot
    $envFile = Join-Path $stackRoot ".env"
    $content = "DEFAULT_MODEL=$($Model.Name)`n"
    if ((Test-Path $envFile) -and (Get-Content $envFile -Raw) -eq $content) {
        return $false
    }
    Set-Content $envFile $content.TrimEnd() -Encoding UTF8
    return $true
}

function Update-LlmDockerStack {
    param(
        $Model,
        [switch]$EnvChanged
    )
    $stackRoot = Get-LlmStackRoot
    Push-Location $stackRoot
    try {
        if ($EnvChanged) {
            Invoke-DockerCompose @("up", "-d", "--build", "--remove-orphans", "--force-recreate", "open-webui")
        } else {
            Invoke-DockerCompose @("up", "-d", "--build", "--remove-orphans")
        }
    } finally {
        Pop-Location
    }
}

# 하위 호환
function Ensure-Gemma4E4bGpuModel {
    param([string]$Root = "")
    Ensure-LlmModel (Resolve-LlmModel "e4b")
}
