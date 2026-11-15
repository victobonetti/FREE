extends Node2D
## Carrega as salas em sequência, lê o teclado/controle e faz as transições.
## Também cuida da barra de recarga do giro e do som dela.

const Levels := preload("res://scripts/levels.gd")
const RoomScript := preload("res://scripts/room.gd")
const InputSetup := preload("res://scripts/input_setup.gd")

const BAR_SIZE := Vector2(40, 3)
const BAR_POS := Vector2(320 - 40 - 6, 180 - 3 - 6)
const MIX_RATE := 22050
const MUSIC_DB := -9.0       # volume da música; abaixo dos efeitos para eles continuarem audíveis
const MUSIC_OFF_DB := -40.0

var room: Node2D
var index := 0
var transitioning := false
var finished := false
var fade_rect: ColorRect
var title: Label
var hint: Label
var end_label: Label
var bar_bg: ColorRect
var bar_fill: ColorRect
var charge_player: AudioStreamPlayer
var ready_player: AudioStreamPlayer
var jump_player: AudioStreamPlayer
var death_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var music: AudioStreamPlayer
var music_path := ""
var music_tween: Tween
var thud_player: AudioStreamPlayer
var thud2_player: AudioStreamPlayer
var gate_open_player: AudioStreamPlayer
var gate_close_player: AudioStreamPlayer
var platform_player: AudioStreamPlayer
var sensor_on_player: AudioStreamPlayer
var sensor_off_player: AudioStreamPlayer
var prev_lock := 0


func _ready() -> void:
	InputSetup.setup()
	_make_ui()
	_make_audio()
	_load_room(0)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	title = Label.new()
	title.position = Vector2(4, 1)
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color(0.89, 0.87, 0.81, 0.55))
	layer.add_child(title)
	hint = Label.new()
	hint.position = Vector2(0, 153)  # embaixo: não briga com o título no canto de cima
	hint.size = Vector2(320, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_constant_override("line_spacing", -1)
	hint.add_theme_color_override("font_color", Color(0.93, 0.91, 0.85, 0.9))
	layer.add_child(hint)
	bar_bg = ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.14)
	bar_bg.position = BAR_POS
	bar_bg.size = BAR_SIZE
	layer.add_child(bar_bg)
	bar_fill = ColorRect.new()
	bar_fill.color = Color.WHITE
	bar_fill.position = BAR_POS
	bar_fill.size = BAR_SIZE
	layer.add_child(bar_fill)
	end_label = Label.new()
	end_label.text = "fim do piloto\n\npressione pular para recomeçar"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.size = Vector2(320, 180)
	end_label.add_theme_font_size_override("font_size", 10)
	end_label.visible = false
	layer.add_child(end_label)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = Vector2(320, 180)
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade_rect)


# ---------------------------------------------------------------- áudio

func _make_audio() -> void:
	charge_player = AudioStreamPlayer.new()
	charge_player.stream = _make_charge_tone()
	charge_player.volume_db = -22.0
	add_child(charge_player)
	ready_player = AudioStreamPlayer.new()
	ready_player.stream = _make_ready_blip()
	ready_player.volume_db = -14.0
	add_child(ready_player)
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_OFF_DB
	add_child(music)
	jump_player = AudioStreamPlayer.new()
	jump_player.stream = _make_jump_sound()
	jump_player.volume_db = -16.0
	add_child(jump_player)
	death_player = AudioStreamPlayer.new()
	death_player.stream = _make_death_sound()
	death_player.volume_db = -12.0
	add_child(death_player)
	win_player = AudioStreamPlayer.new()
	win_player.stream = _make_win_sound()
	win_player.volume_db = -11.0
	add_child(win_player)
	thud_player = AudioStreamPlayer.new()
	thud_player.stream = _make_thud_sound()
	thud_player.volume_db = -9.0
	add_child(thud_player)
	thud2_player = AudioStreamPlayer.new()
	thud2_player.stream = thud_player.stream
	add_child(thud2_player)
	gate_open_player = AudioStreamPlayer.new()
	gate_open_player.stream = _make_gate_sound(true)
	gate_open_player.volume_db = -13.0
	add_child(gate_open_player)
	gate_close_player = AudioStreamPlayer.new()
	gate_close_player.stream = _make_gate_sound(false)
	gate_close_player.volume_db = -13.0
	add_child(gate_close_player)
	platform_player = AudioStreamPlayer.new()
	platform_player.stream = _make_platform_sound()
	platform_player.volume_db = -20.0
	add_child(platform_player)
	sensor_on_player = AudioStreamPlayer.new()
	sensor_on_player.stream = _make_sensor_sound(true)
	sensor_on_player.volume_db = -17.0
	add_child(sensor_on_player)
	sensor_off_player = AudioStreamPlayer.new()
	sensor_off_player.stream = _make_sensor_sound(false)
	sensor_off_player.volume_db = -19.0
	add_child(sensor_off_player)


