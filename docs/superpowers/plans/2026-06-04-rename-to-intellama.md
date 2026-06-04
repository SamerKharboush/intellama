# Intellama Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the published npm package, the installed CLI command, and the GitHub repo from `llama-cli` to `intellama`, with a back-compat `llama-cli` shim, then commit, tag, and push so the new GitHub URL is the source of truth.

**Architecture:** Two-track rename — (1) npm/CLI surface: package name `intellama`, primary bin `intellama`, optional back-compat bin `llama-cli` pointing at the same entry script, updated README, postinstall, and release script text; (2) GitHub: rename the remote repo via `gh repo rename`, update the GitHub Pages / clone URL references in `package.json` `repository`/`bugs`/`homepage`, push, then tag `v1.1.0` (or next) and re-pack the release tarball so archive READMEs are consistent. No binary code paths change.

**Tech Stack:** Node ≥14, npm, zsh, git, GitHub CLI (`gh`).

---

## Surface Map (files to touch)

- `package.json` — name, bin, repository, bugs, homepage
- `bin/llama-cli.js` — rename file, update help/strings, optional compat shim
- `scripts/postinstall.js` — log strings, install path
- `scripts/package-release.sh` — staged README/install.sh strings
- `src/llama-launcher.sh` — internal comment banner only (no behavior change)
- `README.md` — npm name, install command, all `llama-cli` references
- `releases/llama-cpp-macpro-optimized.{tar.gz,zip}` — rebuilt via `npm run pack:release` (artifacts, not text-edited)
- `vendor/llama-cpp-macpro.tar.gz` — rebuilt via `npm run pack:release`
- `.gitignore` — verify no stale `llama-cli-*.tgz` entries need to drop

Compatibility policy: keep the `llama-cli` command working as an alias to `intellama` for one release. Both bins point at the same JS file. Older `/usr/local/llama-cpp/bin/llama-launcher.sh` installs and the `~/.config/llama-launcher/` config dir are NOT renamed — they are platform-utility names, not product names. The `<name> installed at <gh-url>` strings change; the launcher/config paths stay.

---

## Task 1: Verify `intellama` is unclaimed on npm and on GitHub

**Files:** none (read-only checks)

- [ ] **Step 1: Check npm registry**

Run:
```bash
npm view intellama name version --cache /private/tmp/llama-cli-npm-cache 2>&1 | head -20
```
Expected: `npm error code E404 ... Not Found`. If it returns a name/version, pick a scoped name like `@samerkharboush/intellama` and update all subsequent steps.

- [ ] **Step 2: Check GitHub name availability**

Run:
```bash
gh repo view SamerKharboush/intellama 2>&1 | head -5
```
Expected: `Could not resolve to a Repository` (or similar not-found). If it exists, the rename will fail and you must choose a different name.

- [ ] **Step 3: Confirm `gh` is authed**

Run:
```bash
gh auth status
```
Expected: `Logged in to github.com as <you>`. If not, run `gh auth login` first.

- [ ] **Step 4: Commit note (no code change)**

No commit. Move on once the three checks above pass.

---

## Task 2: Update `package.json` metadata

**Files:** Modify `package.json`

- [ ] **Step 1: Edit name and bin**

In `package.json`, replace:
```json
  "name": "llama-cli",
  "version": "1.1.0",
  "description": "Optimized llama.cpp terminal launcher for Intel x64 Macs, tuned for Mac Pro 2013 Ivy Bridge with Apple Accelerate BLAS.",
  "main": "bin/llama-cli.js",
  "bin": {
    "llama-cli": "bin/llama-cli.js"
  },
```
with:
```json
  "name": "intellama",
  "version": "1.1.0",
  "description": "Intellama — optimized llama.cpp terminal launcher for Intel x64 Macs, tuned for Mac Pro 2013 Ivy Bridge with Apple Accelerate BLAS.",
  "main": "bin/intellama.js",
  "bin": {
    "intellama": "bin/intellama.js",
    "llama-cli": "bin/intellama.js"
  },
```

- [ ] **Step 2: Edit repository, bugs, homepage**

