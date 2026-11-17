extends Button
## Botão da paleta: mostra a peça desenhada e diz o nome ao passar o mouse.

const GlyphDraw := preload("res://scripts/editor/glyph_draw.gd")

var glyph := "#"


func setup(g: String) -> void:
	glyph = g
	toggle_mode = true
	custom_minimum_size = Vector2(28, 28)
	tooltip_text = GlyphDraw.name_of(g)
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if "PBSLH".contains(glyph) or "abcdefghi".contains(glyph):
		GlyphDraw.draw_block(self, glyph, inner)
	elif glyph == "D":
		GlyphDraw.draw(self, "D", inner)
		draw_rect(inner, Color(GlyphDraw.RoomScript.C_DOOR_OPEN), false, 2.0)
	elif glyph == "#" or glyph == "|" or glyph == "-":
		GlyphDraw.draw(self, glyph, inner, {"edges": [true, true, true, true]})
	else:
		draw_rect(inner, Color("0c0c12"))
		GlyphDraw.draw(self, glyph, inner)
