extends RefCounted
## Efeitos sonoros gerados em código (sem arquivos): os da fuga do Gatsby e dos componentes
## dela (alavanca, conectores, catapulta, chapas soltas, placa de espinhos). main.gd cria um
## tocador para cada nome de `ONE_SHOTS` e toca quando a sala emite o sinal `sfx` com esse nome.
## `rumble()` é o ronco da placa, em loop: main.gd ajusta volume e tom pelo `room.danger`.

const MIX_RATE := 22050

## nome -> [volume em dB, variação de tom (0 = sempre igual)]
const ONE_SHOTS := {
	"lever": [-13.0, 0.06], "mover_warn": [-20.0, 0.0], "mover_go": [-19.0, 0.08],
	"mover_dock": [-14.0, 0.08], "launch": [-13.0, 0.05], "crumble_warn": [-17.0, 0.1],
	"crumble": [-13.0, 0.1], "crunch": [-15.0, 0.18], "crusher_wake": [-9.0, 0.0],
	"alarm": [-21.0, 0.0], "gatsby_dash": [-18.0, 0.1], "gatsby_laugh": [-15.0, 0.05],
	"acid_burn": [-13.0, 0.06], "acid_splash": [-17.0, 0.1],
	"battery": [-14.0, 0.04], "charge": [-14.0, 0.0], "hatch": [-13.0, 0.05],
	"plate_on": [-15.0, 0.04], "plate_off": [-19.0, 0.04],
	"spring": [-13.0, 0.05], "steam_warn": [-20.0, 0.05], "steam_burst": [-14.0, 0.06],
	"lock_on": [-20.0, 0.0], "missile": [-17.0, 0.12], "homer": [-18.0, 0.08], "slam": [-8.0, 0.05],
	"blast": [-15.0, 0.15], "thump": [-11.0, 0.08],
	"senzi_scream": [-11.0, 0.08], "senzi_grunt": [-12.0, 0.14],
	"step_grass": [-22.0, 0.14], "step_dirt": [-20.0, 0.14], "step_stone": [-23.0, 0.12],
	"step_wet": [-22.0, 0.14], "step_metal": [-25.0, 0.1], "step_wood": [-21.0, 0.12],
	"step_plate": [-24.0, 0.12], "step_water": [-21.0, 0.15],
}


static func make(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"lever":
			return _lever()
		"mover_warn":
			return _mover_warn()
		"mover_go":
			return _mover_go()
		"mover_dock":
			return _mover_dock()
		"launch":
			return _launch()
		"crumble_warn":
			return _crumble_warn()
		"crumble":
			return _crumble()
		"crunch":
			return _crunch()
		"crusher_wake":
			return _crusher_wake()
		"alarm":
			return _alarm()
		"gatsby_dash":
			return _gatsby_dash()
		"gatsby_laugh":
			return _gatsby_laugh()
		"acid_burn":
			return _acid_burn()
		"acid_splash":
			return _acid_splash()
		"battery":
			return _battery()
		"charge":
			return _charge()
		"hatch":
			return _hatch()
		"plate_on":
			return _plate(true)
		"plate_off":
			return _plate(false)
		"spring":
			return _spring()
		"steam_warn":
			return _steam_warn()
		"steam_burst":
			return _steam_burst()
		"lock_on":
			return _lock_on()
		"missile":
			return _missile()
		"homer":
			return _homer()
		"slam":
			return _slam()
		"blast":
			return _blast()
		"thump":
			return _thump()
		"senzi_scream":
			return _senzi_voice(0.85, [180.0, 430.0, 300.0, 130.0], 1)
		"senzi_grunt":
			return _senzi_voice(0.28, [260.0, 330.0, 190.0, 110.0], 2)
	if sfx_name.begins_with("step_"):
		return _step(sfx_name.trim_prefix("step_"))
	return null


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(MIX_RATE * seconds))
	return b


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Alavanca: a pancada do metal, um corpo grave e dois dentes de catraca.
static func _lever() -> AudioStreamWAV:
	var b := _buf(0.2)
	var rng := _rng(101)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
		var v := lp * exp(-t * 90.0) * 0.9 + sin(TAU * 170.0 * t) * exp(-t * 35.0) * 0.7
		v += sin(TAU * 1240.0 * t) * exp(-t * 70.0) * 0.25
		for k in [0.085, 0.125]:
			var tk: float = t - k
			if tk >= 0.0:
				v += lp * exp(-tk * 260.0) * 0.6 + sin(TAU * 900.0 * tk) * exp(-tk * 200.0) * 0.2
		b[i] = tanh(v * 1.4) * 0.8
	return _wav(b)


