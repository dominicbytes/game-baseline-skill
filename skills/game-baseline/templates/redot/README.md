# Redot template

A complete Redot 26.3 project (GL Compatibility renderer, typed GDScript) that implements the
game-baseline checklist: title screen, options, pause, remapping, saving, subtitles, clean quit
and a Windows export preset. The reusable part is the `baseline/` folder. `demo/` is a tiny game
that exercises it, and `tests/` holds the headless tests.

## Install into your project

Follow [references/engines/redot.md](../../references/engines/redot.md) (from the repository root:
`skills/game-baseline/references/engines/redot.md`). It lists what to copy, the project settings
and the export preset.

## Run the demo

Open this folder as a project in Redot 26.3 and run it, or from a terminal:

```bash
<redot> --path .
```

For a bounded run that quits through the template's own quit path, pass the template's argument
after `--`:

```bash
<redot> --headless --audio-driver Dummy --path . -- --baseline-quit-after=5
```

## Run the tests

From the repository root:

```bash
REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh
REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh --only=test_flow
```

Static project checks for any project that uses the template. Import once first, so the class
cache exists and the template's autoloads parse:

```bash
<redot> --headless --path <game> --import
<redot> --headless --path <game> -s res://baseline/tools/check_project.gd
```
