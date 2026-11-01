#!/usr/bin/env node

const { WASI } = require('node:wasi');
const fs = require('node:fs');
const path = require('node:path');

const wasmPath = path.join(__dirname, 'sqlite3.wasm');

if (!fs.existsSync(wasmPath)) {
  console.error(`Error: sqlite3.wasm not found at ${wasmPath}.`);
  console.error('Please build sqlite3.wasm first or ensure the package is completely installed.');
  process.exit(1);
}

const wasi = new WASI({
  version: 'preview1',
  args: ['sqlite3', ...process.argv.slice(2)],
  env: process.env,
  preopens: {
    '.': process.cwd()
  }
});

const wasmBuffer = fs.readFileSync(wasmPath);
const wasmModule = new WebAssembly.Module(wasmBuffer);
const instance = new WebAssembly.Instance(wasmModule, wasi.getImportObject());

try {
  const exitCode = wasi.start(instance);
  if (typeof exitCode === 'number') {
    process.exit(exitCode);
  }
} catch (err) {
  // node:wasi throws an error with code when proc_exit is called
  if (err && typeof err.code === 'number') {
    process.exit(err.code);
  }
  throw err;
}
