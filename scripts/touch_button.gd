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

var _urgency_tween: Tween
var _urgency_bucket := -1
const URGENCY_BUCKETS := 4


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
	_stop_urgency_pulse()
	_urgency_bucket = -1
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


## Continuous "hurry up" pulse independent of the press/release feedback,
## driven by an external 0..1 risk value (e.g. how close a hidden timer is
## to firing). The pulse gets faster and bigger as t rises, so the one
## button in the game visibly demands more urgency right as the danger
## does - the player doesn't have to look elsewhere (a meter, a color) and
## infer they should act; the thing they need to tap is telling them itself.
func set_urgency(t: float) -> void:
	if not _enabled or not _shown:
		t = 0.0
	var bucket: int = clampi(int(t * URGENCY_BUCKETS), 0, URGENCY_BUCKETS - 1)
	if bucket == _urgency_bucket:
		return
	_urgency_bucket = bucket
	_stop_urgency_pulse()

	if bucket == 0 or _is_pressed:
		return

	var frac: float = float(bucket) / float(URGENCY_BUCKETS - 1)
	var period: float = lerpf(0.45, 0.12, frac)
	var pulse_scale: float = lerpf(1.06, 1.24, frac)

	_urgency_tween = create_tween()
	_urgency_tween.set_loops()
	_urgency_tween.tween_property(self, "scale", Vector2(pulse_scale, pulse_scale), period).set_trans(Tween.TRANS_SINE)
	_urgency_tween.tween_property(self, "scale", Vector2(_resting_scale, _resting_scale), period).set_trans(Tween.TRANS_SINE)


func _stop_urgency_pulse() -> void:
	if _urgency_tween:
		_urgency_tween.kill()
		_urgency_tween = null
	if not _is_pressed:
		scale = Vector2(_resting_scale, _resting_scale)


func punch_scale() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), tween_duration)
	tw.tween_property(self, "scale", Vector2(_resting_scale, _resting_scale), tween_duration)


func _animate_to(target_scale: float, target_alpha: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(target_scale, target_scale), tween_duration)
	tw.tween_property(self, "modulate:a", target_alpha, tween_duration)
