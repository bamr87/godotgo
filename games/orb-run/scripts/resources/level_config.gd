class_name LevelConfig
extends Resource
## Designer-facing settings for one level. Saved as a .tres (see
## resources/arena_config.tres) and assigned to [member Level.config].

## Shown by the HUD when the round starts.
@export var title := "Arena"
## Seconds to collect every orb and reach the exit. 0 disables the countdown.
@export_range(0.0, 600.0, 1.0) var time_limit := 60.0
## Falling below this world-space Y respawns the player at the spawn point.
@export_range(-100.0, 0.0, 0.5) var kill_y := -10.0
## Minimum downward speed (m/s) at touchdown that plays the landing sound.
@export_range(0.0, 30.0, 0.5) var land_sound_min_fall_speed := 6.0
