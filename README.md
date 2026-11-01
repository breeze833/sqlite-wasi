# sqlite-wasi

Precompiled **SQLite** C library and command-line interface (CLI) for **WASI Preview 1** (`wasm32-wasip1`), packaged as an npm distribution package and released directly on GitHub Releases.

## Features

- **WASI Preview 1 Native**: Compiled for `wasm32-wasi` with `wasi-sdk`.
- **Precompiled C Library**: `lib/libsqlite3.a` ready to be linked into other WebAssembly modules.
- **C Headers**: Standard `include/sqlite3.h` and `include/sqlite3ext.h`.
- **Standalone CLI Binary**: `bin/sqlite3.wasm` runnable by any WASI runtime (`wasmtime`, `wasmer`, `wazero`, etc.).
- **Zero-Dependency Node.js Runner**: `bin/cli.js` runnable out-of-the-box via `npx sqlite-wasi` with local filesystem access automatically preopened.

---

## Package Contents

When downloading or extracting `sqlite-wasi-<version>.tgz`, the package contains:

```
sqlite-wasi/
├── bin/
│   ├── cli.js            # Node.js WASI CLI launcher
│   └── sqlite3.wasm      # Compiled SQLite WASI executable
├── include/
│   ├── sqlite3.h         # SQLite C API header
│   └── sqlite3ext.h      # SQLite extension header
├── lib/
│   └── libsqlite3.a      # Static library for wasm32-wasi
├── index.js              # Programmatic entrypoint for Node.js
└── package.json
```

---

## Usage

### 1. Direct CLI via `npx` (Node.js)

You can run the SQLite CLI directly without manual Wasm runtime installation:

```bash
# Run in-memory or open a local database
npx sqlite-wasi mydatabase.db "CREATE TABLE users(id INT, name TEXT); INSERT INTO users VALUES(1, 'Alice'); SELECT * FROM users;"

# Interactive shell
npx sqlite-wasi mydatabase.db
```

### 2. Programmatic Node.js API

```javascript
const { runCLI, wasmPath, libPath, includePath } = require('sqlite-wasi');

// Get paths to artifacts
console.log('Wasm CLI path:', wasmPath);
console.log('Static library path:', libPath);
console.log('C headers path:', includePath);

// Execute CLI programmatically
runCLI(['mydatabase.db', 'SELECT sqlite_version();']);
```

### 3. Using with Standalone WASI Runtimes

You can run `bin/sqlite3.wasm` directly using any WASI runtime:

#### Wasmtime
```bash
wasmtime --dir=. bin/sqlite3.wasm mydatabase.db "SELECT sqlite_version();"
```

#### Wasmer
```bash
wasmer run --dir=. bin/sqlite3.wasm -- mydatabase.db
```

### 4. Linking in C / WebAssembly Projects

Use `libsqlite3.a` and `include/` with `wasi-sdk`:

```bash
$WASI_SDK_PATH/bin/clang --target=wasm32-wasi \
  --sysroot=$WASI_SDK_PATH/share/wasi-sysroot \
  -I/path/to/sqlite-wasi/include \
  -L/path/to/sqlite-wasi/lib \
  main.c -lsqlite3 -o main.wasm
```

---

## Building Locally

### Prerequisites

- `curl`, `tar`, `unzip`, `node`, `npm`
- (Optional) `WASI_SDK_PATH` environment variable. If not set, `scripts/build.sh` automatically downloads and unpacks `wasi-sdk-25` to the `build/` directory.

### Build Command

```bash
# Build default version (SQLite 3.54.1, year 2026)
./scripts/build.sh

# Or build a specific version:
./scripts/build.sh 3.54.1 2026

# Or use make
make build
```

This compiles:
1. `lib/libsqlite3.a`
2. `bin/sqlite3.wasm`
3. Copies headers to `include/`
4. Produces the npm distribution package in `dist/sqlite-wasi-<version>.tgz`

---

## GitHub Release Workflow

Releases are generated via GitHub Actions using manual triggers (`workflow_dispatch`):

1. Go to the **Actions** tab on your GitHub repository.
2. Select the **Build and Release** workflow.
3. Click **Run workflow**.
4. Specify:
   - **SQLite Version** (e.g. `3.54.1`)
   - **SQLite Release Year** (e.g. `2026`)
5. The workflow will build the WASI artifacts, create a GitHub release tagged `v<version>`, and upload `sqlite-wasi-<version>.tgz` as a public release asset for direct download.

---

## License

SQLite source code is in the public domain (SQLite Blessing).
Build scripts and runner files are licensed under the MIT License.
