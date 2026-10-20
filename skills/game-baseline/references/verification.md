# Verification

How to check each item. Run the game; read code only to find what to test. Record each result in
`BASELINE.md` as pass, fail, blocked, n/a or not tested, with a one-line note of what you ran and
saw.

Test exported builds as well as editor runs: export settings, data packing and input scaling
differ. Automated checks are welcome, but some items (B04, B13, B16) need at least one real window
on a real desktop.

## B01 Frame pacing

1. Fresh user data (delete the settings file). Launch. Confirm VSync is on and the frame cap reads
   60 in the options menu.
2. Set the cap to Unlimited with VSync off, then 30. Move for a fixed time (or script it): distance
   travelled and timers must match within a few percent.
3. Check the project defaults directly (engine project settings) so a fresh install gets them too.

## B02 Volume

1. Fresh user data. Launch with speakers at a normal level: the title must not blast. Music fades
   in over at least 2 seconds.
2. Reach Options from the first title menu. Master, Music and SFX each change only their own sound.
3. Set Music to 0: it is silent and the slider says "Muted". Restart: the levels persist.
4. Optional measurement: record the game and check peak level stays below 0 dBFS (the limiter
   works).

## B03 Display

1. Fresh user data on a 1920×1080 screen: the window opens at a readable size, centred on the
   primary monitor.
2. Switch Windowed → Fullscreen → Exclusive fullscreen → Windowed. Each change applies at once and
   Windowed restores the chosen size.
3. Window size presets: only sizes that fit the screen appear; the list is disabled in fullscreen.
4. Screenshot the title, options and gameplay at 1280×720, 1366×768, 1920×1080 and an ultrawide
   window (2560×1080). Nothing clips, overlaps or sits in a corner; text is readable at 1280×720.

## B04 Streaming capture

Use any OBS Studio install (a portable copy keeps test settings away from a real streaming setup).

1. Export the game. In OBS, mute or remove Desktop Audio and Mic so they cannot mask the result.
2. Add a **Game Capture** source: mode "Capture specific window", the game's window, and enable
   **Capture audio**.
3. Run the game windowed with sound. The preview shows the game moving; the Game Capture source's
   audio meter moves.
4. Record 10-15 seconds. Play it back: picture and game sound present.
5. Repeat in fullscreen.
6. Control check: disable "Capture audio" and record again. The recording must be silent, which
   proves the sound came from the game capture.
7. Note the window size and position before and after OBS hooks the game: they must not change.

If Game Capture shows black, record which renderer the game uses and try the engine's other
desktop renderers; note which work in the engine guide.

## B05 Pause

1. In gameplay with a running timer, an animation and a looping sound: pause.
2. For 10 seconds: the timer does not advance, animations and transitions freeze, gameplay sounds
   stop, music continues more quietly, and menus respond.
3. Resume: everything continues from the same point.
4. Pause during a scene transition or right after one: no level loads behind the menu.

## B06 Options access

1. Open Options from the title. Back returns to the title.
2. In gameplay, note the score, time or position. Pause → Options → change a setting → Back →
   Resume. The game state is unchanged.

## B07 Standalone Windows build

1. Export a release build for Windows x86_64 with the data embedded and no console wrapper.
2. Zip it. Copy the zip to a different PC or folder; extract into a new folder whose name contains
   a space and a non-ASCII character (for example `Test Build é`).
3. Launch from Explorer by double-click. Windows SmartScreen may warn about an unsigned executable;
   note it. The game starts with no console window and no missing-file error.
4. Check the build folder contains only the executable (and any engine libraries the engine
   requires), not a loose data file.

## B08 Keyboard and mouse

1. Unplug or ignore any gamepad. Play from title to the end (or the first major milestone) with
   keyboard and mouse only.
2. In every menu, use only the keyboard: focus is always visible; arrows and Tab reach every
   control; Enter or Space activates; Esc backs out.
3. Click a HUD button during gameplay: only the button acts (no shot, jump or ping).

## B09 Remapping

1. Rebind an action to another key and to a mouse button. The new binding works in gameplay.
2. Bind a key another action uses: the game asks to swap or cancel. Check both answers.
3. Every prompt, tutorial line and HUD hint shows the new binding.
4. Restart: bindings persist. Reset controls (after its confirmation) restores defaults.
5. Try to bind Esc: it cancels the rebind instead; menus still work with arrows, Enter and Esc.

## B10 Default keys and labels

1. Fresh user data: defaults follow conventions (WASD and arrows, Space, E, Esc, mouse buttons).
2. If possible, switch the OS keyboard layout (for example to AZERTY): movement keys stay in the
   same physical positions and labels show the layout's characters.
3. Read every label: no ambiguous names such as "Left" for an arrow key.

## B11 Quit and back

1. Title: Quit exits immediately (nothing to lose). Esc does nothing.
2. Gameplay: Esc opens pause. Return to Title and Quit to Desktop ask first, naming what is lost;
   Cancel is focused; Esc answers Cancel.
3. New Game with an existing save asks before overwriting.
4. Close the window with its close button and with Alt+F4: the game quits cleanly with no dialog.

## B12 Settings integrity

1. Change each display setting in turn. Watch the window: only the chosen property changes
   (toggling VSync never resizes the window).
2. Change several settings, quit, relaunch: all persist.
3. Corrupt the settings file (type garbage into it). Launch: defaults load, no crash, a note in the
   log.
4. Each category's reset button resets only that category.

## B13 Focus loss

1. Windowed, in gameplay: alt-tab to another window (or minimize). Return: the game is paused and
   the cursor was free while away.
2. On the title or a menu: alt-tab and return. Nothing changed.
3. Alt-tab during a scene transition: the game pauses once the transition ends.

## B14 Saving

1. Play past an autosave point. Kill the process (Task Manager). Relaunch: Continue appears and
   restores recent progress.
2. Corrupt the main save file: the game loads the backup, or offers New Game without crashing.
3. With no save, Continue is hidden.

## B15 Clean quit

1. Quit from the title, from pause, and by closing the window during gameplay with sound playing.
2. Open the log after each: no errors, no leaked objects or resources reported at exit.

## B16 Hit areas

1. In the exported build, at two window sizes and in fullscreen, click the centre and the edges of
   every button on the title, options (each tab), pause and confirm dialogs.
2. Each click activates exactly the button under the cursor.

## B17 Version and log

1. The title screen shows the version, matching the build you exported.
2. After a session, the log file exists in the game's user-data folder and contains the session.

## C01 Mouse-look

1. Change sensitivity: look speed changes proportionally.
2. Toggle invert horizontal and invert vertical separately: each flips only its axis.
3. Settings persist after restart.

## C02 Voice

1. A voice line plays on the Voice bus: the Voice slider changes only voice.
2. Subtitles show the line by default, below menus, and pause with the game.
3. Turn subtitles off: no new lines appear.
