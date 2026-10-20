# Changelog

## 1.0.0 - 2026-10-20

First release.

- Skill `game-baseline`: SKILL.md with Build, Audit and Feature hook modes, a 19-item checklist
  (B01-B17 for every desktop game, C01-C02 for mouse-look and voice), a verification guide with a
  check per item, a `BASELINE.md` tracker, and engine guides for Redot and other engines.
- Redot 26.3 template: title screen, options (audio, display and controls tabs, plus a gameplay
  tab when the game has mouse-look or voice), pause menu, credits, remapping with conflict
  handling, settings store with validation and atomic saves, one-slot autosave with backup, music
  fade-in and ducking, subtitles, focus-loss pause, clean quit, static project checks, a demo game
  and a Windows export preset.
- `tests/run_redot_tests.sh`: headless tests for the template.
- `tests/check_skill.py`: lint for the skill's documents and files.
