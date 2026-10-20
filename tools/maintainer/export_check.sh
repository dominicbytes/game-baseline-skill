#!/usr/bin/env bash
# Maintainer check for B07, B15 and B17: export the Redot template for Windows,
# run it from a freshly extracted zip, and inspect the exe and its log.
#
# Usage:
#   REDOT_BIN=<redot editor executable> tools/maintainer/export_check.sh <export templates .tpz> <scratch dir>
#
# Everything is written under <scratch dir>; the real user app-data folder is never touched.
# Optional: DENYLIST=<file> lists terms (one per line, # comments) that must not appear in the exe.
set -euo pipefail

: "${REDOT_BIN:?Set REDOT_BIN to a Redot 26.3 editor executable}"
TPZ="${1:?Pass the official export templates .tpz}"
SCRATCH="${2:?Pass a scratch directory}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$ROOT/skills/game-baseline/templates/redot"
EXE_NAME="BaselineDemo.exe"

winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
fail() { echo "FAIL $*" >&2; exit 1; }
pass() { echo "PASS $*"; }

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/export_appdata" "$SCRATCH/build" "$SCRATCH/run_appdata"

# Self-contained editors ignore APPDATA and would use their own data folder.
EDITOR_DIR="$(dirname "$REDOT_BIN")"
if ls "$EDITOR_DIR"/_sc_ "$EDITOR_DIR"/._sc_ >/dev/null 2>&1; then
	fail "editor is in self-contained mode (_sc_ file); export templates in APPDATA would be ignored"
fi

# 1. Install only the Windows templates into the scratch app data.
python - "$TPZ" "$SCRATCH/export_appdata" <<'PY'
import os, sys, zipfile
tpz, appdata = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(tpz) as z:
    version = z.read("templates/version.txt").decode().strip()
    target = os.path.join(appdata, "Redot", "export_templates", version)
    os.makedirs(target, exist_ok=True)
    for name in z.namelist():
        base = name.rsplit("/", 1)[-1]
        if name.startswith("templates/") and (base == "version.txt" or base.startswith("windows_")):
            with open(os.path.join(target, base), "wb") as out:
                out.write(z.read(name))
print("templates", version)
PY

# 2. Import, then export a release build.
export APPDATA="$(winpath "$SCRATCH/export_appdata")"
timeout 300 "$REDOT_BIN" --headless --path "$PROJECT" --import >"$SCRATCH/import.log" 2>&1 || true
timeout 600 "$REDOT_BIN" --headless --path "$PROJECT" --export-release "Windows Desktop" \
	"$(winpath "$SCRATCH/build/$EXE_NAME")" >"$SCRATCH/export.log" 2>&1 \
	|| { tail -40 "$SCRATCH/export.log"; fail "export"; }
[ -f "$SCRATCH/build/$EXE_NAME" ] || fail "no $EXE_NAME produced"
[ -z "$(ls "$SCRATCH/build" | grep -v "^$EXE_NAME\$")" ] || fail "extra files next to the exe: $(ls "$SCRATCH/build")"
pass "B07 export produced a single $EXE_NAME (no .pck, no console wrapper)"

python - "$SCRATCH/build/$EXE_NAME" <<'PY' || fail "B07 PE subsystem is not Windows GUI"
import struct, sys
data = open(sys.argv[1], "rb").read(4096)
pe = struct.unpack_from("<I", data, 0x3C)[0]
subsystem = struct.unpack_from("<H", data, pe + 24 + 68)[0]
print("PE subsystem", subsystem)
sys.exit(0 if subsystem == 2 else 1)
PY
pass "B07 exe is a GUI program (no console window)"

# 3. Zip, extract to a folder with a space and a non-ASCII character, mark as downloaded, run.
( cd "$SCRATCH/build" && python -c "import zipfile; zipfile.ZipFile('../BaselineDemo.zip','w',zipfile.ZIP_DEFLATED).write('$EXE_NAME')" )
RUN_DIR="$SCRATCH/Test Build é"
mkdir -p "$RUN_DIR"
python -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$SCRATCH/BaselineDemo.zip" "$RUN_DIR"
if command -v powershell >/dev/null 2>&1; then
	powershell -NoProfile -Command "Set-Content -LiteralPath '$(winpath "$RUN_DIR/$EXE_NAME")' -Stream Zone.Identifier -Value \"[ZoneTransfer]\`r\`nZoneId=3\"" \
		&& echo "note: download mark set (launching from bash does not trigger SmartScreen; check an Explorer launch by hand)"
fi
export APPDATA="$(winpath "$SCRATCH/run_appdata")"
set +e
timeout 60 "$RUN_DIR/$EXE_NAME" --headless --audio-driver Dummy -- --baseline-quit-after=3 >"$SCRATCH/run.log" 2>&1
status=$?
set -e
[ "$status" -eq 0 ] || { cat "$SCRATCH/run.log"; fail "B07 extracted build exited with $status"; }
pass "B07 extracted build ran and quit with exit 0"

LOG="$(find "$SCRATCH/run_appdata" -path '*logs*' -name '*.log' | head -1)"
[ -n "$LOG" ] || fail "B17 no log file written under the game's user data"
pass "B17 release build wrote a log file ($(basename "$LOG"))"
grep -q '\[baseline\] quitting' "$LOG" || fail "B15 log does not show the clean quit"
if grep -nE 'ERROR|WARNING|leaked|still in use' "$LOG" "$SCRATCH/run.log"; then
	fail "B15 errors or warnings in the run log"
fi
pass "B15 clean quit with no errors or leaks in the log"

# 4. The exe must not carry local paths or denylisted terms.
python - "$SCRATCH/build/$EXE_NAME" "${DENYLIST:-}" <<'PY' || fail "exe contains a local path or denylisted term"
import os, re, sys
data = open(sys.argv[1], "rb").read()
terms = ["Users\\", "Users/"]
if sys.argv[2] and os.path.exists(sys.argv[2]):
    # Short single words also occur in engine code (function names), so the binary scan only
    # uses distinctive terms; the lint already scans every project file that goes into the PCK.
    terms += [l.strip() for l in open(sys.argv[2], encoding="utf-8")
              if l.strip() and not l.startswith("#") and (" " in l.strip() or len(l.strip()) >= 8)]
bad = 0
for term in terms:
    for enc in ("utf-8", "utf-16-le"):
        if re.search(re.escape(term.encode(enc)), data, re.IGNORECASE):
            bad += 1
            print("hit (%s)" % enc)
sys.exit(1 if bad else 0)
PY
pass "exe has no local paths or denylisted terms (ASCII and UTF-16)"
