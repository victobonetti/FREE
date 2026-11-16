extends RefCounted
## Registra as ações de entrada em código (teclado e controle).


static func setup() -> void:
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _pad(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _pad(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("jump", [_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP), _key(KEY_K), _pad(JOY_BUTTON_A)])
	# Na corda só dá para descer; as teclas de pulo (inclusive W e seta para cima) soltam.
	_add("climb_down", [_key(KEY_S), _key(KEY_DOWN), _pad(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("rotate_ccw", [_key(KEY_Q), _pad(JOY_BUTTON_LEFT_SHOULDER)])
	_add("rotate_cw", [_key(KEY_E), _pad(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("restart", [_key(KEY_R), _pad(JOY_BUTTON_Y)])
	_add("start", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _pad(JOY_BUTTON_START), _pad(JOY_BUTTON_A)])
	# Atalhos de desenvolvimento
	_add("next_room", [_key(KEY_PAGEDOWN)])
	_add("prev_room", [_key(KEY_PAGEUP)])


static func _add(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.4)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