## Aviso do conector: dois bipes curtos, o segundo mais agudo.
static func _mover_warn() -> AudioStreamWAV:
	var b := _buf(0.2)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for q in [[0.0, 880.0], [0.1, 1175.0]]:
			var tk: float = t - float(q[0])
			if tk >= 0.0 and tk < 0.08:
				var env := minf(tk * 300.0, 1.0) * (1.0 - smoothstep(0.05, 0.08, tk))
				v += (sin(TAU * float(q[1]) * tk) * 0.6 + sin(TAU * float(q[1]) * 2.0 * tk) * 0.15) * env
		b[i] = v * 0.7
	return _wav(b)


## A peça parte: servo subindo de tom, com chiado.
static func _mover_go() -> AudioStreamWAV:
	var b := _buf(0.26)
	var rng := _rng(102)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		ph += TAU * lerpf(85.0, 250.0, t * t) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var env := minf(t * 14.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, t))
		b[i] = tanh((saw * 0.5 + sin(ph * 2.0) * 0.2 + lp * 0.5) * 1.3) * env * 0.7
	return _wav(b)


## A peça encaixa: baque e o metal soando (parciais desafinadas).
static func _mover_dock() -> AudioStreamWAV:
	var b := _buf(0.32)
	var rng := _rng(103)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 120.0 * t) * exp(-t * 28.0) * 0.9
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.6
		v += sin(TAU * 613.0 * t) * exp(-t * 16.0) * 0.22
		v += sin(TAU * 947.0 * t) * exp(-t * 22.0) * 0.16
		v += sin(TAU * 1531.0 * t) * exp(-t * 30.0) * 0.1
		b[i] = tanh(v * 1.3) * 0.8
	return _wav(b)


## Catapulta: mola ("boing") subindo, com um sopro de ar.
static func _launch() -> AudioStreamWAV:
	var b := _buf(0.38)
	var rng := _rng(104)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		var f := lerpf(150.0, 720.0, pow(t, 0.6)) * (1.0 + 0.06 * sin(TAU * 26.0 * t))
		ph += TAU * f / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, 1.4)
		b[i] = (sin(ph) * 0.7 + sin(ph * 2.0) * 0.18 + lp * 0.35 * sin(PI * t)) * env
	return _wav(b)


## Chapa solta pisada: rangido grave, com estalos.
static func _crumble_warn() -> AudioStreamWAV:
	var b := _buf(0.34)
	var rng := _rng(105)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		ph += TAU * lerpf(95.0, 62.0, t) / MIX_RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var trem := 0.5 + 0.5 * sin(TAU * 34.0 * t * 0.34)
		var crack := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.012 else 0.0
		b[i] = (saw * 0.35 * trem + crack * 0.8) * minf(t * 20.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, t))
	return _wav(b)


## Chapa desaba: estalo seco e os pedaços caindo.
static func _crumble() -> AudioStreamWAV:
	var b := _buf(0.42)
	var rng := _rng(106)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var k := 0.5 * exp(-t * 6.0) + 0.04
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var v := lp * exp(-t * 9.0) * 1.6 + sin(TAU * lerpf(160.0, 60.0, minf(t * 4.0, 1.0)) * t) * exp(-t * 14.0) * 0.5
		if rng.randf() < 0.004 and t > 0.1:
			v += rng.randf_range(-0.7, 0.7)
		b[i] = tanh(v * 1.5) * 0.75
	return _wav(b)


