# Configuration

## RimTalk gateway (`config/rimtalk-gateway.json`)

```json
{
  "listen_host": "127.0.0.1",
  "listen_port": 11435,
  "upstream": "http://127.0.0.1:11434",
  "inject": {
    "reasoning_effort": "none",
    "trim_model_name": true,
    "max_tokens": null,
    "force_model": null
  }
}
```

| Field | Purpose |
|-------|---------|
| `inject.reasoning_effort` | `"none"` disables Gemma 4 thinking (large speedup for RimTalk) |
| `inject.trim_model_name` | Strips trailing spaces from model name |
| `inject.force_model` | Override client model (e.g. `"gemma4-e4b-gpu"`) |
| `inject.max_tokens` | Optional cap — **avoid low values**; thinking tokens count when bypassing gateway |

After editing:

```powershell
docker compose restart rimtalk-gateway
```

### Docker overrides (in `docker-compose.yml`)

| Env | Container value | Why |
|-----|-----------------|-----|
| `RIMGATEWAY_UPSTREAM` | `http://host.docker.internal:11434` | Reach host Ollama from container |
| `RIMGATEWAY_LISTEN_HOST` | `0.0.0.0` | Publish port 11435 |

### Run gateway without Docker (dev)

```powershell
$env:RIMGATEWAY_CONFIG = ".\config\rimtalk-gateway.json"
python .\rimtalk-gateway\gateway.py
```

## Ollama GPU (`scripts/Set-LlmGpuEnv.ps1`)

User-level environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `OLLAMA_VULKAN` | `1` | Vulkan backend |
| `GGML_VK_VISIBLE_DEVICES` | `1` | A770 only (see `vulkaninfo --summary`) |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Allow Docker `host.docker.internal` |

Change GPU index if your A770 is not GPU1.

## Modelfiles (`modelfiles/`)

Recipes only — weights come from `ollama pull`.

### `gemma4-e4b-gpu` (default)

- Base: `gemma4:e4b` (~9.6GB Q4)
- `num_ctx 8192`
- **No `num_predict`** — low limits cut off thinking before JSONL output

Recreate after edit:

```powershell
ollama create gemma4-e4b-gpu -f modelfiles/gemma4-e4b-gpu
```

### `gemma4-e2b-cpu` (fallback)

CPU-only when gaming needs full A770 VRAM:

```powershell
ollama pull gemma4:e2b
ollama create gemma4-e2b-cpu -f modelfiles/gemma4-e2b-cpu
```

## Open WebUI (`docker-compose.yml`)

| Env | Default |
|-----|---------|
| `DEFAULT_MODELS` | `gemma4-e4b-gpu` |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` |
| `OFFLINE_MODE` | `true` |

## Extending the gateway

Edit `rimtalk-gateway/gateway.py` → `transform_body()` for custom RimWorld rules, e.g.:

- Force `stream: false`
- Strip markdown fences from responses
- Add default system message prefix

Rebuild:

```powershell
docker compose up -d --build rimtalk-gateway
```
