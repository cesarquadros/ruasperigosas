extends Node2D
# Rua de Fogo - beat 'em up (porte do protótipo HTML). Tudo desenhado via _draw().

const VH := 540.0
const G := 1500.0
var VW := 960.0

const CH := {
	"kael": {"name": "Kael", "nv": 5, "hp": 200, "sp": 1.0, "dm": 1.0, "pillar": "FOGO", "pscale": 1.7, "desc": "Equilibrado · Fogo",
		"enemy": {1: "Rex", 2: "Vik", 3: "Zed", 4: "Brutus"}},
	"murilo": {"name": "Murilo", "nv": 3, "hp": 190, "sp": 1.07, "dm": 1.05, "pillar": "GELO", "pscale": 1.4, "desc": "Ágil · Gelo",
		"enemy": {1: "Ryo", 2: "Nik"}},
	"vortex": {"name": "Dr. Vortex", "nv": 3, "hp": 215, "sp": 0.95, "dm": 1.15, "pillar": "RAIO", "pscale": 1.5, "desc": "Forte · Raio",
		"enemy": {1: "Clone V", 2: "Clone T"}},
}
const HEROES := ["kael", "murilo", "vortex"]
const FRACS := [0.0, 0.34, 0.68]
const DUR := {
	"idle": [.2, .2, .2, .2], "walk": [.11, .11, .11, .11, .11], "run": [.07, .07, .07, .07, .07, .07],
	"punch1": [.06, .08, .12], "punch2": [.06, .08, .12], "punch3": [.07, .1, .16], "kick": [.06, .1, .1, .14],
	"defend": [.06, .1], "hurt": [.12, .12], "getup": [.15, .15, .15], "special": [.08, .08, .08, .09, .11, .2],
	"jump": [1.0], "fall": [1.0], "grab": [.1, .1, .1]}
const LOOPS := ["idle", "walk", "run"]
const ATK := {
	"punch1": {"anim": "punch1", "hit": 1, "dmg": 7, "kb": 70, "knock": false, "next": "punch2"},
	"punch2": {"anim": "punch2", "hit": 1, "dmg": 8, "kb": 80, "knock": false, "next": "combokick"},
	"punch3": {"anim": "punch3", "hit": 1, "dmg": 12, "kb": 260, "knock": true, "next": ""},
	"kick": {"anim": "kick", "hit": 1, "dmg": 11, "kb": 190, "knock": false, "next": ""},
	"combokick": {"anim": "kick", "hit": 1, "dmg": 11, "kb": 150, "knock": false, "next": "ball"},
	"airkick": {"anim": "kick", "hit": 1, "dmg": 10, "kb": 230, "knock": true, "next": ""},
	"dash": {"anim": "punch3", "hit": 1, "dmg": 13, "kb": 280, "knock": true, "next": "", "dash": 420},
}

var META := {}
var TEX := {}
var fighters: Array = []
var projs: Array = []
var fires: Array = []
var sparks: Array = []
var pops: Array = []
var items: Array = []
var player = null
var camX := 0.0
var camMax := 0.0
var hitstop := 0.0
var shake := 0.0
var tNow := 0.0
var state := "menu"
var hintT := 0.0
var fade := 0.0
var clearT := 0.0
var waveIdx := 0
var waveActive := false
var stageIdx := 0
var STAGES: Array = []
var ST: Dictionary = {}
var msgTitle := ""
var msgText := ""
var bot := false
var rng := RandomNumberGenerator.new()
var sfx := {}
var font: Font

# entrada
var keys := {}
var lastTap := {"l": 0, "r": 0}
var runDir := 0
var stick := {"on": false, "id": -1, "cx": 0.0, "cy": 0.0, "x": 0.0, "y": 0.0, "mag": 0.0, "px": 0.0, "py": 0.0}
var btn_touch := {}   # nome do botão -> índice do toque
var held_def := false
var show_pad := false

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	var txt := FileAccess.get_file_as_string("res://assets/meta.json")
	META = JSON.parse_string(txt)
	for c in CH:
		for v in range(CH[c].nv):
			for p in ["", "fx_", "por_"]:
				var path := "res://assets/%s%s_%d.png" % [p, c, v]
				if ResourceLoader.exists(path):
					TEX[p + c + "_" + str(v)] = load(path)
	for s in ["street", "ice", "lab"]:
		for l in ["far", "near", "floor"]:
			TEX["bg_%s_%s" % [s, l]] = load("res://assets/bg_%s_%s.png" % [s, l])
	show_pad = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_build_sfx()
	STAGES = stages("kael")
	if "--bot" in OS.get_cmdline_user_args():
		bot = true
		_run_bot_test()
		return
	if "--shot" in OS.get_cmdline_user_args():
		_shot()
		return
	set_process(true)

func _shot() -> void:
	start_game("kael")
	camX = 0.0
	for i in range(240):
		if i % 30 == 0: set_press("atk")
		player.in.mx = 0.3
		step(1.0 / 60.0)
		VW = 960.0
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shot_play.png")
	to_menu()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shot_menu.png")
	get_tree().quit()

# ------------------------------------------------------------ dados
func E(ch: String, v: int, hp: float, run := false, o := {}) -> Dictionary:
	var d := {"ch": ch, "v": v, "hp": int(round(hp * 0.35)), "run": run, "name": CH[ch].enemy.get(v, CH[ch].name)}
	d.merge(o, true)
	return d

func stages(pl: String) -> Array:
	var boss: Dictionary
	if pl == "vortex":
		boss = E("kael", 4, 340, false, {"name": "Brutus", "sc": 1.55, "mul": 1.35})
	else:
		boss = E("vortex", 0, 340, false, {"name": "Dr. Vortex", "sc": 1.5, "mul": 1.3})
	return [
		{"id": "street", "title": "Rua ao pôr do sol", "bg": "street", "waves": [
			[E("kael", 1, 70), E("kael", 1, 70)],
			[E("kael", 2, 80, true), E("kael", 1, 70), E("kael", 3, 95, true)],
			[E("kael", 3, 95, true), E("kael", 2, 80, true), E("kael", 2, 80, true), E("kael", 1, 70)]]},
		{"id": "ice", "title": "Fortaleza de gelo", "bg": "ice", "waves": [
			[E("murilo", 1, 90), E("murilo", 1, 90), E("kael", 2, 80, true)],
			[E("murilo", 2, 100, true), E("murilo", 1, 90), E("murilo", 2, 100, true)],
			[E("murilo", 2, 100, true), E("murilo", 1, 90), E("kael", 3, 95, true), E("murilo", 1, 90)]]},
		{"id": "lab", "title": "Laboratório noturno", "bg": "lab", "waves": [
			[E("vortex", 1, 110), E("vortex", 2, 110, true)],
			[E("vortex", 1, 110), E("vortex", 2, 110, true), E("murilo", 1, 95, true)],
			[boss, E("vortex", 1, 110), E("vortex", 2, 110, true)]]},
	]

