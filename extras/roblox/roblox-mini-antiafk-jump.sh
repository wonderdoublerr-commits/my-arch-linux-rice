#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACTION=jump exec "$SCRIPT_DIR/roblox-mini-antiafk.sh" "$@"

