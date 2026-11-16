extends Node2D
## Carrega as salas em sequência, lê o teclado/controle e faz as transições.
## Também cuida da barra de recarga do giro e do som dela.

const Replay := preload("res://scripts/replay.gd")
const Levels := preload("res://scripts/levels.gd")
const RoomScript := preload("res://scripts/room.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const IntroScript := preload("res://scripts/intro.gd")
const LevelEditor := preload("res://scripts/editor/editor.gd")
const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")

const EDITOR_SIZE := Vector2i(960, 540)
const GAME_SIZE := Vector2i(320, 180)
const TouchControls := preload("res://scripts/touch_controls.gd")

const BAR_SIZE := Vector2(40, 3)
const BAR_POS := Vector2(320 - 40 - 6, 180 - 3 - 6)
const MIX_RATE := 22050
const MUSIC_DB := -4.0       # volume da música
const MUSIC_OFF_DB := -40.0
const HINT_FREE_HEIGHT := 150   # salas mais altas que isto (px) ficam por baixo do texto de dica
const HINT_SECONDS := 8.0       # nelas, a dica some depois deste tempo
const TITLE_MUSIC := "res://music/free-title.mp3"
const FALL_MUSIC := "res://music/fallinggg.mp3"   # toca enquanto o coelho cai, na abertura

var room: Node2D
var intro: Node2D   # tela de início / cutscene, quando ativa
var index := 0      # nível atual; -1 na abertura e na sala de início
var transitioning := false
var finished := false
var fade_rect: ColorRect
var title: Label
var hint: Label
var hint_tween: Tween
var end_label: Label
var bar_bg: ColorRect
var bar_fill: ColorRect
var limit_bg: ColorRect      # barra vermelha do limitador, paralela à do giro
var limit_fill: ColorRect
var limiter_player: AudioStreamPlayer
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
var splash_player: AudioStreamPlayer
var rope_player: AudioStreamPlayer
var prev_lock := 0
var ui_layer: CanvasLayer
var editor_layer: CanvasLayer
var in_editor_window := false   # janela na escala do editor: o layout de toque não mexe nela
var editor: Control
var rec_runs: Array = []    # comandos gravados no teste do editor (replay)
var rec_state := {}         # estado de partida dos atores, para o replay
var custom := ""            # "", "editor" (teste a partir do editor) ou "list" (fase da lista)
var list_label: Label       # tela "Minhas fases"
var list_items: Array = []
var list_sel := 0
var in_list := false
var touch: Node2D           # controles de toque (aparecem no primeiro toque na tela)
var hint_def := {}          # definição da sala atual, para trocar a dica ao detectar toque


func _ready() -> void:
	InputSetup.setup()
	_make_ui()
	_make_audio()
	_show_intro()
	# atalho de teste: "-- --level=11" na linha de comando, ou "?level=11" no link da versão web,
	# abre direto no nível 11 (pula a abertura)
	var lv := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			lv = int(a.trim_prefix("--level="))
		elif a == "--editor":
			open_editor()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('level') || ''")
		if q is String and q.is_valid_int():
			lv = int(q)
	if lv > 0:
		_load_room(lv - 1)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	ui_layer = layer
	layer.layer = 10
	add_child(layer)
	ui_layer = layer
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
	limit_bg = ColorRect.new()
	limit_bg.color = Color(1, 0.2, 0.2, 0.18)
	limit_bg.position = BAR_POS + Vector2(0, -5)
	limit_bg.size = BAR_SIZE
	layer.add_child(limit_bg)
	limit_fill = ColorRect.new()
	limit_fill.color = Color("e8403c")
	limit_fill.position = BAR_POS + Vector2(0, -5)
	limit_fill.size = BAR_SIZE
	layer.add_child(limit_fill)
	end_label = Label.new()
	end_label.text = "fim do piloto\n\npressione pular para voltar ao início"
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
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 11   # por cima do fade: dá para ver os controles nas transições
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)
	touch.touch_detected.connect(_on_touch_detected)
	touch.panned.connect(func(d: Vector2) -> void:
		if room != null and not transitioning:
			room.pan(d))
	touch.pan_ended.connect(func() -> void:
		if room != null:
			room.end_pan())
	get_window().size_changed.connect(_apply_layout)
	_apply_layout()


## Primeiro toque na tela: troca os textos de teclado pelos de toque.
func _on_touch_detected() -> void:
	_apply_layout()
	if intro != null:
		intro.set_touch_mode()
	if room != null:
		hint.text = _hint_for(hint_def)


