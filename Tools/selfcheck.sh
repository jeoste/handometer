#!/bin/bash
# Compile et lance Tools/selfcheck/main.swift contre Models.swift + StatsStore.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/selfcheck"
swiftc -O Tools/selfcheck/main.swift Sources/Handometer/Models.swift Sources/Handometer/StatsStore.swift -o "$OUT"
"$OUT"
