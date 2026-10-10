extends CanvasLayer
## HUD stile quiz show TV. Solo UI, nessuna regola di gioco.

const PLAYER_COLORS: Array[Color] = [Color("E53935"), Color("1E88E5"), Color("43A047"), Color("FDD835"), Color("8E24AA"), Color("FB8C00")]
const ANSWER_COLORS: Array[Color] = [Color("1E5BFF"), Color("FF8A00"), Color("22D400"), Color("FFD800")]
const NAVY := Color(0.04, 0.06, 0.18, 0.9)
const EDGE := Color(0.75, 0.85, 1.0, 0.8)
const GOLD := Color("FFD600")
const DIM := Color(1, 1, 1, 0.22)
const ROW_X := 1380
const ROW_Y := 300
const ROW_H := 104
const ROW_GAP := 8
const Q_W := 1432.0

var _font: FontVariation
var _logo_font: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
var _gloss: GradientTexture2D
var _menu: Control
var _question: Control
var _score: Control
var _final: Control
var _bar: Panel
var _q_head: Label
var _q_text: Label
var _clock_box: Panel
var _clock: Clock
var _clock_lbl: Label
var _ans_panels: Array[Panel] = []
var _ans_styles: Array[StyleBoxFlat] = []
var _ans_labels: Array[Label] = []
var _ans_nums: Array[Label] = []
var _rows: Dictionary = {}  # id -> {row, style, score, badge, val}
var _loops: Array[Tween] = []
var _final_title: Label
var _score_list: VBoxContainer
var _final_list: VBoxContainer


## Quadrante tondo che si svuota.
class Clock extends Control:
	var frac := 1.0
	var red := false

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, 82.0)
		var col := Color("FF3030") if red else Color.WHITE
		draw_circle(c, 72.0, col)
		draw_circle(c, 63.0, Color(0.05, 0.08, 0.2))
		if frac >= 0.999:
			draw_circle(c, 58.0, col)
		elif frac > 0.01:
			var n := maxi(int(64.0 * frac), 3)
			for i in n:  # a spicchi: il poligono concavo non triangola bene
				var a0 := -PI / 2.0 + TAU * frac * float(i) / float(n)
				var a1 := -PI / 2.0 + TAU * frac * float(i + 1) / float(n)
				draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 58.0, c + Vector2(cos(a1), sin(a1)) * 58.0]), col)


## Badge tondo con spunta o croce.
class Badge extends Control:
	var ok := true

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 29.0, Color.WHITE)
		draw_circle(c, 25.0, Color("2EBD3A") if ok else Color("E02020"))
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-13, 1), c + Vector2(-4, 11), c + Vector2(14, -10)]), Color.WHITE, 7.0, true)
		else:
			draw_line(c + Vector2(-12, -12), c + Vector2(12, 12), Color.WHITE, 7.0, true)
			draw_line(c + Vector2(12, -12), c + Vector2(-12, 12), Color.WHITE, 7.0, true)


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = load("res://assets/fonts/Montserrat.ttf")
	_font.variation_opentype = {2003265652: 800}  # tag 'wght'
	_gloss = GradientTexture2D.new()
	_gloss.width = 4
	_gloss.height = 64
	_gloss.fill_from = Vector2(0, 0)
	_gloss.fill_to = Vector2(0, 1)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.51, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)])
	_gloss.gradient = g
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = _font
	root.theme = th
	add_child(root)
	_build_menu(root)
	_build_question(root)
	_score = _build_center(root, "CLASSIFICA")
	_score_list = _score.get_meta("list")
	_final = _build_center(root, "")
	_final_title = _final.get_meta("title")
	_final_list = _final.get_meta("list")
	hide_all()


# ---------- helper ----------

