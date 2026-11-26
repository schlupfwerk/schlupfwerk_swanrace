extends SceneTree
## Draws the app icon: a variation of the Schlupfwerk logo (the pixel egg with
## the golden crack) where the egg has hatched and a swan pops out, wearing
## the top of the shell like a hat. Pixel art on a 32x32 grid, scaled up with
## no smoothing. Writes the PNGs to assets/icon/:
##   - icon_1024.png: the full icon (iOS App Store, the project icon);
##   - android_main_192.png: the legacy Android launcher icon;
##   - android_foreground_432.png, android_background_432.png and
##     android_monochrome_432.png: the Android adaptive icon layers (the art
##     inside the 66% safe zone, so masks never cut the swan).
## Run: godot --headless --path . --script res://scripts/tools/make_app_icon.gd

const OUT := "res://assets/icon/"
const GRID := 32
const NAVY := Color("13233A")
const GOLD := Color("FFB020")
const SKY := Color("7EC8F2")
const WHITE := Color("FFFFFF")
const SHADE := Color("D9E4EE")
const BEAK := Color("FF8A2A")
const BLACK := Color("13233A")

## The logo egg (10x13 cells, from the site's egg.svg): navy cells and the
## golden crack cells, as "x,y".
const EGG_NAVY := [
	"3,0", "4,0", "5,0", "6,0",
	"2,1", "3,1", "4,1", "5,1", "6,1", "7,1",
	"1,2", "2,2", "3,2", "4,2", "5,2", "6,2", "7,2", "8,2",
	"1,3", "2,3", "3,3", "4,3", "5,3", "6,3", "7,3", "8,3",
	"0,4", "1,4", "2,4", "3,4", "4,4", "5,4", "6,4", "7,4", "8,4", "9,4",
	"0,5", "1,5", "3,5", "4,5", "5,5", "7,5", "8,5", "9,5",
	"0,6", "2,6", "4,6", "6,6", "8,6",
	"1,7", "2,7", "3,7", "5,7", "6,7", "7,7", "9,7",
	"0,8", "1,8", "2,8", "3,8", "4,8", "5,8", "6,8", "7,8", "8,8", "9,8",
	"0,9", "1,9", "2,9", "3,9", "4,9", "5,9", "6,9", "7,9", "8,9", "9,9",
	"1,10", "2,10", "3,10", "4,10", "5,10", "6,10", "7,10", "8,10",
	"2,11", "3,11", "4,11", "5,11", "6,11", "7,11",
	"3,12", "4,12", "5,12", "6,12",
]
const EGG_GOLD := ["2,5", "6,5", "1,6", "3,6", "5,6", "7,6", "9,6", "0,7", "4,7", "8,7"]


func _init() -> void:
	var art := _draw_art()
	DirAccess.make_dir_recursive_absolute(OUT)
	# Full icon: sky background, the art filling most of it.
	_compose(art, 1024, 28, true).save_png(OUT + "icon_1024.png")
	_compose(art, 192, 5, true).save_png(OUT + "android_main_192.png")
	# Adaptive layers: the art small enough for the safe zone.
	_compose(art, 432, 8, false).save_png(OUT + "android_foreground_432.png")
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(SKY)
	background.save_png(OUT + "android_background_432.png")
	var mono := _compose(art, 432, 8, false)
	for y in mono.get_height():
		for x in mono.get_width():
			if mono.get_pixel(x, y).a > 0.0:
				mono.set_pixel(x, y, WHITE)
	mono.save_png(OUT + "android_monochrome_432.png")
	print("icons written to ", ProjectSettings.globalize_path(OUT))
	quit()


## The 32x32 art (transparent where empty).
func _draw_art() -> Image:
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The swan, drawn first so the shell covers its bottom.
	# Body: a round white puff coming out of the egg, wings raised at the sides.
	for y in range(11, 19):
		for x in range(8, 24):
			var dx := (x - 15.5) / 6.5
			var dy := (y - 15.0) / 3.6
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, SHADE if (y >= 16 and (x <= 11 or x >= 20)) else WHITE)
	for cell: Vector2i in [Vector2i(9, 10), Vector2i(9, 11), Vector2i(10, 11), Vector2i(10, 12),
			Vector2i(22, 10), Vector2i(22, 11), Vector2i(21, 11), Vector2i(21, 12), Vector2i(11, 12), Vector2i(20, 12)]:
		img.set_pixelv(cell, WHITE)
	# Neck, up from the body.
	for y in range(10, 13):
		for x in range(15, 18):
			img.set_pixel(x, y, WHITE)
	# Head, just under the shell hat.
	for y in range(6, 11):
		for x in range(14, 20):
			if not ((x == 14 or x == 19) and y == 10):
				img.set_pixel(x, y, WHITE)
	# Beak, eye (with a shine) and a cheek blush: a happy face.
	for cell: Vector2i in [Vector2i(20, 8), Vector2i(21, 8), Vector2i(22, 8), Vector2i(20, 9), Vector2i(21, 9)]:
		img.set_pixelv(cell, BEAK)
	img.set_pixel(17, 7, BLACK)
	img.set_pixel(17, 8, BLACK)
	img.set_pixel(18, 9, Color("FFB3C1"))
	# Bottom half of the egg (logo rows 6-12, doubled): the shell, with the
	# golden zigzag along its broken rim.
	for cell: String in EGG_NAVY:
		var c := _cell(cell)
		if c.y >= 6:
			_block(img, Vector2i(6 + c.x * 2, 4 + c.y * 2), NAVY)
	for cell: String in EGG_GOLD:
		var c := _cell(cell)
		if c.y >= 6:
			_block(img, Vector2i(6 + c.x * 2, 4 + c.y * 2), GOLD)
	# The top of the shell, logo rows 0-5 at its own size, on the swan's head
	# like a little hat, a bit to the back.
	for cell: String in EGG_NAVY:
		var c := _cell(cell)
		if c.y <= 5:
			img.set_pixel(11 + c.x, c.y, NAVY)
	for cell: String in EGG_GOLD:
		var c := _cell(cell)
		if c.y <= 5:
			img.set_pixel(11 + c.x, c.y, GOLD)
	return img


func _cell(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _block(img: Image, at: Vector2i, color: Color) -> void:
	for dy in 2:
		for dx in 2:
			if at.x + dx < GRID and at.y + dy < GRID:
				img.set_pixel(at.x + dx, at.y + dy, color)


## The art scaled by `cell` pixels per grid cell, centered on a square of
## `size` pixels, on the sky background or transparent.
func _compose(art: Image, size: int, cell: int, with_background: bool) -> Image:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(SKY if with_background else Color(0, 0, 0, 0))
	# One cell lower: the art leaves two empty rows at the bottom of the grid.
	var offset := (size - GRID * cell) / 2
	var lift := cell
	for y in GRID:
		for x in GRID:
			var color := art.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			out.fill_rect(Rect2i(offset + x * cell, offset + lift + y * cell, cell, cell), color)
	return out
