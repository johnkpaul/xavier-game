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

## The very first round ever played runs long and slow instead of drawing a
## normal random snap time, so there's a comfortable window to narrate the
## whole loop once before real play begins.
const TUTORIAL_SNAP_TIME := 9.0
const TUTORIAL_WATCH_DURATION := 2.4

const RISK_COLORS: Array[Color] = [
	Color8(0x4C, 0xAF, 0x50), Color8(0xFF, 0xD5, 0x4F),
	Color8(0xFF, 0x8A, 0x3D), Color8(0xE5, 0x39, 0x35),
]

## Closing flipbook: index 0 = fully open (least risk) ... last index =
## almost shut (highest risk before the actual bite). Swapped by risk t so
## the danger is something Xavier can visibly see closing in, not just a
## color shift or an abstract meter.
const TRAP_MOUTH_FRAMES := [
	preload("res://generated_assets/trap_mouth_stage0.png"),
	preload("res://generated_assets/trap_mouth_stage1.png"),
	preload("res://generated_assets/trap_mouth_stage2.png"),
	preload("res://generated_assets/trap_mouth_stage3.png"),
]
const TEX_TRAP_SNAP := preload("res://generated_assets/trap_mouth_snap.png")

## Xavier has one real sprite (see res://imported_assets/) rather than a
## separate baked image per pose. Bonk/cheer are conveyed with tween-driven
## motion and color instead - a knockback + red flash, or a hop + gold flash.
const TEX_XAVIER := preload("res://imported_assets/xavier_sprite.png")
const BONK_FLASH := Color8(0xFF, 0x6B, 0x6B)
const CHEER_FLASH := Color8(0xFF, 0xE0, 0x7A)

@onready var trap_sprite: Sprite2D = $Trap
@onready var xavier_sprite: Sprite2D = $Xavier
@onready var meter_fill_clip: Control = $HUD/RiskMeter/FillClip
@onready var meter_fill: TextureRect = $HUD/RiskMeter/FillClip/Fill
@onready var points_label: Label = $HUD/PointsLabel
@onready var total_label: Label = $HUD/TotalLabel
@onready var tutorial_label: Label = $HUD/TutorialLabel
@onready var run_button: TouchButton = $Controls/RunButton
@onready var hint_arrow: TextureRect = $Controls/HintArrow

var _elapsed := 0.0
var _snap_time := 0.0
var _active := false
var _busy := false
var _is_tutorial_round := false
var _rng := RandomNumberGenerator.new()
var _trap_home_pos: Vector2
var _xavier_home_pos: Vector2
var _xavier_home_scale: Vector2
var _hint_arrow_tween: Tween


func _ready() -> void:
	_rng.randomize()
	_trap_home_pos = trap_sprite.position
	_xavier_home_pos = xavier_sprite.position
	_xavier_home_scale = xavier_sprite.scale

	run_button.pressed.connect(_on_run_pressed)

	total_label.text = "Total: %d" % GameManager.total_points
	GameManager.total_changed.connect(func(t: int): total_label.text = "Total: %d" % t)

	start_new_round()


func start_new_round() -> void:
	_elapsed = 0.0
	_is_tutorial_round = not GameManager.has_seen_tutorial
	_snap_time = TUTORIAL_SNAP_TIME if _is_tutorial_round else _rng.randf_range(MIN_SNAP_TIME, MAX_SNAP_TIME)
	_busy = false
	_active = true

	trap_sprite.texture = TRAP_MOUTH_FRAMES[0]
	trap_sprite.modulate = RISK_COLORS[0]
	xavier_sprite.texture = TEX_XAVIER
	xavier_sprite.position = _xavier_home_pos
	xavier_sprite.scale = _xavier_home_scale
	xavier_sprite.rotation = 0.0
	xavier_sprite.modulate = Color(1, 1, 1, 1)

	_update_points_label(0)
	_update_meter(0.0)
	run_button.set_enabled(true)
	run_button.set_urgency(0.0)

	if _is_tutorial_round:
		_play_tutorial_intro()
	else:
		_hide_tutorial_hints()