# ------------------------------------------------------------ áudio
func _tone(f0: float, dur: float, vol: float, kind: String, f1: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		var f := f0 * pow(max(f1, 30.0) / f0, t)
		ph += f / rate
		var s := 0.0
		match kind:
			"square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			_: s = 4.0 * abs(fmod(ph, 1.0) - 0.5) - 1.0
		s *= vol * pow(0.001, t)
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _build_sfx() -> void:
	var defs := {
		"hit": [220, .09, .5, "square", 90], "big": [150, .2, .7, "saw", 50], "block": [500, .05, .35, "tri", 300],
		"whoosh": [400, .1, .2, "tri", 200], "ball": [300, .3, .4, "saw", 900], "fire": [120, .4, .5, "saw", 60],
		"heal": [600, .2, .4, "tri", 1000], "clear": [500, .25, .4, "square", 900]}
	for k in defs:
		var d: Array = defs[k]
		var p := AudioStreamPlayer.new()
		p.stream = _tone(d[0], d[1], d[2], d[3], d[4])
		p.volume_db = -8
		add_child(p)
		sfx[k] = p

func snd(k: String) -> void:
	if bot:
		return
	var p: AudioStreamPlayer = sfx.get(k)
	if p:
		p.play()

# ------------------------------------------------------------ estado
func mk(o: Dictionary) -> Dictionary:
	var d := {"team": 0, "ch": "kael", "v": 0, "x": 100.0, "y": 400.0, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "face": 1,
		"hp": 200, "hpMax": 200, "mp": 100.0, "mpMax": 100.0, "spd": 1.0, "st": "free", "anim": "idle", "t": 0.0, "fi": 0,
		"done": false, "sc": 1.25, "name": "", "mul": 1.0, "dm": 1.0,
		"in": {"mx": 0.0, "my": 0.0, "run": false, "def": false},
		"press": {"atk": 0, "kick": 0, "jump": 0, "spec": 0, "fire": 0},
		"atkType": "", "chain": false, "hitDone": false, "stun": 0.0, "inv": 0.0, "lie": 0.0, "fade": 0.0,
		"grounded": false, "airAtk": false, "fired": false, "spKind": "", "running": false, "ai": null,
		"remove": false, "dropped": false, "comboT": 0.0, "comboNext": ""}
	d.merge(o, true)
	return d

func clear_press(f: Dictionary) -> void:
	var p: Dictionary = f.press
	p.atk = 0; p.kick = 0; p.jump = 0; p.spec = 0; p.fire = 0

func setup_stage(i: int) -> void:
	stageIdx = i
	var def: Dictionary = STAGES[i]
	var far: Texture2D = TEX["bg_%s_far" % def.bg]
	var near: Texture2D = TEX["bg_%s_near" % def.bg]
	var flo: Texture2D = TEX["bg_%s_floor" % def.bg]
	var tot := float(far.get_height() + near.get_height() + flo.get_height())
	var S := VH / tot
	ST = {"def": def, "S": S, "WW": round(far.get_width() * S), "farH": far.get_height() * S, "nearH": near.get_height() * S,
		"floorH": flo.get_height() * S, "far": far, "near": near, "floor": flo}
	ST.floorTop = ST.farH + ST.nearH
	ST.laneMin = ST.floorTop + min(46.0, ST.floorH * 0.32)
	ST.laneMax = VH - 16.0
	fighters = [player] if player else []
	projs = []; fires = []; sparks = []; pops = []; items = []
	camX = 0.0; waveIdx = 0; waveActive = false; clearT = 0.0; fade = 1.0; hitstop = 0.0; shake = 0.0
	if player:
		player.x = 140.0; player.y = ST.laneMin + 55; player.vx = 0.0; player.vy = 0.0; player.z = 0.0; player.vz = 0.0
		player.st = "free"; player.inv = 1.0
		clear_press(player)
		set_anim(player, "idle")
	state = "play"

func start_game(ch: String) -> void:
	var c: Dictionary = CH[ch]
	STAGES = stages(ch)
	player = mk({"team": 0, "ch": ch, "v": 0, "x": 140.0, "y": 420.0, "name": c.name, "hp": c.hp, "hpMax": c.hp, "spd": c.sp, "dm": c.dm * 1.35})
	setup_stage(0)
	hintT = 6.0

func to_menu() -> void:
	state = "menu"
	fighters = []
	player = null
	STAGES = stages("kael")
	ST = {}

func set_anim(f: Dictionary, a: String) -> void:
	if f.anim != a:
		f.anim = a; f.t = 0.0; f.fi = 0; f.done = false

func advance(f: Dictionary, dt: float) -> void:
	var d: Array = DUR.get(f.anim, [])
	if d.is_empty():
		return
	f.t += dt
	var i: int = f.fi
	while f.t >= d[i]:
		f.t -= d[i]
		i += 1
		if i >= d.size():
			if f.anim in LOOPS:
				i = 0
			else:
				i = d.size() - 1
				f.done = true
				f.t = 0.0
				break
	f.fi = i

# ------------------------------------------------------------ combate
func can_hit(t: Dictionary) -> bool:
	return t.hp > 0 and t.st != "fall" and t.st != "getup" and t.inv <= 0

func add_spark(x: float, y: float, z: float, s: float, ch: String) -> void:
	sparks.append({"x": x, "y": y, "z": z, "s": s, "t": 0.0, "ch": ch})

func pop(t: Dictionary, txt: String, col: Color) -> void:
	pops.append({"x": t.x, "y": t.y, "z": t.z + t.sc * 80, "txt": txt, "t": 0.0, "col": col})

func start_fall(t: Dictionary, dir: float, kb: float) -> void:
	t.st = "fall"; t.vz = 340.0; t.z = 0.01; t.vx = dir * kb; t.vy = 0.0; t.grounded = false; t.lie = 0.0
	set_anim(t, "fall"); t.chain = false; t.airAtk = false; t.running = false

func hit_target(a: Dictionary, t: Dictionary, dmg: float, kb: float, knock: bool, owner, px: float, spark_ch: String) -> void:
	var blocked: bool = t.st == "def" and t.face == -a.face
	var dm: int = max(1, int(round((dmg * 0.2 if blocked else dmg) * a.get("mul", 1.0))))
	t.hp = max(0, t.hp - dm)
	if owner:
		owner.mp = min(owner.mpMax, owner.mp + 3)
	t.mp = min(t.mpMax, t.mp + 2)
	add_spark(px, t.y, t.z + t.sc * 50, 1.0 if blocked else (1.9 if knock else 1.4), spark_ch if spark_ch != "" else (owner.ch if owner else "kael"))
	pop(t, str(dm), Color("99ccff") if blocked else Color.WHITE)
	hitstop = 0.035 if blocked else (0.1 if knock else 0.065)
	shake = max(shake, 6.0 if knock else 2.5)
	if blocked:
		t.vx = a.face * 120.0
		snd("block")
		return
	snd("big" if knock else "hit")
	t.face = -a.face
	var heavy: bool = t.sc > 1.4 and t.hp > 0 and not knock
	if t.hp <= 0 or knock or t.z > 0.5:
		if heavy:
			return
		start_fall(t, a.face, kb)
	elif not heavy:
		t.st = "hurt"; t.stun = 0.34; t.vx = a.face * kb; t.vy = 0.0
		set_anim(t, "hurt"); t.chain = false; t.running = false
	else:
		t.vx = a.face * kb * 0.3

func do_hit(a: Dictionary) -> void:
	var d: Dictionary = ATK[a.atkType]
	var am: Dictionary = META[a.ch].anims[a.anim]
	var fm: Dictionary = am.frames[min(a.fi, int(am.n) - 1)]
	var reach: float = max(48.0, fm.r * a.sc)
	for t in fighters:
		if t.team == a.team or not can_hit(t):
			continue
		var dx: float = (t.x - a.x) * a.face
		if dx < -14 or dx > reach + 16:
			continue
		if abs(t.y - a.y) > 26 or abs(t.z - a.z) > 80:
			continue
		hit_target(a, t, d.dmg * a.dm, d.kb, d.knock, a, a.x + a.face * min(max(dx, 10.0), reach), "")

func start_atk(f: Dictionary, type: String) -> void:
	if type == "ball":
		start_special(f, "ball", true)
		return
	var d: Dictionary = ATK[type]
	f.st = "atk"; f.atkType = type; f.chain = false; f.hitDone = false; f.press.atk = 0; f.press.kick = 0
	f.anim = ""
	set_anim(f, d.anim)
	f.vx = f.face * float(d.dash) if d.has("dash") else 0.0
	f.vy = 0.0
	snd("whoosh")

func start_special(f: Dictionary, kind: String, free := false) -> void:
	if not free:
		f.mp -= 25 if kind == "ball" else 40
	f.comboT = 0.0
	f.st = "spec"; f.spKind = kind; f.fired = false; f.vx = 0.0; f.vy = 0.0
	set_anim(f, "special"); f.running = false
	f.press.spec = 0; f.press.fire = 0

func fire_special(f: Dictionary) -> void:
	var k: float = f.sc / 1.25
	if f.spKind == "ball":
		projs.append({"x": f.x + f.face * 58 * k, "y": f.y, "z": 64 * k, "vx": f.face * 440.0, "face": f.face, "team": f.team,
			"ch": f.ch, "v": f.v, "t": 0.0, "life": 2.4, "owner": f, "mul": f.mul, "dm": f.dm, "sc": k, "dead": false})
		snd("ball")
	else:
		fires.append({"x": f.x + f.face * 120 * k, "y": f.y, "t": 0.0, "team": f.team, "ch": f.ch, "v": f.v, "owner": f,
			"hit": false, "face": f.face, "mul": f.mul, "dm": f.dm, "sc": k})
		snd("fire")

# ------------------------------------------------------------ lutadores
func land(f: Dictionary) -> void:
	if f.st == "air":
		f.st = "land"; f.t = 0.0; f.vx *= 0.35
	elif f.st == "atk" and f.airAtk:
		f.st = "free"; f.airAtk = false; f.vx = 0.0
	elif f.st == "fall":
		f.grounded = true; f.vx *= 0.4; f.lie = 0.65; shake = max(shake, 3.0)

func update_fighter(f: Dictionary, dt: float) -> void:
	if f.inv > 0:
		f.inv -= dt
	if f.comboT > 0:
		f.comboT -= dt
	var i: Dictionary = f.in
	if f.z > 0 or f.vz > 0:
		f.vz -= G * dt
		f.z += f.vz * dt
		if f.z <= 0:
			f.z = 0.0; f.vz = 0.0
			land(f)
	match f.st:
		"free":
			if i.def:
				f.st = "def"; f.vx = 0.0; f.vy = 0.0; set_anim(f, "defend"); f.running = false
			elif f.press.spec and f.mp >= 25:
				start_special(f, "ball")
			elif f.press.fire and f.mp >= 40:
				start_special(f, "pillar")
			elif f.press.jump:
				f.press.jump = 0; f.st = "crouch"; f.t = 0.0; f.vx *= 0.9; set_anim(f, "jump"); f.fi = 0
			elif f.press.atk:
				if f.comboT > 0 and f.comboNext != "":
					start_atk(f, f.comboNext)
				else:
					start_atk(f, "dash" if f.running else "punch1")
			elif f.press.kick:
				start_atk(f, "kick")
			else:
				var mag := Vector2(i.mx, i.my).length()
				var run: bool = i.run and abs(i.mx) > 0.1
				var sp: float = (270.0 if run else 150.0) * f.spd
				f.vx = i.mx * sp
				f.vy = i.my * sp * 0.55
				if abs(i.mx) > 0.1 and f.ai == null:
					f.face = 1 if i.mx > 0 else -1
				f.running = run
				set_anim(f, ("run" if run else "walk") if mag > 0.08 else "idle")
				advance(f, dt)
		"crouch":
			f.fi = 0; f.t += dt; f.vy = 0.0
			if f.t >= 0.07:
				f.st = "air"; f.vz = 560.0; f.z = 0.01; set_anim(f, "jump")
		"air":
			f.fi = 1 if f.vz > 120 else 2
			if f.press.atk or f.press.kick:
				f.press.atk = 0; f.press.kick = 0
				f.st = "atk"; f.atkType = "airkick"; f.airAtk = true; f.hitDone = false
				f.anim = ""
				set_anim(f, "kick")
				snd("whoosh")
		"land":
			f.fi = 3; f.t += dt; f.vx *= exp(-10 * dt); f.vy = 0.0
			if f.t >= 0.09:
				f.st = "free"
		"atk":
			var d: Dictionary = ATK[f.atkType]
			if f.press.atk and d.next != "":
				f.chain = true
			f.press.atk = 0; f.press.kick = 0
			advance(f, dt)
			if not f.hitDone and f.fi >= d.hit:
				f.hitDone = true
				do_hit(f)
			if not f.airAtk:
				f.vx *= exp(-7 * dt); f.vy = 0.0
			if f.done and not f.airAtk:
				if f.chain and d.next != "":
					start_atk(f, d.next)
				else:
					f.st = "free"; f.atkType = ""; f.running = false
					f.comboNext = d.next; f.comboT = 0.35
			if f.airAtk and f.done:
				f.fi = int(META[f.ch].anims.kick.n) - 1
		"spec":
			advance(f, dt)
			if not f.fired and f.fi >= 4:
				f.fired = true
				fire_special(f)
			f.vx = 0.0; f.vy = 0.0
			if f.done:
				f.st = "free"
		"def":
			f.vx = 0.0; f.vy = 0.0
			advance(f, dt)
			if not i.def:
				f.st = "free"
		"hurt":
			f.stun -= dt
			f.vx *= exp(-9 * dt); f.vy = 0.0
			advance(f, dt)
			if f.stun <= 0:
				f.st = "free"; f.inv = 0.02
		"fall":
			if not f.grounded:
				f.fi = 0 if f.vz > 0 else 1
			else:
				f.fi = 2
				f.vx *= exp(-8 * dt)
				f.lie -= dt
				if f.lie <= 0:
					if f.hp <= 0:
						f.fade += dt
						if f.fade > 0.9 and f.team == 1:
							f.remove = true
					else:
						f.st = "getup"; set_anim(f, "getup"); f.inv = 0.7
		"getup":
			advance(f, dt)
			f.vx = 0.0; f.vy = 0.0
			if f.done:
				f.st = "free"
	f.x += f.vx * dt
	f.y += f.vy * dt
	f.y = clamp(f.y, ST.laneMin, ST.laneMax)
	f.x = clamp(f.x, 24.0, ST.WW - 24.0)
	if f.team == 0:
		f.x = clamp(f.x, camX + 34.0, camX + VW - 34.0)
	if f.st in ["hurt", "fall", "getup", "def", "spec"]:
		clear_press(f)
	if f.mp < f.mpMax:
		f.mp = min(f.mpMax, f.mp + (5.0 if f.team == 0 else 4.0) * dt)

# ------------------------------------------------------------ IA
func think(f: Dictionary, dt: float) -> void:
	var i: Dictionary = f.in
	var P = player
	var a: Dictionary = f.ai
	i.mx = 0.0; i.my = 0.0; i.run = false
	if a.defT > 0:
		a.defT -= dt
		i.def = true
		return
	i.def = false
	if P == null or P.hp <= 0:
		return
	var dx: float = P.x - f.x
	var dy: float = P.y - f.y
	var ad: float = abs(dx)
	a.cd -= dt
	if (P.st == "atk" or P.st == "spec") and ad < 140 and abs(dy) < 30:
		if not a.reacted:
			a.reacted = true
			if f.st == "free" and rng.randf() < 0.32:
				a.defT = 0.45 + rng.randf() * 0.4
	else:
		a.reacted = false
	if f.st == "atk" and f.atkType.begins_with("punch") and not f.chain and rng.randf() < dt * 5:
		f.press.atk = 1
	if f.st != "free":
		return
	var want := 64.0 if a.aggr else 240.0
	if ad > want + 22:
		i.mx = signf(dx)
		i.run = a.runner and ad > 340
	elif not a.aggr and ad < want - 40:
		i.mx = -signf(dx)
	if abs(dy) > 12:
		i.my = signf(dy) * (1.0 if a.aggr else 0.6)
	if a.aggr and a.cd <= 0:
		if ad < 100 and abs(dy) < 22:
			f.face = 1 if dx >= 0 else -1
			if rng.randf() < 0.68:
				f.press.atk = 1
			else:
				f.press.kick = 1
			a.cd = 0.9 + rng.randf() * 1.1
		elif ad > 180 and ad < 460 and abs(dy) < 16 and f.mp >= 25 and rng.randf() < 0.025:
			f.face = 1 if dx >= 0 else -1
			f.press.spec = 1
			a.cd = 1.4 + rng.randf() * 1.2

func update_ai_flags() -> void:
	var foes := fighters.filter(func(f): return f.team == 1 and f.hp > 0)
	foes.sort_custom(func(a, b): return abs(a.x - player.x) < abs(b.x - player.x))
	for k in range(foes.size()):
		foes[k].ai.aggr = k < 2

# ------------------------------------------------------------ ondas
func wave_cam(i: int) -> float:
	return round(FRACS[i] * (ST.WW - VW))

func spawn_wave(lst: Array) -> void:
	var n := 0
	for d in lst:
		var left := n % 2 == 0
		var x: float = clamp(camX - 40 - (n / 2) * 30 if left else camX + VW + 40 + (n / 2) * 30, 30.0, ST.WW - 30.0)
		var c: Dictionary = CH[d.ch]
		var f := mk({"team": 1, "ch": d.ch, "v": d.v, "x": x, "y": ST.laneMin + rng.randf() * (ST.laneMax - ST.laneMin),
			"name": d.name, "hp": d.hp, "hpMax": d.hp, "sc": d.get("sc", 1.25),
			"mul": d.get("mul", 1.0) * 0.85 * (1.0 + 0.1 * stageIdx), "spd": c.sp, "dm": c.dm,
			"ai": {"cd": 0.8 + rng.randf() * 1.2, "aggr": false, "runner": d.run, "defT": 0.0, "reacted": false}})
		f.face = 1 if left else -1
		fighters.append(f)
		n += 1

func update_waves(dt: float) -> void:
	var waves: Array = ST.def.waves
	var alive := fighters.any(func(f): return f.team == 1 and f.hp > 0)
	if waveActive and not alive:
		waveActive = false
		waveIdx += 1
	if not waveActive and waveIdx < waves.size() and camX >= wave_cam(waveIdx) - 2:
		spawn_wave(waves[waveIdx])
		waveActive = true
	camMax = wave_cam(waveIdx) if waveIdx < waves.size() else ST.WW - VW
	if waveIdx >= waves.size() and not alive and state == "play":
		clearT += dt
		if clearT > 0.9:
			state = "clear"; clearT = 0.0; snd("clear")
			if stageIdx >= STAGES.size() - 1:
				state = "win"
				msgTitle = "VITÓRIA!"
				msgText = "Você derrubou todos os inimigos. Fim do protótipo!"

# ------------------------------------------------------------ projéteis e itens
func update_projs(dt: float) -> void:
	for p in projs:
		p.t += dt
		p.x += p.vx * dt
		if p.t > p.life or p.x < -60 or p.x > ST.WW + 60:
			p.dead = true
		if p.dead:
			continue
		for t in fighters:
			if t.team == p.team or not can_hit(t):
				continue
			if abs(t.x - p.x) < 36 and abs(t.y - p.y) < 28 and p.z - t.z > -12 and p.z - t.z < t.sc * 78:
				var att := {"x": p.x - p.face * 20, "y": p.y, "z": p.z, "face": p.face, "team": p.team, "mul": p.mul}
				hit_target(att, t, 16 * p.dm, 300, true, p.owner, p.x, p.ch)
				p.dead = true
				add_spark(p.x, p.y, p.z, 2.6, p.ch)
				break
	projs = projs.filter(func(p): return not p.dead)
	for fr in fires:
		fr.t += dt
		if not fr.hit and fr.t > 0.14:
			fr.hit = true
			for t in fighters:
				if t.team == fr.team or not can_hit(t):
					continue
				if abs(t.x - fr.x) < 62 * fr.sc and abs(t.y - fr.y) < 30 and t.z < 60:
					var att := {"x": fr.x - fr.face * 30, "y": fr.y, "z": 0.0, "face": fr.face, "team": fr.team, "mul": fr.mul}
					hit_target(att, t, 20 * fr.dm, 160, true, fr.owner, t.x, fr.ch)
	fires = fires.filter(func(fr): return fr.t < 0.75)
	for it in items:
		it.t += dt
		if player.hp > 0 and abs(player.x - it.x) < 34 and abs(player.y - it.y) < 26:
			player.hp = min(player.hpMax, player.hp + it.hp)
			it.dead = true
			pop(player, "+%d" % it.hp, Color("77ff77"))
			snd("heal")
	items = items.filter(func(i): return not i.dead)
	for s in sparks:
		s.t += dt
	sparks = sparks.filter(func(s): return s.t < 0.22)
	for p in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 0.7)

