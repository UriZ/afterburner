class_name BlockFont
extends RefCounted

## Procedural 5x7 dot-matrix glyph font for the arcade-style HUD.
## Godot has no bundled pixel font (assets/fonts/ is empty), so glyphs are
## drawn as filled squares via draw_rect, matching the project's existing
## _draw()-based rendering convention (see player_jet_2d.gd).
## Covers only the HUD's fixed vocabulary: SCORE, HI, STAGE, SPEED, digits.

const ROWS := 7
const COLS := 5

const GLYPHS: Dictionary = {
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
}


## Draws text (upper-cased) at pos using px-sized square pixels.
## Returns the rendered width in pixels.
static func draw_text(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, spacing: int = 1) -> float:
	var x := pos.x
	for ch in text.to_upper():
		_draw_char(ci, ch, Vector2(x, pos.y), px, color)
		x += float(COLS + spacing) * px
	return x - pos.x


## Width in pixels of a string of the given length at pixel size px, without drawing.
static func text_width(length: int, px: float, spacing: int = 1) -> float:
	if length <= 0:
		return 0.0
	return float(length * (COLS + spacing) - spacing) * px


static func _draw_char(ci: CanvasItem, ch: String, pos: Vector2, px: float, color: Color) -> void:
	var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
	for row in range(ROWS):
		var line: String = glyph[row]
		for col in range(COLS):
			if line[col] == "1":
				ci.draw_rect(Rect2(pos + Vector2(col, row) * px, Vector2(px, px)), color)
