class_name Hazard
extends LeapTrigger
## Spikes. Unlike a coin this re-arms, because the hero respawns and can walk
## back into the same spike.
##
## The scene sets [member LeapTrigger.one_shot] to false so a designer can see
## it in the inspector; setting it from _init() would be silently overwritten by
## any editor save that serialises the property.
##
## Physics: layer 5 (hazards), mask 2 (player).
