# intellama

Optimized local LLM launcher for Intel x64 Macs. `intellama` wraps a tuned `llama.cpp` server, scans your GGUF models, manages runtime settings, and exposes a stable OpenAI-compatible local API.

**Latest published version:** `1.3.0-alpha`  
**Target machine profile:** 2013 Mac Pro, Xeon E5 Ivy Bridge, 64 GB RAM, Apple Accelerate BLAS, OpenCore Legacy Patcher.

![intellama terminal screenshot](assets/llama-cli-screenshot.png)

## What it does

`intellama` starts a local `llama-server` instance from a selected `.gguf` model and gives you a terminal menu for day-to-day operations:

- scan `~/models` for `.gguf` files
- choose a model interactively
- tune context, batch size, threads, KV cache, RoPE, MoE, prompt cache, and fit settings
- start, stop, eject, purge, benchmark, and inspect the running server
- expose an OpenAI-compatible endpoint at `http://127.0.0.1:8081/v1`

The launcher is intentionally conservative: it ships a CPU-first build that is stable on the target hardware and avoids pretending GPU acceleration works when the local backend cannot be verified.

## Install

```bash
npm install -g intellama
intellama
```

The `llama-cli` command remains available as a backwards-compatible alias.

Place models anywhere under:

```bash
~/models
```

You can override the model and backend locations:

```bash
MODELS_DIR=/Volumes/Models intellama
LLAMA_DIR=/usr/local/llama-cpp intellama
```

## Quick start

1. Put one or more `.gguf` files under `~/models`
2. Run:

   ```bash
   intellama
   ```

3. Select a model
4. Start the server
5. Call the local API:

   ```bash
   curl http://127.0.0.1:8081/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"messages":[{"role":"user","content":"Say hello."}],"max_tokens":20}'
   ```

Use any placeholder API key, for example `dummy`.

## Included tools

| Tool | Purpose |
|---|---|
| `intellama` | main terminal launcher |
| `llama-cli` | backwards-compatible alias |
| `llama-launcher.sh` | interactive zsh launcher |
| `llama-server` | OpenAI-compatible local API server |
| `llama-bench` | benchmark runner |
| `llama-quantize` | quantization utility |
| `llama-perplexity` | perplexity testing utility |

## Build profile

The bundled `llama.cpp` build is CPU-first and tuned for Ivy Bridge:

```text
GGML_AVX=ON
GGML_AVX2=OFF
GGML_FMA=OFF
GGML_F16C=ON
GGML_METAL=OFF
GGML_BLAS=ON
GGML_BLAS_VENDOR=Apple
CFLAGS=-march=ivybridge -mtune=ivybridge
CXXFLAGS=-march=ivybridge -mtune=ivybridge
CMAKE_BUILD_TYPE=Release
```

Why CPU-first: this target machine has D700 GPUs, but the stable tested path is Apple Accelerate BLAS on CPU with AVX/F16C and no AVX2/FMA. The launcher keeps that path as the default so it remains predictable on the intended hardware.

## Performance

The launcher auto-detects CPU cores, RAM, and instruction-set features (`AVX`, `AVX2`, `FMA`, `F16C`) on launch via `sysctl`. Thread count defaults to the number of physical cores, and the `Show Hardware` menu option prints the probe results.

On Ivy Bridge, memory bandwidth is usually the ceiling. The launcher bakes in several mitigations:

- MoE-friendly defaults
- `mlock` / `no-mmap`
- conservative context and batch defaults
- optional self-speculative decoding modes
- prompt cache sizing knobs
- explicit GPU-offload controls when you provide a different backend build

The 35B-A3B MoE at Q8_0 is the sweet spot on this profile: roughly 8–9 tok/s on CPU in the tested configuration.

## Default runtime profile

| Setting | Default |
|---|---|
| Threads | `12` |
| Context | `8192` |
| Batch | `2048` |
| uBatch | `512` |
| GPU layers | `0` |
| KV cache | `q4_0/q4_0` |
| mmap | disabled |
| mlock | enabled |
| Fit | `on` |
| Server | `127.0.0.1:8081` |

Direct server example:

