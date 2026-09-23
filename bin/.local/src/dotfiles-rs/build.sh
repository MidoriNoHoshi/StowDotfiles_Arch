#!/usr/bin/env bash
# Build the Rust tools and drop the binaries next to the shell scripts in
# bin/.local/bin, so `stow bin` links them into ~/.local/bin like everything else.
set -euo pipefail
cd "$(dirname "$0")"
cargo build --release
install -m755 target/release/mouse-sensitivity target/release/ambient-brightness ../../bin/
