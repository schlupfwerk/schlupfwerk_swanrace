class_name Nicknames
extends RefCounted
## Friendly random nicknames in the current language, for players without a
## keyboard.

const WORDS := {
	"pt": [
		["Pena", "Bico", "Asa", "Pluma", "Vento", "Raio", "Nuvem", "Pipoca", "Cometa", "Brisa"],
		["Veloz", "Dourada", "Maluca", "Turbo", "Feliz", "Zen", "Solar", "Ligeira", "Doida", "Estelar"],
	],
	"en": [
		["Speedy", "Fluffy", "Sunny", "Breezy", "Cosmic", "Lucky", "Zippy", "Captain", "Turbo", "Happy"],
		["Wing", "Beak", "Splash", "Dash", "Comet", "Pebble", "Puff", "Rocket", "Wave", "Feather"],
	],
}


static func random() -> String:
	var language := "pt" if TranslationServer.get_locale().begins_with("pt") else "en"
	var words: Array = WORDS[language]
	return "%s %s" % [words[0].pick_random(), words[1].pick_random()]
