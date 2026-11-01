const { WASI } = require('node:wasi');
const fs = require('node:fs');
const path = require('node:path');

const wasmPath = path.join(__dirname, 'bin', 'sqlite3.wasm');
const libPath = path.join(__dirname, 'lib', 'libsqlite3.a');
const includePath = path.join(__dirname, 'include');

/**
 * Executes the SQLite WASI CLI programmatically.
 * @param {string[]} [args=[]] Command-line arguments to pass to sqlite3
 * @param {object} [options={}] Additional configuration options
 * @param {Record<string, string>} [options.env=process.env] Environment variables
 * @param {Record<string, string>} [options.preopens={'.': process.cwd()}] Preopened directories
 * @param {number} [options.stdin=0] Stdin file descriptor
 * @param {number} [options.stdout=1] Stdout file descriptor
 * @param {number} [options.stderr=2] Stderr file descriptor
 * @returns {number} Exit code
 */
function runCLI(args = [], options = {}) {
  if (!fs.existsSync(wasmPath)) {
    throw new Error(`sqlite3.wasm not found at ${wasmPath}`);
  }

  const wasi = new WASI({
    version: 'preview1',
    args: ['sqlite3', ...args],
    env: options.env || process.env,
    stdin: options.stdin ?? 0,
    stdout: options.stdout ?? 1,
    stderr: options.stderr ?? 2,
    preopens: options.preopens || { '.': process.cwd() }
  });

  const wasmBuffer = fs.readFileSync(wasmPath);
  const wasmModule = new WebAssembly.Module(wasmBuffer);
  const instance = new WebAssembly.Instance(wasmModule, wasi.getImportObject());

  try {
    const exitCode = wasi.start(instance);
    return typeof exitCode === 'number' ? exitCode : 0;
  } catch (err) {
    if (err && typeof err.code === 'number') {
      return err.code;
    }
    throw err;
  }
}

module.exports = {
  runCLI,
  wasmPath,
  libPath,
  includePath
};