In `package.json`, replace:
```json
  "repository": {
    "type": "git",
    "url": "https://github.com/SamerKharboush/llama-cli.git"
  },
  "bugs": {
    "url": "https://github.com/SamerKharboush/llama-cli/issues"
  },
  "homehome": "https://github.com/SamerKharboush/llama-cli#readme",
```
with (drop the stray `homehome` typo and use the new slug):
```json
  "repository": {
    "type": "git",
    "url": "https://github.com/SamerKharboush/intellama.git"
  },
  "bugs": {
    "url": "https://github.com/SamerKharboush/intellama/issues"
  },
  "homepage": "https://github.com/SamerKharboush/intellama#readme",
```

- [ ] **Step 3: Run the existing test to make sure JSON still parses**

Run:
```bash
node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('ok')"
```
Expected: `ok`. JSON syntax error → fix and re-run.

- [ ] **Step 4: Commit**

```bash
git add package.json
git commit -m "chore: rename npm package to intellama, keep llama-cli bin alias"
```

---

## Task 3: Rename the CLI entry script and update its strings

**Files:**
- Rename `bin/llama-cli.js` → `bin/intellama.js`
- Create: `bin/llama-cli.js` (1-line compat shim)
- Modify: `bin/intellama.js` strings

- [ ] **Step 1: Move the entry script**

Run:
```bash
git mv bin/llama-cli.js bin/intellama.js
```

- [ ] **Step 2: Update doc/strings in the renamed file**

In `bin/intellama.js`, replace:
```js
 * llama-cli — Interactive CLI launcher for optimized llama.cpp
 * For Intel Mac (Mac Pro 2013, Ivy Bridge, AVX + F16C + Apple Accelerate BLAS)
```
with:
```js
 * intellama — Interactive CLI launcher for optimized llama.cpp
 * For Intel Mac (Mac Pro 2013, Ivy Bridge, AVX + F16C + Apple Accelerate BLAS)
```

Replace the help text block:
```js
  console.log(`llama-cli ${pkg.version}

Usage:
  llama-cli
  MODELS_DIR=/path/to/models llama-cli
  LLAMA_DIR=/path/to/llama-cpp-build-or-package llama-cli

Models:
  Put .gguf files under ~/models by default.

Server:
  The launcher starts llama-server at http://127.0.0.1:8081/v1 by default.
`);
```
with:
```js
  console.log(`intellama ${pkg.version} (compat: llama-cli)

Usage:
  intellama
  MODELS_DIR=/path/to/models intellama
  LLAMA_DIR=/path/to/llama-cpp-build-or-package intellama

Models:
  Put .gguf files under ~/models by default.

Server:
  The launcher starts llama-server at http://127.0.0.1:8081/v1 by default.
`);
```

Replace error messages:
```js
  console.error('\x1b[31mError: llama-launcher.sh not found.\x1b[0m');
  console.error('The package may not be fully installed. Try:');
  console.error('  npm reinstall -g llama-cli');
```
with:
```js
  console.error('\x1b[31mError: llama-launcher.sh not found.\x1b[0m');
  console.error('The package may not be fully installed. Try:');
  console.error('  npm reinstall -g intellama');
```

Replace:
```js
  console.error('\x1b[31mError: vendor binaries not found.\x1b[0m');
  console.error('The postinstall script may not have run. Try:');
  console.error('  cd ' + PACKAGE_DIR + ' && node scripts/postinstall.js');
  console.error('');
  console.error('For development with an external llama.cpp build:');
  console.error('  LLAMA_DIR=/Users/macpro/llama.cpp/build llama-cli');
```
with:
```js
  console.error('\x1b[31mError: vendor binaries not found.\x1b[0m');
  console.error('The postinstall script may not have run. Try:');
  console.error('  cd ' + PACKAGE_DIR + ' && node scripts/postinstall.js');
  console.error('');
  console.error('For development with an external llama.cpp build:');
  console.error('  LLAMA_DIR=/Users/macpro/llama.cpp/build intellama');
```

Replace:
```js
    console.error('\x1b[31mError launching llama-cli:\x1b[0m', err.message);
```
with:
```js
    console.error('\x1b[31mError launching intellama:\x1b[0m', err.message);
```

- [ ] **Step 3: Create the compat shim**

Write `bin/llama-cli.js` with:
```js
#!/usr/bin/env node
// Back-compat shim: `llama-cli` now resolves to the `intellama` package.
require('./intellama.js');
```

- [ ] **Step 4: Syntax check both files**

Run:
```bash
node --check bin/intellama.js && node --check bin/llama-cli.js && echo ok
```
Expected: `ok`. Fix any reported error and re-run.

- [ ] **Step 5: Commit**

