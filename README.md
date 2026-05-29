# llama-cli

Optimized [llama.cpp](https://github.com/ggerganov/llama.cpp) CLI launcher for **Intel Mac** — specifically tuned for Mac Pro 2013 (Ivy Bridge, Xeon E5, DDR3).

Interactive terminal UI for managing local LLM inference with 34 configurable settings.

## Quick Install

### via npm (recommended)
```bash
npm install -g llama-cli
llama-cli
```

### via tar.gz (standalone)
```bash
# Download the archive from GitHub Releases
tar xzf llama-cpp-macpro-optimized.tar.gz
cd llama-cpp-macpro
chmod +x install.sh
./install.sh
```

## Requirements

- **macOS** (Sequoia, Sonoma, Ventura)
- **Intel x64** CPU (optimized for Ivy Bridge / Xeon E5)
- Place `.gguf` model files in `~/models/` (any subfolder)

## What's Included

| Component | Description |
|---|---|
| `llama-server` | OpenAI-compatible API server |
| `llama-cli` | Command-line inference |
| `llama-quantize` | Model quantization tool |
| `llama-bench` | Benchmarking tool |
| `llama-launcher` | Interactive TUI (34 settings) |

## Build Configuration

```
AVX=ON  AVX2=OFF  FMA=OFF  F16C=ON
Metal=OFF  BLAS=ON (Apple Accelerate)
-march=ivybridge -mtune=ivybridge
```

## Usage

```bash
# Launch interactive TUI
llama-cli

# Direct server start
llama-server -m ~/models/your-model.gguf \
  -ngl 0 -t 12 --mlock --no-mmap \
  -c 8192 -b 2048 \
  --cache-type-k q4_0 --cache-type-v q4_0 \
  --port 8081 --host 127.0.0.1

# Connect Open WebUI to http://127.0.0.1:8081 (API key: dummy)
```

## Optimal Flags for Mac Pro 2013

| Flag | Value | Reason |
|---|---|---|
| `-ngl 0` | CPU-only | D700 GPU Metal compute broken under OCLP |
| `-t 12` | 12 threads | Physical cores only |
| `--mlock` | Lock RAM | Prevent swapping (models <25GB) |
| `--no-mmap` | No mmap | Better for this Xeon |
| `-c 8192` | Context | Speed vs capability sweet spot |
| `-b 2048` | Batch | Throughput optimization |
| `--cache-type-k/v q4_0` | KV cache | Memory savings |

## Performance

| Model | Generation | Prompt |
|---|---|---|
| Qwen3.6-27B Q6_K (dense) | ~1.9 tok/s | ~3.2 tok/s |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LLAMA_DIR` | auto-detected | Path to llama.cpp binaries |
| `MODELS_DIR` | `~/models` | Path to .gguf model files |

## Architecture

```
npm install -g llama-cli
        │
        ▼
  postinstall.js
        │ extracts vendor/llama-cpp-macpro.tar.gz
        ▼
  llama-cli command
        │ spawns src/llama-launcher.sh
        ▼
  Interactive TUI
        │ user selects model + configures 34 settings
        ▼
  llama-server (OpenAI-compatible API on :8081)
```

## Standalone Install (tar.gz)

If you prefer not to use npm:

1. Download `llama-cpp-macpro-optimized.tar.gz` from [Releases](https://github.com/SamerKharboush/llama-cli/releases)
2. Extract: `tar xzf llama-cpp-macpro-optimized.tar.gz`
3. Run: `cd llama-cpp-macpro && ./install.sh`
4. Use: `/usr/local/llama-cpp/bin/llama-server -m ~/models/model.gguf ...`

## License

MIT
