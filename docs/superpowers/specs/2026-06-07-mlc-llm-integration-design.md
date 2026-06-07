# intellama + MLC-LLM Integration Design

**Status:** Draft v1
**Date:** 2026-06-07
**Target release:** intellama v1.3.0 (post-validation)
**Hardware context:** 2013 Mac Pro · 2× AMD FirePro D700 (GCN 1.0, 6 GB VRAM each) · Intel Xeon E5 Ivy Bridge · macOS Sequoia via OCLP · no Xcode
**Source plan:** `/Users/macpro/mlc-llm-adoption-plan.md`

---

## Goal & Non-Goals

**Goal.** Validate whether MLC-LLM can drive the 2× D700 GPUs via Vulkan/MoltenVK on this Mac Pro. If validation succeeds, integrate MLC-LLM as a first-class backend in intellama with auto-detect and graceful fallback to the existing llama.cpp CPU path. If validation fails, ship CPU improvements and file a llama.cpp PR with the Vulkan-vs-Metal benchmarks as evidence.

**Non-goals.**
- Replacing llama.cpp — it remains the default and fallback backend.
- Supporting non-Intel Macs or non-macOS platforms.
- Writing a generic multi-backend framework for backends that don't exist yet (YAGNI).
- Full model conversion pipelines — we use prebuilt MLC artifacts and the standard convert/compile flow only when needed.
- Tokenizer or chat template work — the server handles all of that.
- Touching the intellama → Ollama / OpenAI-remote integrations.

**Success criteria.**
- `mlc_llm chat HF://mlc-ai/Qwen2.5-0.5B-Instruct-q4f16_1-MLC --device vulkan:0` produces a coherent "Paris" answer on this hardware.
- If yes: intellama menu option `M` configures the MLC port; the launcher auto-detects MLC at startup and uses it when present; llama.cpp remains the fall-through path when MLC is not configured.
- If no: launcher behavior is byte-identical to v1.2.3; benchmark numbers go into `docs/mlc-bench-*.txt` and a llama.cpp PR is filed (if the diff is publishable).

---

## Architecture

Three layers, all in-tree, no new runtime dependencies for end users.

```
┌──────────────────────────────────────────────────────┐
│ intellama launcher (zsh, src/llama-launcher.sh)      │
│  • select_model, settings menu, GPU probe             │
│  • NEW: probe_backend() — talks to /v1/models         │
│  • NEW: backend_active = mlc | llama                  │
│  • start_server() dispatches to backend launcher      │
└──────────────────┬───────────────────────────────────┘
                   │ uses
                   ▼
┌──────────────────────────────────────────────────────┐
│ Backend abstraction (zsh functions in llama-launcher) │
│  • backend_launch_cmd()   → prints exec argv           │
│  • backend_stop_pid()     → kills child                │
│  • backend_health_url()   → /health or /v1/models      │
│  • backend_unload()       → POST /models/unload        │
│  • impls: llama_cpp (existing), mlc_llm (new)          │
└──────────────────┬───────────────────────────────────┘
                   │ starts
                   ▼
┌──────────────────────────────────────────────────────┐
│ MLC-LLM server (mlc_llm serve, port 8080 by default) │
│  • OpenAI-compatible /v1/chat/completions              │
│  • Loaded with: mlc_llm serve MODEL --device vulkan   │
└──────────────────────────────────────────────────────┘
```

**Design choices that matter.**
- **zsh functions, not separate JS files.** The plan's `src/backends/mlc.js` is the wrong layer — intellama is a zsh launcher. The right place is zsh helpers alongside `start_server()`. The Node.js `bin/intellama.js` is just a thin `spawn` wrapper; it stays unchanged.
- **Backend selector at startup.** When `start_server` or `select_model` runs, probe the configured MLC port first; if alive, use MLC; else fall through to llama.cpp.
- **Single config knob.** New `mlc_port` setting (default empty). If set, MLC is preferred. If unset, current v1.2.3 behavior is preserved. **Zero behavior change for existing users.**
- **Process tracking.** MLC server gets a separate `~/.config/llama-launcher/mlc.pid` file alongside the existing `server.pid`. Stops/purges/foreign-detection all work via the same iteration.

---

## Components

### C1. `probe_backend(port)` — zsh function
- `curl --max-time 2 http://$host:$port/v1/models`
- Returns 0 if response is valid JSON with a `data[0].id` field
- Used by `start_server`, `select_model`, foreign detection
- Does not care which backend is answering — it's a generic OpenAI-compat probe

