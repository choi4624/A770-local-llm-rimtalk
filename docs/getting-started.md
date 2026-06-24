# Getting started

Local LLM stack for **RimWorld + RimTalk**, **Open WebUI**, and **Gemma 4 e4b** on Intel Arc **A770** (16GB VRAM).

> This repo does **not** include model weights. You download them with `ollama pull` on first run (~9.6GB for `gemma4:e4b`).

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Windows 10/11 | Tested on Windows with PowerShell |
| [Ollama](https://ollama.com) | 0.30+ with Vulkan support |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | For Open WebUI + RimTalk gateway |
| Intel Arc **A770** 16GB | LLM GPU (`GGML_VK_VISIBLE_DEVICES=1`) |
| Intel Arc **B580** (optional) | Display / games — not used for LLM |

Verify Vulkan GPU order:

```powershell
vulkaninfo --summary
# GPU0 = B580 (display)
# GPU1 = A770 (LLM)  <- target for Ollama
```

## Step 1 — Clone and enter the repo

```powershell
git clone <your-repo-url>
cd <repo-folder>
```

## Step 2 — Start the full stack

```powershell
cd scripts
.\startup.ps1
```

This runs in order:

1. Host Ollama on A770 (`OLLAMA_VULKAN=1`, `GGML_VK_VISIBLE_DEVICES=1`)
2. `ollama pull gemma4:e4b` + create `gemma4-e4b-gpu` (first run only, ~9.6GB)
3. Model warmup on GPU
4. Docker stack `llm` (Open WebUI + rimtalk-gateway)

Verify:

```powershell
ollama ps          # 100% GPU
docker compose -p llm ps
```

Optional:

```powershell
.\startup.ps1 -SkipWarmup        # model already loaded
.\startup.ps1 -Register          # autostart on Windows login
.\scripts\measure-tps.ps1 -Model gemma4-e4b-gpu
```

Ollama only (no Docker):

```powershell
.\scripts\start-ollama-gpu.ps1
```

## Step 3 — Configure RimTalk

In RimTalk mod settings:

| Setting | Value |
|---------|-------|
| API Base URL | `http://127.0.0.1:11435/v1` |
| API Key | any string (e.g. `ollama`) |
| Model | `gemma4-e4b-gpu` |

Do **not** point RimTalk directly at `:11434` unless you can send `reasoning_effort: "none"`. Without it, Gemma 4 thinking mode adds latency and empty `content` responses are possible.

The gateway injects `reasoning_effort: "none"` automatically. See [configuration.md](configuration.md).

## Step 4 — Open WebUI (optional)

1. Open http://localhost:3000
2. Create a local account (first user = admin)
3. Default model: `gemma4-e4b-gpu`

## Daily usage

After reboot (if registered):

```powershell
# Automatic via Startup\LLM-Stack.cmd
# Requires Docker Desktop "start on login"
```

Manual:

```powershell
cd scripts
.\startup.ps1
```

Stop:

```powershell
docker compose -p llm down    # from parent D:\llm when nested
```

## Troubleshooting

### RimTalk returns empty `content` or `finish_reason: "length"`

- Use gateway URL `:11435`, not direct Ollama `:11434`
- Do not set `max_tokens` too low in `config/rimtalk-gateway.json` (thinking counts toward limit if gateway is bypassed)

### Slow responses (>30s)

- Confirm RimTalk uses **:11435** gateway
- Check `docker logs rimtalk-gateway` for `reasoning_effort=none`
- `ollama ps` should show `100% GPU` for `gemma4-e4b-gpu`

### Wrong GPU (B580 used for LLM)

Re-run `.\scripts\start-ollama-gpu.ps1` and verify `GGML_VK_VISIBLE_DEVICES=1`.

### Open WebUI not loading

```powershell
docker logs gemma-webui -f
```

First boot may download embedding models; `OFFLINE_MODE=true` is set to reduce this.

## Next steps

- [Configuration](configuration.md) — gateway rules, modelfiles, env vars
- [Intel Arc dual GPU](intel-arc-dual-gpu.md) — B580 vs A770 split
