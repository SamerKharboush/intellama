#!/usr/bin/env zsh
# setup-mlc.sh — Install MLC-LLM toolchain and verify Vulkan sees the D700s.
# Idempotent. Refuses to run as root. macOS / Intel x86_64 only.
#
# Usage: zsh scripts/setup-mlc.sh
# Env:   INTELLAMA_HOME (default: ~/.config/intellama)

set -euo pipefail

# ─── Paths & colors ──────────────────────────────────────────────
INTELLAMA_HOME="${INTELLAMA_HOME:-$HOME/.config/intellama}"
VENV_DIR="$INTELLAMA_HOME/venv"
BREWFILE="$(cd "$(dirname "$0")" && pwd)/setup-mlc.brewfile"

RED=$'\033[31m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# ─── Pre-flight checks (abort on any failure) ───────────────────
if [[ "$(id -u)" -eq 0 ]]; then
    echo "${RED}intellama setup-mlc: do not run as root.${RESET}" >&2
    exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "${RED}intellama setup-mlc: macOS required (got: $(uname -s)).${RESET}" >&2
    exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "${RED}intellama setup-mlc: Intel x86_64 required (Apple Silicon is a separate effort).${RESET}" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "${RED}intellama setup-mlc: python3 not found. Install via 'brew install python@3.12'.${RESET}" >&2
    exit 1
fi

PY_VERSION="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_MAJOR="${PY_VERSION%.*}"
PY_MINOR="${PY_VERSION#*.}"
if [[ "$PY_MAJOR" -lt 3 ]] || { [[ "$PY_MAJOR" -eq 3 ]] && [[ "$PY_MINOR" -lt 9 ]]; }; then
    echo "${RED}intellama setup-mlc: python3 >= 3.9 required (got: $PY_VERSION). Install via 'brew install python@3.12'.${RESET}" >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "${RED}intellama setup-mlc: Homebrew required. Install from https://brew.sh.${RESET}" >&2
    exit 1
fi

# Warn-only: Xcode CLT — Phase 0–2 do not need it.
if ! xcode-select -p >/dev/null 2>&1; then
    echo "${YELLOW}intellama setup-mlc: warning — Xcode Command Line Tools not installed.${RESET}" >&2
    echo "${YELLOW}Phase 0–2 work without Xcode; Phase 3 (Metal fallback) will need 'xcode-select --install'.${RESET}" >&2
fi

# Ensure Homebrew is on PATH for this script's subprocesses only.
eval "$(brew --prefix)/bin/brew shellenv" 2>/dev/null || true

# ─── Step 1 — Homebrew install (idempotent) ─────────────────────
BREW_FORMULAE=(molten-vk vulkan-headers vulkan-loader vulkan-tools)
MISSING=()
for f in "${BREW_FORMULAE[@]}"; do
    brew list --formula "$f" >/dev/null 2>&1 || MISSING+=("$f")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "brew: ${#BREW_FORMULAE[@]} formulae already installed, skipping"
else
    if [[ ! -f "$BREWFILE" ]]; then
        echo "${RED}intellama setup-mlc: Brewfile not found: $BREWFILE${RESET}" >&2
        exit 1
    fi
    echo "brew: installing ${#MISSING[@]} missing formulae from $BREWFILE"
    brew bundle --file="$BREWFILE" --no-upgrade
    BREW_EXIT=$?
    if [[ $BREW_EXIT -ne 0 ]]; then
        echo "${RED}intellama setup-mlc: brew install failed — see output above.${RESET}" >&2
        echo "${RED}Common cause: missing Xcode CLT (required by Homebrew itself, not just by Phase 3).${RESET}" >&2
        echo "${RED}Try 'xcode-select --install' and re-run.${RESET}" >&2
        exit 1
    fi
fi

# Re-eval shellenv in case brew just installed for the first time.
eval "$(brew --prefix)/bin/brew shellenv" 2>/dev/null || true

# ─── Step 2 — Project venv + MLC-LLM wheels ────────────────────
mkdir -p "$INTELLAMA_HOME"

if [[ -x "$VENV_DIR/bin/python" ]]; then
    echo "venv: already present at $VENV_DIR, skipping create"
    echo "venv: upgrading pip"
    "$VENV_DIR/bin/pip" install --upgrade pip --quiet