# ------------------------------------------------------------ entrada
func set_press(k: String) -> void:
	if player and state == "play":
		player.press[k] = 1

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		if e.echo:
			return
		var k := OS.get_keycode_string(e.physical_keycode).to_lower()
		if e.pressed:
			keys[k] = true
			var now := Time.get_ticks_msec()
			if k == "left" or k == "a":
				if now - lastTap.l < 260: runDir = -1
				lastTap.l = now
			if k == "right" or k == "d":
				if now - lastTap.r < 260: runDir = 1
				lastTap.r = now
			if k == "z" or k == "j": set_press("atk")
			if k == "x" or k == "k": set_press("atk")
			if k == "c" or k == "space": set_press("jump")
			if k == "v" or k == "l": set_press("fire")
			if k == "f": set_press("fire")
			if state == "menu":
				if k == "1": start_game("kael")
				if k == "2": start_game("murilo")
				if k == "3": start_game("vortex")
			if state == "win" and (k == "enter" or k == "space"):
				to_menu()
		else:
			keys[k] = false
			if (k == "left" or k == "a") and runDir == -1: runDir = 0
			if (k == "right" or k == "d") and runDir == 1: runDir = 0
	elif e is InputEventScreenTouch:
		show_pad = true
		if e.pressed:
			_touch_down(e.index, e.position)
		else:
			_touch_up(e.index)
	elif e is InputEventScreenDrag:
		if stick.on and e.index == stick.id:
			var d: Vector2 = e.position - Vector2(stick.cx, stick.cy)
			var r := 60.0
			if d.length() > r:
				d = d.normalized() * r
			stick.px = d.x; stick.py = d.y
			var n := d / r
			stick.mag = n.length()
			stick.x = 0.0 if stick.mag < 0.18 else n.x
			stick.y = 0.0 if stick.mag < 0.18 else n.y

