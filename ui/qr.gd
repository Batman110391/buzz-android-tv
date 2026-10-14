class_name Qr
## Encoder QR minimo: modalità byte, correzione M, versioni 1-5, maschera fissa 0.

const DATI := [0, 16, 28, 44, 64, 86]  # codeword di dati per versione (M)
const EC := [0, 10, 16, 26, 18, 24]  # codeword EC per blocco
const BLOCCHI := [0, 1, 1, 1, 2, 2]
const ALLINEA := [[], [], [6, 18], [6, 22], [6, 26], [6, 30]]

static var _exp: PackedInt32Array
static var _log: PackedInt32Array


static func _gf() -> void:
	if _exp.size() > 0:
		return
	_exp.resize(512)
	_log.resize(256)
	var x := 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]


static func _mul(a: int, b: int) -> int:
	return 0 if a == 0 or b == 0 else _exp[_log[a] + _log[b]]


static func _rs(dati: PackedByteArray, n: int) -> PackedByteArray:
	var div := PackedInt32Array()
	div.resize(n)
	div[n - 1] = 1
	var root := 1
	for i in n:
		for j in n:
			div[j] = _mul(div[j], root)
			if j + 1 < n:
				div[j] ^= div[j + 1]
		root = _mul(root, 2)
	var rem := PackedByteArray()
	rem.resize(n)
	for b in dati:
		var f := b ^ rem[0]
		rem.remove_at(0)
		rem.append(0)
		for i in n:
			rem[i] ^= _mul(div[i], f)
	return rem


## Ritorna la matrice come Array di PackedByteArray (1 = scuro); vuota se il testo non entra.
static func matrice(testo: String) -> Array:
	_gf()
	var dati := testo.to_utf8_buffer()
	var v := 1
	while v <= 5 and dati.size() > DATI[v] - 2:
		v += 1
	if v > 5:
		return []
	var bits: Array[int] = []
	for b in [0, 1, 0, 0]:
		bits.append(b)
	for i in range(7, -1, -1):
		bits.append((dati.size() >> i) & 1)
	for byte in dati:
		for i in range(7, -1, -1):
			bits.append((byte >> i) & 1)
	for i in mini(4, DATI[v] * 8 - bits.size()):
		bits.append(0)
	while bits.size() % 8:
		bits.append(0)
	var cw := PackedByteArray()
	for i in bits.size() / 8:
		var x := 0
		for j in 8:
			x = (x << 1) | bits[i * 8 + j]
		cw.append(x)
	var pad := 0xEC
	while cw.size() < DATI[v]:
		cw.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	# blocchi + interleave
	var nb: int = BLOCCHI[v]
	var lb: int = DATI[v] / nb
	var dblk: Array[PackedByteArray] = []
	var eblk: Array[PackedByteArray] = []
	for k in nb:
		var d := cw.slice(k * lb, (k + 1) * lb)
		dblk.append(d)
		eblk.append(_rs(d, EC[v]))
	var tot := PackedByteArray()
	for i in lb:
		for k in nb:
			tot.append(dblk[k][i])
	for i in EC[v]:
		for k in nb:
			tot.append(eblk[k][i])
	# matrice
	var n := 17 + 4 * v
	var m: Array[PackedByteArray] = []
	var fn: Array[PackedByteArray] = []
	for y in n:
		var r := PackedByteArray()
		r.resize(n)
		m.append(r)
		fn.append(r.duplicate())
	var set_f := func(x: int, y: int, d: bool) -> void:
		m[y][x] = 1 if d else 0
		fn[y][x] = 1
	for i in n:
		set_f.call(6, i, i % 2 == 0)
		set_f.call(i, 6, i % 2 == 0)
	for c in [Vector2i(3, 3), Vector2i(n - 4, 3), Vector2i(3, n - 4)]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x >= 0 and x < n and y >= 0 and y < n:
					var dist := maxi(absi(dx), absi(dy))
					set_f.call(x, y, dist != 2 and dist != 4)
	var al: Array = ALLINEA[v]
	for ax in al:
		for ay in al:
			if (ax == 6 and ay == 6) or (ax == 6 and ay == al[-1]) or (ax == al[-1] and ay == 6):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					set_f.call(ax + dx, ay + dy, maxi(absi(dx), absi(dy)) != 1)
	# formato (EC M = 00, maschera 0)
	var rem := 0
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var fb := rem & 0x3FF
	fb ^= 0x5412
	for i in 15:
		var d := ((fb >> i) & 1) == 1
		if i < 6:
			set_f.call(8, i, d)
		elif i == 6:
			set_f.call(8, 7, d)
		elif i == 7:
			set_f.call(8, 8, d)
		elif i == 8:
			set_f.call(7, 8, d)
		else:
			set_f.call(14 - i, 8, d)
		if i < 8:
			set_f.call(n - 1 - i, 8, d)
		else:
			set_f.call(8, n - 15 + i, d)
	set_f.call(8, n - 8, true)
	# dati a zigzag + maschera 0
	# ponytail: maschera fissa 0 senza penalità; valutare le 8 maschere se la scansione è inaffidabile
	var k := 0
	var right := n - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in n:
			for j in 2:
				var x := right - j
				var y := (n - 1 - vert) if ((right + 1) & 2) == 0 else vert
				if fn[y][x] == 0:
					var d := 0
					if k < tot.size() * 8:
						d = (tot[k >> 3] >> (7 - (k & 7))) & 1
						k += 1
					m[y][x] = d ^ (1 if (x + y) % 2 == 0 else 0)
		right -= 2
	var out: Array = []
	out.assign(m)
	return out


## Texture nitida: modulo intero in pixel, zona di quiete di 4 moduli, entra in max_px.
static func texture(testo: String, max_px: int, scuro: Color, chiaro: Color) -> ImageTexture:
	var m := matrice(testo)
	if m.is_empty():
		return null
	var n := m.size()
	var k := maxi(1, max_px / (n + 8))
	var img := Image.create((n + 8) * k, (n + 8) * k, false, Image.FORMAT_RGB8)
	img.fill(chiaro)
	for y in n:
		for x in n:
			if m[y][x] == 1:
				img.fill_rect(Rect2i((x + 4) * k, (y + 4) * k, k, k), scuro)
	return ImageTexture.create_from_image(img)
