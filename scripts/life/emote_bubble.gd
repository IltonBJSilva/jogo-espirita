class_name EmoteBubble
extends Node2D
## Balões de emoção e falas curtas acima da cabeça dos NPCs, desenhados em pixel
## art por código (sem assets). Ícones: conversa, sono, comida, trabalho, musica,
## exclamacao, coracao, prece, estudo.

const PX := 2  # cada "pixel" do ícone = 2 px (mesma densidade da arte do jogo)
const PAPER := Color(0.96, 0.92, 0.82)
const INK := Color(0.16, 0.09, 0.09)
const ICONS := {
	"conversa": ["........", "........", "........", "##.##.##", "##.##.##", "........", "........"],
	"sono": ["######..", "....#...", "...#....", "..#..###", ".#....#.", "#####.#.", ".....###"],
	"comida": ["..#.#...", ".#.#....", "........", "########", "#......#", ".#....#.", "..####.."],
	"trabalho": [".####...", ".####...", "...##...", "...##...", "...##...", "...##...", "...##..."],
	"musica": ["...####.", "...#..#.", "...#..#.", "...#..#.", ".###.##.", "####.##.", ".##....."],
	"exclamacao": ["...##...", "...##...", "...##...", "...##...", "........", "...##...", "...##..."],
	"coracao": [".##..##.", "########", "########", ".######.", "..####..", "...##...", "........"],
	"prece": ["...##...", "..#..#..", "..#..#..", ".#.##.#.", ".#.##.#.", "#..##..#", "########"],
	"estudo": ["........", "###..###", "#..##..#", "#..##..#", "#..##..#", "###..###", "...##..."],
}
const ICON_COLORS := {
	"coracao": Color(0.75, 0.2, 0.3), "comida": Color(0.55, 0.32, 0.14), "trabalho": Color(0.35, 0.28, 0.25),
	"musica": Color(0.3, 0.2, 0.45), "prece": Color(0.7, 0.55, 0.15), "estudo": Color(0.36, 0.11, 0.16),
	"sono": Color(0.2, 0.25, 0.5), "exclamacao": Color(0.75, 0.3, 0.1),
}

var _kind := ""
var _text := ""
var _tween: Tween


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	position = Vector2(0, -100)
	modulate.a = 0.0


func show_emote(kind: String, seconds: float = 2.2) -> void:
	if not ICONS.has(kind):
		return
	_kind = kind
	_text = ""
	_play(seconds)


func show_bark(text: String, seconds: float = 3.0) -> void:
	_kind = ""
	_text = text.substr(0, 46)
	_play(seconds)


func _play(seconds: float) -> void:
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	position = Vector2(0, -96)
	modulate.a = 0.0
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.parallel().tween_property(self, "position:y", -102.0, 0.18)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)


func _font() -> Font:
	var theme := ThemeDB.get_project_theme()
	return theme.default_font if theme and theme.default_font else ThemeDB.fallback_font


func _draw() -> void:
	if _text != "":
		var font := _font()
		var size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var w := ceilf(size.x) + 10.0
		var r := Rect2(-w / 2.0, -18, w, 17)
		_bubble(r)
		draw_string(font, Vector2(r.position.x + 5, r.position.y + 12), _text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		return
	if _kind == "":
		return
	var rows: Array = ICONS[_kind]
	var iw := 8 * PX
	var r2 := Rect2(-iw / 2.0 - 4, -rows.size() * PX - 8, iw + 8, rows.size() * PX + 7)
	_bubble(r2)
	var color: Color = ICON_COLORS.get(_kind, INK)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "#":
				draw_rect(Rect2(r2.position.x + 4 + x * PX, r2.position.y + 4 + y * PX, PX, PX), color)


func _bubble(r: Rect2) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, PAPER)
	# rabicho apontando para a cabeça
	draw_rect(Rect2(-3, r.end.y, 6, 2), INK)
	draw_rect(Rect2(-2, r.end.y, 4, 1), PAPER)
	draw_rect(Rect2(-1, r.end.y + 2, 2, 2), INK)
