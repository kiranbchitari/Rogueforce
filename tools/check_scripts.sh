#!/bin/sh
# Re-imports the project headless and prints any script errors.
cd "$(dirname "$0")/.." && godot --headless --path . --import 2>&1 | grep -A1 -E "SCRIPT ERROR|ERROR:|WARNING:" | grep -v "^--$"
