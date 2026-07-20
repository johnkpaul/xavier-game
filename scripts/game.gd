extends Node2D
class_name Game

## Hold-your-nerve loop: each round, Xavier stands his ground in front of
## the trap's mouth and bravery points tick up for every second he holds
## out. A hidden timer (randomized per round, never shown to the player)
## decides when the mouth snaps - the mouth's color and the risk meter rise
## continuously so the danger is always felt, even though the exact moment
## is luck. Tap RUN before it snaps to bank the points; wait too long and
## the mouth catches him, discarding this round's (unbanked) points - never
## anything permanent. There is exactly one button in the whole game.

signal celebration(points: int, is_new_best: bool, milestone: int)

const MIN_SNAP_TIME := 1.2
const MAX_SNAP_TIME := 5.0
## Visual/meter reference span - deliberately equal to MAX_SNAP_TIME so a
## full risk meter roughly means "you're in the danger zone now", even
## though the actual hidden snap time is drawn from the same range.
const METER_SPAN := MAX_SNAP_TIME
const POINTS_PER_SECOND := 10.0

const RISK_COLORS: Array[Color] = [
	Color8(0x4C, 0xAF, 0x50), Color8(0xFF, 0xD5, 0x4F),
	Color8(0xFF, 0x8A, 0x3D), Color8(0xE5, 0x39, 0x35),
]

const TEX_TRAP_OPEN := preload("res://generated_assets/trap_mouth_open.png")
const TEX_TRAP_SNAP := preload("res://generated_assets/trap_mouth_snap.png")
const TEX_XAVIER_IDLE := preload("res://generated_assets/xavier_idle.png")
const TEX_XAVIER_BRACE := preload("res://generated_assets/xavier_reach.png")
const TEX_XAVIER_BONK := preload("res://generated_assets/xavier_bonk.png")
const TEX_XAVIER_CHEER := preload("res://generated_assets/xavier_cheer.png")

@onready var trap_sprite: Sprite2D = $Trap
@onready var xavier_sprite: Sprite2D = $Xavier
@onready var meter_fill_clip: Control = $HUD/RiskMeter/FillClip
@onready var meter_fill: TextureRect = $HUD/RiskMeter/FillClip/Fill
@onready var points_label: Label = $HUD/PointsLabel
@onready var total_label: Label = $HUD/TotalLabel
@onready var run_button: TouchButton = $Controls/RunButton

var _elapsed := 0.0
var _snap_time := 0.0
var _active := false
var _busy := false
var _rng := RandomNumberGenerator.new()
var _trap_home_pos: Vector2


func _ready() -> void:
	_rng.randomize()
	_trap_home_pos = trap_sprite.position

	run_button.pressed.connect(_on_run_pressed)

	total_label.text = "Total: %d" % GameManager.total_points
	GameManager.total_changed.connect(func(t: int): total_label.text = "Total: %d" % t)

	start_new_round()


func start_new_round() -> void:
	_elapsed = 0.0
	_snap_time = _rng.randf_range(MIN_SNAP_TIME, MAX_SNAP_TIME)
	_busy = false
	_active = true

	trap_sprite.texture = TEX_TRAP_OPEN
	trap_sprite.modulate = RISK_COLORS[0]
	xavier_sprite.texture = TEX_XAVIER_BRACE

	_update_points_label(0)
	_update_meter(0.0)
	run_button.set_enabled(true)


func _process(delta: float) -> void:
	if not _active or _busy:
		return
	_elapsed += delta
	_update_points_label(_current_points())
	_update_meter(clampf(_elapsed / METER_SPAN, 0.0, 1.0))

	if _elapsed >= _snap_time:
		_active = false
		_do_snap()


func _current_points() -> int:
	return int(_elapsed * POINTS_PER_SECOND)


func _on_run_pressed() -> void:
	if _busy or not _active:
		return
	_active = false
	_busy = true
	run_button.set_enabled(false)

	var points := _current_points()
	xavier_sprite.texture = TEX_XAVIER_CHEER
	ProceduralAudio.play_sfx("bank")

	var result := GameManager.bank(points)

	await get_tree().create_timer(0.9).timeout

	if result["is_new_best"] or result["milestone"] > 0:
		celebration.emit(points, result["is_new_best"], result["milestone"])
	else:
		start_new_round()


func _do_snap() -> void:
	_busy = true
	run_button.set_enabled(false)

	trap_sprite.texture = TEX_TRAP_SNAP
	trap_sprite.modulate = Color(1, 1, 1, 1)
	xavier_sprite.texture = TEX_XAVIER_BONK
	ProceduralAudio.play_sfx("snap")
	_shake_trap()

	await get_tree().create_timer(0.9).timeout
	start_new_round()


func _shake_trap() -> void:
	var tw := create_tween()
	for i in range(4):
		var offset := Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-6, 6))
		tw.tween_property(trap_sprite, "position", _trap_home_pos + offset, 0.04)
	tw.tween_property(trap_sprite, "position", _trap_home_pos, 0.04)


func _update_points_label(points: int) -> void:
	points_label.text = "Points: %d" % points


func _update_meter(t: float) -> void:
	var col := _risk_color(t)
	trap_sprite.modulate = col
	meter_fill.modulate = col
	var full_width: float = meter_fill.size.x
	meter_fill_clip.size.x = full_width * t


func _risk_color(t: float) -> Color:
	var scaled: float = clampf(t, 0.0, 1.0) * float(RISK_COLORS.size() - 1)
	var i := int(scaled)
	if i >= RISK_COLORS.size() - 1:
		return RISK_COLORS[RISK_COLORS.size() - 1]
	return RISK_COLORS[i].lerp(RISK_COLORS[i + 1], scaled - i)