## A placa mastiga a sala: ruído grave ressoando e estalos de entulho.
static func _crunch() -> AudioStreamWAV:
	var b := _buf(0.24)
	var rng := _rng(107)
	var lp := 0.0
	var bp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.08
		bp += (lp - bp) * 0.3
		var v := (lp - bp * 0.5) * 3.0 * exp(-t * 13.0) + sin(TAU * 74.0 * t) * exp(-t * 18.0) * 0.6
		if rng.randf() < 0.02:
			v += n * 0.6 * exp(-t * 8.0)
		b[i] = tanh(v * 1.6) * 0.8
	return _wav(b)


## A placa acorda: um rosnado de máquina que cresce e uma batida de metal no fim.
static func _crusher_wake() -> AudioStreamWAV:
	var b := _buf(1.1)
	var rng := _rng(108)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		ph += TAU * lerpf(34.0, 78.0, smoothstep(0.0, 0.8, t)) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		var growl := (fmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.5 + sin(ph * 0.5) * 0.5
		var env := smoothstep(0.0, 0.7, t) * (1.0 - smoothstep(0.95, 1.1, t))
		var v := (growl * (0.7 + 0.3 * sin(TAU * 11.0 * t)) + lp * 2.5) * env
		var tk := t - 0.8
		if tk >= 0.0:
			v += sin(TAU * 96.0 * tk) * exp(-tk * 14.0) * 1.2 + sin(TAU * 540.0 * tk) * exp(-tk * 20.0) * 0.25
		b[i] = tanh(v * 1.5) * 0.85
	return _wav(b)


## Alarme: buzina curta de dois tons.
static func _alarm() -> AudioStreamWAV:
	var b := _buf(0.16)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var f := 587.0 if t < 0.08 else 440.0
		var sq := 1.0 if sin(TAU * f * t) > 0.0 else -1.0
		lp += (sq - lp) * 0.25
		var env := minf(t * 200.0, 1.0) * (1.0 - smoothstep(0.13, 0.16, t))
		b[i] = lp * env * 0.6
	return _wav(b)


## O arranque do Gatsby: sopro de jato e um assobio subindo.
static func _gatsby_dash() -> AudioStreamWAV:
	var b := _buf(0.3)
	var rng := _rng(109)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * lerpf(0.1, 0.5, t)
		ph += TAU * lerpf(380.0, 980.0, t) / MIX_RATE
		var env := sin(PI * pow(t, 0.6))
		b[i] = (lp * 0.8 + sin(ph) * 0.18) * env * 0.8
	return _wav(b)


## A risada do Gatsby: cinco "rá" descendo, nasalados.
static func _gatsby_laugh() -> AudioStreamWAV:
	var b := _buf(0.7)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in 5:
			var tk := t - k * 0.125
			if tk >= 0.0 and tk < 0.1:
				var f := lerpf(560.0, 430.0, float(k) / 4.0) * (1.0 - tk * 1.6)
				var saw := fmod(f * tk, 1.0) * 2.0 - 1.0
				var env := minf(tk * 120.0, 1.0) * (1.0 - smoothstep(0.04, 0.1, tk))
				v += (saw * 0.45 + sin(TAU * f * 2.5 * tk) * 0.25) * env
		b[i] = tanh(v * 1.4) * 0.7
	return _wav(b)


## O coelho toca o ácido: chiado agudo que cai, com estalos de bolhas.
static func _acid_burn() -> AudioStreamWAV:
	var b := _buf(0.5)
	var rng := _rng(111)
	var hp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		hp = n - hp * 0.55   # filtro passa-alta simples: chiado
		var v := hp * 0.45 * exp(-t * 5.0)
		v += sin(TAU * lerpf(900.0, 260.0, minf(t * 3.0, 1.0)) * t) * exp(-t * 9.0) * 0.3
		if rng.randf() < 0.018 and t < 0.35:
			v += rng.randf_range(-0.8, 0.8) * exp(-t * 4.0)
		b[i] = tanh(v * 1.3) * 0.7
	return _wav(b)


## Algo cai no ácido: um "glub" borbulhante, mais grosso que o da água.
static func _acid_splash() -> AudioStreamWAV:
	var b := _buf(0.3)
	var rng := _rng(112)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := sin(TAU * lerpf(300.0, 120.0, minf(t * 5.0, 1.0)) * t) * exp(-t * 14.0) * 0.8
		v += sin(TAU * 520.0 * t) * exp(-t * 30.0) * 0.3
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 45.0) * 0.3
		b[i] = tanh(v * 1.3) * 0.75
	return _wav(b)


