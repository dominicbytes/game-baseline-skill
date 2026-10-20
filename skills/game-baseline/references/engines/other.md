# Other engines

The checklist is engine-neutral. These tables point to the usual building blocks in other engines.
They are starting points, not tested templates. Check the API against the engine version you
actually use, and verify every item by running the game
([verification.md](../verification.md)).

## Godot 4

Redot is a Godot 4 fork, so the [Redot guide](redot.md) and template apply almost directly. Run
the template's tests on your Godot version before trusting it: the template is only tested on
Redot 26.3.

## Unity

| Item | Building blocks |
| --- | --- |
| B01 | `QualitySettings.vSyncCount = 1`; `Application.targetFrameRate = 60` (ignored while vSyncCount > 0 on most platforms, so apply the cap when VSync is off); move with `Time.deltaTime`, physics in `FixedUpdate` |
| B02 | `AudioMixer` groups for Music and SFX with exposed volume parameters; convert slider value with `Mathf.Log10(v) * 20` (floor at -80 dB); a limiter or compressor on the master group |
| B03 | `Screen.fullScreenMode` (`Windowed`, `FullScreenWindow`, `ExclusiveFullScreen`); `Screen.SetResolution`; Canvas Scaler "Scale With Screen Size" |
| B04 | Test with OBS; D3D11 and D3D12 builds hook normally |
| B05 | `Time.timeScale = 0` plus pausing `AudioSource`s (or `AudioListener.pause`, then let music sources ignore it with `ignoreListenerPause`); unscaled time for menus |
| B06 | Shared options prefab opened from both title and pause |
| B07 | Windows standalone x86_64 build; ship the whole build folder zipped (Unity needs its `_Data` folder and `UnityPlayer.dll`, and the `_Data` folder must keep the exe's name) |
| B08 | `EventSystem` with keyboard navigation and a selected-state style; `EventSystem.current.IsPointerOverGameObject()` before gameplay clicks |
| B09 | Input System `PerformInteractiveRebinding()` with binding overrides saved as JSON (`SaveBindingOverridesAsJson`) |
| B10 | Bind keys by physical location in the Input System (the default for keyboard controls); show `GetBindingDisplayString()` |
| B11 | Quit button calls `Application.Quit()`; confirmation dialog; handle `Application.wantsToQuit` for close requests |
| B12 | Your own settings class serialized to JSON in `Application.persistentDataPath`; validate on load. `PlayerPrefs` is fine for a few small settings, but a JSON file in `persistentDataPath` is easier to validate and back up |
| B13 | `OnApplicationFocus(false)` or the `Application.focusChanged` event → pause and `Cursor.lockState = CursorLockMode.None` |
| B14 | Write to a temp file, then `File.Replace(temp, main, backup)`. `File.Replace` throws when the main file does not exist yet, so on the first save use `File.Move(temp, main)` |
| B15 | Stop coroutines and audio on quit; check `Player.log` |
| B16 | Canvas Scaler plus Graphic Raycaster; test at several resolutions in the build |
| B17 | `Application.version` on the title; `Player.log` in the persistent data folder |
| C01 | Sensitivity multiplier and per-axis invert applied to the look input |
| C02 | Voice mixer group; subtitle UI driven by your dialogue system |

## Unreal Engine

| Item | Building blocks |
| --- | --- |
| B01 | `UGameUserSettings::SetVSyncEnabled`, `SetFrameRateLimit(60)`; scale by `DeltaSeconds` |
| B02 | Sound Classes (Master, Music, SFX) and a Sound Class Mix, or Submixes with volume control |
| B03 | `UGameUserSettings::SetFullscreenMode` (`Windowed`, `WindowedFullscreen`, `Fullscreen`), `SetScreenResolution`, `ApplySettings`; DPI scaling curve for UMG |
| B04 | Test with OBS; D3D11 and D3D12 hook normally |
| B05 | `UGameplayStatics::SetGamePaused`; audio components set to pause with the game; menus ticking while paused |
| B06 | One options widget opened from both the main menu and the pause menu |
| B07 | Shipping build for Win64, packaged in a single folder; zip the whole build folder, since the exe needs the folders beside it; prerequisites installer optional |
| B08 | UMG focus navigation and focus brushes; `bShowMouseCursor` handling; Common UI input routing |
| B09 | Enhanced Input user settings (player-mappable keys) saved with the user settings |
| B10 | Default mappings in the Input Mapping Context; show key display names from the current mapping |
| B11 | `UKismetSystemLibrary::QuitGame`; confirmation widget |
| B12 | `UGameUserSettings` subclass for custom settings; validate after load |
| B13 | `FSlateApplication::Get().OnApplicationActivationStateChanged()` (fires when the desktop window gains or loses focus) → pause and show the cursor |
| B14 | `USaveGame` with `AsyncSaveGameToSlot`; keep a second slot as backup |
| B15 | Check `Saved/Logs` after quitting from each screen. Shipping builds compile logging out unless the game's `Target.cs` sets `bUseLoggingInShipping = true`, so test a Development build or set it |
| B16 | UMG DPI scaling; test in a packaged build |
| B17 | Project version in the title widget; logs in `Saved/Logs`. Shipping builds write no log unless the game's `Target.cs` sets `bUseLoggingInShipping = true` |
| C01 | Sensitivity and invert modifiers on the look input action |
| C02 | Voice Sound Class; subtitles through dialogue waves or your own widget |

## Custom or other engines

Implement the same building blocks the Redot template uses:

- A **settings store**: a key, a default, a validator and an apply function per setting, saved as
  one file in the user-data folder.
- A **flow controller** that owns pause, the menu screen stack, Esc routing, focus-loss pause, scene
  transitions, music ducking and the clean quit.
- An **input layer** that stores bindings as plain data (physical key or mouse button), applies
  them to the engine's input map, and produces readable labels.
- **Crash-safe file writes**: temp file, backup, replace.
- The standard **screens**: title, options (audio, display, controls), pause, confirm, credits.

Then run every check in [verification.md](../verification.md).
