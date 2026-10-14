class_name Domande extends RefCounted
## Versione base (G1e): solo la riserva res://domande/<tipo>/<categoria>.json, controllata da tools/domande_check.mjs.
## Rete, cache e validazione dei dati scaricati arrivano con D5.

const RISERVA := "res://domande/"
const USCITE := "user://uscite.json"

var _tutte: Array = []
var _uscite: Dictionary = {}  # id -> true


func carica() -> void:
	_tutte.clear()
	for tipo in DirAccess.get_directories_at(RISERVA):
		for f in DirAccess.get_files_at(RISERVA + tipo):
			if f.ends_with(".json"):
				var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(RISERVA + tipo + "/" + f))
				if a is Array:
					_tutte.append_array(a)
	var u: Variant = JSON.parse_string(FileAccess.get_file_as_string(USCITE)) if FileAccess.file_exists(USCITE) else null
	if u is Array:
		for id: String in u:
			_uscite[id] = true


## n domande del tipo (e della difficoltà se > 0, della categoria se non vuota): prima le mai uscite, poi le altre; le segna come uscite.
## Le risposte restano con la giusta per prima: le mescola Game.
func pesca(tipo: String, n: int, difficolta := 0, categoria := "") -> Array:
	var nuove: Array = []
	var vecchie: Array = []
	for q: Dictionary in _tutte:
		if q["tipo"] == tipo and (difficolta == 0 or int(q["difficolta"]) == difficolta) and (categoria == "" or q["categoria"] == categoria):
			(vecchie if _uscite.has(q["id"]) else nuove).append(q)
	nuove.shuffle()
	vecchie.shuffle()
	var scelte: Array = (nuove + vecchie).slice(0, n)
	for q: Dictionary in scelte:
		_uscite[q["id"]] = true
	var f := FileAccess.open(USCITE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_uscite.keys()))
	return scelte


## Quante domande ci sono di quel tipo e categoria (uscite comprese).
func quante(tipo: String, categoria: String) -> int:
	var n := 0
	for q: Dictionary in _tutte:
		if q["tipo"] == tipo and q["categoria"] == categoria:
			n += 1
	return n
