#!/usr/bin/env bash
# Runs the Redot template's headless tests with isolated user data.
# Usage: REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh [--only=test_name]
set -euo pipefail

: "${REDOT_BIN:?Set REDOT_BIN to a Redot 26.3 editor executable}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/skills/game-baseline/templates/redot"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fresh user data for every run (APPDATA on Windows, XDG_DATA_HOME elsewhere).
mkdir -p "$WORK/appdata" "$WORK/xdg"
if command -v cygpath >/dev/null 2>&1; then
	export APPDATA="$(cygpath -w "$WORK/appdata")"
else
	export APPDATA="$WORK/appdata"
fi
export XDG_DATA_HOME="$WORK/xdg"

# Build the class cache. Some builds crash on headless import shutdown; the cache is still usable.
timeout 300 "$REDOT_BIN" --headless --path "$PROJECT" --import >"$WORK/import.log" 2>&1 || true

set +e
timeout 600 "$REDOT_BIN" --headless --audio-driver Dummy --path "$PROJECT" \
	res://tests/runner.tscn --quit-after 36000 -- "$@" 2>&1 | tee "$WORK/test.log"
status=${PIPESTATUS[0]}
set -e

# Import problems (missing classes, broken resources) often explain a failed run.
show_import_log() {
	echo "run_redot_tests: last 40 lines of the import log:" >&2
	tail -n 40 "$WORK/import.log" >&2
}

if grep -qE 'SCRIPT ERROR|^ERROR:|Parse Error|WARNING:|leaked' "$WORK/test.log"; then
	echo "run_redot_tests: engine errors or warnings in the log (see above)" >&2
	show_import_log
	exit 1
fi
if ! grep -q '^RESULT ' "$WORK/test.log"; then
	echo "run_redot_tests: runner did not finish" >&2
	show_import_log
	exit 1
fi
if [ "$status" -ne 0 ]; then
	show_import_log
fi
exit "$status"
