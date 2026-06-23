# A770 LLM GPU profile (B580=display, A770=LLM, iGPU excluded)
$ErrorActionPreference = "Stop"

# vulkaninfo --summary:
#   GPU0 = Intel Arc B580 (display / games)
#   GPU1 = Intel Arc A770 (LLM)
#   GPU2 = Intel UHD iGPU (unused)
$script:A770VulkanIndex = "1"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Set-LlmGpuUserEnv {
    [System.Environment]::SetEnvironmentVariable("OLLAMA_VULKAN", "1", "User")
    [System.Environment]::SetEnvironmentVariable("GGML_VK_VISIBLE_DEVICES", $script:A770VulkanIndex, "User")
    [System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
    [System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", $null, "User")
    [System.Environment]::SetEnvironmentVariable("OLLAMA_IGPU_ENABLE", $null, "User")
}

function Set-LlmGpuSessionEnv {
    $env:OLLAMA_VULKAN = "1"
    $env:GGML_VK_VISIBLE_DEVICES = $script:A770VulkanIndex
    $env:OLLAMA_HOST = "0.0.0.0:11434"
    Remove-Item Env:OLLAMA_NUM_GPU -ErrorAction SilentlyContinue
    Remove-Item Env:OLLAMA_IGPU_ENABLE -ErrorAction SilentlyContinue
}

function Restart-OllamaForGpu {
    Get-Process ollama, "ollama app" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3

    $ollamaApp = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama app.exe"
    if (Test-Path $ollamaApp) {
        Start-Process $ollamaApp
    } else {
        Start-Process "ollama" -ArgumentList "serve"
    }
    Start-Sleep -Seconds 5
}

function Ensure-Gemma4E4bGpuModel {
    param(
        [string]$ModelfilesDir = (Join-Path (Get-RepoRoot) "modelfiles")
    )

    if (-not (ollama list 2>$null | Select-String "gemma4:e4b")) {
        Write-Host "Pulling gemma4:e4b (~9.6GB, not stored in this repo) ..."
        ollama pull gemma4:e4b
    }

    if (-not (ollama list 2>$null | Select-String "gemma4-e4b-gpu")) {
        $threads = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        if (-not $threads) { $threads = 8 }
        $mf = Join-Path $ModelfilesDir "gemma4-e4b-gpu"
        (Get-Content $mf -Raw) -replace "num_thread \d+", "num_thread $threads" | Set-Content $mf -NoNewline
        ollama create gemma4-e4b-gpu -f $mf
    }
}
