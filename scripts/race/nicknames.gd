class_name Nicknames
extends RefCounted
## Friendly random nicknames, for players without a keyboard.

const FIRST := ["Pena", "Bico", "Asa", "Pluma", "Vento", "Raio", "Nuvem", "Pipoca", "Cometa", "Brisa"]
const SECOND := ["Veloz", "Dourada", "Maluca", "Turbo", "Feliz", "Zen", "Solar", "Ligeira", "Doida", "Estelar"]


static func random() -> String:
	return "%s %s" % [FIRST.pick_random(), SECOND.pick_random()]
