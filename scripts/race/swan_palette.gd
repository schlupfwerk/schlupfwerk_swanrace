class_name SwanPalette
extends RefCounted
## Colors offered in the wardrobe. Picked with left/right, so it works on a
## controller without a mouse. Ordered by shade: whites and grays, then
## around the color wheel, then brown.

## Translation keys of the color names (see translations/strings.csv).
static var names: PackedStringArray = [
	"COLOR_WHITE", "COLOR_CREAM", "COLOR_SILVER", "COLOR_GRAY", "COLOR_BLACK",
	"COLOR_PINK", "COLOR_MAGENTA", "COLOR_CORAL", "COLOR_RED", "COLOR_WINE",
	"COLOR_ORANGE", "COLOR_PEACH", "COLOR_YELLOW", "COLOR_GOLD", "COLOR_LIME",
	"COLOR_GREEN", "COLOR_DARK_GREEN", "COLOR_MINT", "COLOR_TURQUOISE", "COLOR_SKY_BLUE",
	"COLOR_BLUE", "COLOR_NAVY", "COLOR_LILAC", "COLOR_PURPLE", "COLOR_BROWN",
]
static var colors: Array[Color] = [
	Color("f7f5ee"), Color("f1e3c2"), Color("c8ccd4"), Color("8d8f96"), Color("2b2b30"),
	Color("ff8fb8"), Color("d63aa8"), Color("ff6f61"), Color("e8413c"), Color("8e1f2f"),
	Color("ff8a2a"), Color("ffc49b"), Color("ffd23f"), Color("d9ab3f"), Color("b5e550"),
	Color("4cbf56"), Color("2e7d4f"), Color("8ee6c4"), Color("2ec4c4"), Color("8fc1ff"),
	Color("2f6fe0"), Color("1f3a6b"), Color("c9a7f0"), Color("8e5bd8"), Color("7a5232"),
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