func _play_tutorial_intro() -> void:
	tutorial_label.visible = true
	tutorial_label.modulate.a = 0.0
	tutorial_label.text = "WATCH THE MOUTH GET CLOSER..."
	var tw := create_tween()
	tw.tween_property(tutorial_label, "modulate:a", 1.0, 0.3)

	await get_tree().create_timer(TUTORIAL_WATCH_DURATION).timeout
	if not _is_tutorial_round or not _active:
		return

	tutorial_label.text = "TAP RUN TO ESCAPE SAFELY!"
	hint_arrow.visible = true
	hint_arrow.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(hint_arrow, "modulate:a", 1.0, 0.25)
	_start_hint_arrow_bounce()


func _start_hint_arrow_bounce() -> void:
	_stop_hint_arrow_bounce()
	var base_y := hint_arrow.position.y
	_hint_arrow_tween = create_tween()
	_hint_arrow_tween.set_loops()
	_hint_arrow_tween.tween_property(hint_arrow, "position:y", base_y + 20.0, 0.4).set_trans(Tween.TRANS_SINE)
	_hint_arrow_tween.tween_property(hint_arrow, "position:y", base_y, 0.4).set_trans(Tween.TRANS_SINE)


func _stop_hint_arrow_bounce() -> void:
	if _hint_arrow_tween:
		_hint_arrow_tween.kill()
		_hint_arrow_tween = null


func _hide_tutorial_hints() -> void:
	tutorial_label.visible = false
	hint_arrow.visible = false
	_stop_hint_arrow_bounce()


func _finish_tutorial_if_needed() -> void:
	if not _is_tutorial_round:
		return
	_is_tutorial_round = false
	GameManager.mark_tutorial_seen()
	_hide_tutorial_hints()


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
	run_button.set_urgency(0.0)
	_finish_tutorial_if_needed()

	var points := _current_points()
	_play_cheer()
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
	run_button.set_urgency(0.0)
	_finish_tutorial_if_needed()

	trap_sprite.texture = TEX_TRAP_SNAP
	trap_sprite.modulate = Color(1, 1, 1, 1)
	_play_bonk()
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


## Knockback + red flash: a quick shove backward-and-down with a squash,
## conveying "caught" without a separate baked bonk pose.
func _play_bonk() -> void:
	var kick_pos := _xavier_home_pos + Vector2(-24, 12)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(xavier_sprite, "position", kick_pos, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(xavier_sprite, "rotation", -0.35, 0.12)
	tw.tween_property(xavier_sprite, "modulate", BONK_FLASH, 0.08)
	tw.chain().tween_property(xavier_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.chain().tween_property(xavier_sprite, "position", _xavier_home_pos, 0.3).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(xavier_sprite, "rotation", 0.0, 0.3)


## Hop + gold flash: a happy little bounce up, conveying "escaped safely"
## without a separate baked cheer pose.
func _play_cheer() -> void:
	var hop_pos := _xavier_home_pos + Vector2(0, -36)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(xavier_sprite, "position", hop_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(xavier_sprite, "scale", _xavier_home_scale * 1.15, 0.18)
	tw.tween_property(xavier_sprite, "modulate", CHEER_FLASH, 0.1)
	tw.chain().tween_property(xavier_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.chain().tween_property(xavier_sprite, "position", _xavier_home_pos, 0.3).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(xavier_sprite, "scale", _xavier_home_scale, 0.3)


func _update_points_label(points: int) -> void:
	points_label.text = "Points: %d" % points


func _update_meter(t: float) -> void:
	var col := _risk_color(t)
	trap_sprite.modulate = col
	trap_sprite.texture = TRAP_MOUTH_FRAMES[_frame_index(t)]
	meter_fill.modulate = col
	var full_width: float = meter_fill.size.x
	meter_fill_clip.size.x = full_width * t
	run_button.set_urgency(t)


func _frame_index(t: float) -> int:
	var last := TRAP_MOUTH_FRAMES.size() - 1
	return clampi(int(round(t * last)), 0, last)


func _risk_color(t: float) -> Color:
	var scaled: float = clampf(t, 0.0, 1.0) * float(RISK_COLORS.size() - 1)
	var i := int(scaled)
	if i >= RISK_COLORS.size() - 1:
		return RISK_COLORS[RISK_COLORS.size() - 1]
	return RISK_COLORS[i].lerp(RISK_COLORS[i + 1], scaled - i)