### C2. `backend_active` — global var
- Set to `mlc` or `llama` at the start of `start_server` and `select_model` after probing
- Persisted as `INTELLAMA_BACKEND` env var passed to the child server (for log annotation only)
- Read by `backend_health_url`, `backend_unload`, `stop_server` for dispatch

### C3. `start_mlc_server(model)` — new function
- Builds `mlc_llm serve <compiled_model_path> --device ${INTELLAMA_DEVICE:-vulkan:0} --host 127.0.0.1 --port ${mlc_port}`
- Forks, tracks PID in `$MLC_PID_FILE`
- Waits up to 240s (slightly longer than llama.cpp's 180s; MLC can be slower on first compile-on-load) for `/v1/models` to return
- Compiled model path resolved from new setting `mlc_model_dir` (default `~/models/qwen3-35b-q4f16-mlc`)
- Logs to `~/.config/llama-launcher/logs/mlc-server-YYYYMMDD-HHMMSS.log`

### C4. `mlc_health_url()` / `mlc_unload()` — adapter functions
- Match the existing `port_responds` / `eject_model` pattern
- MLC supports `POST /unload` (may not support `/models/unload`); the existing fallback chain in `eject_model` already handles both endpoints

### C5. Settings additions (entries in `ALL_KEYS` and `DEFAULT_SETTINGS`)
- `mlc_port` — string, default `""` (empty → backend disabled)
- `mlc_model_dir` — string, default `$HOME/models/qwen3-35b-q4f16-mlc`
- `mlc_device` — string, default `vulkan:0`, valid: `cpu`, `vulkan:0`, `vulkan:0,vulkan:1`
- All three go through the existing `set_setting` validation

### C6. `scripts/start-mlc.sh` — convenience wrapper
- Standalone script so MLC can be started without intellama
- Used by the new menu option `M`
- Takes `model_path` and `port` as args; defaults from `INTELLAMA_MLC_*` env vars

### C7. New menu option `M` — "Set MLC backend port"
- Asks for `mlc_port` (empty to disable)
- If set, immediately probes and reports status (health, model loaded)
- If unset, MLC is disabled; menu returns to v1.2.3 behavior

### C8. README section update
- Document the MLC path, fallback semantics, env vars, and how to convert/compile a model
- Note that MLC requires `pip install mlc-llm-nightly` and `brew install molten-vk`

---

## Data Flow & Error Handling

### Flow: `select_model` → `start_server`

```
1. select_model() picks GGUF path
   ↓
2. Check mlc_port setting
   ↓ if empty → use llama.cpp (legacy path, unchanged)
   ↓ if set →
3. probe_backend(mlc_port)
   ↓ if healthy → check /v1/models
   ↓                   ↓ if same model → return "already running"
   ↓                   ↓ if different model → offer swap (use existing eject flow)
   ↓ if down → start_mlc_server() → set backend_active=mlc
   ↓
4. Return; user calls /v1/chat/completions as usual
```

### Flow: stop / purge

```
stop_server / purge → iterate PID files:
  - $server.pid (llama.cpp)
  - $mlc.pid (MLC, new)
  → kill all owned, with foreign-server confirmation per PID (existing v1.2.2 logic)
```

### Flow: eject (model unload)

```
eject_model() → if backend_active=mlc:
  → POST /unload to mlc_port (with /models/unload fallback for llama.cpp)
  → foreign-server detection same as v1.2.2
```

### Error handling
- **MLC server crashes on start** — log shows `mlc_llm` output; fall back to llama.cpp prompt: one-line `MLC failed, start llama.cpp instead? [Y/n]`.
- **MLC server crashes during use** — PID tracker notices on next stop, reports and clears the PID file.
- **Vulkan device lost** — MLC exits; launcher prompts: `MLC died, start llama.cpp fallback? [Y/n]`.
- **Port already bound by foreign server** — existing foreign-server confirmation flow (v1.2.2).
- **Empty `mlc_model_dir`** — refuse to start MLC, prompt user to set it via menu option `M` or `mlc_model_dir` setting.
- **`mlc_llm` not installed** — `start_mlc_server` checks for binary; if missing, prints install instructions from the README.

### Logging
- `~/.config/llama-launcher/logs/mlc-server-YYYYMMDD-HHMMSS.log` (separate from `llama-server-*.log`)

---

## Testing

### T1. Static checks (npm test)
- `zsh -n src/llama-launcher.sh` (existing)
- `node --check bin/intellama.js` (existing)
- **New:** `zsh -n scripts/start-mlc.sh`
- **New (optional):** `shellcheck scripts/start-mlc.sh src/llama-launcher.sh` if shellcheck is on the path; skip silently if absent

### T2. Manual tests (zsh, before/after each phase)
- `mlc_llm chat` smoke test (Phase 1 CPU)
- `mlc_llm bench --device vulkan:0` (Phase 2 GPU)
- Probe + start with MLC: confirm `/v1/models` returns
- Foreign server detection: start MLC externally, launch intellama, see foreign-server prompt
- Fallback: clear `mlc_port`, confirm intellama still works exactly as v1.2.3

### T3. MLC benchmark record
- After Phase 1: `docs/mlc-bench-cpu.txt` (`mlc_llm bench ... --device cpu --num-prompts 3`)
- After Phase 2 single: `docs/mlc-bench-vulkan0.txt` (`--device vulkan:0`)
- After Phase 2 dual: `docs/mlc-bench-vulkan0-1.txt` (`--device vulkan:0,vulkan:1`)
- These become the PR evidence if Vulkan works

### T4. CI / automation
- The existing npm test stays a syntax-check only (this is a local tool, no CI)
- No new test framework — zsh is the test harness

---

## Phasing (matches source plan)

| Phase | What | Stop condition |
|-------|------|----------------|
| 0 | `brew install molten-vk vulkan-tools`; `vulkaninfo`; `pip install mlc-llm-nightly` | tooling installs cleanly |
| 1 | `mlc_llm chat --device cpu` smoke test; record CPU bench | ≥10 tok/s on the 0.5B model |
| 2 | `mlc_llm chat --device vulkan:0` then `vulkan:1`; record GPU bench; if coherent, `compile` and `serve` the 35B | coherent output on both D700s |
| 3 | (only if Phase 2 fails) install Xcode CLT, retry Metal backend | if still broken, stop |
| 4 | intellama integration: settings, menu option, backend abstraction, scripts, README | npm test passes + manual T2 cases |
| 5 | dual-GPU tensor parallel serve with `--tensor-parallel-shards 2` | bench vs single-GPU |

**Stop conditions are hard.** If Phase 2 fails after Phase 3, no Phase 4 — we ship CPU polish instead and file the llama.cpp PR.

---

## File-Level Changes

| File | Change | Notes |
|------|--------|-------|
| `src/llama-launcher.sh` | Add `probe_backend`, `start_mlc_server`, `mlc_unload`, `mlc_health_url`; add `mlc_*` to `ALL_KEYS`/`DEFAULT_SETTINGS`; add menu option `M`; modify `start_server`, `eject_model`, `stop_server`, `purge`, `select_model` to dispatch on `backend_active` | ≤150 lines net add |
| `scripts/start-mlc.sh` | New file | ~25 lines |
| `bin/intellama.js` | No change | thin Node wrapper, untouched |
| `package.json` | Add `zsh -n scripts/start-mlc.sh` to test script | one-line |
| `README.md` | New section: MLC-LLM backend, fallback semantics, install steps | ~80 lines |
| `docs/mlc-bench-*.txt` | New benchmark records (only if Phase 2 runs) | one-time captures |

---

## Open Questions

None at design time. Decisions captured:
- zsh, not Node — intellama is a zsh launcher.
- Auto-detect with fallback — single config knob (`mlc_port`).
- intellama launches MLC — same UX as llama.cpp.
- Scope = "experiments first, then integrate" — stop conditions respected.

---

## Risks

1. **MoltenVK on D700 may not compute at all.** GCN 1.0 + Metal 2 only + OCLP is a fragile stack. The 0.5B smoke test is the canary; if it produces garbage, MLC has the same problem as llama.cpp's Metal backend.
2. **Vulkan memory model + 6 GB VRAM cap.** A 35B q4f16 is ~17–20 GB; only the MoE 35B-A3B (~9–11 GB q4f16) fits in 12 GB combined. Single-GPU Vulkan would require a smaller quant or offloading. Dual-GPU tensor parallel is the realistic path for 35B.
3. **OCLP nightly regressions.** OCLP changes can break Metal compute overnight. Pin the OCLP version in the README when MLC integration lands.
4. **No Xcode = no Metal compile path.** We cannot use MLC's `--device metal` until Xcode CLT is installed (~1.5 GB). The design assumes Vulkan is the path; Metal is a fallback if and only if Phase 3 runs.
