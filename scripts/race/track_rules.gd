class_name TrackRules
extends RefCounted
## Terrain rules of the island beach, applied to every swan after each tick.
## The same for players and bots.
##   - In the water: wet and slow (WATER_SPEED_SCALE), feet sink a little.
##   - Into the forest: bump, speed drops to 0, a short daze, then the swan
##     turns back towards the race direction.
##   - Never the wrong way: the heading is kept within MAX_WRONG_ANGLE of the
##     race direction.


static func apply(swan: Swan, laps: LapTracker, track: IslandTrack) -> void:
	var i := laps.hint
	var lateral := laps.lateral
	var race_heading := track.heading_at(i)

	var in_water := lateral > track.water_line(i)
	swan.motor.max_speed_scale = IslandTrack.WATER_SPEED_SCALE if in_water else 1.0
	swan.in_water = in_water
	swan.ground_y = maxf(track.ground_height(i, lateral), IslandTrack.SEA_LEVEL - 0.45)

	# The open sea is too deep: the swan cannot wade further out.
	var max_out := track.water_line(i) + 26.0
	if lateral > max_out:
		var inside := track.edge(i, max_out)
		swan.motor.position.x = inside.x
		swan.motor.position.z = inside.y

	if lateral < track.forest_edge(i) - 0.8 and not swan.is_stunned():
		var back := track.edge(i, track.forest_edge(i) + 0.6)
		swan.motor.position.x = back.x
		swan.motor.position.z = back.y
		swan.bump(race_heading)

	var off := wrapf(swan.motor.heading - race_heading, -PI, PI)
	if absf(off) > IslandTrack.MAX_WRONG_ANGLE:
		swan.motor.heading = race_heading + signf(off) * IslandTrack.MAX_WRONG_ANGLE
