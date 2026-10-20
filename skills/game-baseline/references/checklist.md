# Baseline checklist

Each item has the requirement, why it matters, and where its check lives. The "why" notes are
lessons from prior Redot Game Jams: patterns seen across many reviewed entries, not any one game.

Settings keys are shared with the
[game-accessibility skill](https://github.com/dominicbytes/game-accessibility-skill) where the two
overlap, so both skills can use one settings file. Keys that are not in that skill's registry
(for example `game.display.window_size`) use the `game.` prefix so they never clash with a future
registry key. "See also" lines name that skill's items as
`accessibility <ID>` (for example accessibility C29), so they are never confused with this
skill's own IDs such as C01 and C02.

## B01 Frame pacing

**Requirement**
- VSync is on by default (`game.display.vsync`).
- The frame cap defaults to 60 and is never unlimited by default (`game.display.frame_cap`). Offer 30, 60,
  120, 144, Match display and Unlimited.
- Explain in the menu that players on 120 Hz or faster screens should pick Match display: a 60 cap
  on a 144 Hz screen can judder.
- Game speed, physics and timers are independent of frame rate (multiply by delta, or use a fixed
  physics step).

**Why:** jam reviewers repeatedly saw entries running uncapped, spinning the GPU and fans, and
asked for VSync by default. Timers tied to frame rate made a game easier or harder depending on
the player's monitor.

**Verify:** [verification.md#b01-frame-pacing](verification.md#b01-frame-pacing)

## B02 Volume

**Requirement**
- Separate Master, Music and SFX sliders (`audio.master`, `audio.music`, `audio.sfx`), each on its
  own bus, 0-100 %, shown as a percentage and "Muted" at 0.
- Safe defaults: Master 70 %, Music 60 %, SFX 80 %. A limiter on the master bus.
- Volume is reachable before any loud sound: Options is on the first title menu, and title music
  fades in from silence over at least 2 seconds.

**Why:** loud audio with no in-game control was the most common complaint across reviewed jam
entries. Reviewers reached for their own volume knob before they could play, and music that
started before the options menu was reachable made the first impression painful.

**See also:** accessibility H01 (master volume).
**Verify:** [verification.md#b02-volume](verification.md#b02-volume)

## B03 Display

**Requirement**
- Window modes: Windowed, Fullscreen (borderless, desktop resolution) and Exclusive fullscreen
  (`game.display.window_mode`).
- Window size presets that fit the current screen, only active in Windowed
  (`game.display.window_size`). Fullscreen always uses the desktop resolution.
- The default window is readable: the largest preset within 85 % of the screen, centred on the
  primary monitor.
- Menus and gameplay use one scaling rule, tested at 1280×720, 1366×768, 1920×1080 and an
  ultrawide size.

**Why:** reviewed jam entries opened in tiny windows, on the wrong monitor, with menus that did not
fill the screen or a gameplay area boxed into a corner. Several were hard to judge at all.

**Verify:** [verification.md#b03-display](verification.md#b03-display)

## B04 Streaming capture

**Requirement**
- OBS Game Capture shows the game, in windowed and fullscreen.
- With "Capture audio" enabled on the Game Capture source, OBS picks up the game's sound without
  desktop audio.
- The game never changes its own window size or mode during a session, except when the player
  changes that setting.

**Why:** streams and recorded reviews are how many indie and jam games get seen. Games that
resized themselves mid-session or could not be captured cleanly made that harder.

**Verify:** [verification.md#b04-streaming-capture](verification.md#b04-streaming-capture)

## B05 Pause

**Requirement**
- Pause stops gameplay, physics, timers, animations, tweens, scene transitions and gameplay sounds,
  including loops.
- Music keeps playing at a lower volume. Menus keep working.
- Resume continues exactly where the game stopped.

**Why:** reviewed jam entries with no pause, or a pause that let timers run, lost players who
needed to step away or change a setting. A countdown that kept running during a tutorial ended
one run before it started.

**See also:** accessibility D27 (pause gameplay and cinematics).
**Verify:** [verification.md#b05-pause](verification.md#b05-pause)

## B06 Options access

**Requirement**
- Options is reachable from the title screen and from the pause menu.
- Opening and closing Options never loses progress or restarts the level.

**Why:** jam reviewers looked for settings on the start screen and in pause, and gave up on entries
that hid them. One pattern was leaving to the title just to lower a setting, which threw away the
level.

**Verify:** [verification.md#b06-options-access](verification.md#b06-options-access)

## B07 Standalone Windows build

**Requirement**
- A Windows 10 x64 build runs from a freshly extracted zip in a new folder, including a folder name
  with spaces or non-ASCII characters.
- The build is self-contained: the zipped folder runs as-is, with no loose data file that must
  keep a matching name.
- No console window opens. No installer or admin rights are needed.
- Other platforms are optional extras; Windows desktop is the baseline.

**Why:** reviewed jam entries failed to start because a data file was missing or had been renamed,
crashed on first launch, or were browser-only and could not be played in a reviewer's normal
setup.

**Verify:** [verification.md#b07-standalone-windows-build](verification.md#b07-standalone-windows-build)

## B08 Keyboard and mouse

**Requirement**
- Keyboard and mouse can finish the whole game and every menu. A gamepad is optional.
- Every menu shows a visible keyboard focus. Arrows and Tab move focus, Enter or Space activates,
  Esc backs out.
- A click that hits a UI element never also triggers a gameplay action.

**Why:** some reviewed jam entries needed a controller or a second player and could not be
reviewed at all. Others had menus that only worked by mouse, or a HUD click that also fired the
player's weapon.

**See also:** accessibility V32 (persistent focus appearance).
**Verify:** [verification.md#b08-keyboard-and-mouse](verification.md#b08-keyboard-and-mouse)

## B09 Remapping

**Requirement**
- Every gameplay action can be rebound to keys and mouse buttons (`game.input.bindings`).
- Binding a key that another action uses asks to swap or cancel. A reset button restores defaults
  after confirming.
- Every prompt, tutorial line and HUD hint shows the live binding.
- Menu navigation keys stay fixed so menus always work, and Esc is reserved for pause and back.

**Why:** remapping materially improved reviewers' first impressions when it existed, but partial
remapping hurt: mouse buttons that could not be bound, and tutorials that kept showing the old key.

**See also:** accessibility M01 (full action remapping).
**Verify:** [verification.md#b09-remapping](verification.md#b09-remapping)

## B10 Default keys and labels

**Requirement**
- Conventional defaults: WASD and arrows to move, Space, E to interact, Esc to pause, mouse
  buttons for primary actions.
- Bind by physical key position so other keyboard layouts get the same positions.
- Labels use the player's layout and plain names: "W", "Space", "Left Mouse", "Left Arrow". Never
  ambiguous names like "Left".

**Why:** unusual defaults were the main source of difficulty in several reviewed jam entries, and
labels like "Left" (arrow key or mouse button?) sent reviewers guessing.

**Verify:** [verification.md#b10-default-keys-and-labels](verification.md#b10-default-keys-and-labels)

## B11 Quit and back

**Requirement**
- Quit to Desktop on the title screen and in the pause menu.
- Quit from pause, Return to Title and New Game over a save ask for confirmation and say what will
  be lost. Focus starts on Cancel.
- Quit from the title screen has nothing to lose, so it quits without asking.
- Esc backs out one menu level, opens pause during gameplay, and does nothing on the title screen.
  It never drops the player to the title.
- Closing the window (close button or Alt+F4) quits cleanly without a dialog.

**Why:** reviewers closed jam entries with Alt+F4 because there was no way out, and lost progress
when Esc went straight to the title.

**See also:** accessibility C29 (destructive-action confirmation).
**Verify:** [verification.md#b11-quit-and-back](verification.md#b11-quit-and-back)

## B12 Settings integrity

**Requirement**
- Each setting changes only its own property. Toggling VSync never resizes the window.
- Settings are saved to user data, validated on load (bad values fall back to defaults; a corrupt
  file never crashes the game) and applied at startup.
- Each settings category has a reset button. Saves are debounced and flushed on quit.

**Why:** a jam entry's window shrank mid-stream when a display toggle reapplied the whole display
state. Settings that reset on every launch made players redo them each time.

**See also:** accessibility L02 (persist preferences), accessibility C30 (per-category reset).
**Verify:** [verification.md#b12-settings-integrity](verification.md#b12-settings-integrity)

## B13 Focus loss

**Requirement**
- When the game window loses focus during gameplay (alt-tab, a notification, a click elsewhere),
  gameplay pauses and the mouse cursor is released.
- Menus are not paused by focus loss; they are already waiting.

**Why:** reviewers alt-tab to take notes or screenshots. Games that kept running or kept the
cursor locked caused deaths and window trouble while the reviewer was away.

**Verify:** [verification.md#b13-focus-loss](verification.md#b13-focus-loss)

## B14 Saving

**Requirement**
- The game autosaves at points it chooses, often enough that a crash loses little.
- Writes are crash-safe: write a temp file, keep the previous file as a backup, then replace.
- Loading falls back to the backup when the main file is corrupt. A corrupt or missing save never
  crashes the game. Continue only appears when a usable save exists.

**Why:** a long jam session that crashed with no autosave cost a reviewer the ending and cost the
entry its ranking.

**Verify:** [verification.md#b14-saving](verification.md#b14-saving)

## B15 Clean quit

**Requirement**
- Quitting from any screen, by Quit button or by closing the window, saves pending settings, stops
  sound and exits without errors or leaked-resource warnings in the log.

**Why:** a lesson from prior Redot Game Jam projects in general: errors at exit hid real problems,
and leaked resources showed up in jam projects' logs. A messy exit can also corrupt files that were
being written.

**Verify:** [verification.md#b15-clean-quit](verification.md#b15-clean-quit)

## B16 Hit areas

**Requirement**
- The clickable area of every button matches what is drawn, at every window size and mode, in the
  exported build.

**Why:** in a reviewed jam entry, pointing at Play activated Exit in the exported build because
input scaling and drawing scaling disagreed.

**Verify:** [verification.md#b16-hit-areas](verification.md#b16-hit-areas)

## B17 Version and log

**Requirement**
- The version number is visible on the title screen.
- Release builds write a log file to user data.

**Why:** a lesson from prior Redot Game Jam projects in general: reviews and bug reports could not
be matched to the exact build a player ran, and without a log the problem could not be diagnosed.

**Verify:** [verification.md#b17-version-and-log](verification.md#b17-version-and-log)

## C01 Mouse-look (conditional)

**Applies when** the game has mouse-look, aiming or a pointer-driven camera.

**Requirement**
- Look sensitivity slider (`input.look_sensitivity`, 0.25-3.0, default 1.0).
- Separate invert horizontal (`game.input.invert_x`) and invert vertical (`input.invert_y`).

**Why:** default sensitivity made some reviewed jam entries unplayable and made reviewers
motion-sick, with no way to change it.

**See also:** accessibility M07 (independent X/Y inversion).
**Verify:** [verification.md#c01-mouse-look](verification.md#c01-mouse-look)

## C02 Voice (conditional)

**Applies when** the game has spoken dialogue or voice lines.

**Requirement**
- Voice volume slider on its own bus (`audio.voice`, default 100 %).
- Subtitles on by default (`subtitles.dialogue`), drawn below menus and paused with the game.

**Why:** a lesson from prior Redot Game Jams: voice lines shipped without subtitles or a volume of
their own, so a line lost under music or effects could not be followed or turned up.

**See also:** accessibility H17 (dialogue subtitles), and its subtitle size, background and
speaker options for depth.
**Verify:** [verification.md#c02-voice](verification.md#c02-voice)
