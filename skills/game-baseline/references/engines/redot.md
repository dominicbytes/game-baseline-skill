# Redot guide

Redot is the main supported engine. The template in [`templates/redot/`](../../templates/redot/)
is a complete, tested project for **Redot 26.3** (GL Compatibility renderer, typed GDScript).
Its reusable part is one folder, `baseline/`; the rest is a demo game and tests.

Godot 4 projects can likely use the same folder, since the APIs match, but that is untested.
Run the template's tests on your engine version before relying on it.

## Install into a project

1. **Copy `baseline/`** into the project root. Copy `default_bus_layout.tres` too if the project
   has no bus layout yet. If it already has one, add the missing `Music`, `SFX` and `Voice` buses
   (each sending to `Master`) and a `HardLimiter` effect on `Master`.
2. **Apply the project settings** from the table below, or copy the matching lines from the
   template's `project.godot`.
3. **Export preset:** copy or merge the template's `Windows Desktop` preset from
   `export_presets.cfg`, then set your own `export_path`.
4. **Edit `baseline/baseline_config.tres`:** game title, `game_scene_path`, `title_music_path`,
   C01 (`enable_mouse_look`) and C02 (`enable_voice`), friendly action names, action order and
   credits text.
5. **Set the main scene** to `res://baseline/ui/title_screen.tscn`.
6. **Check:** import once (`<redot> --headless --path <game> --import`), then run
   `<redot> --headless --path <game> -s res://baseline/tools/check_project.gd`. It prints PASS or
   FAIL per static check and exits 1 if anything fails. A project without the template's
   autoloads gets one `MANUAL B05/B11/B13/B15` line instead: verify those items by hand with
   [verification.md](../verification.md). MANUAL lines do not affect the exit code.

Your gameplay scene's root must join the `baseline_gameplay` group
(`add_to_group(BaselineFlow.GAMEPLAY_GROUP)`). That is how pause, Esc and focus-loss know gameplay
is running.

## Project settings

| Setting | Value | Item |
| --- | --- | --- |
| `display/window/vsync/vsync_mode` | `1` (enabled) | B01 |
| `application/run/max_fps` | `60` | B01 |
| `audio/buses/default_bus_layout` | `res://default_bus_layout.tres` | B02 |
| `display/window/size/viewport_width`, `viewport_height` | your base size, e.g. `1280` × `720` | B03 |
| `display/window/stretch/mode` | `canvas_items` | B03, B16 |
| `display/window/stretch/aspect` | `expand` | B03 |
| `display/window/size/initial_position_type` | `1` (centre of primary screen) | B03 |
| `[autoload]` | `BaselineSettings`, then `BaselineFlow` (both `baseline/core/`) | B05, B11-B15 |
| `[input]` | gameplay actions on `physical_keycode`, device `-1` (all) | B09, B10 |
| `debug/file_logging/enable_file_logging.pc` | `true` | B17 |
| `application/config/version` | your version, e.g. `1.0.0` | B17 |
| Export `binary_format/embed_pck` | `true` | B07 |
| Export `debug/export_console_wrapper` | `0` | B07 |

## Item to code map

| Item | Where |
| --- | --- |
| B01 | `BaselineSettings` keys `game.display.vsync`, `game.display.frame_cap`; Display tab (`options_display_tab.gd`) |
| B02 | `audio.master`, `audio.music`, `audio.sfx`; Audio tab; `BaselineMusic` fade-in; bus layout limiter |
| B03 | `game.display.window_mode`, `game.display.window_size`; `BaselineSettings.default_window_size()` |
| B04 | No code: stable window behaviour from B12; verify with OBS |
| B05 | `BaselineFlow.pause()` / `resume()`; `BaselineMusic.duck()`; pausable gameplay nodes |
| B06 | Options button on `title_screen.gd` and `pause_menu.gd` |
| B07 | `export_presets.cfg` |
| B08 | `BaselineTheme` focus style; `BaselineScreen` focus handling; gameplay input in `_unhandled_input` |
| B09 | `game.input.bindings`; `BaselineBindings`; `controls_panel.gd` |
| B10 | `[input]` defaults; `BaselineInputLabels.action_label()` |
| B11 | `pause_menu.gd`, `title_screen.gd`, `BaselineConfirm.ask()`; Esc routing in `BaselineScreenStack` |
| B12 | `BaselineSettings` (validate, apply one key, debounced save, `reset_category()`) |
| B13 | `BaselineFlow._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` |
| B14 | `BaselineSave` and `BaselineFile` (temp file, `.bak`, fallback load) |
| B15 | `BaselineFlow.quit_game()`, also called on `NOTIFICATION_WM_CLOSE_REQUEST` |
| B16 | One stretch mode for everything; `tests/test_ui_focus.gd` |
| B17 | Version label on `title_screen.gd`; file logging setting |
| C01 | `input.look_sensitivity`, `game.input.invert_x`, `input.invert_y`; Gameplay tab |
| C02 | `audio.voice`, `subtitles.dialogue`; `BaselineFlow.show_subtitle()` |

