# game-baseline-skill

An agent skill that gives an AI game-development agent a checklist of the technical basics and
standard menus every indie game needs, so nothing gets forgotten: a pause menu that really pauses,
volume sliders, display options, remappable controls, a clean quit, a standalone build. It is
engine-neutral. Redot is the main supported engine, and the skill includes a tested Redot template
you can drop into a project. It covers technical basics and menus only, never game design.

## The checklist at a glance

| ID | Item |
| --- | --- |
| B01 | Frame pacing |
| B02 | Volume |
| B03 | Display |
| B04 | Streaming capture |
| B05 | Pause |
| B06 | Options access |
| B07 | Standalone Windows build |
| B08 | Keyboard and mouse |
| B09 | Remapping |
| B10 | Default keys and labels |
| B11 | Quit and back |
| B12 | Settings integrity |
| B13 | Focus loss |
| B14 | Saving |
| B15 | Clean quit |
| B16 | Hit areas |
| B17 | Version and log |
| C01 | Mouse-look sensitivity and invert (only if the game has mouse-look or aiming) |
| C02 | Voice volume and subtitles (only if the game has spoken dialogue) |

Requirements are in [checklist.md](skills/game-baseline/references/checklist.md), and how to check
each item is in [verification.md](skills/game-baseline/references/verification.md). An item counts
as pass only after its check has been run.

## Install

**Claude Code:** copy the `skills/game-baseline` folder into `.claude/skills/` for one project, or
into `~/.claude/skills/` for all your projects.

**Other agents:** point the agent at `skills/game-baseline/SKILL.md`. It links to everything else
with relative paths, so keep the folder together.

## Redot template quick start

The template is a complete project for Redot 26.3 (GL Compatibility renderer, typed GDScript). Its
reusable part is the `baseline/` folder. The full steps are in
[redot.md](skills/game-baseline/references/engines/redot.md); in short:

1. Copy `skills/game-baseline/templates/redot/baseline/` into your project (plus
   `default_bus_layout.tres` if you have no bus layout yet).
2. Apply the project settings and the `Windows Desktop` export preset listed in the guide.
3. Edit `baseline/baseline_config.tres`. The shipped file is the demo's (it starts
   `res://demo/demo_game.tscn`) and must be edited: set your own title, game scene and options.
4. Set the main scene to `res://baseline/ui/title_screen.tscn`.
5. Run the static checks:

   ```bash
   <redot> --headless --path <game> --import
   <redot> --headless --path <game> -s res://baseline/tools/check_project.gd
   ```

To try the template as it is, open `skills/game-baseline/templates/redot/` in Redot and run it. See
the [template README](skills/game-baseline/templates/redot/README.md).

## Tests

Run both from the repository root.

```bash
REDOT_BIN=<redot editor executable> tests/run_redot_tests.sh   # the template's headless tests
python tests/check_skill.py                                    # lint the skill's docs and files
```

`run_redot_tests.sh` runs the template headless with isolated user data and fails on any engine
error, warning or leak. `check_skill.py` (Python 3, standard library only) checks the SKILL.md
frontmatter, relative links and heading anchors, that every item ID appears in each document that
must carry it, that settings keys named in the docs are registered in the template, and that no
file contains local paths or AI attribution. `python tests/check_skill.py --self-test` checks the
lint's own scanners.

## Relationship to game-accessibility-skill

This skill deliberately overlaps with
[game-accessibility-skill](https://github.com/dominicbytes/game-accessibility-skill): remapping,
volume, pause and subtitles appear in both. This skill states each item in one line and sets up the
structure (menus, settings store, pause, quit); the accessibility skill adds depth and more options.
The two share setting keys, so both can write into one settings file, and they do not contradict
each other.

## Credit

Template feature set inspired by RedotJamTemplate by Takun Hiwatari (https://github.com/TakunHiwatari/RedotJamTemplate). Clean-room reimplementation, no code reused.

See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## License

MIT. See [LICENSE](LICENSE).
