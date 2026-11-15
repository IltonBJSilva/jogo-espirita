extends Control
## Ícone de sol/lua do relógio, desenhado em código em blocos de pixel (16-bit).
## Usado por scenes/ui/clock_widget.tscn.

const PX := 2.0  # tamanho de cada "pixel"

var _phase := "manha"


func set_phase(phase: String, _minute_of_day: int) -> void:
	if phase != _phase:
		_phase = phase
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	match _phase:
		"noite", "madrugada":
			_moon(c)
		"amanhecer", "por_do_sol":
			_sun(c, Color(0.98, 0.62, 0.32), true)
		_:
			_sun(c, Color(1.0, 0.84, 0.36), false)


func _px(cell: Vector2, color: Color) -> void:
	draw_rect(Rect2(cell * PX, Vector2(PX, PX)), color)


func _disc(center: Vector2, r: float, color: Color, hole := Vector2.INF, hole_r := 0.0) -> void:
	var cc := center / PX
	for y in range(int(cc.y - r) - 1, int(cc.y + r) + 2):
		for x in range(int(cc.x - r) - 1, int(cc.x + r) + 2):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(cc) <= r and (hole == Vector2.INF or p.distance_to(hole / PX) > hole_r):
				_px(Vector2(x, y), color)


func _sun(c: Vector2, color: Color, low: bool) -> void:
	var outline := Color(0.36, 0.16, 0.08)
	for i in 8:
		var a := TAU * i / 8.0
		var p := c / PX + Vector2(cos(a), sin(a)) * 6.0
		_px(p.floor(), color)
	_disc(c, 4.6, outline)
	_disc(c, 3.8, color)
	_px((c / PX + Vector2(-1.5, -1.5)).floor(), Color(1, 0.97, 0.8))
	if low:  # horizonte no amanhecer e no pôr do sol
		draw_rect(Rect2(Vector2(0, c.y + 2 * PX), Vector2(size.x, size.y - c.y - 2 * PX)), Color(0.29, 0.12, 0.2))
		draw_line(Vector2(0, c.y + 2 * PX), Vector2(size.x, c.y + 2 * PX), Color(0.79, 0.6, 0.29), PX)


func _moon(c: Vector2) -> void:
	var outline := Color(0.12, 0.1, 0.2)
	_disc(c, 5.0, outline, c + Vector2(4, -3), 4.4)
	_disc(c, 4.2, Color(0.88, 0.88, 1.0), c + Vector2(4, -3), 4.4)
	_px((c / PX + Vector2(-3, -6)).floor(), Color(1, 1, 0.9))
	_px((c / PX + Vector2(5, 4)).floor(), Color(1, 1, 0.9))