## No modo toque, alarga a tela do jogo para o formato da janela (celular deitado é ~20:9).
## A área de jogo continua 320×180 no centro; as faixas laterais ficam para os controles.
func _apply_layout() -> void:
	if in_editor_window:
		return   # o editor tem a própria escala (960x540)
	var w := 320
	if touch.active:
		var win := get_window().size
		if win.y > 0:
			# a escala é inteira (pixel art): escolhe a largura que cabe na janela nessa escala
			var s := maxi(win.y / 180, 1)
			w = clampi(win.x / s, 320, 432)
			w -= w % 2   # faixas de largura inteira e igual dos dois lados
	var g := (w - 320) / 2
	get_tree().root.content_scale_size = Vector2i(w, 180)
	position.x = g
	ui_layer.offset.x = g
	touch.set_layout(w, g)


func _hint_for(def: Dictionary) -> String:
	if touch.active and def.has("hint_touch"):
		return def["hint_touch"]
	return def.get("hint", "")


# ---------------------------------------------------------------- áudio

func _make_audio() -> void:
	charge_player = AudioStreamPlayer.new()
	charge_player.stream = _make_charge_tone()
	charge_player.volume_db = -25.0
	add_child(charge_player)
	ready_player = AudioStreamPlayer.new()
	ready_player.stream = _make_ready_blip()
	ready_player.volume_db = -17.0
	add_child(ready_player)
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_OFF_DB
	add_child(music)
	jump_player = AudioStreamPlayer.new()
	jump_player.stream = _make_jump_sound()
	jump_player.volume_db = -19.0
	add_child(jump_player)
	death_player = AudioStreamPlayer.new()
	death_player.stream = _make_death_sound()
	death_player.volume_db = -15.0
	add_child(death_player)
	win_player = AudioStreamPlayer.new()
	win_player.stream = _make_win_sound()
	win_player.volume_db = -19.0
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
	gate_open_player.volume_db = -16.0
	add_child(gate_open_player)
	gate_close_player = AudioStreamPlayer.new()
	gate_close_player.stream = _make_gate_sound(false)
	gate_close_player.volume_db = -16.0
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
	limiter_player = AudioStreamPlayer.new()
	limiter_player.stream = _make_limiter_sound()
	limiter_player.volume_db = -13.0
	add_child(limiter_player)
	splash_player = AudioStreamPlayer.new()
	splash_player.stream = _make_splash_sound()
	splash_player.volume_db = -17.0
	add_child(splash_player)
	rope_player = AudioStreamPlayer.new()
	rope_player.stream = _make_rope_sound()
	rope_player.volume_db = -18.0
	add_child(rope_player)


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