## Pegar uma bateria: dois "plins" metálicos subindo (uma quinta).
static func _battery() -> AudioStreamWAV:
	var b := _buf(0.3)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for q in [[0.0, 880.0], [0.07, 1320.0]]:
			var tk: float = t - float(q[0])
			if tk >= 0.0:
				var f: float = q[1]
				v += (sin(TAU * f * tk) * 0.6 + sin(TAU * f * 2.01 * tk) * 0.18 + sin(TAU * f * 3.97 * tk) * 0.06) * exp(-tk * 16.0) * minf(tk * 400.0, 1.0)
		b[i] = v * 0.75
	return _wav(b)


## Todas as baterias: a alavanca carrega. Zumbido que sobe e fecha com um estalo.
static func _charge() -> AudioStreamWAV:
	var b := _buf(0.7)
	var rng := _rng(113)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		ph += TAU * lerpf(110.0, 520.0, t * t) / MIX_RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var env := minf(t * 12.0, 1.0) * (1.0 - smoothstep(0.88, 1.0, t))
		var v := (saw * 0.35 + sin(ph) * 0.35) * env
		if t > 0.9:
			v += rng.randf_range(-1.0, 1.0) * exp(-(t - 0.9) * 90.0) * 0.5
		b[i] = tanh(v * 1.4) * 0.75
	return _wav(b)


## A calha abre: batida de metal e um sopro de ar.
static func _hatch() -> AudioStreamWAV:
	var b := _buf(0.4)
	var rng := _rng(114)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		var v := sin(TAU * 98.0 * t) * exp(-t * 22.0) * 0.9
		v += sin(TAU * 410.0 * t) * exp(-t * 28.0) * 0.25
		v += lp * exp(-t * 7.0) * 0.45 * minf(t * 60.0, 1.0)
		b[i] = tanh(v * 1.3) * 0.75
	return _wav(b)


## Botão de pressão: um "clac" seco e curto; ao soltar, mais fraco e mais agudo.
static func _plate(down: bool) -> AudioStreamWAV:
	var b := _buf(0.14)
	var rng := _rng(115 if down else 116)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var f := 150.0 if down else 230.0
		var v := sin(TAU * f * t) * exp(-t * 40.0) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.5
		v += sin(TAU * f * 5.3 * t) * exp(-t * 70.0) * 0.2
		b[i] = tanh(v * 1.3) * (0.8 if down else 0.55)
	return _wav(b)


## Mola: "boing" curto e brilhante, com uma segunda oscilação.
static func _spring() -> AudioStreamWAV:
	var b := _buf(0.32)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var f := 330.0 + 520.0 * exp(-t * 14.0) + 14.0 * sin(TAU * 38.0 * t)
		ph += TAU * f / MIX_RATE
		var env := minf(t * 300.0, 1.0) * exp(-t * 9.0)
		b[i] = (sin(ph) * 0.65 + sin(ph * 2.0) * 0.2 + sin(ph * 3.01) * 0.08) * env * 0.85
	return _wav(b)