func buttons() -> Array:
	var rx := VW - 20.0
	return [
		{"n": "atk", "x": rx - 80, "y": VH - 100, "r": 56, "l": "BATER"},
		{"n": "jump", "x": rx - 55, "y": VH - 225, "r": 40, "l": "PULO"},
		{"n": "fire", "x": rx - 200, "y": VH - 80, "r": 44, "l": "ESPECIAL"},
		{"n": "def", "x": rx - 185, "y": VH - 205, "r": 38, "l": "DEFESA"},
	]

func _touch_down(idx: int, pos: Vector2) -> void:
	if state == "menu":
		var cards := menu_cards()
		for k in range(cards.size()):
			if cards[k].has_point(pos):
				start_game(HEROES[k])
		return
	if state == "win":
		to_menu()
		return
	for b in buttons():
		if pos.distance_to(Vector2(b.x, b.y)) <= b.r + 12:
			btn_touch[idx] = b.n
			if b.n == "def":
				held_def = true
			else:
				set_press(b.n)
			return
	if pos.x < VW * 0.5 and not stick.on:
		stick.on = true; stick.id = idx; stick.cx = pos.x; stick.cy = pos.y
		stick.px = 0.0; stick.py = 0.0; stick.x = 0.0; stick.y = 0.0; stick.mag = 0.0