## Limitador desfazendo o giro: uma varredura grave que despenca, quebrada em degraus de
## amostragem e saturada, com rajadas de ruído: um som deliberadamente estragado.
func _make_limiter_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.55)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var phase := 0.0
	var held := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(520.0, 38.0, pow(t, 0.55)) * (1.0 + 0.25 * sin(t * 90.0))
		phase += TAU * f / float(MIX_RATE)
		if i % 5 == 0:  # "sample and hold": reduz a taxa de amostragem
			var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
			var burst := 1.0 if fmod(t * 14.0, 1.0) < 0.3 else 0.0
			held = tanh(3.5 * saw + 1.2 * rng.randf_range(-1.0, 1.0) * burst)
			held = roundf(held * 4.0) / 4.0  # só 9 níveis
		var env := minf(t * 60.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, t))
		data.encode_s16(i * 2, int(clampf(held * env, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Cair na água: ruído que começa aberto e fecha rápido, com uma gota grave por baixo.
func _make_splash_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.5, 0.04, sqrt(t))
		phase += TAU * lerpf(260.0, 90.0, sqrt(t)) / float(MIX_RATE)
		var v := lp * 1.6 * exp(-t * 6.0) + 0.5 * sin(phase) * exp(-t * 14.0)
		data.encode_s16(i * 2, int(clampf(v * minf(t * 80.0, 1.0), -1.0, 1.0) * 30000.0))
	return _wav(data)


## Agarrar a corda: um estalo curto de fibra esticando, grave, com um leve tremor.
func _make_rope_sound() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += TAU * (lerpf(210.0, 150.0, t) + 14.0 * sin(TAU * 38.0 * t * 0.16)) / float(MIX_RATE)
		var env := minf(t * 40.0, 1.0) * exp(-t * 7.0)
		var v := env * (0.7 * sin(phase) + 0.3 * sin(3.0 * phase))
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


## Interrompe a música na hora, sem fade.
func _stop_music() -> void:
	if music_tween != null:
		music_tween.kill()
	music_path = ""
	music.stop()
	music.volume_db = MUSIC_OFF_DB


## Começa uma faixa na hora, já no volume cheio (sem o fade de _play_music).
func _start_music_now(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	if music_tween != null:
		music_tween.kill()
	var s = load(path)
	if "loop" in s:
		s.loop = true
	music_path = path
	music.stop()
	music.stream = s
	music.volume_db = MUSIC_DB
	music.play()


func _play_sfx(sfx_name: String) -> void:
	if sfx_name == "falling":
		_start_music_now(FALL_MUSIC)
		return
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
	if sfx_name == "limiter":
		limiter_player.play()
		return
	if sfx_name == "splash":
		splash_player.pitch_scale = randf_range(0.92, 1.08)
		splash_player.play()
		return
	if sfx_name == "rope":
		rope_player.pitch_scale = randf_range(0.95, 1.05)
		rope_player.play()
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
	var limited: bool = room != null and room.def.get("limiter", false) and room.limit_t > 0 and not finished
	limit_bg.visible = limited
	limit_fill.visible = limited
	if limited:
		limit_fill.size.x = maxf(roundf(BAR_SIZE.x * room.limiter_ratio()), 0.0)
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

## Tela de início e cutscene de abertura. A música do título toca em loop até apertarem Enter.
func _show_intro() -> void:
	_clear_scene()
	index = -1
	finished = false
	title.text = ""
	hint.text = ""
	end_label.visible = false
	_stop_music()
	_play_music(TITLE_MUSIC)
	intro = IntroScript.new()
	add_child(intro)
	if touch.active:
		intro.set_touch_mode()
	intro.started.connect(_stop_music)
	intro.sfx.connect(_play_sfx)
	intro.impact.connect(_on_impact)
	intro.finished.connect(_load_start_room)


## A sala em que a abertura termina: o coelho anda até a porta para começar o nível 1.
func _load_start_room() -> void:
	_spawn_room(Levels.START, -1, "")


func _load_room(i: int) -> void:
	var n := clampi(i, 0, Levels.count() - 1)
	var def: Dictionary = Levels.def_at(n)
	_spawn_room(def, n, "%d · %s" % [n + 1, def["name"]])


func _clear_scene() -> void:
	if room != null:
		room.queue_free()
		room = null
	if intro != null:
		intro.queue_free()
		intro = null


func _spawn_room(def: Dictionary, i: int, title_text: String) -> void:
	_clear_scene()
	index = i
	var r: Node2D = RoomScript.new()
	r.position = Vector2(160, 90)
	add_child(r)
	r.setup(def)
	r.completed.connect(_on_completed)
	r.sfx.connect(_play_sfx)
	r.music_request.connect(_play_music)
	r.impact.connect(_on_impact)
	room = r
	prev_lock = 0
	# Só em desenvolvimento (build de depuração: editor, run.ps1): o número do nível no canto.
	# Nas versões exportadas não há texto nenhum além das dicas de controle.
	title.text = str(i + 1) if OS.is_debug_build() and i >= 0 else ""
	hint_def = def
	hint.text = _hint_for(def)
	_play_music(r.music_override if r.music_override != "" else def.get("music", Levels.DEFAULT_MUSIC))
	hint.modulate.a = 0.0
	if hint_tween != null:
		hint_tween.kill()
	if hint.text != "":
		hint_tween = create_tween()
		hint_tween.tween_property(hint, "modulate:a", 1.0, 0.6).set_delay(0.3)
		if r.ph > HINT_FREE_HEIGHT:
			# sala alta: a dica fica por cima do chão; some depois de dar tempo de ler
			hint_tween.tween_property(hint, "modulate:a", 0.0, 1.2).set_delay(HINT_SECONDS)
	end_label.visible = false
	finished = false


func _on_completed() -> void:
	if transitioning:
		return
	if custom != "":
		transitioning = true
		var tw0 := create_tween()
		tw0.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
		tw0.tween_callback(func(): _end_custom(true))
		tw0.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
		tw0.tween_callback(func(): transitioning = false)
		return
	transitioning = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
	tw.tween_callback(_advance)
	tw.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): transitioning = false)


func _advance() -> void:
	if index + 1 >= Levels.count():
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
	touch.hide_ui = intro != null
	_tick()
	_update_rotation_hud()


func _tick() -> void:
	if in_list:
		_tick_list()
		return
	if editor_layer != null and editor_layer.visible:
		return
	if custom != "" and Input.is_action_just_pressed("back") and not transitioning:
		_end_custom(false)
		return
	if intro != null and intro.phase == intro.TITLE:
		if Input.is_action_just_pressed("open_editor"):
			open_editor()
			return
		if Input.is_action_just_pressed("my_levels"):
			show_list()
			return
	if finished:
		if Input.is_action_just_pressed("jump") and not transitioning:
			_show_intro()
		return
	if intro != null:
		if Input.is_action_just_pressed("next_room"):
			_load_room(0)
			return
		intro.step(Input.is_action_just_pressed("start"))
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
		if custom == "editor":
			Replay.record(rec_runs, {"reset": true})
		return
	var rot := 0
	if Input.is_action_just_pressed("rotate_cw"):
		rot += 1
	if Input.is_action_just_pressed("rotate_ccw"):
		rot -= 1
	var inp := {
		"move": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"climb": Input.get_action_strength("climb_down"),
		"rotate": rot,
	}
	if custom == "editor":
		Replay.record(rec_runs, inp)   # teste do editor: grava para o replay
	room.step(inp)


# ---------------------------------------------------------------- editor e fases do jogador

func _set_window_for_editor(on: bool) -> void:
	var w := get_window()
	in_editor_window = on
	if on:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		w.content_scale_size = EDITOR_SIZE
	else:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		w.content_scale_size = GAME_SIZE
		if touch != null:
			_apply_layout()


## Abre o editor. Com `level` (um LevelData) abre essa fase; sem, continua de onde estava.
func open_editor(level: RefCounted = null, id := "") -> void:
	_stop_music()
	_clear_scene()
	_hide_list()
	custom = ""
	ui_layer.visible = false
	_set_window_for_editor(true)
	if editor_layer == null:
		editor_layer = CanvasLayer.new()
		editor_layer.layer = 30
		add_child(editor_layer)
		editor = LevelEditor.new()
		editor.exit_requested.connect(_close_editor)
		editor.play_requested.connect(_play_from_editor)
		editor_layer.add_child(editor)
	editor_layer.visible = true
	if level != null:
		editor.load_level(level, id)


func _close_editor() -> void:
	editor_layer.visible = false
	_set_window_for_editor(false)
	ui_layer.visible = true
	_show_intro()


func _play_from_editor(def: Dictionary) -> void:
	editor_layer.visible = false
	_set_window_for_editor(false)
	ui_layer.visible = true
	custom = "editor"
	transitioning = false
	rec_runs = []
	rec_state = Replay.capture_state(def)
	_spawn_room(def, -1, "")


## Termina uma fase avulsa (venceu ou saiu) e volta de onde veio.
func _end_custom(won: bool) -> void:
	var from := custom
	custom = ""
	_clear_scene()
	hint.text = ""
	title.text = ""
	if from == "editor":
		ui_layer.visible = false
		_set_window_for_editor(true)
		editor_layer.visible = true
		editor.play_finished(won, rec_runs, rec_state)
	else:
		show_list()


func show_list() -> void:
	_stop_music()
	_clear_scene()
	finished = false
	hint.text = ""
	title.text = ""
	end_label.visible = false
	list_items = []
	for e in LevelStore.list():
		if e["data"].is_verified() and e["data"].is_playable():
			list_items.append(e)
	list_sel = clampi(list_sel, 0, maxi(list_items.size() - 1, 0))
	in_list = true
	if list_label == null:
		list_label = Label.new()
		list_label.position = Vector2(20, 14)
		list_label.size = Vector2(280, 150)
		list_label.add_theme_font_size_override("font_size", 8)
		list_label.add_theme_constant_override("line_spacing", 2)
		ui_layer.add_child(list_label)
	list_label.visible = true
	_refresh_list()


func _refresh_list() -> void:
	var t := "MINHAS FASES\n\n"
	if list_items.is_empty():
		t += "Nenhuma fase verificada ainda.\nCrie uma no editor (E na tela de início)\ne vença-a uma vez para ela aparecer aqui.\n\nEsc volta."
	else:
		var first := clampi(list_sel - 5, 0, maxi(list_items.size() - 10, 0))
		for i in range(first, mini(first + 10, list_items.size())):
			var d = list_items[i]["data"]
			t += "%s %s   %dx%d\n" % [">" if i == list_sel else " ", d.name if d.name != "" else list_items[i]["id"], d.width(), d.height()]
		t += "\nCima/baixo escolhe  ·  Enter joga  ·  E edita  ·  Esc volta"
	list_label.text = t


func _hide_list() -> void:
	in_list = false
	if list_label != null:
		list_label.visible = false


func _tick_list() -> void:
	if Input.is_action_just_pressed("back"):
		_hide_list()
		_show_intro()
		return
	if list_items.is_empty():
		return
	if Input.is_action_just_pressed("ui_down"):
		list_sel = mini(list_sel + 1, list_items.size() - 1)
		_refresh_list()
	elif Input.is_action_just_pressed("ui_up"):
		list_sel = maxi(list_sel - 1, 0)
		_refresh_list()
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("start"):
		_play_list_item()
	elif Input.is_action_just_pressed("open_editor"):
		var e2: Dictionary = list_items[list_sel]
		open_editor(e2["data"], e2["id"])


func _play_list_item() -> void:
	if list_items.is_empty():
		return
	var e: Dictionary = list_items[list_sel]
	_hide_list()
	custom = "list"
	transitioning = false
	_spawn_room(e["data"].to_def(), -1, "")