## Aviso do vapor: um chiado que cresce, curto.
static func _steam_warn() -> AudioStreamWAV:
	var b := _buf(0.45)
	var rng := _rng(117)
	var hp := 0.0
	for i in b.size():
		var t := float(i) / float(b.size())
		var n := rng.randf_range(-1.0, 1.0)
		hp = n - hp * 0.6
		b[i] = hp * 0.5 * smoothstep(0.0, 0.8, t) * (1.0 - smoothstep(0.85, 1.0, t)) * 0.8
	return _wav(b)


## O jato abre: sopro forte que decai, com um estalo de válvula no começo.
static func _steam_burst() -> AudioStreamWAV:
	var b := _buf(0.6)
	var rng := _rng(118)
	var lp := 0.0
	var hp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.5
		hp = lp - hp * 0.35
		var v := hp * 0.8 * exp(-t * 3.2) * minf(t * 120.0, 1.0)
		v += sin(TAU * 130.0 * t) * exp(-t * 40.0) * 0.5
		b[i] = tanh(v * 1.4) * 0.8
	return _wav(b)


## Mira da mecha: três bipes agudos e rápidos.
static func _lock_on() -> AudioStreamWAV:
	var b := _buf(0.3)
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in 3:
			var tk: float = t - k * 0.09
			if tk >= 0.0 and tk < 0.05:
				var env := minf(tk * 400.0, 1.0) * (1.0 - smoothstep(0.03, 0.05, tk))
				v += signf(sin(TAU * 1568.0 * tk)) * 0.25 * env + sin(TAU * 1568.0 * tk) * 0.3 * env
		b[i] = v * 0.7
	return _wav(b)


## Míssil da mira: um assobio que desce rápido, com chiado.
static func _missile() -> AudioStreamWAV:
	var b := _buf(0.18)
	var rng := _rng(131)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		ph += TAU * (2600.0 - t * 9000.0) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.6
		var env := minf(t * 300.0, 1.0) * exp(-t * 14.0)
		b[i] = (sin(ph) * 0.35 + lp * 0.4) * env
	return _wav(b)


## Teleguiado saindo: um sopro de foguete que cresce e some.
static func _homer() -> AudioStreamWAV:
	var b := _buf(0.45)
	var rng := _rng(133)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		var env := minf(t * 25.0, 1.0) * exp(-t * 6.0)
		b[i] = tanh((lp * 2.2 + sin(TAU * (90.0 + t * 60.0) * t) * 0.3) * env * 1.5) * 0.8
	return _wav(b)


## A investida bate na parede: pancada grave e enorme, com metal rangendo.
static func _slam() -> AudioStreamWAV:
	var b := _buf(0.7)
	var rng := _rng(137)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.06
		var v := sin(TAU * (55.0 - t * 20.0) * t) * exp(-t * 5.0) * 1.1
		v += lp * 4.0 * exp(-t * 9.0)
		v += sin(TAU * 410.0 * t + sin(TAU * 7.0 * t) * 3.0) * exp(-t * 4.0) * 0.18
		b[i] = tanh(v * 1.8) * 0.85
	return _wav(b)


## Explosão pequena (míssil): estalo e ronco curto.
static func _blast() -> AudioStreamWAV:
	var b := _buf(0.32)
	var rng := _rng(139)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.2
		var v := n * exp(-t * 60.0) * 0.8 + lp * 2.0 * exp(-t * 11.0) + sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.6
		b[i] = tanh(v * 1.5) * 0.8
	return _wav(b)


## A batida de pata do coelho (o giro): um baque grave e curto, com um estalo de terra.
static func _thump() -> AudioStreamWAV:
	var b := _buf(0.22)
	var rng := _rng(141)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.15
		var v := sin(TAU * (95.0 - t * 160.0) * t) * exp(-t * 22.0) * 1.1 + lp * 1.6 * exp(-t * 45.0)
		b[i] = tanh(v * 1.6) * 0.8
	return _wav(b)