## Portal: sem melodia. Uma varredura grave que sobe com modulação de frequência, ruído
## filtrado girando com tremolo cada vez mais rápido, distorção e quantização (som "sujo"),
## terminando em um golpe grave quando a porta se fecha.
func _make_win_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.85)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ph_c := 0.0
	var ph_m := 0.0
	var ph_t := 0.0
	var ph_s := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		# portadora: 70 Hz -> ~1,3 kHz, modulada em frequência por um oscilador lento
		ph_c += TAU * (70.0 * pow(18.0, t)) / float(MIX_RATE)
		ph_m += TAU * (31.0 + 70.0 * t) / float(MIX_RATE)
		var carrier := sin(ph_c + (2.0 + 3.0 * t) * sin(ph_m))
		# ruído passa-baixas, com o corte subindo, e tremolo acelerando
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.03 + 0.5 * t * t)
		ph_t += TAU * (8.0 + 34.0 * t) / float(MIX_RATE)
		var swirl := lp * (0.55 + 0.45 * sin(ph_t)) * 2.2
		var v := 0.5 * carrier + swirl
		# golpe grave no fim, junto com o fechamento da porta
		if t > 0.82:
			var th := (t - 0.82) / 0.18
			ph_s += TAU * lerpf(90.0, 38.0, th) / float(MIX_RATE)
			v += 1.1 * sin(ph_s) * exp(-th * 3.0)
		v = tanh(v * 2.4)                    # distorção
		v = roundf(v * 10.0) / 10.0          # quantização grosseira
		var env := minf(t * 25.0, 1.0) * (0.35 + 0.65 * t) * (1.0 - smoothstep(0.96, 1.0, t))
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Comporta: deslizar mecânico (ruído filtrado com um zumbido que desce ao abrir, sobe ao fechar)
## e uma batida seca no fim.
func _make_gate_sound(opening: bool) -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.32)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21 if opening else 22
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(220.0, 110.0, t) if opening else lerpf(110.0, 200.0, t)
		phase += TAU * f / float(MIX_RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.12
		var hum := (1.0 if sin(phase) > 0.0 else -1.0) * 0.25 + sin(phase) * 0.35
		var slide := (hum + lp * 1.4) * minf(t * 20.0, 1.0) * (1.0 - smoothstep(0.7, 0.85, t))
		var tk := maxf(t - 0.8, 0.0)
		var knock := sin(TAU * 70.0 * tk) * exp(-tk * 60.0) * (1.0 if t >= 0.8 else 0.0)
		data.encode_s16(i * 2, int(clampf(tanh(slide * 1.5) * 0.7 + knock, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Plataforma por orientação mudando: um "tic" de vidro, curto e agudo.
func _make_platform_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 45.0)
		var v := env * (0.5 * sin(TAU * 1760.0 * t) + 0.3 * sin(TAU * 2637.0 * t) + 0.2 * sin(TAU * 3520.0 * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Pouso da caixa: quanto mais forte, mais alto e mais grave. Dois baques sobrepostos nos fortes.
func _on_impact(strength: float) -> void:
	var k := clampf(strength / 2.5, 0.0, 1.0)
	thud_player.volume_db = lerpf(-17.0, -5.0, k)
	thud_player.pitch_scale = lerpf(1.15, 0.7, k) * randf_range(0.96, 1.04)
	thud_player.play()
	if strength > 1.3:
		thud2_player.volume_db = lerpf(-14.0, -7.0, k)
		thud2_player.pitch_scale = lerpf(0.9, 0.55, k)
		thud2_player.play()


## Pouso da caixa: baque grave curto com um pouco de ruído.
func _make_thud_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.2)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += TAU * lerpf(120.0, 45.0, sqrt(t)) / float(MIX_RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		var v := sin(phase) * exp(-t * 7.0) + lp * exp(-t * 28.0) * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Sensor: dois bipes curtos e secos. Ligado sobe, desligado desce.
func _make_sensor_sound(up: bool) -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.13)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f1 := 880.0 if up else 1180.0
	var f2 := 1320.0 if up else 700.0
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var gate := 1.0 if (t < 0.4 or t > 0.5) else 0.0   # pequena pausa entre os dois bipes
		var f := f1 if t < 0.45 else f2
		phase += TAU * f / float(MIX_RATE)
		var env := minf(t * 60.0, 1.0) * pow(1.0 - t, 0.8)
		var sq := 1.0 if sin(phase) > 0.0 else -1.0          # onda quadrada suave: som de sensor
		var v := (0.35 * sq + 0.65 * sin(phase)) * env * gate
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Troca a música com fade. A mesma faixa continua tocando sem reiniciar.
func _play_music(path: String) -> void:
	if path == music_path:
		return
	music_path = path
	if music_tween != null:
		music_tween.kill()
	music_tween = create_tween()
	if music.playing:
		music_tween.tween_property(music, "volume_db", MUSIC_OFF_DB, 0.8)
	music_tween.tween_callback(func():
		music.stop()
		if path == "" or not ResourceLoader.exists(path):
			return
		var s = load(path)
		if "loop" in s:
			s.loop = true
		music.stream = s
		music.volume_db = MUSIC_OFF_DB
		music.play())
	if path != "":
		music_tween.tween_property(music, "volume_db", MUSIC_DB, 1.5)


func _play_sfx(sfx_name: String) -> void:
	if sfx_name == "gate_open":
		gate_open_player.play()
		return
	if sfx_name == "gate_close":
		gate_close_player.play()
		return
	if sfx_name == "platform":
		platform_player.pitch_scale = randf_range(0.95, 1.05)
		platform_player.play()
		return
	if sfx_name == "sensor_on":
		sensor_on_player.play()
		return
	if sfx_name == "sensor_off":
		sensor_off_player.play()
		return
	if sfx_name == "win":
		win_player.play()
		return
	if sfx_name == "jump":
		jump_player.pitch_scale = randf_range(0.94, 1.08)  # varia um pouco a cada pulo
		jump_player.play()
	elif sfx_name == "death":
		death_player.play()


## Pulo: varredura curta e suave, de grave para agudo (mesma "família" do tom da recarga).
func _make_jump_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.14)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(330.0, 760.0, t * t ** 0.5)
		phase += TAU * f / float(MIX_RATE)
		var env := minf(t * 18.0, 1.0) * pow(1.0 - t, 1.6)
		var v := env * (0.75 * sin(phase) + 0.25 * sin(2.0 * phase))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Morte: varredura descendente com um estalo de ruído no começo.
func _make_death_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.38)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(520.0, 70.0, pow(t, 0.55))
		phase += TAU * f / float(MIX_RATE)
		var tone := sin(phase) * 0.6 + sin(phase * 0.5) * 0.3
		var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.7
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, 1.3)
		data.encode_s16(i * 2, int(clampf(tone * env + noise, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s


## Um ciclo de onda suave em loop (220,5 Hz). O tom sobe mudando o pitch_scale.
func _make_charge_tone() -> AudioStreamWAV:
	var n := 100
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var ph := TAU * float(i) / float(n)
		var v := 0.6 * sin(ph) + 0.22 * sin(2.0 * ph) + 0.08 * sin(3.0 * ph)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s


## "Plim" curto quando o giro volta a ficar disponível.
func _make_ready_blip() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 26.0)
		var v := env * (0.7 * sin(TAU * 1320.0 * t) + 0.3 * sin(TAU * 1980.0 * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s


func _update_rotation_hud() -> void:
	var active: bool = room != null and room.allow_rotate and not finished
	bar_bg.visible = active
	bar_fill.visible = active
	if not active:
		charge_player.stop()
		prev_lock = 0
		return
	var ratio: float = room.rot_ratio()
	var charging: bool = room.rot_lock > 0 and room.state == "play"
	bar_fill.size.x = maxf(roundf(BAR_SIZE.x * ratio), 0.0)
	bar_fill.color = Color(1, 1, 1, 0.55 if charging else 1.0)
	if charging:
		# o tom sobe de 220 Hz até quase 3x ao longo da recarga
		charge_player.pitch_scale = 1.0 + 1.9 * ratio * ratio
		if not charge_player.playing:
			charge_player.play()
	else:
		if charge_player.playing:
			charge_player.stop()
		if prev_lock > 0 and room.rot_lock == 0 and room.state == "play":
			ready_player.play()
	prev_lock = room.rot_lock


# ---------------------------------------------------------------- salas

func _load_room(i: int) -> void:
	if room != null:
		room.queue_free()
		room = null
	index = clampi(i, 0, Levels.ROOMS.size() - 1)
	var r: Node2D = RoomScript.new()
	r.position = Vector2(160, 90)
	add_child(r)
	r.setup(Levels.ROOMS[index])
	r.completed.connect(_on_completed)
	r.sfx.connect(_play_sfx)
	r.impact.connect(_on_impact)
	room = r
	prev_lock = 0
	title.text = "%d · %s" % [index + 1, Levels.ROOMS[index]["name"]]
	hint.text = Levels.ROOMS[index].get("hint", "")
	_play_music(Levels.ROOMS[index].get("music", Levels.DEFAULT_MUSIC))
	hint.modulate.a = 0.0
	if hint.text != "":
		create_tween().tween_property(hint, "modulate:a", 1.0, 0.6).set_delay(0.3)
	end_label.visible = false
	finished = false


func _on_completed() -> void:
	if transitioning:
		return
	transitioning = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
	tw.tween_callback(_advance)
	tw.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): transitioning = false)


func _advance() -> void:
	if index + 1 >= Levels.ROOMS.size():
		if room != null:
			room.queue_free()
			room = null
		finished = true
		title.text = ""
		hint.text = ""
		end_label.visible = true
	else:
		_load_room(index + 1)


func _physics_process(_delta: float) -> void:
	_tick()
	_update_rotation_hud()


func _tick() -> void:
	if finished:
		if Input.is_action_just_pressed("jump") and not transitioning:
			_load_room(0)
		return
	if room == null or transitioning:
		return
	if Input.is_action_just_pressed("next_room"):
		_load_room(index + 1)
		return
	if Input.is_action_just_pressed("prev_room"):
		_load_room(index - 1)
		return
	if Input.is_action_just_pressed("restart"):
		room.reset()
		return
	var rot := 0
	if Input.is_action_just_pressed("rotate_cw"):
		rot += 1
	if Input.is_action_just_pressed("rotate_ccw"):
		rot -= 1
	room.step({
		"move": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"rotate": rot,
	})
