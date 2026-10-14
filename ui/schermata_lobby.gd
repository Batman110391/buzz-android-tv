class_name SchermataLobby
extends Node2D
## Lobby 1b: card join a sinistra, griglia 3x2 di slot a destra, pill N/6 in alto.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const SLOT := Vector2(329, 399)
const GRIGLIA := Vector2(752, 200)
const GAP := 28.0

var _url: Label
var _qr: TextureRect
var _cod: Array[Label] = []
var _pill: Label
var _vuoti: Array[Node2D] = []
var _pieni: Array[Node2D] = []
var _pers: Array[Personaggio] = []


class Tratteggio extends Node2D:
	var dim: Vector2
	func _draw() -> void:
		var c := Color(CREAM, 0.55)
		var r := Rect2(Vector2.ZERO, dim).grow(-3)
		var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			draw_dashed_line(p[i], p[i + 1], c, 6, 20)




func _init() -> void:
	var tit := _lab("Entrate in studio!", Risposta.font_display(), 100, GOLD, 1000, 120, HORIZONTAL_ALIGNMENT_LEFT)
	tit.add_theme_constant_override("outline_size", 18)
	tit.add_theme_color_override("font_outline_color", INK)
	tit.add_theme_color_override("font_shadow_color", INK)
	tit.add_theme_constant_override("shadow_offset_y", 8)
	tit.position = Vector2(96, 54)
	add_child(tit)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Risposta.box(GOLD, INK, 6, 6, 40))
	pill.size = Vector2(560, 80)
	pill.position = Vector2(1824 - 560, 62)
	add_child(pill)
	_pill = _lab("", Risposta.font_testo(), 40, INK, 560, 74)
	pill.add_child(_pill)
	_card()
	for i in 6:
		var pos := GRIGLIA + Vector2(i % 3, i / 3) * (SLOT + Vector2(GAP, GAP))
		var v := Node2D.new()
		v.position = pos + SLOT / 2.0
		var t := Tratteggio.new()
		t.dim = SLOT
		t.position = -SLOT / 2.0
		v.add_child(t)
		var q := _lab("?", Risposta.font_display(), 160, Color(CREAM, 0.35), SLOT.x, 200)
		q.position = Vector2(-SLOT.x / 2.0, -150)
		v.add_child(q)
		var w := _lab("In attesa…", Risposta.font_testo(), 36, Color(CREAM, 0.8), SLOT.x, 60)
		w.position = Vector2(-SLOT.x / 2.0, 40)
		v.add_child(w)
		add_child(v)
		_vuoti.append(v)
		var p := Node2D.new()
		p.position = v.position
		p.visible = false
		add_child(p)
		_pieni.append(p)
		_pers.append(null)
	_conta()


func _lab(t: String, f: Font, d: int, c: Color, w: float, h: float, al := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return Risposta.etichetta(t, f, d, c, w, h, al)


func _card() -> void:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", Risposta.box(CREAM, INK, 6, 14, 28))
	c.size = Vector2(620, 826)
	c.position = Vector2(96, 200)
	add_child(c)
	c.add_child(_pos(_lab("Inquadra col telefono", Risposta.font_testo(), 48, INK, 620, 70), 0, 28))
	var qp := Panel.new()
	qp.add_theme_stylebox_override("panel", Risposta.box(CREAM, INK, 6, 6, 8))
	qp.size = Vector2(380, 380)
	qp.position = Vector2(120, 112)
	_qr = TextureRect.new()
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qp.add_child(_qr)
	c.add_child(qp)
	c.add_child(_pos(_lab("oppure vai su", Risposta.font_testo(), 36, INK, 620, 50), 0, 510))
	_url = _lab("", Risposta.font_display(), 64, INK, 620, 80)
	c.add_child(_pos(_url, 0, 566))
	for i in 4:
		var b := Panel.new()
		b.add_theme_stylebox_override("panel", Risposta.box(INK, INK, 0, 0, 16))
		b.size = Vector2(100, 112)
		b.position = Vector2(94 + i * 112, 668)
		c.add_child(b)
		var l := _lab("", Risposta.font_display(), 80, GOLD, 100, 108)
		b.add_child(l)
		_cod.append(l)


func _pos(n: Control, x: float, y: float) -> Control:
	n.position = Vector2(x, y)
	return n


func setup(url: String, codice: String) -> void:
	_url.text = url.trim_prefix("http://").trim_prefix("https://").get_slice("/", 0)
	var t := Qr.texture(url, 368, INK, CREAM)
	_qr.texture = t
	if t:
		_qr.position = (Vector2(380, 380) - t.get_size()) / 2.0
	for i in 4:
		_cod[i].text = codice.substr(i, 1)


func aggiungi(slot: int, id_personaggio: String, nome: String, colore: Color) -> void:
	var p := _pieni[slot]
	for c in p.get_children():
		c.queue_free()
	var h := SLOT / 2.0
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Risposta.box(colore, INK, 6, 12, 22))
	card.size = SLOT
	card.position = -h
	p.add_child(card)
	var pe := Personaggio.new()
	pe.setup(id_personaggio)
	pe.scale = Vector2.ONE * 1.45
	pe.position = Vector2(-145, -h.y + 34)
	p.add_child(pe)
	var barra := Panel.new()
	barra.add_theme_stylebox_override("panel", Risposta.box(INK, INK, 0, 0, 14))
	barra.size = Vector2(SLOT.x - 12, 64)
	barra.position = Vector2(-h.x + 6, h.y - 76)
	p.add_child(barra)
	barra.add_child(_lab(nome, Risposta.font_display(), 40, CREAM, barra.size.x, 64))
	_pers[slot] = pe
	_vuoti[slot].visible = false
	p.visible = true
	p.scale = Vector2.ZERO
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE * 1.1, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pe.stato("esulta")
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(pe):
			pe.stato("attesa"))
	_conta()


func togli(slot: int) -> void:
	for c in _pieni[slot].get_children():
		c.queue_free()
	_pers[slot] = null
	_pieni[slot].visible = false
	_vuoti[slot].visible = true
	_conta()


func _conta() -> void:
	var n := 0
	for p in _pieni:
		if p.visible:
			n += 1
	_pill.text = "%d/6 · INVIO per iniziare" % n