```bash
llama-server \
  -m ~/models/model-folder/model.gguf \
  -ngl 0 -t 12 -tb 12 \
  --mlock --no-mmap \
  -c 8192 -b 2048 -ub 512 \
  --cache-type-k q4_0 --cache-type-v q4_0 \
  --fit on \
  --port 8081 --host 127.0.0.1
```

## Launcher features

- Lists every `.gguf` model under `~/models`, including nested folders
- Saves settings in `~/.config/llama-launcher/settings.conf`
- Starts `llama-server` in the background and records its PID
- Avoids killing unrelated `llama-server` processes from other apps
- Shows health, memory, uptime, and loaded model when available
- Offers model eject through the server unload endpoint, with stop fallback
- Supports advanced flags for context, batch, threads, KV cache type, RoPE settings, MoE CPU options, prompt cache RAM, cache reuse, custom Jinja chat template, and fit target

## Performance notes

Measured on the target Mac Pro profile:

| Model | Generation | Prompt | Output |
|---|---:|---:|---|
| Dense 27B Q6_K | about 1.9 tok/s | about 3.2 tok/s | clean |
| Qwopus3.6 35B A3B Q8_0 | about 8.6 tok/s | about 20.8 tok/s | bad conversion output in testing |

Model quality and GGUF conversion correctness matter. Runtime flags cannot fix corrupted or badly converted weights.

## GPU / experimental backends

This package intentionally ships the stable CPU/Accelerate build. Current practical notes:

- `vLLM` is strongest on Linux GPU servers. Its macOS GPU path is aimed at Apple Silicon through vLLM-Metal/MLX, not Intel Mac Pro FirePro GPUs.
- `llama.cpp` Metal can work on some Intel Mac AMD systems, but this target build and OCLP setup reported no usable GPU during testing.
- Vulkan/ROCm paths are worth testing on Linux or newer AMD hardware. They are not the default here because the goal is a portable package that works on the matching Intel Mac without extra driver work.

If you want to experiment, keep this CPU build as the stable baseline and create a separate `LLAMA_DIR` build with Metal or Vulkan so the launcher can switch via:

```bash
LLAMA_DIR=/path/to/experimental/llama.cpp/build intellama
```

**Probe the GPU (v1.2.1):** the launcher ships an opt-in companion
`releases/llama-cpp-macpro-metal.tar.gz` (Metal-enabled, otherwise
identical to the default AVX build). The `g` menu option probes this
companion binary with `-ngl 99` and reports whether the D700s compute
path is functional under your current OCLP nightly. Read-only with
respect to the running server and your saved config — safe to run at
any time.

## MLC-LLM toolchain

`v1.3.0-alpha` adds the Phase 0 setup script for MLC-LLM:

- `scripts/setup-mlc.sh`
- `docs/gpu-mlc-setup.md`
- `scripts/setup-mlc.brewfile`

The script installs the Vulkan/MoltenVK toolchain, creates a project venv, installs the MLC nightly wheels, and verifies that Vulkan sees the D700 GPUs.

```bash
zsh scripts/setup-mlc.sh
```

Current status: Vulkan detection succeeds on both D700 GPUs, but the current x86_64 macOS MLC nightly wheels fail to import cleanly on Python 3.12 due to an upstream `tvm_ffi` issue. The setup script records that failure and leaves the CPU build as the stable path.

## Rebuild release archives

From this repo on the optimized Mac:

```bash
npm run pack:release
```

This rebuilds:

```text
vendor/llama-cpp-macpro.tar.gz
releases/llama-cpp-macpro-optimized.tar.gz
releases/llama-cpp-macpro-optimized.zip
```

To additionally build the Metal companion archive for the GPU probe:

```bash
npm run pack:release -- --with-metal
```

…which adds `releases/llama-cpp-macpro-metal.tar.gz`.

## Development

```bash
npm test
npm pack
```

Local run without global install:

```bash
node bin/intellama.js
```

## Renamed from `llama-cli`

This project was previously published as `llama-cli`. The `llama-cli` npm
command still works as an alias to `intellama` for backwards compatibility.
The on-disk launcher (`llama-launcher.sh`) and config dir
(`~/.config/llama-launcher/`) keep their original names.

## License

MIT. The bundled `llama.cpp` binaries are built from `llama.cpp`; see the upstream project license for its components.
