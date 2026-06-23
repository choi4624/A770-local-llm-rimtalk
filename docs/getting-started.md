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

## Step 2 — Start Ollama on A770

```powershell
.\scripts\start-ollama-gpu.ps1
```

This script:

1. Sets user env: `OLLAMA_VULKAN=1`, `GGML_VK_VISIBLE_DEVICES=1`, `OLLAMA_HOST=0.0.0.0:11434`
2. Restarts Ollama
3. Runs `ollama pull gemma4:e4b` (downloads weights — **not in git**)
4. Creates custom model `gemma4-e4b-gpu` from `modelfiles/gemma4-e4b-gpu`

Check GPU offload:

```powershell
ollama run gemma4-e4b-gpu "hello"
# In another terminal:
ollama ps
# Expect: 100% GPU
```

Optional speed check:

```powershell
.\scripts\measure-tps.ps1 -Model gemma4-e4b-gpu
```

## Step 3 — Start Docker services

```powershell
.\scripts\start-docker.ps1
```

Or start everything in one go (Ollama + Docker):

```powershell
.\scripts\start-docker.ps1
```

`docker compose` starts:

| Service | Port | Purpose |
|---------|------|---------|
| `gemma-webui` | 3000 | Browser chat UI |
| `rimtalk-gateway` | 11435 | RimTalk OpenAI proxy |

Both containers talk to **host Ollama** via `host.docker.internal:11434`.

Gateway only:

```powershell
.\scripts\start-rimtalk-gateway.ps1
```

## Step 4 — Configure RimTalk

In RimTalk mod settings:

| Setting | Value |
|---------|-------|
| API Base URL | `http://127.0.0.1:11435/v1` |
| API Key | any string (e.g. `ollama`) |
| Model | `gemma4-e4b-gpu` |

Do **not** point RimTalk directly at `:11434` unless you can send `reasoning_effort: "none"`. Without it, Gemma 4 thinking mode adds latency and empty `content` responses are possible.

The gateway injects `reasoning_effort: "none"` automatically. See [configuration.md](configuration.md).

## Step 5 — Open WebUI (optional)

1. Open http://localhost:3000
2. Create a local account (first user = admin)
3. Default model: `gemma4-e4b-gpu`

## Daily usage

After reboot:

```powershell
# 1) Ollama on GPU (host)
.\scripts\start-ollama-gpu.ps1

# 2) Docker stacks (if not set to auto-start)
docker compose up -d
```

Stop Docker:

```powershell
docker compose down
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
