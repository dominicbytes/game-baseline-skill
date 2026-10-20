---
name: game-baseline
description: Use when creating, building, auditing, exporting or releasing any desktop video game or game prototype, in any engine. This includes adding or changing menus, the title screen, options or settings, pause, saving, input or key bindings, audio mixing, window or display modes, frame rate, quitting, logging or Windows builds. Also use when someone asks what basic features a game is missing, how to make a game feel polished or finished, or mentions VSync, FPS caps, volume sliders, fullscreen or resolution options, remapping controls, pause menus, alt-tab behaviour, OBS or streaming capture, standalone builds, version numbers or crash-safe saves.
license: MIT
metadata:
  version: "1.0.0"
  repository: "https://github.com/dominicbytes/game-baseline-skill"
---

# Game baseline

## Overview

Every desktop game, however small, needs the same technical basics and menus: a pause menu that
actually stops the game, volume sliders, display options, remappable controls, a clean quit, a
standalone build. Players expect them, and reviewers notice when one is missing. This skill makes
sure none are forgotten.

**Scope: technical basics and standard menus only.** This skill never changes game design or level
design: not difficulty, pacing, tutorials, story, art direction or music choice.

Redot is the main supported engine and ships with a tested drop-in template
(`templates/redot/`). The checklist itself is engine-neutral.

Core principle: **an item is only "pass" after its check has actually been run.** Reading code is
not verifying behaviour.

## Relationship to the accessibility skill

This skill overlaps on purpose with
[game-accessibility-skill](https://github.com/dominicbytes/game-accessibility-skill): remapping,
volume, pause and subtitles appear in both. This skill states each item in one line and sets up the
structure (menus, settings store, pause, quit). The accessibility skill adds depth and more options
into the same settings store. The two never contradict each other, and setting key names are shared.

## Modes

| Mode | When | Do |
| --- | --- | --- |
| **Build** | New project or prototype | Redot: install the template ([references/engines/redot.md](references/engines/redot.md)). Other engines: follow [references/engines/other.md](references/engines/other.md). Create `BASELINE.md`. |
| **Audit** | Existing game, milestone, pre-release, after reviewer feedback | Walk every item and record status with evidence. Redot: run `baseline/tools/check_project.gd` first for the static checks. |
| **Feature hook** | Adding or changing a menu, scene transition, save, audio, input or window behaviour | Re-check only the items that change touches. |

## Workflow

1. **Open or create `BASELINE.md`** at the game's root from [assets/BASELINE.md](assets/BASELINE.md).
   It records each item's status and evidence across sessions.
2. **Decide the conditional items** from what the game contains (C01 mouse-look, C02 voice). Record
   the decision.
3. **Implement what is missing.** Use the requirements in
   [references/checklist.md](references/checklist.md) and the engine guide for this project.
4. **Verify** each item with [references/verification.md](references/verification.md). Run the
   game. Exercise the behaviour.
5. **Report honestly.** For each item: pass, fail, blocked (and why), n/a, or not tested.

For a game jam or a deadline under a month, still ship every must-have: most are an hour or less
with the template. Cut nothing silently; record anything deferred as "not tested" or "fail" with a
reason.

## The checklist

Must-haves (every desktop game):

| ID | Item | Requirement in one line |
| --- | --- | --- |
| B01 | Frame pacing | VSync on by default; frame cap 60 by default and never unlimited by default; cap is a setting; game speed independent of frame rate. |
| B02 | Volume | Master, Music and SFX sliders on separate buses; safe default levels; reachable before any loud sound plays. |
| B03 | Display | Windowed, fullscreen and exclusive fullscreen; window size choice; readable default window on the primary monitor; menus and gameplay scale the same way. |
| B04 | Streaming capture | OBS Game Capture shows the game and "Capture audio" picks up its sound; the game never resizes itself mid-session. |
| B05 | Pause | Pause stops gameplay, physics, timers, animations, transitions and gameplay sounds; menus keep working; resume continues exactly. |
| B06 | Options access | Options reachable from the title and from pause; opening options never loses progress. |
| B07 | Standalone Windows build | Runs on Windows 10 x64 from a freshly extracted zip; data embedded; no console window; no installer or admin rights. |
| B08 | Keyboard and mouse | Keyboard and mouse can finish the whole game and every menu; visible keyboard focus; UI clicks never also trigger gameplay. |
| B09 | Remapping | Every gameplay action remappable to keys and mouse buttons, with conflict handling and reset; every prompt shows the live binding. |
| B10 | Default keys and labels | Conventional defaults bound by physical key position; plain labels such as "Left Mouse" and "Space". |
| B11 | Quit and back | Quit to Desktop on title and pause; confirm anything that loses progress; Esc backs out one level and never dumps to the title. |
| B12 | Settings integrity | Each setting changes only itself; settings saved, validated and applied at startup; reset per category. |
| B13 | Focus loss | Alt-tab or losing focus pauses gameplay and releases the mouse cursor. |
| B14 | Saving | Autosave; crash-safe writes with a backup; a corrupt save never crashes the game. |
| B15 | Clean quit | Every way of quitting, including the window's close button, exits without errors or leaks. |
| B16 | Hit areas | Clicks land on the button under the cursor at every window size and mode. |
| B17 | Version and log | Version shown on the title screen; release builds write a log file. |

Conditional:

| ID | Condition | Item |
| --- | --- | --- |
| C01 | Mouse-look, aiming or pointer-driven camera | Look sensitivity slider plus invert X and invert Y. |
| C02 | Spoken dialogue or voice | Voice volume slider on its own bus; subtitles, on by default. |

## Status and reporting

Use exactly these statuses in `BASELINE.md` and in reports: **pass / fail / blocked / n/a / not
tested**, each with a one-line evidence note (the command run, the screen checked, the log line
seen).

- Never mark an item pass from reading code alone.
- "Blocked" names the missing prerequisite (for example "no second monitor to test B03 placement").
- A finished report lists every item, not only the ones that passed.

## Red flags

| Thought | Reality |
| --- | --- |
| "It's only a jam game" | Jam reviewers hit missing volume control and missing pause within the first minute. |
| "The engine handles VSync" | Defaults vary by engine and project; check the setting and the cap. |
| "Pause just sets a flag" | Timers, tweens, transitions and looping sounds keep running unless handled. |
| "I tested it in the editor" | Exported builds differ: missing data files, console windows, different input scaling. |
| "Remapping can come later" | Later means prompts, tutorials and menus all show stale keys. Build it with input. |
