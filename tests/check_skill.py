#!/usr/bin/env python3
"""Lint for the game-baseline skill repository.

Run from the repository root (the script changes into it anyway):

    python tests/check_skill.py              run every check, exit 0 when clean
    python tests/check_skill.py --self-test  check the scanners on in-memory strings

Standard library only. Failures print as `FAIL <file>: <reason>`.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKILL_DIR = Path("skills/game-baseline")
SKILL_MD = SKILL_DIR / "SKILL.md"
CHECKLIST = SKILL_DIR / "references/checklist.md"
VERIFICATION = SKILL_DIR / "references/verification.md"
BASELINE_TEMPLATE = SKILL_DIR / "assets/BASELINE.md"
REDOT_GUIDE = SKILL_DIR / "references/engines/redot.md"
SETTINGS_GD = SKILL_DIR / "templates/redot/baseline/core/baseline_settings.gd"
DENYLIST = Path("tests/.denylist.local.txt")
SELF = Path("tests/check_skill.py")

EXPECTED_IDS = [f"B{n:02d}" for n in range(1, 18)] + ["C01", "C02"]
ID_FILES = [SKILL_MD, CHECKLIST, VERIFICATION, BASELINE_TEMPLATE]
ACCESSIBILITY_URL = "https://github.com/dominicbytes/game-accessibility-skill"
BINARY_SUFFIXES = {
	".wav", ".png", ".tpz", ".exe", ".ogg", ".mp3", ".jpg", ".jpeg",
	".zip", ".pck", ".ttf", ".otf",
}

# Literals are built by concatenation so this file does not match its own scan.
_NOREPLY = "noreply" + "@" + "anthropic" + ".com"
FORBIDDEN: list[tuple[str, re.Pattern[str]]] = [
	("drive-letter path", re.compile(r"(?<![A-Za-z])[A-Za-z]:[\\/]")),
	("user folder path", re.compile("Us" + r"ers[\\/]")),
	("home folder path", re.compile("/ho" + "me/")),
	(
		"AI co-author trailer",
		re.compile("Co-Authored" + r"-By:.*(Cl" + "aude|Co" + "dex|G" + "PT)", re.IGNORECASE),
	),
	(
		"AI generated-with line",
		re.compile("Generated " + r"with .*(Cl" + "aude|Co" + "dex|Chat" + "GPT)", re.IGNORECASE),
	),
	("AI noreply address", re.compile(re.escape(_NOREPLY), re.IGNORECASE)),
]

failures: list[str] = []


def fail(where: str | Path, reason: str) -> None:
	failures.append(f"FAIL {Path(where).as_posix()}: {reason}")


# ---------------------------------------------------------------- helpers

def strip_fences(text: str) -> list[tuple[int, str]]:
	"""Return (line number, line) pairs outside fenced code blocks."""
	out: list[tuple[int, str]] = []
	fence = ""
	for number, line in enumerate(text.splitlines(), 1):
		marker = line.lstrip()[:3]
		if marker in ("```", "~~~"):
			if not fence:
				fence = marker
			elif marker == fence:
				fence = ""
			continue
		if not fence:
			out.append((number, line))
	return out


def slugify(heading: str) -> str:
	"""GitHub heading slug: lowercase, spaces to hyphens, punctuation dropped."""
	text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", heading)  # links keep their text
	text = text.replace("`", "").strip().lower()
	text = re.sub(r"[^\w\- ]", "", text)
	return text.replace(" ", "-")


def heading_slugs(text: str) -> set[str]:
	slugs: set[str] = set()
	seen: dict[str, int] = {}
	for _, line in strip_fences(text):
		match = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
		if not match:
			continue
		slug = slugify(match.group(1))
		count = seen.get(slug, 0)
		seen[slug] = count + 1
		slugs.add(slug if count == 0 else f"{slug}-{count}")
	return slugs


LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def markdown_links(text: str) -> list[tuple[int, str, str]]:
	"""(line, link text, target) for inline links outside code."""
	links = []
	for number, line in strip_fences(text):
		line = re.sub(r"`[^`]*`", "", line)
		for match in LINK_RE.finditer(line):
			links.append((number, match.group(1), match.group(2)))
	return links


def find_ids(text: str) -> set[str]:
	"""B/C item IDs, counted only in table rows and headings."""
	ids: set[str] = set()
	for _, line in strip_fences(text):
		stripped = line.lstrip()
		if stripped.startswith("|") or stripped.startswith("#"):
			ids.update(re.findall(r"\b[BC]\d{2}\b", line))
	return ids


def find_forbidden(text: str) -> list[tuple[int, str]]:
	hits = []
	for number, line in enumerate(text.splitlines(), 1):
		for label, pattern in FORBIDDEN:
			if pattern.search(line):
				hits.append((number, label))
	return hits


def load_denylist(text: str) -> list[re.Pattern[str]]:
	patterns = []
	for line in text.splitlines():
		word = line.strip()
		if not word or word.startswith("#"):
			continue
		patterns.append(re.compile(r"(?<!\w)" + re.escape(word) + r"(?!\w)", re.IGNORECASE))
	return patterns


def find_denylisted(text: str, patterns: list[re.Pattern[str]]) -> list[int]:
	"""Line numbers only. The matched word is never returned or printed."""
	return [n for n, line in enumerate(text.splitlines(), 1) if any(p.search(line) for p in patterns)]


def read_text(path: Path) -> str | None:
	"""File text, or None for binary files."""
	if path.suffix.lower() in BINARY_SUFFIXES:
		return None
	data = path.read_bytes()
	if b"\0" in data:
		return None
	return data.decode("utf-8", errors="replace")


def tracked_files() -> list[Path]:
	result = subprocess.run(
		["git", "ls-files", "--cached", "--others", "--exclude-standard"],
		capture_output=True, text=True, check=True, encoding="utf-8",
	)
	return [Path(line) for line in result.stdout.splitlines() if line and Path(line).is_file()]


def markdown_files() -> list[Path]:
	files = sorted(Path("skills").rglob("*.md"))
	for extra in ("README.md", "ACKNOWLEDGEMENTS.md", "CHANGELOG.md"):
		if Path(extra).is_file():
			files.append(Path(extra))
	return files


# ----------------------------------------------------------------- checks

def check_frontmatter() -> None:
	if not SKILL_MD.is_file():
		fail(SKILL_MD, "missing")
		return
	text = SKILL_MD.read_text(encoding="utf-8")
	match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
	if not match:
		fail(SKILL_MD, "no YAML frontmatter")
		return
	fields = {}
	for line in match.group(1).splitlines():
		key = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
		if key:
			fields[key.group(1)] = key.group(2).strip().strip('"')
	for required in ("name", "description", "license"):
		if not fields.get(required):
			fail(SKILL_MD, f"frontmatter lacks `{required}`")
	if fields.get("name") and fields["name"] != SKILL_MD.parent.name:
		fail(SKILL_MD, f"name `{fields['name']}` does not match folder `{SKILL_MD.parent.name}`")


def check_links() -> None:
	slug_cache: dict[Path, set[str]] = {}

	def slugs_of(path: Path) -> set[str]:
		if path not in slug_cache:
			slug_cache[path] = heading_slugs(path.read_text(encoding="utf-8"))
		return slug_cache[path]

	for md in markdown_files():
		text = md.read_text(encoding="utf-8")
		for number, _label, target in markdown_links(text):
			if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target):
				continue  # http(s), mailto, res://
			path_part, _, anchor = target.partition("#")
			dest = md if not path_part else Path(os.path.normpath(md.parent / path_part))
			if path_part and (dest.is_absolute() or dest.parts[:1] == ("..",)):
				fail(md, f"line {number}: link `{target}` leaves the repository")
				continue
			if not dest.exists():
				fail(md, f"line {number}: link `{target}` does not resolve")
				continue
			if anchor and dest.suffix == ".md" and anchor.lower() not in slugs_of(dest):
				fail(md, f"line {number}: anchor `#{anchor}` not found in {dest.as_posix()}")


def check_ids() -> None:
	expected = set(EXPECTED_IDS)
	for path in ID_FILES:
		if not path.is_file():
			fail(path, "missing")
			continue
		ids = find_ids(path.read_text(encoding="utf-8"))
		missing = sorted(expected - ids)
		if missing:
			fail(path, "missing item IDs " + ", ".join(missing))
	for md in sorted(Path("skills").rglob("*.md")):
		extra = sorted(find_ids(md.read_text(encoding="utf-8")) - expected)
		if extra:
			fail(md, "unknown item IDs " + ", ".join(extra))


def check_forbidden_and_denylist() -> None:
	patterns: list[re.Pattern[str]] = []
	if DENYLIST.is_file():
		patterns = load_denylist(DENYLIST.read_text(encoding="utf-8"))
	for path in tracked_files():
		text = read_text(path)
		if text is None:
			continue
		for number, label in find_forbidden(text):
			fail(path, f"line {number}: {label}")
		if patterns and path.as_posix() not in (SELF.as_posix(), DENYLIST.as_posix()):
			for number in find_denylisted(text, patterns):
				fail(path, f"line {number}: local denylist term")  # never print the term


def check_settings_keys() -> None:
	if not SETTINGS_GD.is_file():
		fail(SETTINGS_GD, "missing")
		return
	registered = set(re.findall(r'register_key\("([^"]+)"', SETTINGS_GD.read_text(encoding="utf-8")))
	if not registered:
		fail(SETTINGS_GD, "no register_key calls found")
	key_re = re.compile(r"(audio|display|input|game|subtitles)\.[a-z_.]+")
	for md in (CHECKLIST, REDOT_GUIDE):
		for number, line in strip_fences(md.read_text(encoding="utf-8")):
			for span in re.findall(r"`([^`]+)`", line):
				if key_re.fullmatch(span) and span not in registered:
					fail(md, f"line {number}: settings key `{span}` is not registered in {SETTINGS_GD.name}")


def check_accessibility_links() -> None:
	for md in markdown_files():
		for number, label, target in markdown_links(md.read_text(encoding="utf-8")):
			if "accessibility" in (label + target).lower() and not target.startswith(ACCESSIBILITY_URL):
				fail(md, f"line {number}: accessibility skill link `{target}` must use {ACCESSIBILITY_URL}")


def run_checks() -> int:
	os.chdir(REPO)
	check_frontmatter()
	check_links()
	check_ids()
	check_forbidden_and_denylist()
	check_settings_keys()
	check_accessibility_links()
	for line in failures:
		print(line)
	if failures:
		print(f"{len(failures)} problem(s) found")
		return 1
	print("OK: all skill checks passed")
	return 0


# -------------------------------------------------------------- self-test

def run_self_test() -> int:
	problems: list[str] = []

	def expect(name: str, condition: bool) -> None:
		if not condition:
			problems.append(name)

	drive = "C" + ":" + "\\" + "work"
	drive_fwd = "d" + ":" + "/" + "work"
	expect("drive path hits", bool(find_forbidden(drive)) and bool(find_forbidden(drive_fwd)))
	expect("res:// is clean", not find_forbidden("res://baseline/core"))
	expect("user:// is clean", not find_forbidden("user://settings.json"))
	expect("https:// is clean", not find_forbidden("see https://example.com/x"))
	expect("users folder hits", bool(find_forbidden("Us" + "ers/someone/file")))
	expect("home folder hits", bool(find_forbidden("cd /ho" + "me/someone")))
	expect("trailer hits", bool(find_forbidden("Co-Authored" + "-By: Cl" + "aude <x@y.z>")))
	expect("generated line hits", bool(find_forbidden("Generated " + "with [Cl" + "aude Code](https://x.y)")))
	expect("noreply hits", bool(find_forbidden("mail " + _NOREPLY)))
	expect("install mention is clean", not find_forbidden("Copy the folder for Claude Code projects."))
	expect("hit reports its line", find_forbidden("ok\nfine\n" + drive)[0][0] == 3)

	patterns = load_denylist("# comment\nSecretGame\n\nsecret two\n")
	expect("denylist whole word", find_denylisted("I like secretgame a lot", patterns) == [1])
	expect("denylist phrase", find_denylisted("a\nSECRET TWO here", patterns) == [2])
	expect("denylist ignores substrings", not find_denylisted("secretgames and xsecretgame", patterns))
	expect("denylist ignores comment lines", not find_denylisted("comment", patterns))
	expect("denylist returns only line numbers", all(isinstance(n, int) for n in find_denylisted("secretgame", patterns)))

	expect("slug basic", slugify("B07 Standalone Windows build") == "b07-standalone-windows-build")
	expect("slug punctuation", slugify("Items & `code`, (v2)!") == "items--code-v2")
	slugs = heading_slugs("# One\n\n```\n# not a heading\n```\n\n## One\n")
	expect("duplicate headings", slugs == {"one", "one-1"})

	md = "# T\n| B01 | x |\n## C02 Voice\nplain B03 text\n```\n| B04 |\n```\ncolour B05 here\n"
	expect("ids only in rows and headings", find_ids(md) == {"B01", "C02"})
	expect("links skip code", markdown_links("`[a](b.md)` and [c](d.md)") == [(1, "c", "d.md")])

	for problem in problems:
		print(f"SELF-TEST FAIL: {problem}")
	if problems:
		return 1
	print("OK: self-test passed")
	return 0


if __name__ == "__main__":
	if "--self-test" in sys.argv[1:]:
		sys.exit(run_self_test())
	sys.exit(run_checks())