## API you will use from game code

```gdscript
# Gameplay scene root
func _ready() -> void:
	add_to_group(BaselineFlow.GAMEPLAY_GROUP)
	var data := BaselineSave.load_data()           # {} when there is no save
	BaselineFlow.play_music(load("res://music/level.ogg"))

func _unhandled_input(event: InputEvent) -> void:   # never _input for gameplay (B08)
	if event.is_action_pressed("interact"):
		BaselineSave.save({"level": 2, "x": position.x})

# Prompts always show the live binding (B09)
label.text = "Jump: " + BaselineInputLabels.action_label("jump")

# Capture the mouse only while gameplay wants it (B13 releases it on focus loss)
BaselineFlow.set_gameplay_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Your own setting in the same file (validator returns the clean value or null)
BaselineSettings.register_key("game.show_timer", true,
	func(v: Variant) -> Variant: return v if v is bool else null)

# A destructive action
if await BaselineConfirm.ask("Restart the level? Progress since the checkpoint will be lost.", "Restart").answered:
	BaselineFlow.change_scene("res://levels/level_2.tscn")
```

Other useful calls: `BaselineFlow.pause()`, `resume()`, `return_to_title()`, `quit_game()`,
`show_subtitle(text, seconds)`, `push_screen(screen)` for your own `BaselineScreen` subclasses,
and `BaselineSettings.changed` to refresh UI when a setting changes.

## Running the template's tests

```bash
REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh            # all tests
REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh --only=test_flow
```

Each run uses fresh user data and fails on any engine error, warning or leak line.

For bounded runs of a game, use the template's own argument instead of the engine's
`--quit-after`:

```bash
<redot> --headless --audio-driver Dummy --path <game> -- --baseline-quit-after=5
```

It quits through `BaselineFlow.quit_game()`. The engine's `--quit-after` skips that path, and any
sound still playing then leaks at exit.

## Exporting

Install the official export templates matching your editor version, then:

```bash
<redot> --headless --path <game> --import
<redot> --headless --path <game> --export-release "Windows Desktop" <output folder>/MyGame.exe
```

For B07, embed the PCK in the exe (`binary_format/embed_pck=true`, already set in the template's
preset). The build is then self-contained: expect one `.exe` and no `.pck` or `.console.exe`
beside it, so there is no loose data file that must keep the exe's name. Test it from a fresh zip
as in [verification.md](../verification.md#b07-standalone-windows-build).

## Renderer and OBS

The template uses the GL Compatibility renderer for broad hardware support. OBS Game Capture
results for this template are recorded in its
[BASELINE.md](../../templates/redot/BASELINE.md) under B04. If capture shows black for your game,
try the other renderers and record which work.

## Pitfalls

- **Pausing does not stop everything by default.** `SceneTree.create_timer()` keeps running while
  paused unless you pass `process_always = false`. Tweens follow the process mode of the node that
  created them. Autoloads set to `PROCESS_MODE_ALWAYS` keep their sounds and timers running.
- **Never refer to a script's own class name inside that script, and never use `static var`.** In
  Redot 26.3 the engine's script cleanup at exit can stop early depending on load order. A script
  that references itself (`Foo.new()` inside `class_name Foo`, a static function called through
  its own class name, or a `static var` read from its functions) then shows up as "resources still
  in use at exit" or "ObjectDB instances leaked", and unrelated edits make it appear or disappear.
  Use `new()`, call your own static functions unqualified, and keep shared state on an autoload.
  Type annotations like `-> Foo` are safe.
- **Let sounds drain before quitting.** Stopped playbacks are released by the audio thread a few
  frames later. Quitting immediately leaks them. `quit_game()` waits 0.25 s.
- **`--quit-after` skips your quit code.** See the bounded-run argument above.
- **`ProjectSettings.save()` in a headless script can rewrite `project.godot`** and drop
  sections. Edit input actions in the editor, or insert them as text.
- **Close requests:** the window's close button only reaches your quit code if
  `get_tree().set_auto_accept_quit(false)` is set (`BaselineFlow` does this).
- **Focus loss can arrive while a scene is still being built:** defer the pause.
- **Applying fullscreen from an autoload's `_ready` causes a visible resize** after the window
  opens. Keep the default windowed; a saved fullscreen choice is applied at startup.
- **Headless runs differ:** there is no keyboard layout (key labels fall back to physical names),
  window and VSync calls do nothing, and `Input.mouse_mode` always reads visible. Use the template's
  own state (`BaselineFlow.requested_mouse_mode`) when testing.
- **Corrupt settings files:** `ConfigFile.parse()` prints engine errors on bad text. The template
  stores settings as JSON validated with `JSON.new().parse()`, which fails quietly and falls back
  to the backup or defaults.
