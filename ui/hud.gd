extends CanvasLayer
## HUD testi/UI. Nessuna regola di gioco.

const PLAYER_COLORS: Array[Color] = [Color("E53935"), Color("1E88E5"), Color("43A047"), Color("FDD835"), Color("8E24AA"), Color("FB8C00")]
const ANSWER_COLORS: Array[Color] = [Color("1565C0"), Color("E65100"), Color("2E7D32"), Color("FDD835")]
const ANSWER_TEXT: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE, Color("1A1A1A")]
const PANEL_BG := Color("1B1740")
const MX := 96
const MY := 54

var _font: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
var _menu: Control
var _question: Control
var _score: Control
var _final: Control
var _q_head: Label
var _q_text: Label
var _ans_panels: Array[PanelContainer] = []
var _ans_labels: Array[Label] = []
var _timer_bar: ProgressBar
var _timer_lbl: Label
var _chips: Dictionary = {}
var _score_list: VBoxContainer
var _final_title: Label
var _final_list: VBoxContainer


func _ready() -> void:
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


func _style(color: Color, radius: int = 28, border: Color = Color.WHITE, bw: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _label(size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _rect(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _build_menu(root: Control) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_menu)
	var t := _label(300, Color("FFD600"))
	t.text = "BUZZ!"
	t.add_theme_color_override("font_outline_color", Color("B71C1C"))
	t.add_theme_constant_override("outline_size", 24)
	_rect(t, MX, 200, 1920 - 2 * MX, 380)
	_menu.add_child(t)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL_BG))
	_rect(p, 480, 700, 960, 150)
	var s := _label(64)
	s.text = "Premi OK per iniziare"
	p.add_child(s)
	_menu.add_child(p)


func _build_question(root: Control) -> void:
	_question = Control.new()
	_question.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_question)
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", _style(PANEL_BG))
	_rect(qp, MX, 530, 1920 - 2 * MX, 226)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_q_head = _label(36, Color("FFD600"))
	_q_text = _label(56)
	_q_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_q_head)
	v.add_child(_q_text)
	qp.add_child(v)
	_question.add_child(qp)
	var w := (1920 - 2 * MX - 20) / 2
	var h := 114
	for i in 4:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _style(ANSWER_COLORS[i]))
		_rect(p, MX + (i % 2) * (w + 20), 774 + (i / 2) * (h + 18), w, h)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		var n := _label(56, ANSWER_TEXT[i])
		n.text = str(i + 1)
		n.custom_minimum_size.x = 56
		var l := _label(44, ANSWER_TEXT[i], HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 100
		hb.add_child(n)
		hb.add_child(l)
		p.add_child(hb)
		_question.add_child(p)
		_ans_panels.append(p)
		_ans_labels.append(l)
	# timer in alto a destra
	var tb := Control.new()
	_question.add_child(tb)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.max_value = 1.0
	_timer_bar.add_theme_stylebox_override("background", _style(PANEL_BG, 20, Color.WHITE, 3))
	var fill := _style(Color("FFD600"), 16, Color(0, 0, 0, 0), 0)
	fill.shadow_size = 0
	_timer_bar.add_theme_stylebox_override("fill", fill)
	_rect(_timer_bar, 0, 0, 380, 56)
	_timer_lbl = _label(64, Color("FFD600"))
	_timer_lbl.add_theme_color_override("font_outline_color", PANEL_BG)
	_timer_lbl.add_theme_constant_override("outline_size", 10)
	_rect(_timer_lbl, 390, -6, 100, 68)
	tb.add_child(_timer_bar)
	tb.add_child(_timer_lbl)
	_rect(tb, 1920 - MX - 490, MY, 490, 56)
	# chips giocatori in alto a sinistra
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 14)
	_rect(cb, MX, MY, 700, 56)
	_question.add_child(cb)
	for i in PLAYER_COLORS.size():
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(56, 56)
		c.add_theme_stylebox_override("panel", _style(PLAYER_COLORS[i], 28, Color.WHITE, 4))
		c.visible = false
		cb.add_child(c)
		_chips[i] = c


## Pannello centrale con titolo e lista; ritorna il Control radice (meta: title, list).
func _build_center(root: Control, title: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL_BG, 36))
	_rect(p, 360, MY + 20, 1200, 1080 - 2 * MY - 40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var t := _label(88, Color("FFD600"))
	t.text = title
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(t)
	v.add_child(list)
	p.add_child(v)
	c.add_child(p)
	c.set_meta("title", t)
	c.set_meta("list", list)
	return c


func _fill_ranking(list: VBoxContainer, ranking: Array) -> void:
	for ch in list.get_children():
		ch.queue_free()
	var rows := ranking.size()
	var rh := mini(84, int(660.0 / maxi(rows, 1)) - 10)
	for i in rows:
		var r: Dictionary = ranking[i]
		var id: int = r.get("id", 0)
		var p := PanelContainer.new()
		var col: Color = PLAYER_COLORS[id % PLAYER_COLORS.size()]
		p.add_theme_stylebox_override("panel", _style(col.darkened(0.35), 20, col, 4))
		p.custom_minimum_size.y = rh
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		var pos := _label(52, Color.WHITE)
		pos.text = "%d." % (i + 1)
		pos.custom_minimum_size.x = 80
		var nm := _label(52, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		nm.text = str(r.get("name", ""))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		var sc := _label(56, Color("FFD600"), HORIZONTAL_ALIGNMENT_RIGHT)
		sc.text = str(r.get("score", 0))
		sc.custom_minimum_size.x = 160
		hb.add_child(pos)
		hb.add_child(nm)
		hb.add_child(sc)
		p.add_child(hb)
		list.add_child(p)


func _pop(c: Control) -> void:
	c.pivot_offset = Vector2(960, 540)
	c.scale = Vector2(0.9, 0.9)
	c.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)


func _only(c: Control) -> void:
	for x: Control in [_menu, _question, _score, _final]:
		x.visible = x == c
	if c != null:
		_pop(c)


func hide_all() -> void:
	_only(null)


func show_menu() -> void:
	_only(_menu)


func show_question(index: int, total: int, q: Dictionary) -> void:
	_only(_question)
	_q_head.text = "Domanda %d/%d  ·  %s" % [index + 1, total, str(q.get("category", ""))]
	_q_text.text = str(q.get("question", ""))
	var a: Array = q.get("answers", [])
	for i in 4:
		_ans_labels[i].text = str(a[i]) if i < a.size() else ""
		_ans_panels[i].modulate = Color.WHITE
	for c: Control in _chips.values():
		c.visible = false
	set_time(1.0, 1.0)


func set_time(left: float, total: float) -> void:
	_timer_bar.value = clampf(left / maxf(total, 0.001), 0.0, 1.0)
	_timer_lbl.text = str(ceili(maxf(left, 0.0)))


func mark_answered(player_id: int) -> void:
	if not _chips.has(player_id):
		return
	var c: Control = _chips[player_id]
	c.visible = true
	c.scale = Vector2.ZERO
	c.pivot_offset = Vector2(28, 28)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_reveal(correct: int) -> void:
	for i in 4:
		_ans_panels[i].modulate = Color.WHITE if i == correct else Color(1, 1, 1, 0.3)


func show_scoreboard(ranking: Array) -> void:
	_fill_ranking(_score_list, ranking)
	_only(_score)


func show_final(ranking: Array) -> void:
	_final_title.text = ("Vince %s!" % str(ranking[0].get("name", ""))) if ranking.size() > 0 else "Fine!"
	_fill_ranking(_final_list, ranking)
	_only(_final)
