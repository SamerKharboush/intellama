#!/usr/bin/env node

/**
 * intellama — Interactive CLI launcher for optimized llama.cpp
 * For Intel Mac (Mac Pro 2013, Ivy Bridge, AVX + F16C + Apple Accelerate BLAS)
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const PACKAGE_DIR = path.resolve(__dirname, '..');
const LAUNCHER_PATH = path.join(PACKAGE_DIR, 'src', 'llama-launcher.sh');
const VENDOR_DIR = path.join(PACKAGE_DIR, 'vendor', 'llama-cpp-macpro');
const pkg = require(path.join(PACKAGE_DIR, 'package.json'));

if (process.argv.includes('--version') || process.argv.includes('-v')) {
  console.log(pkg.version);
  process.exit(0);
}

if (process.argv.includes('--help') || process.argv.includes('-h')) {
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
  process.exit(0);
}

// Verify installation
if (!fs.existsSync(LAUNCHER_PATH)) {
  console.error('\x1b[31mError: llama-launcher.sh not found.\x1b[0m');
  console.error('The package may not be fully installed. Try:');
  console.error('  npm reinstall -g intellama');
  process.exit(1);
}

if (!fs.existsSync(VENDOR_DIR)) {
  console.error('\x1b[31mError: vendor binaries not found.\x1b[0m');
  console.error('The postinstall script may not have run. Try:');
  console.error('  cd ' + PACKAGE_DIR + ' && node scripts/postinstall.js');
  console.error('');
  console.error('For development with an external llama.cpp build:');
  console.error('  LLAMA_DIR=/Users/macpro/llama.cpp/build intellama');
  process.exit(1);
}

// Set environment for the launcher
const env = Object.assign({}, process.env, {
  LLAMA_DIR: VENDOR_DIR,
  MODELS_DIR: process.env.MODELS_DIR || path.join(process.env.HOME, 'models'),
});

// Spawn the launcher as an interactive process
const child = spawn('/bin/zsh', [LAUNCHER_PATH].concat(process.argv.slice(2)), {
  stdio: 'inherit',
  env: env,
});

// Forward signals
process.on('SIGINT', () => child.kill('SIGINT'));
process.on('SIGTERM', () => child.kill('SIGTERM'));

child.on('exit', (code) => {
  process.exit(code || 0);
});

child.on('error', (err) => {
  if (err.code === 'ENOENT') {
    console.error('\x1b[31mError: zsh not found.\x1b[0m');
    console.error('llama-cli requires zsh (default macOS shell).');
  } else {
    console.error('\x1b[31mError launching intellama:\x1b[0m', err.message);
  }
  process.exit(1);
});
