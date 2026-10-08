---
name: run-godotgo
description: Build, run, drive and screenshot the GodotGo games (leap, orb-run, shift, swarm, cascade). Use when asked to start a game, play it, interact with it, see what it looks like, take a screenshot, or check that a change actually looks right on screen.
---

Five Godot 4 games live in this workspace. Drive any of them with `.claude/skills/run-godotgo/drive.sh`, which runs the real game inside the toolchain container under Xvfb with software Vulkan, sends scripted input, and writes PNG screenshots you can open. No GPU, no display, nothing installed but Docker.

All paths are relative to the repository root.

**This is not `tools/smoke.sh`.** Smoke boots each game with `--headless`, which selects the dummy renderer: it proves a scene loads, but it cannot produce a pixel or read a score. Use smoke as the gate; use this when the question is *what does the game do when the player presses this*.

## Prerequisites

Docker, and the toolchain image. That is all — the engine, Xvfb and Mesa are baked in:

```bash
tools/docker.sh build
```

The image already carries `Xvfb`, `xvfb-run` and Mesa's lavapipe software Vulkan (`/usr/share/vulkan/icd.d/lvp_icd.json`). Confirm with:

```bash
docker run --rm godotgo-tools:local bash -lc 'command -v Xvfb; godot --version'
```

Only needed for `GODOTGO_DRIVE_HOST=1` (below): the host engine, from `tools/install_godot.sh`.

## Run (agent path)

```bash
.claude/skills/run-godotgo/drive.sh <game> [steps] [out-dir]
```

`<game>` is `leap`, `orb-run`, `shift`, `swarm` or `cascade`. Screenshots default to `build/shots/` (gitignored). Steps default to `wait:60,shot:boot,state`.

Real runs from this session:

```bash
# Boot Leap and photograph it
.claude/skills/run-godotgo/drive.sh leap 'wait:60,shot:leap-boot,state'

# Walk forward in Orb Run until an orb is collected
.claude/skills/run-godotgo/drive.sh orb-run 'state,press:move_forward:150,state,shot:orb-forward'

# Push a crate in Shift, then undo
.claude/skills/run-godotgo/drive.sh shift 'tap:move_right,wait:15,tap:move_right,wait:15,shot:shift-moved,state,tap:undo,wait:15,shot:shift-undo'

# Hold fire in Swarm
.claude/skills/run-godotgo/drive.sh swarm 'state,press:fire:90,wait:30,shot:swarm-fight,state'

# Pop the group under Cascade's cursor, then step right and take another
.claude/skills/run-godotgo/drive.sh cascade 'tap:pop,wait:45,state,tap:move_right,tap:move_right,tap:move_right,tap:pop,wait:45,shot:cascade-play,state'
```

### The step grammar

Comma separated, run in order. Passed straight through to `driver.gd`.

| Step | Does |
| --- | --- |
| `wait:N` | Advance N physics frames |
| `press:ACTION:N` | Hold an input action for N frames, then release |
| `tap:ACTION` | Press and release across one frame |
| `shot:NAME` | Write `<out-dir>/NAME.png` |
| `state` | Print one JSON line of the session state |

**Frame counts are physics frames, so 60 is one second of game time**, whatever the renderer is doing. An unknown action name fails the run rather than being skipped silently, so a typo is an error and not a mysteriously inert step.

Actions per game, from each `project.godot`:

| Game | Actions |
| --- | --- |
| leap | `move_left move_right jump restart` |
| orb-run | `move_forward move_back move_left move_right jump sprint restart` |
| shift | `move_up move_down move_left move_right undo restart next_level` |
| swarm | `move_up move_down move_left move_right fire restart` |
| cascade | `move_up move_down move_left move_right pop restart next_level` |

### Reading the result

`state` prints a line you can parse instead of squinting at a screenshot:

```
[driver] state {"elapsed":2.9,"goal":5,"progress":1,"score":100,"state":1,"state_name":"PLAYING","time_left":87.1}
```

That one is the proof the drive worked: walking forward in Orb Run took `progress` from 0 to 1 and `score` from 0 to 100. **Look at the PNG as well** — a game that renders a black frame still reports a healthy session.

