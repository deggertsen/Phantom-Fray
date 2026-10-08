#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Tests never need XR. With a runtime installed but no headset, OpenXR start-up hangs.
"$GODOT_BIN" --headless --xr-mode off --editor --path "$PROJECT_DIR" --quit
"$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://Tests/validation_runner.gd
