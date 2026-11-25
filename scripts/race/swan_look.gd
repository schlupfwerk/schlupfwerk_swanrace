class_name SwanLook
extends Resource
## How a swan looks: nickname, colors and what it wears.
## Pure data. It never changes how fast a swan is.

enum FeatherStyle { SOLID, GRADIENT }

## Stable item ids (ADR 0012). Never rename an id: saves refer to them.
## Slots hold one item at a time (or none).
const SLOTS := {
	"head": ["cap", "straw_hat", "top_hat", "cowboy_hat", "beanie", "wig", "wig_long"],
	"outfit": ["jacket", "winter_jacket", "tank_top", "hoodie"],
	"footwear": ["sneakers", "boots", "shoes", "flip_flops"],
	"back": ["backpack", "bag", "cape", "dog_bag", "cat_bag", "ostrich_egg"],
	"necklace": ["necklace_round", "necklace", "necklace_pearls"],
}
## Items that are simply worn or not, each with one color.
const EXTRAS := ["lashes", "lipstick", "socks"]
## Glasses shapes ("" = no glasses).
const GLASSES_STYLES := ["round", "square", "aviator", "visor"]
const NICKNAME_MAX_LENGTH := 16

@export var nickname := TranslationServer.translate("DEFAULT_NICKNAME")
@export var feather_style := FeatherStyle.SOLID
@export var feather_color := Color("f7f5ee")
## Top color when feather_style is GRADIENT.
@export var feather_color_2 := Color("8fc1ff")
@export var leg_color := Color("2b2b30")
## Worn items (slot items and extras): id -> color. Missing = not worn.
@export var accessories: Dictionary = {}
@export var glasses_style := ""
@export var glasses_frame := Color("2b2b30")
@export var glasses_lens := Color("8fc1ff")
@export var glasses_lens_gradient := false
## Bottom color of the lens when glasses_lens_gradient is on.
@export var glasses_lens_2 := Color("ff8fb8")


func is_wearing(id: String) -> bool:
	return accessories.has(id)


## The item worn in a slot ("head", "outfit", "footwear"), or "".
func slot_item(slot: String) -> String:
	for id: String in SLOTS[slot]:
		if accessories.has(id):
			return id
	return ""


## Wears `id` in its slot (taking off the previous one), or empties it with "".
func set_slot(slot: String, id: String, color: Color) -> void:
	for other: String in SLOTS[slot]:
		accessories.erase(other)
	if id in SLOTS[slot]:
		accessories[id] = color


## Color of what is worn in a slot (or `fallback`).
func slot_color(slot: String, fallback: Color) -> Color:
	var id := slot_item(slot)
	return accessories[id] if id != "" else fallback


## The footwear being worn, or "" when barefoot.
func footwear() -> String:
	return slot_item("footwear")


func to_dict() -> Dictionary:
	var worn := {}
	for id: String in accessories:
		worn[id] = (accessories[id] as Color).to_html(false)
	return {
		"nickname": nickname,
		"feather_style": "gradient" if feather_style == FeatherStyle.GRADIENT else "solid",
		"feather_color": feather_color.to_html(false),
		"feather_color_2": feather_color_2.to_html(false),
		"leg_color": leg_color.to_html(false),
		"accessories": worn,
		"glasses": {
			"style": glasses_style,
			"frame": glasses_frame.to_html(false),
			"lens": glasses_lens.to_html(false),
			"lens_2": glasses_lens_2.to_html(false),
			"lens_gradient": glasses_lens_gradient,
		},
	}


static func from_dict(data: Dictionary) -> SwanLook:
	var look := SwanLook.new()
	look.nickname = str(data.get("nickname", look.nickname)).left(NICKNAME_MAX_LENGTH)
	if data.get("feather_style", "solid") == "gradient":
		look.feather_style = FeatherStyle.GRADIENT
	look.feather_color = _color(data.get("feather_color"), look.feather_color)
	look.feather_color_2 = _color(data.get("feather_color_2"), look.feather_color_2)
	look.leg_color = _color(data.get("leg_color"), look.leg_color)
	var worn = data.get("accessories", {})
	if worn is Dictionary:
		for id in worn:
			var color := _color(worn[id], Color.WHITE)
			if id == "glasses":
				# Saves from before glasses had shapes.
				look.glasses_style = "round"
				look.glasses_frame = color
				continue
			for slot: String in SLOTS:
				if id in SLOTS[slot]:
					look.set_slot(slot, id, color)
			if id in EXTRAS:
				look.accessories[id] = color
	var glasses = data.get("glasses", {})
	if glasses is Dictionary and not glasses.is_empty():
		var style := str(glasses.get("style", ""))
		look.glasses_style = style if style in GLASSES_STYLES else ""
		look.glasses_frame = _color(glasses.get("frame"), look.glasses_frame)
		look.glasses_lens = _color(glasses.get("lens"), look.glasses_lens)
		look.glasses_lens_2 = _color(glasses.get("lens_2"), look.glasses_lens_2)
		look.glasses_lens_gradient = bool(glasses.get("lens_gradient", false))
	return look


static func _color(value, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