Exit code is 0 only if every step ran and every screenshot was written.

## Run (human path)

```bash
tools/run.sh leap                  # a real window, close it to stop
tools/godot_ai.sh edit leap        # the editor, with the MCP bridge live
```

Both are useless without a display. `HEADLESS=1 tools/run.sh leap` boots for two seconds with no renderer, which is what `tools/smoke.sh` wraps.

To watch the driver work in a real window on a machine that has one:

```bash
GODOTGO_DRIVE_HOST=1 .claude/skills/run-godotgo/drive.sh shift 'tap:move_right,wait:15,shot:host-shift,state'
```

## Test

The gate, unchanged by any of this:

```bash
tools/verify.sh            # pins, check, test, smoke - every project
tools/verify.sh leap       # one project
tools/docker.sh verify     # the same, in the container CI uses
```

## Gotchas

- **`Input.action_press()` does not reach `_unhandled_input`.** It only moves
the polled state that `is_action_pressed()` reads. Shift takes every move through `_unhandled_input`, so a whole run of taps left it sitting at "Moves 0" while reporting success. `driver.gd` now sends an `InputEventAction` through `Input.parse_input_event()` *and* sets the polled state, which covers both styles; leap, orb-run and swarm poll, shift does not.
- **A screenshot must wait for the frame it means to photograph.** Capturing
from inside a process frame gets the *previous* frame, or nothing at all. `driver.gd` awaits `RenderingServer.frame_post_draw` before reading the viewport.
- **Do not photograph the first frames.** The window is still being sized and
the game's `_ready` work has not run, so you get a black rectangle that looks exactly like a crash. `--settle=30` (the default) is enough.
- **Frames are not wall-clock.** Under Xvfb with no vsync the engine free-runs
at roughly 150 fps, so counting *rendered* frames made `press:move_right:90` last 0.6 s rather than 1.5 s. The driver counts physics frames instead.
- **`driver.gd` lives outside every Godot project**, so `res://` cannot address
it. It is passed to `--script` as an absolute filesystem path, which Godot accepts. Do not move it into a project to "fix" this — it is shared by all five games, and this is why `drive.sh` builds `/workspace/...` paths for the container.
- **Screenshot size is the project's viewport, not the Xvfb screen.** Xvfb runs
at 1280x720; leap, shift, swarm and cascade produce 960x540 because that is their configured viewport. Only orb-run is 1280x720.
- **Swarm aims with the mouse.** `press:fire` fires along the default aim, so
bullets appear but usually miss. The driver has no mouse verb; assert on bullets existing, not on kills.
- **Shift refuses illegal moves, correctly.** `tap:move_down` into a wall
registers no move, so "3 taps, Moves 2" is the game working, not the driver failing.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `viewport gave no image ...; is this running with --headless?` | Something added `--headless`. The dummy renderer has no pixels; drop the flag. |
| `Unable to open X display` | Xvfb had not finished creating its socket. `drive.sh` waits for `/tmp/.X11-unix/X99`; on a cold container that wait matters. |
| A dozen `ALSA lib conf.c` lines and `init_output_device ... ERR_CANT_OPEN` | The image has no sound card. Harmless — Godot falls back to a dummy driver — but `--audio-driver Dummy`, which `drive.sh` passes, silences it. |
| `no such input action: X` | That action is not in this game's `project.godot`; see the table above. |
| Screenshot is black | Photographed too early, or the scene really is broken. Raise `--settle`, and take a second shot later in the run to tell the two apart. |
| `framework has no main scene; drive a game instead` | `framework` is a library project. Drive `leap`, `orb-run`, `shift`, `swarm` or `cascade`. |

## The harness

- `.claude/skills/run-godotgo/drive.sh` — wraps the container, Xvfb, the
  lavapipe ICD and the audio flag. The thing you invoke.
- `.claude/skills/run-godotgo/driver.gd` — a `SceneTree` script: loads the
scene, runs the step machine, injects input, captures PNGs, prints state. Its header documents the argument and step grammar.