func _touch_up(idx: int) -> void:
	if stick.on and idx == stick.id:
		stick.on = false; stick.x = 0.0; stick.y = 0.0; stick.mag = 0.0
	if btn_touch.has(idx):
		if btn_touch[idx] == "def":
			held_def = false
		btn_touch.erase(idx)

func read_input() -> void:
	if player == null:
		return
	var mx := float((1 if (keys.get("right", false) or keys.get("d", false)) else 0) - (1 if (keys.get("left", false) or keys.get("a", false)) else 0))
	var my := float((1 if (keys.get("down", false) or keys.get("s", false)) else 0) - (1 if (keys.get("up", false) or keys.get("w", false)) else 0))
	var run := (mx > 0 and runDir == 1) or (mx < 0 and runDir == -1)
	if stick.on:
		mx = stick.x; my = stick.y; run = stick.mag > 0.92
	player.in.mx = mx; player.in.my = my; player.in.run = run
	player.in.def = keys.get("b", false) or keys.get("shift", false) or held_def

func menu_cards() -> Array:
	var out := []
	var w := 200.0
	var h := 250.0
	var gap := 24.0
	var x0 := VW / 2 - (w * 3 + gap * 2) / 2
	for k in range(3):
		out.append(Rect2(x0 + k * (w + gap), 190, w, h))
	return out

