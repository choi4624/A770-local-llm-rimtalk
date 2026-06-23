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

## System memory (observed)

Typical usage on this setup (Windows, Docker Desktop + host Ollama, `gemma4-e4b-gpu` loaded):

| Process / area | RAM (approx.) | Notes |
|----------------|---------------|-------|
| **vmmemWSL** | **~4 GB** | WSL2 VM backing **Docker Desktop** — not just our two containers |
| **llama-server** | **~1 GB** | Ollama inference engine on the host (Task Manager: *System* / Ollama) |
| Open WebUI + gateway containers | ~0.3–1 GB inside WSL | Included in **vmmemWSL**, not separate in Task Manager |

**GPU VRAM (A770, separate from RAM above):** `gemma4-e4b-gpu` loaded ≈ **8–10 GB** VRAM (`ollama ps`).

### Why is vmmemWSL ~4 GB?

Docker Desktop on Windows runs Linux containers inside a **WSL2 virtual machine**. Task Manager shows that VM as `vmmemWSL`. It includes:

- The WSL2 kernel and base overhead
- **Open WebUI** (larger Python/Node stack, can idle at 1 GB+)
- **rimtalk-gateway** (small Alpine + Python, tens of MB)
- Memory the VM keeps cached until Windows reclaims it

So 4 GB is mostly **Docker Desktop + WSL2**, not the gateway alone. To reduce it:

- Docker Desktop → **Settings → Resources → Memory** (e.g. limit to 2–3 GB if you only run this stack)
- `docker compose down` when not playing RimWorld
- Optional: run only `rimtalk-gateway` without Open WebUI if you do not need the web UI

`llama-server` ~1 GB is normal for the host-side Ollama process while a model is loaded; weights live primarily in **VRAM**, not in that 1 GB.

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

---

# 림월드 로컬 LLM 스택 (한국어)

Gemma 4를 **Intel Arc A770**(LLM) + **B580**(디스플레이)에서 돌리고, **Open WebUI**와 RimTalk용 **게이트웨이**(`reasoning_effort: "none"` 자동 주입)로 인게임 대화 속도를 맞춘 구성입니다.

이 저장소에는 **설정·스크립트만** 포함됩니다. 모델 가중치는 `ollama pull`로 별도 다운로드합니다 (~9.6GB).

## 구성

```
RimTalk 모드  -->  rimtalk-gateway (:11435)  -->  호스트 Ollama (:11434, A770 GPU)
브라우저      -->  open-webui (:3000)        -->  호스트 Ollama (:11434)
```

| 구성 요소 | URL | 비고 |
|-----------|-----|------|
| RimTalk API | `http://127.0.0.1:11435/v1` | 모드 설정에 입력 |
| Ollama API | `http://127.0.0.1:11434/v1` | 직접 연결 (thinking 기본 ON) |
| Open WebUI | `http://localhost:3000` | 브라우저 채팅 |

## 빠른 시작

자세한 절차: **[docs/getting-started.md](docs/getting-started.md)**

```powershell
git clone <your-repo-url>
cd <repo>

.\scripts\start-ollama-gpu.ps1   # Ollama + gemma4-e4b-gpu
.\scripts\start-docker.ps1       # Open WebUI + RimTalk gateway
```

RimTalk: API `http://127.0.0.1:11435/v1`, 모델 `gemma4-e4b-gpu`.

## 시스템 메모리 (실측)

Windows + Docker Desktop + 호스트 Ollama, `gemma4-e4b-gpu` 로드 시:

| 프로세스 / 영역 | RAM (대략) | 설명 |
|-----------------|------------|------|
| **vmmemWSL** | **~4 GB** | Docker Desktop이 쓰는 **WSL2 가상머신** 전체 |
| **llama-server** | **~1 GB** | 호스트 Ollama 추론 엔진 (작업 관리자 *System*) |
| Open WebUI + gateway | WSL 내부 ~0.3–1 GB | **vmmemWSL에 포함** (별도 항목으로 안 보임) |

**GPU VRAM (A770, RAM과 별도):** `gemma4-e4b-gpu` 로드 시 ≈ **8–10 GB**.

### vmmemWSL이 4GB나 되는 이유

Windows의 Docker Desktop은 컨테이너를 **WSL2 Linux VM** 안에서 실행합니다. 작업 관리자의 `vmmemWSL`은 그 VM 전체 메모리입니다.

- WSL2 기본 오버헤드
- **Open WebUI** (상대적으로 큼, 유휴 시에도 1GB 근처 가능)
- **rimtalk-gateway** (Alpine + Python, 수십 MB 수준)
- VM이 잡아둔 캐시 (Windows가 바로 회수하지 않음)

즉 4GB는 **게이트웨이만**이 아니라 **Docker Desktop + WSL2 + Open WebUI** 합입니다. 줄이려면:

- Docker Desktop → **설정 → Resources → Memory** (2–3GB로 제한 등)
- 림월드 안 할 때 `docker compose down`
- 웹 UI 불필요하면 Open WebUI 없이 `rimtalk-gateway`만 실행

`llama-server` 1GB는 모델 로드 중 호스트 프로세스로 흔한 수준이며, 가중치 대부분은 **VRAM**에 올라갑니다.

## 문서

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [Intel Arc dual GPU](docs/intel-arc-dual-gpu.md)

## 라이선스

설정·스크립트는 자유롭게 사용 가능. Gemma 4 가중치는 [Google Gemma 라이선스](https://ai.google.dev/gemma/terms)를 따릅니다.

