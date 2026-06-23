# RimWorld Local LLM Stack

Gemma 4 on **Intel Arc A770** (LLM) + **B580** (display), with **Open WebUI** and a **RimTalk gateway** that injects `reasoning_effort: "none"` for fast in-game dialogue.

This repository contains **configuration and scripts only**. Model weights are downloaded separately via Ollama (`ollama pull`).

## Architecture

```
RimTalk mod  -->  rimtalk-gateway (:11435)  -->  Ollama on host (:11434, A770 GPU)
Browser      -->  open-webui (:3000)        -->  Ollama on host (:11434)
```

| Component | URL | Notes |
|-----------|-----|-------|
| RimTalk API | `http://127.0.0.1:11435/v1` | Use this in the mod settings |
| Ollama API | `http://127.0.0.1:11434/v1` | Direct access (thinking ON by default) |
| Open WebUI | `http://localhost:3000` | Browser chat |

## Quick start

See **[docs/getting-started.md](docs/getting-started.md)** for the full walkthrough.

```powershell
git clone <your-repo-url>
cd <repo>

# 1) Host Ollama + pull weights + create gemma4-e4b-gpu
.\scripts\start-ollama-gpu.ps1

# 2) Docker: Open WebUI + RimTalk gateway
.\scripts\start-docker.ps1
```

RimTalk: set API base URL to `http://127.0.0.1:11435/v1`, model `gemma4-e4b-gpu`.

## Repository layout

```
.
├── config/                 # Gateway and runtime config (no weights)
│   └── rimtalk-gateway.json
├── modelfiles/             # Ollama Modelfile recipes (not GGUF weights)
│   ├── gemma4-e4b-gpu
│   └── gemma4-e2b-cpu
├── rimtalk-gateway/        # Docker image for RimTalk proxy
│   ├── Dockerfile
│   └── gateway.py
├── scripts/                # Windows setup helpers
├── docs/
│   ├── getting-started.md
│   ├── configuration.md
│   └── intel-arc-dual-gpu.md
└── docker-compose.yml
```

## Documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [Intel Arc dual GPU (B580 + A770)](docs/intel-arc-dual-gpu.md)

## License

Configuration and scripts: use freely. Gemma 4 model weights are subject to [Google's Gemma license](https://ai.google.dev/gemma/terms).
