# Baseline status

Tracks the [game-baseline checklist](https://github.com/dominicbytes/game-baseline-skill) for this
template's demo game.

- **Game:** Baseline Demo (the template itself)
- **Engine and version:** Redot 26.3-stable, GL Compatibility renderer
- **Build checked:** 1.0.0, Windows x86_64 release export with the official 26.3-stable templates, 2026-10-20
- **Checked by:** automated headless tests (97), background-window screenshots at 4 sizes, an
  exported-build check script, OBS Studio 32.1.2 capture runs, and live window checks on Windows 10

Statuses: **pass / fail / blocked / n/a / not tested**.

## Conditional items

| ID | Applies? | Reason |
| --- | --- | --- |
| C01 | yes | The demo has hold-to-aim mouse-look so the option can be exercised. |
| C02 | yes | The demo plays a voice line with a subtitle so the option can be exercised. |

## Items

| ID | Item | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| B01 | Frame pacing | pass | Project defaults (VSync on, 60 cap) pass `check_project.gd`; the display tab offers 30/60/120/144/Match display/Unlimited; movement covers the same distance at 30 and 144 steps per second (test). | VSync itself was not measured on a high-refresh monitor. |
| B02 | Volume | pass | Bus, dB-mapping, "Muted" label and title fade-in tests pass; OBS meter peak -12.1 dBFS and recording mean -18.3 dB with the default mix. | |
| B03 | Display | pass | Fresh run opened 1920×1080 centred on a 2560×1440 primary monitor; borderless and exclusive fullscreen ran at 2560×1440; menu screenshots clean at 1280×720, 1366×768, 1920×1080 and 2560×1080. | |
| B04 | Streaming capture | pass | OBS Game Capture with Capture audio, windowed and fullscreen: picture present and changing, audio meter -12.1 dBFS, recording mean -18.3 dB; control run without Capture audio recorded silence (-91 dB); game window size and position unchanged while hooked. | Tested with the GL Compatibility renderer only. |
| B05 | Pause | pass | Tests: timer, tween and looping sound stop, music ducks to -10 dB and keeps playing, resume restores. Live: the timer stayed frozen behind the pause menu. | |
| B06 | Options access | pass | Options opened from the title and from pause in the exported build; Esc returned to pause with the game state unchanged (test and live). | |
| B07 | Standalone Windows build | pass | Export produced one `BaselineDemo.exe` (data embedded, no console wrapper, PE subsystem GUI); it ran and quit cleanly from a fresh zip extracted into a folder with a space and an accented character, with the download mark set. | A double-click launch from Explorer (SmartScreen prompt) was not tested; the exe is unsigned. |
| B08 | Keyboard and mouse | pass | Tests: every control is focusable and reachable by Tab, arrow keys move focus, a HUD click does not ping. Screenshots show the focus outline on every screen. | |
| B09 | Remapping | pass | Tests: rebind to key and mouse button, conflict swap and cancel, Esc refused, reset with confirmation, persistence, prompts follow the live binding. | |
| B10 | Default keys and labels | pass | Defaults on physical keys (WASD/arrows, Space, E, mouse buttons, Esc for pause); labels such as "Left Arrow" and "Left Mouse" in the controls tab and HUD. | Not tested with a non-QWERTY keyboard layout. |
| B11 | Quit and back | pass | Live: Quit to Desktop asked first with Cancel focused, then exited; tests cover Return to Title, New Game over a save, Esc routing and the title doing nothing on Esc. | |
| B12 | Settings integrity | pass | Tests: each key applies only itself, persistence round trip, corrupt values and an unparseable file fall back, backup used when the main file is corrupt, per-category reset. | |
| B13 | Focus loss | pass | Live on the exported build: minimizing the game during play paused it (`[baseline] paused (focus lost)` in the log); tests cover the cursor release and focus loss during a transition. | |
| B14 | Saving | pass | Tests: atomic write with backup, corrupt main falls back to backup, stale temp cleanup, Continue only with a usable save. | A process kill mid-session was not tested live. |
| B15 | Clean quit | pass | Exported build: Quit button and window close request both exited in about 0.5 s; logs show `[baseline] quitting` and no errors or leaks. | |
| B16 | Hit areas | pass | Hover tests at 4 sizes; in the exported build, posted mouse messages hit the intended buttons at 1920×1080 windowed and 2560×1440 borderless and exclusive fullscreen. | A pass with injected real mouse input was blocked: this test session's injected input did not reach the window. |
| B17 | Version and log | pass | "Version 1.0.0" on the title; the release build wrote `logs/godot.log` in its user data. | |
| C01 | Mouse-look | pass | Tests: sensitivity scales look movement, horizontal and vertical invert flip their own axis, aim captures and releases the mouse. | Not exercised live. |
| C02 | Voice | pass | Tests: Voice bus and slider, subtitles on by default, hidden when off, paused with the game; screenshot shows the subtitle below the menus. | |

## Open issues

- B16: repeat the real-mouse click pass on a normal desktop session (one click on Options and Back).
- B07: launch once from Explorer to see the SmartScreen prompt for the unsigned exe.