```bash
git add bin/llama-cli.js bin/intellama.js
git commit -m "feat(cli): rename entry to intellama with llama-cli shim"
```

---

## Task 4: Update `scripts/postinstall.js` strings

**Files:** Modify `scripts/postinstall.js`

- [ ] **Step 1: Edit log lines**

In `scripts/postinstall.js`, replace:
```js
console.log('\x1b[36m[llama-cli]\x1b[0m Setting up llama.cpp binaries...');
```
with:
```js
console.log('\x1b[36m[intellama]\x1b[0m Setting up llama.cpp binaries...');
```

Replace:
```js
  console.log('\x1b[32m[llama-cli]\x1b[0m Binaries already extracted. Skipping.');
```
with:
```js
  console.log('\x1b[32m[intellama]\x1b[0m Binaries already extracted. Skipping.');
```

Replace:
```js
  console.error('\x1b[31m[llama-cli]\x1b[0m Tarball not found:', TARBALL);
  console.error('The package may be corrupted. Try: npm reinstall -g llama-cli');
```
with:
```js
  console.error('\x1b[31m[intellama]\x1b[0m Tarball not found:', TARBALL);
  console.error('The package may be corrupted. Try: npm reinstall -g intellama');
```

Replace:
```js
  console.log('\x1b[36m[llama-cli]\x1b[0m Extracting binaries...');
```
with:
```js
  console.log('\x1b[36m[intellama]\x1b[0m Extracting binaries...');
```

Replace:
```js
  console.log('\x1b[32m[llama-cli]\x1b[0m Setup complete!');
  console.log('');
  console.log('  Run \x1b[33mllama-cli\x1b[0m to launch the interactive TUI.');
  console.log('  Place .gguf models in \x1b[33m~/models/\x1b[0m');
  console.log('  Local API default: \x1b[33mhttp://127.0.0.1:8081/v1\x1b[0m');
  console.log('');
```
with:
```js
  console.log('\x1b[32m[intellama]\x1b[0m Setup complete!');
  console.log('');
  console.log('  Run \x1b[33mintellama\x1b[0m to launch the interactive TUI.');
  console.log('  Place .gguf models in \x1b[33m~/models/\x1b[0m');
  console.log('  Local API default: \x1b[33mhttp://127.0.0.1:8081/v1\x1b[0m');
  console.log('');
```

Replace:
```js
  console.error('\x1b[31m[llama-cli]\x1b[0m Setup failed:', err.message);
```
with:
```js
  console.error('\x1b[31m[intellama]\x1b[0m Setup failed:', err.message);
```

- [ ] **Step 2: Syntax check**

Run:
```bash
node --check scripts/postinstall.js && echo ok
```
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add scripts/postinstall.js
git commit -m "chore(postinstall): rebrand log lines to intellama"
```

---

## Task 5: Update `scripts/package-release.sh` strings (staged archive metadata)

**Files:** Modify `scripts/package-release.sh`

- [ ] **Step 1: Update staged README header**

In `scripts/package-release.sh`, replace the heredoc body of `$STAGE_DIR/README.md`:
```bash
cat > "$STAGE_DIR/README.md" <<'README'
# llama.cpp Optimized Build for Intel Mac Pro

This archive contains a pinned llama.cpp build optimized for Intel x64 Mac Pro hardware.
```
with:
```bash
cat > "$STAGE_DIR/README.md" <<'README'
# intellama — Optimized llama.cpp Build for Intel Mac Pro

This archive contains a pinned llama.cpp build for the **intellama** package
(`npm install -g intellama`). Optimized for Intel x64 Mac Pro hardware.
```

- [ ] **Step 2: Update the install hint inside the staged README**

Replace the existing:
```text
Run the interactive launcher:

```bash
/usr/local/llama-cpp/bin/llama-launcher.sh
```
```
with:
```text
Run the interactive launcher (it is launched via `intellama` once installed):

```bash
intellama
```

…or, if you installed the standalone archive only:

```bash
/usr/local/llama-cpp/bin/llama-launcher.sh
```
```

- [ ] **Step 3: Syntax check**

Run:
```bash
zsh -n scripts/package-release.sh && echo ok
```
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add scripts/package-release.sh
git commit -m "chore(release): brand staged archive as intellama"
```

---

## Task 6: Update the launcher's internal comment banner

**Files:** Modify `src/llama-launcher.sh` (banner only — no behavior change)

