class_name SchermataDuello
extends Control
## Duello degli indizi (TV): 3 indizi a tempo, premio che scende, 4 risposte, due squadre ai lati.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const MAGENTA := Color("FF3DA8")
const GOLD := Color("FFC83D")
const BLU := Color("2F7BFF")
const VERDE := Color("3DDC84")
const ROSSO := Color("F2384A")
const DIM_BG := Color("3A2A6E")
const DIM_TEXT := Color("B8ACE0")
const OMBRA := Color("0A0320")
const CX := 420.0
const CW := 1080.0

var _tab: Panel
var _tab_lbl: Label
var _cat: Label
var _strisce: Array[Panel] = []
var _testi: Array[Label] = []
var _indizi: Array = []
var _premio_lbl: Label
var _barra: Control
var _frazione := 1.0
var _sec := 0
var _premio := 0
var _carte: Array[Risposta] = []
var _squadre: Array = []
var _righe: Array = [[], []]  # per squadra: [{pid, pannello}]
var _risponde: Array[Label] = [null, null]
var _stato: Array[Panel] = [null, null]
var _stato_lbl: Array[Label] = [null, null]
var _giusto: Array[bool] = [false, false]


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# categoria
	_pannello(Vector2(CX, 80), Vector2(CW, 80), INK, MAGENTA, 8, 28)
	_cat = Risposta.etichetta("", Risposta.font_display(), 52, GOLD, CW - 60, 72)
	_cat.position = Vector2(CX + 30, 84)
	add_child(_cat)
	_tab = Panel.new()
	_tab.position = Vector2(CX + 40, 36)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.add_theme_stylebox_override("panel", Risposta.box(MAGENTA, INK, 6, 6, 30))
	add_child(_tab)
	_tab_lbl = Risposta.etichetta("", Risposta.font_display(), 32, INK, 100, 56)
	_tab.add_child(_tab_lbl)
	# indizi
	for i in 3:
		var p := Panel.new()
		p.position = Vector2(CX, 180.0 + i * 142.0)
		p.size = Vector2(CW, 128)
		p.pivot_offset = p.size / 2.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", Risposta.box(DIM_BG, INK, 6, 12, 28))
		add_child(p)
		var n := Panel.new()
		n.position = Vector2(20, 24)
		n.size = Vector2(76, 76)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_theme_stylebox_override("panel", Risposta.box(MAGENTA, INK, 6, 6, 38))
		n.add_child(Risposta.etichetta(str(i + 1), Risposta.font_display(), 48, INK, 76, 70))
		p.add_child(n)
		var l := Risposta.etichetta("?", Risposta.font_testo(), 44, DIM_TEXT, CW - 150, 108)
		l.position = Vector2(120, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = true  # senza, l'autowrap allunga la label e adatta() non vede l'overflow
		p.add_child(l)
		_strisce.append(p)
		_testi.append(l)
	# premio + timer
	_pannello(Vector2(CX, 612), Vector2(CW, 80), INK, GOLD, 8, 28)
	var pt := Risposta.etichetta("PREMIO", Risposta.font_display(), 32, CREAM, 160, 72, HORIZONTAL_ALIGNMENT_LEFT)
	pt.position = Vector2(CX + 30, 616)
	add_child(pt)
	_premio_lbl = Risposta.etichetta("", Risposta.font_display(), 64, GOLD, 200, 72, HORIZONTAL_ALIGNMENT_LEFT)
	_premio_lbl.position = Vector2(CX + 190, 614)
	_premio_lbl.pivot_offset = Vector2(60, 36)
	add_child(_premio_lbl)
	_barra = Control.new()
	_barra.position = Vector2(CX + 420, 626)
	_barra.size = Vector2(CW - 450, 52)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_disegna_barra)
	add_child(_barra)
	# risposte 2x2 (carte da 852 px ridotte a 0,62)
	for i in 4:
		var c := Control.new()
		c.position = Vector2(CX + (i % 2) * 552.0, 716.0 + (i / 2) * 98.0)
		c.scale = Vector2(0.62, 0.62)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var r := Risposta.new()
		c.add_child(r)
		r.setup("ABCD"[i], "")
		_carte.append(r)


