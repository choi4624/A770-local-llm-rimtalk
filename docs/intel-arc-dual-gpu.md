# Intel Arc dual GPU — B580 + A770

## Role split

| GPU | Vulkan ID | Role | Ollama |
|-----|-----------|------|--------|
| Arc B580 | GPU0 | Monitor, games, general graphics | Not used |
| Arc A770 | GPU1 | LLM inference (16GB VRAM) | `GGML_VK_VISIBLE_DEVICES=1` |
| UHD iGPU | GPU2 | Unused | Excluded |

## Verify

```powershell
vulkaninfo --summary
```

## Environment (applied by `scripts/start-ollama-gpu.ps1`)

```powershell
OLLAMA_VULKAN=1
GGML_VK_VISIBLE_DEVICES=1
OLLAMA_HOST=0.0.0.0:11434
```

## Model choice (A770 16GB)

| Model | Size | Fit | Use case |
|-------|------|-----|----------|
| `gemma4:e2b` | ~7GB | Comfortable | Maximum speed |
| **`gemma4:e4b`** | **~9.6GB** | **Good** | **Default — RimTalk + quality** |
| `gemma4:12b` | ~7.6GB Q4 | Good | Higher quality, slower dense model |
| `gemma4:26b` | ~17GB | Tight | Needs Q3 or CPU; not recommended on 16GB |

Default custom model: `gemma4-e4b-gpu`.

## Validation

```powershell
.\scripts\measure-tps.ps1 -Model gemma4-e4b-gpu
ollama ps   # expect 100% GPU
```

If B580 is selected, re-check `GGML_VK_VISIBLE_DEVICES`.
