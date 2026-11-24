class_name SwanLook
extends Resource
## How a swan looks: nickname, colors and worn accessories.
## Pure data. It never changes how fast a swan is.

enum FeatherStyle { SOLID, GRADIENT }

## Stable item ids (ADR 0012). Never rename an id: saves refer to them.
const ACCESSORY_IDS := ["cap", "wig", "makeup", "jacket", "sneakers"]
const NICKNAME_MAX_LENGTH := 16

@export var nickname := "Cisne"
@export var feather_style := FeatherStyle.SOLID
@export var feather_color := Color("f7f5ee")
## Top color when feather_style is GRADIENT.
@export var feather_color_2 := Color("8fc1ff")
@export var leg_color := Color("2b2b30")
## Worn accessories: id -> color. An id that is missing is not worn.
@export var accessories: Dictionary = {}


func is_wearing(id: String) -> bool:
	return accessories.has(id)


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
			if id in ACCESSORY_IDS:
				look.accessories[id] = _color(worn[id], Color.WHITE)
	return look


static func _color(value, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
