# A770 LLM GPU profile (B580=display, A770=LLM, iGPU excluded)
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "LlmModels.ps1")

$script:A770VulkanIndex = "1"

function Get-RepoRoot {
    return (Get-LlmGatewayRepo -ScriptsDir $PSScriptRoot)
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