# ------------------------------------------------------------ bot de teste
func bot_input() -> void:
	var foes := fighters.filter(func(f): return f.team == 1 and f.hp > 0)
	player.in.mx = 0.0; player.in.my = 0.0; player.in.run = false; player.in.def = false
	if foes.is_empty():
		player.in.mx = 1.0
		return
	var tgt = foes[0]
	for f in foes:
		if abs(f.x - player.x) < abs(tgt.x - player.x):
			tgt = f
	var dx: float = tgt.x - player.x
	var dy: float = tgt.y - player.y
	if abs(dy) > 10:
		player.in.my = signf(dy)
	if abs(dx) > 48:
		player.in.mx = signf(dx)
	else:
		player.face = 1 if dx >= 0 else -1
		if abs(dy) < 20:
			set_press("atk")

func _run_bot_test() -> void:
	rng.seed = 7
	start_game("kael")
	var steps := 0
	var last_stage := -1
	while steps < 60 * 60 * 6 and state != "win":
		bot_input_step()
		steps += 1
		if steps % 600 == 0:
			var al := fighters.filter(func(f): return f.team == 1 and f.hp > 0)
			print("t=", steps / 60, " wave=", waveIdx, " active=", waveActive, " cam=", snappedf(camX, 1), "/", snappedf(camMax, 1), " px=", snappedf(player.x, 1), " st=", player.st, " foes=", al.size(), " ", al.map(func(f): return [snappedf(f.x, 1), snappedf(f.y, 1), f.st, f.hp]))
		if stageIdx != last_stage:
			last_stage = stageIdx
			print("fase ", stageIdx + 1, " em t=", snappedf(steps / 60.0, 0.1), "s hp=", player.hp)
		if player.hp <= 0:
			print("JOGADOR MORREU na fase ", stageIdx + 1)
			break
	print("RESULTADO estado=", state, " passos=", steps, " hp=", player.hp)
	get_tree().quit(0 if state == "win" else 1)

func bot_input_step() -> void:
	if state == "play":
		bot_input()
	step(1.0 / 60.0)

# ------------------------------------------------------------ loop
func _process(dt: float) -> void:
	dt = min(dt, 0.05)
	var vs := get_viewport_rect().size
	VW = clamp(vs.x, 720.0, 1320.0)
	step(dt)
	queue_redraw()

func step(dt: float) -> void:
	tNow += dt
	if fade > 0:
		fade = max(0.0, fade - dt * 2.2)
	if state == "menu" or player == null or ST.is_empty():
		return
	if hintT > 0 and player.st != "free":
		hintT = min(hintT, 2.0)
	if hintT > 0:
		hintT -= dt
	shake = max(0.0, shake - dt * 30)
	if hitstop > 0:
		hitstop -= dt
		return
	if state == "play" and not bot:
		read_input()
	elif state != "play":
		player.in.mx = 0.0; player.in.my = 0.0; player.in.run = false; player.in.def = false
	if state == "clear":
		clearT += dt
		if clearT > 2.2:
			player.hp = min(player.hpMax, player.hp + int(round(player.hpMax * 0.4)))
			player.mp = player.mpMax
			setup_stage(stageIdx + 1)
			return
	update_ai_flags()
	for f in fighters:
		if f.ai != null and f.hp > 0:
			think(f, dt)
		elif f.ai != null:
			f.in.mx = 0.0; f.in.my = 0.0
	for f in fighters:
		update_fighter(f, dt)
		if f.ai != null and f.st == "free" and player.hp > 0:
			f.face = 1 if player.x >= f.x else -1
	for f in fighters:
		if f.remove and not f.dropped:
			f.dropped = true
			if rng.randf() < 0.3:
				items.append({"x": f.x, "y": f.y, "hp": 45, "t": 0.0, "dead": false})
	fighters = fighters.filter(func(f): return not f.remove)
	update_projs(dt)
	if state == "play" or state == "clear":
		update_waves(dt)
	var target: float = clamp(player.x - VW / 2, 0.0, camMax)
	camX += (target - camX) * min(1.0, dt * 6)
	if camX > camMax:
		camX = camMax
	if player.hp <= 0 and state == "play":
		var any_alive := fighters.any(func(f): return f.team == 0 and f.hp > 0)
		if not any_alive and player.st == "fall" and player.grounded and player.lie <= 0:
			state = "win"
			msgTitle = "DERROTA"
			msgText = "Toque para voltar ao menu."