## Passos, um por material: curtos e baixinhos (o tom varia um pouco a cada passo).
static func _step(mat: String) -> AudioStreamWAV:
	var b := _buf(0.2 if mat == "metal" or mat == "plate" else 0.12)
	var rng := _rng(150 + mat.length() * 7 + mat.unicode_at(0))
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.12
		lp2 += (n - lp2) * 0.35
		hp = n - lp2
		var v := 0.0
		match mat:
			"grass":
				v = sin(TAU * 140.0 * t) * exp(-t * 45.0) * 0.6 + hp * 0.35 * exp(-t * 28.0) * minf(t * 300.0, 1.0)
			"dirt":
				v = sin(TAU * 105.0 * t) * exp(-t * 40.0) * 0.8 + lp * 2.2 * exp(-t * 35.0)
			"stone":
				v = hp * 0.9 * exp(-t * 110.0) + sin(TAU * 620.0 * t) * exp(-t * 70.0) * 0.35 + sin(TAU * 180.0 * t) * exp(-t * 60.0) * 0.4
			"wet":
				v = hp * 0.6 * exp(-t * 90.0) + lp2 * 1.2 * exp(-t * 22.0) * minf(t * 200.0, 1.0) + sin(TAU * (950.0 - t * 2500.0) * t) * exp(-t * 35.0) * 0.18
			"metal":
				v = hp * 0.5 * exp(-t * 150.0)
				for f in [523.0, 1307.0, 2149.0, 3011.0]:
					v += sin(TAU * f * t) * exp(-t * (18.0 + f / 120.0)) * 0.16
			"wood":
				v = sin(TAU * 230.0 * t) * exp(-t * 45.0) * 0.6 + sin(TAU * 470.0 * t) * exp(-t * 60.0) * 0.25 + hp * 0.4 * exp(-t * 160.0)
			"plate":
				v = hp * 0.4 * exp(-t * 120.0)
				for f in [410.0, 980.0, 1720.0]:
					v += sin(TAU * f * t) * exp(-t * 20.0) * 0.16
				v *= 0.6 + 0.4 * signf(sin(TAU * 38.0 * t))   # chacoalha
			"water":
				v = lp2 * 1.6 * exp(-t * 18.0) * minf(t * 120.0, 1.0) + sin(TAU * (700.0 + t * 900.0) * t) * exp(-t * 30.0) * 0.12
		b[i] = tanh(v * 1.4) * 0.8
	return _wav(b)


## Ventilador, em loop de 1 s: sopro grave e um zumbido de pás (frequências inteiras: fecha o ciclo).
static func fan_loop() -> AudioStreamWAV:
	var n := MIX_RATE
	var raw := PackedFloat32Array()
	raw.resize(n + n / 4)
	var rng := _rng(119)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.12
		lp2 += (lp - lp2) * 0.4
		raw[i] = lp2 * 1.6 + sin(TAU * 58.0 * t) * 0.12 * (0.7 + 0.3 * sin(TAU * 9.0 * t))
	var b := PackedFloat32Array()
	b.resize(n)
	var fade := n / 4
	for i in n:
		var v := raw[i]
		if i < fade:
			var k := float(i) / float(fade)
			v = v * k + raw[i + n] * (1.0 - k)
		b[i] = tanh(v) * 0.7
	return _wav(b, true)


## Esteira, em loop de 1 s: batidas surdas e regulares (8 por segundo) com um zumbido baixo.
static func belt_loop() -> AudioStreamWAV:
	var n := MIX_RATE
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := _rng(120)
	for i in n:
		var t := float(i) / MIX_RATE
		var tk := fmod(t, 0.125)
		var v := sin(TAU * 76.0 * tk) * exp(-tk * 55.0) * 0.55 + rng.randf_range(-1.0, 1.0) * exp(-tk * 140.0) * 0.25
		v += sin(TAU * 52.0 * t) * 0.1
		b[i] = tanh(v * 1.2) * 0.7
	return _wav(b, true)