func _pannello(pos: Vector2, sz: Vector2, bg: Color, bordo: Color, b: int, r: int) -> Panel:
	var ombra := Panel.new()
	ombra.position = pos + Vector2(0, 12)
	ombra.size = sz
	ombra.add_theme_stylebox_override("panel", Risposta.box(OMBRA, OMBRA, 0, 0, r))
	ombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ombra)
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", Risposta.box(bg, bordo, b, b, r))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


## squadre: due array di {pid, nome, colore, personaggio}.
func setup(squadre: Array) -> void:
	_squadre = squadre
	for t in 2:
		var col := MAGENTA if t == 0 else BLU
		var p := _pannello(Vector2(20.0 if t == 0 else 1520.0, 80), Vector2(380, 900), INK, col, 8, 32)
		var h := Panel.new()
		h.position = Vector2(24, -26)
		h.size = Vector2(250, 56)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_stylebox_override("panel", Risposta.box(col, INK, 6, 6, 28))
		h.add_child(Risposta.etichetta("SQUADRA " + "AB"[t], Risposta.font_display(), 32, INK, 250, 52))
		p.add_child(h)
		var rb := Panel.new()
		rb.position = Vector2(24, 50)
		rb.size = Vector2(332, 130)
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.add_theme_stylebox_override("panel", Risposta.box(GOLD, INK, 6, 10, 24))
		p.add_child(rb)
		rb.add_child(Risposta.etichetta("RISPONDE", Risposta.font_display(), 28, INK, 332, 40))
		var rn := Risposta.etichetta("", Risposta.font_display(), 52, INK, 308, 70)
		rn.position = Vector2(12, 46)
		rb.add_child(rn)
		_risponde[t] = rn
		var membri: Array = squadre[t]
		_righe[t] = []
		for i in membri.size():
			var m: Dictionary = membri[i]
			var riga := Panel.new()
			riga.position = Vector2(24, 210 + i * 118)
			riga.size = Vector2(332, 104)
			riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
			riga.add_theme_stylebox_override("panel", Risposta.box(CREAM, INK, 5, 8, 24))
			p.add_child(riga)
			var cerchio := Panel.new()
			cerchio.position = Vector2(14, 12)
			cerchio.size = Vector2(72, 72)
			cerchio.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cerchio.add_theme_stylebox_override("panel", Risposta.box(m["colore"], INK, 5, 5, 36))
			cerchio.add_child(Risposta.etichetta(str(m["nome"]).substr(0, 1).to_upper(), Risposta.font_display(), 44, INK, 72, 66))
			riga.add_child(cerchio)
			var nome := Risposta.etichetta(m["nome"], Risposta.font_display(), 38, INK, 220, 84, HORIZONTAL_ALIGNMENT_LEFT)
			nome.position = Vector2(100, 4)
			Risposta.adatta(nome, 38, 22)
			riga.add_child(nome)
			_righe[t].append({"pid": m["pid"], "pannello": riga})
		var st := Panel.new()
		st.position = Vector2(24, 730)
		st.size = Vector2(332, 146)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.add_theme_stylebox_override("panel", Risposta.box(DIM_BG, INK, 6, 10, 24))
		p.add_child(st)
		var sl := Risposta.etichetta("", Risposta.font_display(), 40, DIM_TEXT, 308, 126)
		sl.position = Vector2(12, 6)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.clip_text = true
		st.add_child(sl)
		_stato[t] = st
		_stato_lbl[t] = sl


func _nome(pid: int) -> String:
	for sq in _squadre:
		for m in sq:
			if m["pid"] == pid:
				return m["nome"]
	return ""