# ------------------------------------------------------------ desenho
func txt(t: String, x: float, y: float, size: int, col: Color = Color.WHITE, align := "left") -> void:
	var pos := Vector2(x, y)
	var ha := HORIZONTAL_ALIGNMENT_LEFT
	if align == "center":
		pos.x = x - 500; ha = HORIZONTAL_ALIGNMENT_CENTER
	elif align == "right":
		pos.x = x - 1000; ha = HORIZONTAL_ALIGNMENT_RIGHT
	draw_string_outline(font, pos, t, ha, 1000, size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, t, ha, 1000, size, col)

func bar(x: float, y: float, w: float, h: float, pct: float, col: Color, bg := Color("3a2020")) -> void:
	draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), Color.BLACK)
	draw_rect(Rect2(x, y, w, h), bg)
	draw_rect(Rect2(x, y, max(0.0, w * pct), h), col)
	draw_rect(Rect2(x, y, max(0.0, w * pct), max(1.0, h * 0.35)), Color(1, 1, 1, 0.25))

func reset_t() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_shadow(x: float, y: float, z: float, sc: float) -> void:
	var s: float = max(0.4, 1.0 - z / 220.0)
	draw_set_transform(Vector2(x - camX + _sx, y + 1 + _sy), 0.0, Vector2(28 * sc / 1.25 * s, 7 * sc / 1.25 * s))
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.32 * s))
	reset_t()

var _sx := 0.0
var _sy := 0.0

func draw_sprite(f: Dictionary) -> void:
	var m: Dictionary = META[f.ch].anims.get(f.anim, {})
	if m.is_empty():
		return
	var tex: Texture2D = TEX.get("%s_%d" % [f.ch, f.v])
	if tex == null:
		return
	var fi: int = min(f.fi, int(m.n) - 1)
	var dw: float = m.cw * f.sc
	var dh: float = m.ch * f.sc
	var shx := 0.0
	if f.st == "hurt":
		shx = sin(tNow * 90.0) * 2.5
	var a := 1.0
	if f.hp <= 0 and f.st == "fall" and f.grounded:
		a = max(0.0, 1.0 - f.fade / 0.9)
		if int(tNow * 14) % 2 == 0:
			a *= 0.5
	if f.inv > 0 and f.st == "getup" and int(tNow * 20) % 2 == 0:
		a *= 0.6
	draw_set_transform(Vector2(round(f.x - camX + shx) + _sx, round(f.y - f.z) + _sy), 0.0, Vector2(f.face, 1))
	draw_texture_rect_region(tex, Rect2(-dw / 2, -dh, dw, dh), Rect2(fi * m.cw, m.y, m.cw, m.ch), Color(1, 1, 1, a))
	reset_t()

func draw_fx(ch: String, v: int, name: String, fi: int, x: float, y: float, s: float, bottom: bool) -> void:
	var m: Dictionary = META[ch].fx.get(name, {})
	var tex: Texture2D = TEX.get("fx_%s_%d" % [ch, v])
	if m.is_empty() or tex == null:
		return
	var f: int = min(fi, int(m.n) - 1)
	var dw: float = m.cw * s
	var dh: float = m.ch * s
	var py: float = y - dh if bottom else y - dh / 2
	draw_texture_rect_region(tex, Rect2(x - camX - dw / 2 + _sx, py + _sy, dw, dh), Rect2(f * m.cw, m.y, m.cw, m.ch))

func draw_item(it: Dictionary) -> void:
	var bob := sin(it.t * 5.0) * 2.0
	draw_shadow(it.x, it.y, 0.0, 0.7)
	var x: float = it.x - camX + _sx
	var y: float = it.y - 8 + bob + _sy
	draw_rect(Rect2(x - 6, y - 24, 12, 22), Color("f2f2f2"))
	draw_rect(Rect2(x - 4, y - 30, 8, 7), Color("4895ef"))
	draw_rect(Rect2(x - 6, y - 14, 12, 4), Color("cfd8e6"))
	draw_rect(Rect2(x - 6, y - 24, 12, 22), Color("111111"), false, 1.5)

func _draw() -> void:
	draw_rect(Rect2(0, 0, VW + 4, VH + 4), Color("07060d"))
	if state == "menu":
		draw_menu()
		return
	if ST.is_empty():
		return
	_sx = 0.0; _sy = 0.0
	if shake > 0.3:
		_sx = (rng.randf() - 0.5) * shake * 2
		_sy = (rng.randf() - 0.5) * shake * 1.2
	draw_texture_rect(ST.far, Rect2(-camX * 0.5 + _sx, _sy, ST.WW, ST.farH + 1), false)
	draw_texture_rect(ST.near, Rect2(-camX + _sx, ST.farH - 1 + _sy, ST.WW, ST.nearH + 2), false)
	draw_texture_rect(ST.floor, Rect2(-camX + _sx, ST.floorTop - 1 + _sy, ST.WW, ST.floorH + 2), false)
	var lst := []
	for f in fighters: lst.append({"y": f.y, "k": "f", "o": f})
	for p in projs: lst.append({"y": p.y, "k": "p", "o": p})
	for fr in fires: lst.append({"y": fr.y, "k": "fr", "o": fr})
	for it in items: lst.append({"y": it.y, "k": "i", "o": it})
	lst.sort_custom(func(a, b): return a.y < b.y)
	for e in lst:
		var o = e.o
		match e.k:
			"f":
				draw_shadow(o.x, o.y, o.z, o.sc)
				draw_sprite(o)
			"p":
				draw_shadow(o.x, o.y, o.z, 0.9)
				var n: int = int(META[o.ch].fx.ball.n)
				draw_fx(o.ch, o.v, "ball", int(o.t * 16) % n, o.x, o.y - o.z, 1.45 * o.sc, false)
			"fr":
				var n2: int = int(META[o.ch].fx.pillar.n)
				var fi := int(o.t * 14) % n2
				var s: float = CH[o.ch].pscale * o.sc * (o.t / 0.1 if o.t < 0.1 else 1.0)
				draw_fx(o.ch, o.v, "pillar", fi, o.x, o.y, max(0.1, s), true)
			_:
				draw_item(o)
	for s in sparks:
		var fi2: int = min(2, int(s.t / 0.075))
		var k := 1.5
		if s.ch == "murilo": k = 1.1
		elif s.ch == "vortex": k = 0.9
		draw_fx(s.ch, 0, "spark", fi2, s.x, s.y - s.z, s.s * k, false)
	for p in pops:
		txt(p.txt, p.x - camX, p.y - p.z - p.t * 40, 15, p.col, "center")
	if player:
		draw_hud()
	if show_pad and state == "play":
		draw_pad()
	if fade > 0:
		draw_rect(Rect2(0, 0, VW + 4, VH + 4), Color(0, 0, 0, min(1.0, fade)))
	if state == "win":
		draw_rect(Rect2(0, 0, VW + 4, VH + 4), Color(0, 0, 0, 0.6))
		txt(msgTitle, VW / 2, VH / 2 - 10, 56, Color("ffd24d"), "center")
		txt(msgText, VW / 2, VH / 2 + 30, 20, Color.WHITE, "center")