## Ronco da placa, em loop de 1 s: grave contínuo e ruído grave. O começo e o fim se emendam.
static func rumble() -> AudioStreamWAV:
	var n := MIX_RATE
	var raw := PackedFloat32Array()
	raw.resize(n + n / 4)
	var rng := _rng(110)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.035
		lp2 += (lp - lp2) * 0.2
		# frequências inteiras (em Hz): fecham o ciclo em 1 s
		raw[i] = lp2 * 5.0 + sin(TAU * 42.0 * t) * 0.35 + sin(TAU * 63.0 * t) * 0.18 * (0.6 + 0.4 * sin(TAU * 3.0 * t))
	var b := PackedFloat32Array()
	b.resize(n)
	var fade := n / 4
	for i in n:
		var v := raw[i]
		if i < fade:
			var k := float(i) / float(fade)
			v = v * k + raw[i + n] * (1.0 - k)   # o fim do ruído entra por baixo do começo
		b[i] = tanh(v * 1.2) * 0.8
	return _wav(b, true)


## A voz do Senzi (D116): um grito distorcido, meio de bicho, meio de máquina. O tom sobe, segura e
## cai (os quatro pontos de `pitch`), com vibrato; a fonte é dente de serra com quadrada, filtrada por três
## formantes de vogal aberta ("aah"), com chiado de bafo; um anel de modulação a 63 Hz deixa estranha
## (alienígena), e o final passa por saturação forte, esmagamento de bits e queda de taxa (a distorção).
static func _senzi_voice(seconds: float, pitch: Array, seed_value: int) -> AudioStreamWAV:
	var b := _buf(seconds)
	var rng := _rng(seed_value)
	var n := b.size()
	var formants := [[720.0, 1.0, 140.0], [1150.0, 0.7, 180.0], [2600.0, 0.45, 300.0]]
	var phase := 0.0
	var hold := 0.0
	var amps := PackedFloat32Array()
	amps.resize(18)
	for i in n:
		var t := float(i) / MIX_RATE
		var k := t / seconds
		# o contorno do tom: sobe rápido, segura, cai
		var f0: float
		if k < 0.12:
			f0 = lerpf(pitch[0], pitch[1], k / 0.12)
		elif k < 0.55:
			f0 = lerpf(pitch[1], pitch[2], (k - 0.12) / 0.43)
		else:
			f0 = lerpf(pitch[2], pitch[3], (k - 0.55) / 0.45)
		f0 *= 1.0 + 0.07 * sin(TAU * 9.0 * t) + 0.03 * sin(TAU * 23.0 * t)
		phase += f0 / MIX_RATE
		# harmônicos pesados pelos formantes (os pesos mudam devagar: recalculados a cada 64 amostras)
		if i % 64 == 0:
			for h in range(1, 18):
				var fh := f0 * h
				var amp := 0.0
				for fm in formants:
					var d: float = (fh - fm[0]) / fm[2]
					amp += fm[1] * exp(-d * d)
				amps[h] = amp / h * 2.2
		var v := 0.0
		for h in range(1, 18):
			v += sin(TAU * phase * h) * amps[h]
		v += (fmod(phase, 1.0) * 2.0 - 1.0) * 0.18                # o dente de serra cru por baixo
		v += rng.randf_range(-1.0, 1.0) * (0.18 + 0.25 * k)         # o bafo
		v *= 0.6 + 0.4 * sin(TAU * 63.0 * t)                        # o anel: estranho
		var env := minf(t / 0.025, 1.0) * (1.0 - smoothstep(0.7, 1.0, k))
		v = tanh(v * 3.2 * env)                                     # a saturação
		v = roundf(v * 14.0) / 14.0                                 # o esmagamento de bits
		if i % 3 == 0:
			hold = v                                                # a queda de taxa
		b[i] = hold * 0.75
	return _wav(b)
