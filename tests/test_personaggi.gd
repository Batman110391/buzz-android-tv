extends Node2D
# Prova Q2: Tony parla a turno con il fumetto, i 6 concorrenti ciclano gli stati sfasati.

const STATI: Array[String] = ["attesa", "pensa", "risposto", "esulta", "sconfitta", "sorpreso"]
const CONCORRENTI: Array[String] = ["chef", "nonna", "zombi", "gatto", "boss", "diva"]
const BATTUTE := [["firstbuzz_1", "sorpresa"], ["firstbuzz_2", "esulta"], ["hurry_1", "annuncio"], ["hurry_2", "saluto"]]
const INK := Color("1B0B3A")

var _host: Personaggio
var _testo: Label
var _testi: Dictionary


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("25095E")
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	_host = Personaggio.new()
	_host.setup("host")
	_host.position = Vector2(60, 270)
	_host.scale = Vector2.ONE * 2.5
	add_child(_host)

	_fumetto()
	for i in CONCORRENTI.size():
		var p := Personaggio.new()
		p.setup(CONCORRENTI[i])
		p.position = Vector2(980 + (i % 3) * 305, 340 + (i / 3) * 305)
		p.scale = Vector2.ONE * 1.45
		add_child(p)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 32)
		l.position = p.position + Vector2(0, 292)
		add_child(l)
		_cicla(p, l, i)
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voice/lines.json"))

	var re := RegEx.create_from_string(r"\[[^\]]*\]\s*")
	for k: String in lines:
		_testi[k] = re.sub(str(lines[k]), "", true)
	_sequenza()


func _fumetto() -> void:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Baloo2.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("FFF4DC")
	sb.set_border_width_all(6)
	sb.border_width_bottom = 16
	sb.border_color = INK
	sb.set_corner_radius_all(44)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 30
	sb.content_margin_bottom = 40
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	pc.position = Vector2(740, 50)
	pc.custom_minimum_size = Vector2(1000, 0)
	_testo = Label.new()
	_testo.add_theme_font_override("font", fv)
	_testo.add_theme_font_size_override("font_size", 56)
	_testo.add_theme_color_override("font_color", INK)
	_testo.add_theme_constant_override("line_spacing", -12)
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.custom_minimum_size = Vector2(912, 0)
	pc.add_child(_testo)
	add_child(pc)
	var coda := Polygon2D.new()
	coda.polygon = PackedVector2Array([Vector2(745, 120), Vector2(700, 215), Vector2(790, 180)])
	coda.color = INK
	add_child(coda)


func _dici(b: Array) -> void:
	var stream := load("res://assets/voice/%s.mp3" % b[0]) as AudioStream
	_testo.text = _testi[b[0]]
	_host.gesto(b[1], stream.get_length())
	_host.parla(stream)


func _sequenza() -> void:
	var i := 0
	while true:
		_dici(BATTUTE[i % BATTUTE.size()])
		await _host.finito_parlare
		await get_tree().create_timer(2.6).timeout
		i += 1


func _cicla(p: Personaggio, l: Label, i: int) -> void:
	var k := (i * 5) % 6
	await get_tree().create_timer(0.3 * i).timeout
	while true:
		var s := STATI[k % STATI.size()]
		p.stato(s)
		l.text = s
		await get_tree().create_timer(randf_range(1.8, 3.6)).timeout
		k += 1 + randi() % 2