func draw_menu() -> void:
	txt("RUA DE FOGO", VW / 2, 110, 64, Color("ffd24d"), "center")
	txt("Escolha seu lutador", VW / 2, 150, 22, Color.WHITE, "center")
	var cards := menu_cards()
	for k in range(3):
		var c: String = HEROES[k]
		var r: Rect2 = cards[k]
		draw_rect(r, Color(0.05, 0.05, 0.12, 0.85))
		draw_rect(r, Color("ffd24d"), false, 3)
		var tex: Texture2D = TEX.get("por_%s_0" % c)
		if tex:
			draw_texture_rect(tex, Rect2(r.position.x + 40, r.position.y + 14, 120, 122), false)
		txt(CH[c].name, r.position.x + r.size.x / 2, r.position.y + 170, 24, Color.WHITE, "center")
		txt(CH[c].desc, r.position.x + r.size.x / 2, r.position.y + 205, 16, Color("ffd24d"), "center")
	txt("Teclado: 1/2/3 · Z bater (combo) · C pular · V especial · B defesa", VW / 2, VH - 40, 15, Color("cccccc"), "center")

func draw_pad() -> void:
	if stick.on:
		draw_circle(Vector2(stick.cx, stick.cy), 60, Color(1, 1, 1, 0.12))
		draw_arc(Vector2(stick.cx, stick.cy), 60, 0, TAU, 40, Color(1, 1, 1, 0.5), 2)
		draw_circle(Vector2(stick.cx + stick.px, stick.cy + stick.py), 26, Color(1, 1, 1, 0.45))
	else:
		draw_arc(Vector2(110, VH - 110), 50, 0, TAU, 40, Color(1, 1, 1, 0.2), 2)
	var pressed := btn_touch.values()
	for b in buttons():
		var on: bool = pressed.has(b.n)
		var col := Color(1, 1, 1, 0.38 if on else 0.16)
		draw_circle(Vector2(b.x, b.y), b.r, col)
		draw_arc(Vector2(b.x, b.y), b.r, 0, TAU, 32, Color(1, 1, 1, 0.55), 2)
		var label: String = b.l
		if b.n == "fire":
			label = CH[player.ch].pillar
		txt(label, b.x, b.y + 5, 12, Color.WHITE, "center")

func draw_hud() -> void:
	var L := 8.0
	var Rr := VW - 8.0
	var T := 8.0
	draw_rect(Rect2(L, T, 250, 70), Color(0.03, 0.03, 0.08, 0.6))
	var pi: Texture2D = TEX.get("por_%s_%d" % [player.ch, player.v])
	if pi:
		draw_texture_rect(pi, Rect2(L + 4, T + 4, 56, 57), false)
	draw_rect(Rect2(L + 4, T + 4, 56, 57), Color.WHITE, false, 2)
	txt(player.name.to_upper(), L + 68, T + 18, 15, Color("ffd24d"))
	bar(L + 68, T + 24, 170, 11, float(player.hp) / player.hpMax, Color("e63946"))
	bar(L + 68, T + 42, 170, 8, player.mp / player.mpMax, Color("4895ef"), Color("1d2a44"))
	txt("HP %d" % int(ceil(player.hp)), L + 68, T + 64, 11)
	var foes := fighters.filter(func(f): return f.team == 1 and f.hp > 0).slice(0, 4)
	for k in range(foes.size()):
		var f = foes[k]
		var x := Rr - 196
		var y := T + 2 + k * 34
		draw_rect(Rect2(x - 4, y - 3, 200, 31), Color(0.03, 0.03, 0.08, 0.55))
		var im: Texture2D = TEX.get("por_%s_%d" % [f.ch, f.v])
		if im:
			draw_texture_rect(im, Rect2(x, y, 26, 27), false)
		txt(f.name.to_upper(), x + 32, y + 11, 11)
		bar(x + 32, y + 15, 150, 8, float(f.hp) / f.hpMax, Color("e07a2d"))
	txt("FASE %d: %s" % [stageIdx + 1, ST.def.title.to_upper()], VW / 2, T + 18, 14, Color.WHITE, "center")
	var left := fighters.filter(func(f): return f.team == 1 and f.hp > 0).size()
	if waveActive:
		txt("Inimigos: %d" % left, VW / 2, T + 38, 12, Color("ffd24d"), "center")
	if state == "play" and not waveActive and waveIdx < ST.def.waves.size() and int(tNow * 2.4) % 2 == 0:
		txt("VÁ ▶", VW - 110, VH / 2 - 30, 30, Color("ffd24d"), "center")
	if state == "clear":
		draw_rect(Rect2(0, VH / 2 - 50, VW, 100), Color(0, 0, 0, 0.45))
		txt("FASE %d COMPLETA!" % (stageIdx + 1), VW / 2, VH / 2 + 10, 32, Color("ffd24d"), "center")
	if hintT > 0 and not show_pad:
		draw_rect(Rect2(VW / 2 - 290, VH - 70, 580, 52), Color(0.03, 0.03, 0.08, 0.6))
		txt("Setas/WASD: mover (toque duplo = correr) · Z bater · C pular", VW / 2, VH - 50, 13, Color.WHITE, "center")
		txt("Bater 4x = soco, soco, chute e magia · V especial · B defesa", VW / 2, VH - 31, 13, Color("ffd24d"), "center")
