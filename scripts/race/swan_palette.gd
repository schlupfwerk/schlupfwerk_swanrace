class_name SwanPalette
extends RefCounted
## Colors offered in the wardrobe. Picked with left/right, so it works on a
## controller without a mouse.

## Translation keys of the color names (see translations/strings.csv).
static var names: PackedStringArray = [
	"COLOR_WHITE", "COLOR_CREAM", "COLOR_BLACK", "COLOR_GRAY", "COLOR_PINK", "COLOR_RED",
	"COLOR_ORANGE", "COLOR_YELLOW", "COLOR_GOLD", "COLOR_GREEN", "COLOR_MINT", "COLOR_SKY_BLUE",
	"COLOR_BLUE", "COLOR_PURPLE", "COLOR_BROWN",
]
static var colors: Array[Color] = [
	Color("f7f5ee"), Color("f1e3c2"), Color("2b2b30"), Color("8d8f96"),
	Color("ff8fb8"), Color("e8413c"), Color("ff8a2a"), Color("ffd23f"),
	Color("d9ab3f"), Color("4cbf56"), Color("8ee6c4"),
	Color("8fc1ff"), Color("2f6fe0"), Color("8e5bd8"), Color("7a5232"),
]


static func closest(color: Color) -> int:
	var best := 0
	var best_distance := INF
	for i in colors.size():
		var c := colors[i]
		var d := Vector3(c.r - color.r, c.g - color.g, c.b - color.b).length_squared()
		if d < best_distance:
			best_distance = d
			best = i
	return best


## Color names in the current language.
static func display_names() -> PackedStringArray:
	var translated := PackedStringArray()
	for key in names:
		translated.append(TranslationServer.translate(key))
	return translated
