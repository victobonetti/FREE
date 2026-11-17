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