else
    echo "venv: creating at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c "import mlc_llm, tvm" >/dev/null 2>&1; then
    echo "pip: installing mlc-ai-nightly and mlc-llm-nightly from https://mlc.ai/wheels"
    "$VENV_DIR/bin/pip" install --pre -U mlc-ai-nightly mlc-llm-nightly -f https://mlc.ai/wheels
    PIP_EXIT=$?
    if [[ $PIP_EXIT -ne 0 ]]; then
        echo "${RED}intellama setup-mlc: pip install failed — see output above.${RESET}" >&2
        echo "${RED}The nightly index is at https://mlc.ai/wheels; check for upstream build breakages.${RESET}" >&2
        exit 1
    fi
    if ! "$VENV_DIR/bin/python" -c "import mlc_llm, tvm" >/dev/null 2>&1; then
        echo "${RED}intellama setup-mlc: pip install completed but import still fails.${RESET}" >&2
        echo "${RED}The nightly index may be broken. See docs/gpu-mlc-setup.md#troubleshooting.${RESET}" >&2
        exit 1
    fi
else
    echo "pip: mlc-ai-nightly and mlc-llm-nightly already installed, skipping"
fi

# ─── Step 3 — GPU verification (strict gate) ────────────────────
if ! command -v vulkaninfo >/dev/null 2>&1; then
    echo "${RED}intellama setup-mlc: vulkaninfo not found — brew install of vulkan-tools did not put it on PATH.${RESET}" >&2
    echo "${RED}Try 'eval \"\$(brew --prefix)/bin/brew shellenv\"' and re-run.${RESET}" >&2
    exit 1
fi

VULKAN_OUTPUT="$(vulkaninfo --summary 2>&1 || true)"
if [[ -z "$VULKAN_OUTPUT" ]]; then
    VULKAN_OUTPUT="$(vulkaninfo 2>&1 || true)"
fi

# Count deviceName lines containing AMD (case-insensitive).
AMD_COUNT="$(echo "$VULKAN_OUTPUT" | grep -c '^deviceName' || true)"
AMD_COUNT_AMD="$(echo "$VULKAN_OUTPUT" | grep -i '^deviceName.*amd' | wc -l | tr -d ' ' || true)"

if [[ "$AMD_COUNT_AMD" -ge 2 ]]; then
    echo "GPU: detected $AMD_COUNT_AMD AMD devices via Vulkan"
elif [[ "$AMD_COUNT" -ge 2 ]]; then
    echo "GPU: detected $AMD_COUNT devices via Vulkan (no 'AMD' string match — MoltenVK may report a generic name)"
else
    echo "${RED}intellama setup-mlc: GPU verification FAILED.${RESET}" >&2
    echo "" >&2
    echo "${RED}Detected $AMD_COUNT_AMD AMD device(s) via Vulkan.${RESET}" >&2
    echo "${RED}Expected: >= 2 AMD devices (Mac Pro 2013 has 2x FirePro D700).${RESET}" >&2
    echo "" >&2
    echo "${RED}Common causes:${RESET}" >&2
    echo "${RED}  1. OCLP nightly regression — Metal/Vulkan compute sometimes breaks${RESET}" >&2
    echo "${RED}     after OpenCore-Legacy-Patcher updates. See 'pmset gpuswitch 1' to${RESET}" >&2
    echo "${RED}     force discrete GPU.${RESET}" >&2
    echo "${RED}  2. MoltenVK not seeing the D700s — verify with${RESET}" >&2
    echo "${RED}     'vulkaninfo --summary | grep deviceName'. Each D700 should appear.${RESET}" >&2
    echo "${RED}  3. macOS Sequoia regression — check the OCLP release notes for your nightly.${RESET}" >&2
    echo "" >&2
    echo "${RED}Troubleshooting: see docs/gpu-mlc-setup.md#troubleshooting${RESET}" >&2
    exit 1
fi

# ─── Final banner ──────────────────────────────────────────────
MLC_VERSION="$("$VENV_DIR/bin/python" -c 'import mlc_llm; print(mlc_llm.__version__)' 2>/dev/null || echo unknown)"
echo "${GREEN}✓ MLC-LLM toolchain ready${RESET}"
echo "${DIM}venv:  $VENV_DIR${RESET}"
echo "${DIM}mlc:   $MLC_VERSION${RESET}"
echo "${DIM}next:  see docs/mlc-bench-cpu.txt (sub-project 2)${RESET}"
