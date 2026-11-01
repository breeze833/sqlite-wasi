.PHONY: all build pack clean

all: build

build:
	./scripts/build.sh

pack:
	npm pack --pack-destination=dist

clean:
	rm -rf build dist lib include bin/sqlite3.wasm
