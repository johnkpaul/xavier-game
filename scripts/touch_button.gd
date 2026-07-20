extends Control
class_name TouchButton

## Generic large touch/mouse button with visible press feedback.

signal pressed
signal released

@export var pressed_scale: float = 1.15
@export var pressed_alpha: float = 1.0
@export var idle_scale: float = 1.0
@export var idle_alpha: float = 0.85
@export var tween_duration: float = 0.1

var _is_pressed := false
var _touch_index := -2
var _shown := true
var _resting_scale := 1.0
var _resting_alpha := 1.0
var _enabled := true


func _ready() -> void:
	pivot_offset = size / 2.0
	_resting_scale = idle_scale
	_resting_alpha = idle_alpha
	scale = Vector2(_resting_scale, _resting_scale)
	modulate.a = _resting_alpha
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not _shown or not _enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index)
		elif event.index == _touch_index:
			_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(-1)
		elif _touch_index == -1:
			_release()


func _press(idx: int) -> void:
	if _is_pressed:
		return
	_is_pressed = true
	_touch_index = idx
	_animate_to(pressed_scale, pressed_alpha)
	pressed.emit()
	_try_haptic()


func _release() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	_touch_index = -2
	_animate_to(_resting_scale, _resting_alpha)
	released.emit()


func _try_haptic() -> void:
	if Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(20)


## Enables/disables tap response without hiding the button (used to prevent
## double-taps during grab/bank/snap animations).
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	modulate.a = _resting_alpha if enabled else _resting_alpha * 0.4


func set_shown(shown: bool) -> void:
	if _shown == shown:
		return
	_shown = shown
	mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	_resting_scale = 1.0 if shown else 0.0
	_resting_alpha = (1.0 if _enabled else 0.4) if shown else 0.0
	if not _is_pressed:
		_animate_to(_resting_scale, _resting_alpha)


func punch_scale() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), tween_duration)
	tw.tween_property(self, "scale", Vector2(_resting_scale, _resting_scale), tween_duration)


func _animate_to(target_scale: float, target_alpha: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(target_scale, target_scale), tween_duration)
	tw.tween_property(self, "modulate:a", target_alpha, tween_duration)