func _style(bg: Color, border: Color, bw: int, radius: int, glow: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(border.r, border.g, border.b, 0.55) if glow > 0.0 else Color(0, 0, 0, 0.45)
	s.shadow_size = int(glow) if glow > 0.0 else 10
	s.shadow_offset = Vector2.ZERO if glow > 0.0 else Vector2(0, 5)
	return s


func _rect(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


## Pannello "vetro": fondo blu notte + riflesso chiaro in alto.
func _glass(parent: Control, x: float, y: float, w: float, h: float, st: StyleBoxFlat) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", st)
	_rect(p, x, y, w, h)
	parent.add_child(p)
	var gl := TextureRect.new()
	gl.texture = _gloss
	gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gl.stretch_mode = TextureRect.STRETCH_SCALE
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := float(st.border_width_left) + 3.0
	_rect(gl, inset, inset, w - 2.0 * inset, h - 2.0 * inset)
	p.add_child(gl)
	return p


func _label(parent: Control, size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _full(root: Control) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _loop(tw: Tween) -> void:
	tw.set_loops()
	_loops.append(tw)


func _stop_loops() -> void:
	for t in _loops:
		t.kill()
	_loops.clear()


# ---------- costruzione ----------

func _build_menu(root: Control) -> void:
	_menu = _full(root)
	var logo := _glass(_menu, 300, 250, 1320, 330, _style(Color(0.04, 0.06, 0.2, 0.82), EDGE, 4, 44))
	logo.set_meta("logo", true)
	var t := _label(_menu, 205, GOLD)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.text = "QUIZ PARTY!"
	t.add_theme_font_override("font", _logo_font)
	t.add_theme_color_override("font_outline_color", Color("C2185B"))
	t.add_theme_constant_override("outline_size", 36)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("shadow_offset_y", 12)
	_rect(t, 300, 250, 1320, 330)
	t.pivot_offset = Vector2(660, 165)
	t.rotation_degrees = -3.0
	var p := _glass(_menu, 560, 700, 800, 130, _style(NAVY, GOLD, 5, 30, 14.0))
	var s := _label(p, 56)
	s.text = "PREMI OK PER INIZIARE"
	s.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rect(s, 0, 0, 800, 130)
	p.pivot_offset = Vector2(400, 65)
	p.set_meta("pulse", true)


func _build_question(root: Control) -> void:
	_question = _full(root)
	_bar = _glass(_question, 96, 54, 1494, 180, _style(NAVY, EDGE, 3, 22))
	_q_head = _label(_bar, 32, Color("7FC8FF"), HORIZONTAL_ALIGNMENT_LEFT)
	_q_head.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rect(_q_head, 32, 8, 1400, 38)
	_q_text = _label(_bar, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_q_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q_text.add_theme_constant_override("line_spacing", -6)
	_rect(_q_text, 32, 46, Q_W, 128)
	# orologio
	_clock_box = _glass(_question, 1610, 40, 214, 210, _style(NAVY, EDGE, 3, 22))
	_clock = Clock.new()
	_rect(_clock, 0, 0, 214, 210)
	_clock_box.add_child(_clock)
	_clock_lbl = _label(_clock_box, 44, Color.WHITE)
	_rect(_clock_lbl, 0, 156, 214, 46)
	_clock_box.pivot_offset = Vector2(107, 105)
	# risposte
	for i in 4:
		var st := _style(NAVY, ANSWER_COLORS[i], 7, 16, 12.0)
		var p := _glass(_question, 96, 300 + i * 178, 504, 160, st)
		var n := _label(p, 32, ANSWER_COLORS[i], HORIZONTAL_ALIGNMENT_LEFT)
		_rect(n, 16, 6, 40, 40)
		var l := _label(p, 44)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", -6)
		_rect(l, 22, 8, 460, 144)
		p.pivot_offset = Vector2(252, 80)
		_ans_panels.append(p)
		_ans_styles.append(st)
		_ans_labels.append(l)
		_ans_nums.append(n)
		n.text = str(i + 1)


## Pannello centrale con titolo e lista (meta: title, list).
func _build_center(root: Control, title: String) -> Control:
	var c := _full(root)
	var p := _glass(c, 460, 120, 1000, 840, _style(NAVY, EDGE, 4, 36))
	var t := _label(p, 84, GOLD)
	t.add_theme_font_override("font", _logo_font)
	t.add_theme_constant_override("outline_size", 14)
	t.text = title
	_rect(t, 0, 24, 1000, 120)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	_rect(list, 50, 170, 900, 640)
	p.add_child(list)
	c.set_meta("title", t)
	c.set_meta("list", list)
	return c


func _fill_ranking(list: VBoxContainer, ranking: Array) -> void:
	for ch in list.get_children():
		ch.queue_free()
	var rows := ranking.size()
	var rh := mini(96, int(640.0 / maxi(rows, 1)) - 12)
	for i in rows:
		var r: Dictionary = ranking[i]
		var col: Color = PLAYER_COLORS[int(r.get("id", 0)) % PLAYER_COLORS.size()]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(900, rh)
		list.add_child(holder)
		var st := _style(Color(0.04, 0.06, 0.18, 0.92), col, 6, 16, 10.0)
		_glass(holder, 0, 0, 900, rh, st)
		var pos := _label(holder, 48, GOLD)
		pos.text = "%d" % (i + 1)
		_rect(pos, 10, 0, 80, rh)
		var nm := _label(holder, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		nm.text = str(r.get("name", "")).to_upper()
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		_rect(nm, 100, 0, 560, rh)
		var sc := _label(holder, 48, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		sc.text = str(r.get("score", 0))
		_rect(sc, 660, 0, 220, rh)


# ---------- API ----------

func _only(c: Control) -> void:
	_stop_loops()
	for x: Control in [_menu, _question, _score, _final]:
		x.visible = x == c
	if c == null:
		return
	if c == _menu:
		for ch in _menu.get_children():
			if ch.has_meta("pulse"):
				var tw := create_tween()
				tw.tween_property(ch, "scale", Vector2(1.06, 1.06), 0.6).set_trans(Tween.TRANS_SINE)
				tw.tween_property(ch, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
				_loop(tw)
	if c != _question:
		c.pivot_offset = Vector2(960, 540)
		c.scale = Vector2(0.92, 0.92)
		c.modulate.a = 0.0
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(c, "modulate:a", 1.0, 0.25)


func hide_all() -> void:
	_only(null)


func show_menu() -> void:
	_only(_menu)


func setup_players(names: Array[String], portraits: Array) -> void:
	for d: Dictionary in _rows.values():
		(d.row as Control).queue_free()
	_rows.clear()
	for i in mini(names.size(), PLAYER_COLORS.size()):
		var col := PLAYER_COLORS[i]
		var row := Control.new()
		_rect(row, ROW_X, ROW_Y + i * (ROW_H + ROW_GAP), 444, ROW_H)
		row.pivot_offset = Vector2(222, ROW_H / 2.0)
		_question.add_child(row)
		var st := _style(NAVY, EDGE, 3, 12)
		var pn := _glass(row, 0, 0, 336, ROW_H, st)
		var nm := _label(pn, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		nm.text = names[i].to_upper()
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		_rect(nm, 18, 2, 300, 44)
		var line := ColorRect.new()
		line.color = Color(0.75, 0.85, 1.0, 0.45)
		_rect(line, 14, 49, 308, 3)
		pn.add_child(line)
		var sc := _label(pn, 42, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sc.text = "0"
		sc.autowrap_mode = TextServer.AUTOWRAP_OFF
		_rect(sc, 18, 52, 300, 48)
		# ritratto
		var fr := Panel.new()
		fr.add_theme_stylebox_override("panel", _style(col.darkened(0.4), col.lightened(0.5), 5, 10))
		_rect(fr, 340, 0, 104, ROW_H)
		row.add_child(fr)
		var tex: Texture2D = portraits[i] if i < portraits.size() else null
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_rect(tr, 6, 6, 92, ROW_H - 12)
			fr.add_child(tr)
		else:
			var cr := ColorRect.new()
			cr.color = col.darkened(0.15)
			_rect(cr, 6, 6, 92, ROW_H - 12)
			fr.add_child(cr)
			var ini := _label(cr, 52, Color.WHITE if i != 3 else Color("202020"))
			ini.text = names[i].substr(0, 1).to_upper()
			ini.add_theme_constant_override("outline_size", 0)
			_rect(ini, 0, 0, 92, ROW_H - 12)
		var bd := Badge.new()
		_rect(bd, -72, (ROW_H - 58) / 2.0, 58, 58)
		bd.pivot_offset = Vector2(29, 29)
		bd.visible = false
		row.add_child(bd)
		_rows[i] = {"row": row, "style": st, "score": sc, "badge": bd, "val": 0}
		row.visible = false


func show_question(index: int, total: int, q: Dictionary) -> void:
	_only(_question)
	_q_head.text = "DOMANDA %d/%d  ·  %s" % [index + 1, total, str(q.get("category", "")).to_upper()]
	var txt := str(q.get("question", "")).to_upper()
	_q_text.text = txt
	var fs := 56
	for sz in [56, 52, 48, 44, 40]:
		fs = sz
		var h := _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, Q_W, sz).y - 6.0 * (ceilf(_font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, Q_W, sz).y / (sz * 1.22)) - 1.0)
		if h <= 124.0:
			break
	_q_text.add_theme_font_size_override("font_size", fs)
	var a: Array = q.get("answers", [])
	for i in 4:
		_ans_labels[i].text = str(a[i]).to_upper() if i < a.size() else ""
		_ans_labels[i].modulate = Color.WHITE
		_ans_styles[i].bg_color = NAVY
		_ans_nums[i].add_theme_color_override("font_color", ANSWER_COLORS[i])
		_ans_panels[i].scale = Vector2.ONE
	for d: Dictionary in _rows.values():
		var st: StyleBoxFlat = d.style
		st.border_color = EDGE
		st.set_border_width_all(3)
		st.shadow_color = Color(0, 0, 0, 0.45)
		st.shadow_size = 10
		(d.badge as Control).visible = false
		(d.row as Control).visible = true
		(d.row as Control).modulate.a = 0.0
		create_tween().tween_property(d.row, "modulate:a", 1.0, 0.5).set_delay(0.5)
	set_time(1.0, 1.0)
	_bar.position.y = -220
	create_tween().tween_property(_bar, "position:y", 54.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_clock_box.modulate.a = 0.0
	create_tween().tween_property(_clock_box, "modulate:a", 1.0, 0.4).set_delay(0.3)
	for i in 4:
		var p := _ans_panels[i]
		p.position.x = -620
		create_tween().tween_property(p, "position:x", 96.0, 0.4).set_delay(0.3 + 0.15 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_time(left: float, total: float) -> void:
	var f := clampf(left / maxf(total, 0.001), 0.0, 1.0)
	_clock.frac = f
	_clock.red = left <= 5.0 and left > 0.0
	_clock.queue_redraw()
	_clock_lbl.text = str(ceili(maxf(left, 0.0)))
	_clock_lbl.add_theme_color_override("font_color", Color("FF5050") if _clock.red else Color.WHITE)
	var s := 1.0
	if _clock.red:
		s = 1.0 + 0.07 * sin((left - floorf(left)) * PI)
	_clock_box.scale = Vector2(s, s)


func mark_answered(player_id: int) -> void:
	if not _rows.has(player_id):
		return
	var d: Dictionary = _rows[player_id]
	var col := PLAYER_COLORS[player_id % PLAYER_COLORS.size()]
	var st: StyleBoxFlat = d.style
	st.border_color = col
	st.set_border_width_all(7)
	st.shadow_color = Color(col.r, col.g, col.b, 0.8)
	st.shadow_size = 20
	var row: Control = d.row
	row.scale = Vector2(1.08, 1.08)
	create_tween().tween_property(row, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_reveal(correct: int, results: Dictionary) -> void:
	for i in 4:
		if i == correct:
			_ans_styles[i].bg_color = ANSWER_COLORS[i].darkened(0.15)
			_ans_nums[i].add_theme_color_override("font_color", Color.WHITE)
			var tw := create_tween()
			tw.tween_property(_ans_panels[i], "scale", Vector2(1.05, 1.05), 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_ans_panels[i], "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
			_loop(tw)
		else:
			_ans_labels[i].modulate = DIM
			_ans_nums[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
	for id: int in _rows:
		var b: Badge = _rows[id].badge
		b.ok = bool(results.get(id, false))
		b.queue_redraw()
		b.visible = true
		b.scale = Vector2.ZERO
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_scores(scores: Dictionary) -> void:
	for id: int in _rows:
		var d: Dictionary = _rows[id]
		(d.badge as Control).visible = false
		var to: int = int(scores.get(id, d.val))
		var lbl: Label = d.score
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: lbl.text = str(int(round(v))), float(d.val), float(to), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		d.val = to


func show_scoreboard(ranking: Array) -> void:
	_fill_ranking(_score_list, ranking)
	_only(_score)


func show_final(ranking: Array) -> void:
	_final_title.text = ("VINCE %s!" % str(ranking[0].get("name", "")).to_upper()) if ranking.size() > 0 else "FINE!"
	_fill_ranking(_final_list, ranking)
	_only(_final)
