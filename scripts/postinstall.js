#!/usr/bin/env node

/**
 * postinstall.js — Extracts llama.cpp binaries after npm install
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const PACKAGE_DIR = path.resolve(__dirname, '..');
const VENDOR_DIR = path.join(PACKAGE_DIR, 'vendor');
const TARBALL = path.join(VENDOR_DIR, 'llama-cpp-macpro.tar.gz');
const EXTRACT_DIR = path.join(VENDOR_DIR, 'llama-cpp-macpro');
const CONFIG_DIR = path.join(process.env.HOME, '.config', 'llama-launcher');

console.log('\x1b[36m[llama-cli]\x1b[0m Setting up llama.cpp binaries...');

// Check if already extracted
if (fs.existsSync(path.join(EXTRACT_DIR, 'bin', 'llama-server'))) {
  console.log('\x1b[32m[llama-cli]\x1b[0m Binaries already extracted. Skipping.');
  process.exit(0);
}

// Check tarball exists
if (!fs.existsSync(TARBALL)) {
  console.error('\x1b[31m[llama-cli]\x1b[0m Tarball not found:', TARBALL);
  console.error('The package may be corrupted. Try: npm reinstall -g llama-cli');
  process.exit(1);
}

try {
  // Extract tarball
  console.log('\x1b[36m[llama-cli]\x1b[0m Extracting binaries...');
  execSync(`tar xzf "${TARBALL}" -C "${VENDOR_DIR}"`, { stdio: 'pipe' });

  // Set executable permissions
  const binDir = path.join(EXTRACT_DIR, 'bin');
  if (fs.existsSync(binDir)) {
    const bins = fs.readdirSync(binDir);
    for (const bin of bins) {
      const binPath = path.join(binDir, bin);
      try {
        fs.chmodSync(binPath, 0o755);
      } catch (e) {
        // Ignore permission errors on non-binary files
      }
    }
  }

  // Create config directory
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
  }

  console.log('\x1b[32m[llama-cli]\x1b[0m Setup complete!');
  console.log('');
  console.log('  Run \x1b[33mllama-cli\x1b[0m to launch the interactive TUI.');
  console.log('  Place .gguf models in \x1b[33m~/models/\x1b[0m');
  console.log('');

} catch (err) {
  console.error('\x1b[31m[llama-cli]\x1b[0m Setup failed:', err.message);
  console.error('You may need to run this manually:');
  console.error(`  tar xzf "${TARBALL}" -C "${VENDOR_DIR}"`);
  process.exit(1);
}