- [ ] **Step 1: Update the ASCII banner header**

In `src/llama-launcher.sh`, replace:
```sh
# ╔══════════════════════════════════════════════════════════════╗
# ║  llama-cli — Interactive llama.cpp Launcher                 ║
# ║  Optimized for Intel Mac (Mac Pro 2013, Ivy Bridge)         ║
# ╚══════════════════════════════════════════════════════════════╝
```
with:
```sh
# ╔══════════════════════════════════════════════════════════════╗
# ║  intellama — Interactive llama.cpp Launcher                 ║
# ║  (formerly llama-cli)  Optimized for Intel Mac Pro 2013    ║
# ╚══════════════════════════════════════════════════════════════╝
```

Do NOT change `CONFIG_DIR`, `LOG_DIR`, `PID_FILE`, `llama-launcher.sh` filename, or any runtime code — the on-disk user config and the launcher binary keep the old internal name on purpose (they are platform-utility names, not product names).

- [ ] **Step 2: Syntax check**

Run:
```bash
zsh -n src/llama-launcher.sh && echo ok
```
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add src/llama-launcher.sh
git commit -m "chore(launcher): update banner to intellama"
```

---

## Task 7: Rewrite `README.md`

**Files:** Modify `README.md`

- [ ] **Step 1: Replace the H1 and product line**

In `README.md`, replace:
```markdown
# llama-cli

Optimized terminal launcher for local GGUF models on Intel x64 Macs, built around a pinned `llama.cpp` binary package and an interactive `llama-cli` menu.

![llama-cli terminal screenshot](assets/llama-cli-screenshot.png)
```
with:
```markdown
# intellama

Optimized terminal launcher for local GGUF models on Intel x64 Macs, built around a pinned `llama.cpp` binary package and an interactive `intellama` menu (formerly `llama-cli`).

![intellama terminal screenshot](assets/llama-cli-screenshot.png)
```
(Keep the screenshot filename as-is to avoid a broken image — the asset is not being renamed in this pass.)

- [ ] **Step 2: Replace the Install With npm block**

Replace:
```markdown
## Install With npm

```bash
npm install -g llama-cli
llama-cli
```
```
with:
```markdown
## Install With npm

```bash
npm install -g intellama
intellama
```

> Back-compat: the `llama-cli` command is still installed as an alias to `intellama` for this release.
```

- [ ] **Step 3: Replace the MODELS_DIR / LLAMA_DIR examples**

Replace the two `llama-cli` invocations in the env-override examples with `intellama`.

- [ ] **Step 4: Update the Tools table**

Replace the `llama-cli` row:
```markdown
| `llama-cli` | NPM command that launches the terminal app |
```
with:
```markdown
| `intellama` | NPM command that launches the terminal app |
| `llama-cli` | Back-compat alias to `intellama` |
```

- [ ] **Step 5: Update the LLAMA_DIR override example**

Replace:
```bash
LLAMA_DIR=/path/to/experimental/llama.cpp/build llama-cli
```
with:
```bash
LLAMA_DIR=/path/to/experimental/llama.cpp/build intellama
```

- [ ] **Step 6: Update the Development block**

Replace:
```bash
node bin/llama-cli.js
```
with:
```bash
node bin/intellama.js
```

- [ ] **Step 7: Add a "Renamed from llama-cli" note at the bottom**

Append before the `## License` section:
```markdown
## Renamed from `llama-cli`

This project was previously published as `llama-cli`. The `llama-cli` npm
command still works as an alias to `intellama` for backwards compatibility.
The on-disk launcher (`llama-launcher.sh`) and config dir
(`~/.config/llama-launcher/`) keep their original names.
```

- [ ] **Step 8: Commit**

```bash
git add README.md
git commit -m "docs: rebrand README to intellama, document rename"
```

---

## Task 8: Run the test suite and a `npm pack` smoke check

**Files:** none

- [ ] **Step 1: Run the test script**

Run:
```bash
npm test
```
Expected: exits 0, prints nothing on success. The script runs `zsh -n src/llama-launcher.sh && node --check bin/intellama.js && node --check bin/llama-cli.js && node --check scripts/postinstall.js` (the `package.json` test was updated implicitly only if Step 2 below edits the script; if not, the existing test still passes because all checked files exist).

- [ ] **Step 2: Update the `test` script to also check the renamed file**

