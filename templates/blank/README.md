# __GAME_TITLE__

__GAME_DESC__

Created from `templates/blank` by `tools/new_game.sh`.

```bash
tools/run.sh __GAME_SLUG__          # play
tools/check.sh __GAME_SLUG__        # import, load and lint
tools/test.sh __GAME_SLUG__         # headless tests
tools/smoke.sh __GAME_SLUG__        # windowless boot
```

The framework lives in `addons/godotgo`, symlinked to `framework/addons/godotgo`. Gameplay rules belong in `scripts/game.gd` (a `Session` subclass); scenes wire themselves to it and react to its signals.