func mostra_domanda(k: int, categoria_indizi: String, indizi: Array, risposte: Array, chi: Array) -> void:
	_tab_lbl.text = "DUELLO DEGLI INDIZI · DOMANDA %d/3" % k
	var w := Risposta.font_display().get_string_size(_tab_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x + 56.0 + 12.0
	_tab.size = Vector2(w, 60)
	_tab_lbl.size.x = w - 12.0
	_cat.text = categoria_indizi
	Risposta.adatta(_cat, 52, 28)
	_indizi = indizi
	for i in 3:
		_strisce[i].add_theme_stylebox_override("panel", Risposta.box(DIM_BG, INK, 6, 12, 28))
		_strisce[i].scale = Vector2.ONE
		_testi[i].text = "?"
		_testi[i].add_theme_color_override("font_color", DIM_TEXT)
		Risposta.adatta(_testi[i], 44, 28)
	for i in 4:
		_carte[i].reset()
		_carte[i]._testo.text = risposte[i]
		_carte[i]._layout_testo()
		_carte[i].entra(0.2 + 0.08 * i)
	for t in 2:
		_giusto[t] = false
		_set_stato(t, "attesa", 0)
		_risponde[t].text = _nome(chi[t])
		Risposta.adatta(_risponde[t], 52, 24)
		for r in _righe[t]:
			var ora: bool = r["pid"] == chi[t]
			r["pannello"].add_theme_stylebox_override("panel", Risposta.box(GOLD if ora else CREAM, INK, 5, 8, 24))
	set_premio(Duello.PREMI[0])
	set_tempo(Duello.INDIZIO_SEC, Duello.INDIZIO_SEC)


var _ultimo_indizio := 0  # indizi già scoperti: dopo il 3° la barra conta la fine della domanda


func mostra_indizio(n: int) -> void:
	var i := n - 1
	_ultimo_indizio = n
	_strisce[i].add_theme_stylebox_override("panel", Risposta.box(CREAM, INK, 6, 12, 28))
	_testi[i].text = _indizi[i]
	_testi[i].add_theme_color_override("font_color", INK)
	Risposta.adatta(_testi[i], 44, 26)
	_strisce[i].scale = Vector2(0.85, 0.85)
	create_tween().tween_property(_strisce[i], "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for t in 2:  # chi aveva sbagliato riprova col nuovo indizio
		if not _giusto[t]:
			_set_stato(t, "attesa", 0)


func set_premio(premio: int) -> void:
	if premio != _premio:
		_premio_lbl.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(_premio_lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_premio = premio
	_premio_lbl.text = str(premio)


func set_tempo(secondi: float, totale: float) -> void:
	_frazione = clampf(secondi / totale, 0.0, 1.0)
	_sec = ceili(secondi)
	_barra.queue_redraw()


func _disegna_barra() -> void:
	var s := _barra.size
	_barra.draw_rect(Rect2(0, 0, s.x, s.y), INK)
	_barra.draw_rect(Rect2(6, 6, s.x - 12, s.y - 12), DIM_BG)
	_barra.draw_rect(Rect2(6, 6, (s.x - 12) * _frazione, s.y - 12), GOLD)
	var t := ("PROSSIMO INDIZIO  %d" if _ultimo_indizio < 3 else "ULTIMI SECONDI  %d") % _sec
	_barra.draw_string_outline(Risposta.font_display(), Vector2(0, 38), t, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, 8, INK)
	_barra.draw_string(Risposta.font_display(), Vector2(0, 38), t, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, CREAM)


## punti_per_membro: valore assoluto mostrato (+ se giusta, - se sbagliata).
func esito_squadra(squadra: int, giusta: bool, punti_per_membro: int) -> void:
	_giusto[squadra] = giusta
	_set_stato(squadra, "giusto" if giusta else "sbagliato", absi(punti_per_membro))


func _set_stato(t: int, s: String, punti: int) -> void:
	var bg := DIM_BG
	var col := DIM_TEXT
	var txt := "IN ATTESA"
	if s == "giusto":
		bg = VERDE
		col = INK
		txt = "INDOVINATO!\n+%d" % punti
	elif s == "sbagliato":
		bg = ROSSO
		col = CREAM
		txt = "SBAGLIATO -%d\nriprova dopo" % punti
	_stato[t].add_theme_stylebox_override("panel", Risposta.box(bg, INK, 6, 10, 24))
	_stato_lbl[t].text = txt
	_stato_lbl[t].add_theme_color_override("font_color", col)
	Risposta.adatta(_stato_lbl[t], 40, 22)


func rivela(corretta: int) -> void:
	set_tempo(0.0, 1.0)
	for i in 4:
		_carte[i].set_stato("giusta" if i == corretta else "sbagliata")
