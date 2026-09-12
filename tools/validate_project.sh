#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --quit
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://Tests/validation_runner.gd