If `package.json` `scripts.test` still references the old path, edit it to:
```json
    "test": "zsh -n src/llama-launcher.sh && node --check bin/intellama.js && node --check bin/llama-cli.js && node --check scripts/postinstall.js"
```
(Same paths, just confirming.) Commit:
```bash
git add package.json
git commit -m "chore(test): keep test script paths aligned with rename"
```

- [ ] **Step 3: Pack dry-run**

Run:
```bash
npm pack --dry-run
```
Expected: tarball name `intellama-1.1.0.tgz`, lists `package.json`, `bin/intellama.js`, `bin/llama-cli.js`, `assets/`, `scripts/`, `src/`, `vendor/llama-cpp-macpro.tar.gz`. If the tarball is still named `llama-cli-*.tgz`, `package.json` `name` was not updated correctly — go back to Task 2.

---

## Task 9: Rename the GitHub repo and update the remote

**Files:** none (remote ops)

- [ ] **Step 1: Rename via `gh`**

Run:
```bash
gh repo rename SamerKharboush/intellama --yes
```
Expected: `https://github.com/SamerKharboush/intellama`.

- [ ] **Step 2: Update the local `origin` URL**

Run:
```bash
git remote set-url origin https://github.com/SamerKharboush/intellama.git
git remote -v
```
Expected: `origin  https://github.com/SamerKharboush/intellama.git (fetch)` and `(push)`.

- [ ] **Step 3: Push the branch**

Run:
```bash
git push -u origin main
```
Expected: branch is up to date at the new URL.

- [ ] **Step 4: Push tags (if any exist)**

Run:
```bash
git tag -l
git push origin --tags
```

- [ ] **Step 5: Create a new tag and push it**

Run:
```bash
git tag -a v1.1.0-intellama -m "Release v1.1.0 as intellama (renamed from llama-cli)"
git push origin v1.1.0-intellama
```
(If `v1.1.0` was already published as `llama-cli`, pick a new tag like `v1.2.0-intellama` for the renamed release.)

---

## Task 10: Rebuild the release artifacts under the new name

**Files:** regenerated `vendor/llama-cpp-macpro.tar.gz`, `releases/llama-cpp-macpro-optimized.{tar.gz,zip}`

- [ ] **Step 1: Rebuild**

Run:
```bash
npm run pack:release
```
Expected: prints `Created:` and `ls -lh` lines for the three artifacts. Required binaries must already exist in `LLAMA_CPP_DIR/build/bin/` (set via env or default `/Users/macpro/llama.cpp`). If a binary is missing, the script exits 1 — fix the build first.

- [ ] **Step 2: Commit the rebuilt artifacts**

```bash
git add vendor/llama-cpp-macpro.tar.gz releases/llama-cpp-macpro-optimized.tar.gz releases/llama-cpp-macpro-optimized.zip
git commit -m "chore(release): rebuild archives with intellama branding"
git push origin main
```

- [ ] **Step 3: Optional — publish to npm**

Run (only when ready to publish; confirm scope/auth first):
```bash
npm login
npm publish
```
Expected: `+ intellama@1.1.0`. If `npm view intellama` still 404s at this point, you don't own the name — Task 1 will have already caught this.

---

## Self-Review Checklist

- [ ] All `llama-cli` references in source/docs are either renamed to `intellama` or intentionally kept as the compat bin alias.
- [ ] `package.json` `name` is `intellama`, `bin` exposes both `intellama` and `llama-cli`, `repository`/`bugs`/`homepage` point at the new GH slug.
- [ ] `bin/llama-cli.js` is a 1-line shim that requires `bin/intellama.js`.
- [ ] `bin/intellama.js` strings say `intellama`; only help text mentions the compat alias.
- [ ] `src/llama-launcher.sh` banner updated; runtime paths and binary names untouched.
- [ ] `scripts/postinstall.js` log tags use `[intellama]`; recovery hint says `npm reinstall -g intellama`.
- [ ] `scripts/package-release.sh` staged archive README/branding says `intellama`.
- [ ] `README.md` install instructions use `intellama`; Tools table lists the alias; a rename note is present.
- [ ] `npm test` passes.
- [ ] `npm pack --dry-run` produces `intellama-1.1.0.tgz`.
- [ ] GitHub repo renamed, `origin` updated, branch + new tag pushed.
- [ ] Release archives rebuilt and committed.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-04-rename-to-intellama.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
