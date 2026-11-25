class_name BotLooks
extends RefCounted
## Random looks and names for AI racers, always clearly different from the
## player's swan: another feather color and other items in every slot.


static func make(rng: RandomNumberGenerator, player: SwanLook, used_names: Array) -> SwanLook:
	var look := SwanLook.new()
	look.nickname = _unique_name(rng, player.nickname, used_names)
	# Feathers: a color far from the player's.
	var colors := SwanPalette.colors
	var far: Array[Color] = []
	for color in colors:
		if _distance(color, player.feather_color) > 0.45:
			far.append(color)
	look.feather_color = far.pick_random() if not far.is_empty() else colors.pick_random()
	if rng.randf() < 0.4:
		look.feather_style = SwanLook.FeatherStyle.GRADIENT
		look.feather_color_2 = colors[rng.randi() % colors.size()]
	look.leg_color = colors[rng.randi() % colors.size()]
	# One item per slot, never the same item as the player.
	for slot: String in SwanLook.SLOTS:
		var options: Array = SwanLook.SLOTS[slot].duplicate()
		options.erase(player.slot_item(slot))
		options.append("")
		var item: String = options[rng.randi() % options.size()]
		if item != "":
			look.set_slot(slot, item, colors[rng.randi() % colors.size()])
	if rng.randf() < 0.35:
		var styles := SwanLook.GLASSES_STYLES.duplicate()
		styles.erase(player.glasses_style)
		look.glasses_style = styles[rng.randi() % styles.size()]
		look.glasses_frame = colors[rng.randi() % colors.size()]
		look.glasses_lens = colors[rng.randi() % colors.size()]
	for extra: String in SwanLook.EXTRAS:
		if rng.randf() < 0.3:
			look.accessories[extra] = Color.BLACK if extra == "lashes" else colors[rng.randi() % colors.size()]
	return look


static func _unique_name(rng: RandomNumberGenerator, player_name: String, used: Array) -> String:
	for attempt in 30:
		var candidate := Nicknames.random()
		if candidate != player_name and not candidate in used:
			used.append(candidate)
			return candidate
	var fallback := "%s %d" % [Nicknames.random(), rng.randi_range(2, 99)]
	used.append(fallback)
	return fallback


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
