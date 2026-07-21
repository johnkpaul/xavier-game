extends Node2D
class_name Game

## Dash-across loop: the trap's mouth opens and closes on a fixed, visible
## rhythm (never hidden or random - the whole point is that a kid can watch
## it and learn the pattern). Xavier waits on one side; tapping RUN sends
## him dashing to the other side. If the mouth is in its closed/dangerous
## phase while he's passing through the middle, he's caught, bounces back
## to the side he started from, and his streak resets - never a game over.
## Every successful crossing banks points and extends the streak. There is
## exactly one button in the whole game.

signal celebration(points: int, is_new_best: bool, milestone: int)

## Full open->closed->open rhythm length. Fixed and predictable on purpose.
const CYCLE_DURATION := 3.0
## Fraction of the cycle (centered on the fully-closed midpoint) treated as
## dangerous. 0.3 means the middle 30% of the cycle is "the mouth is closed
## enough to bite" - the remaining 70%, split before/after, is safe.
const DANGER_FRACTION := 0.3

## How long a crossing takes to walk from one side to the other.
const CROSS_DURATION := 1.0
## The portion of a crossing (as a fraction of CROSS_DURATION, centered on
## the midpoint) during which Xavier is actually near the mouth and can be
## caught. Outside this window he's safely near a side, whatever the mouth
## is doing.
const RISK_WINDOW_START := 0.3
const RISK_WINDOW_END := 0.7

const CROSSING_POINTS := 10

## The two waiting spots, tuned to sit clear of the trap's mouth on both
## sides (which spans roughly x:560-1360 at its current position/scale).
const LEFT_X := 260.0
const RIGHT_X := 1660.0

## The very first crossing ever attempted uses a slower, more generous cycle
## instead of the normal rhythm, so there's a comfortable window to narrate
## the whole loop once before real play begins.
const TUTORIAL_CYCLE_DURATION := 5.0
const TUTORIAL_WATCH_CYCLES := 1.0

const RISK_COLORS: Array[Color] = [
	Color8(0x4C, 0xAF, 0x50), Color8(0xFF, 0xD5, 0x4F),
	Color8(0xFF, 0x8A, 0x3D), Color8(0xE5, 0x39, 0x35),
]

## Closing flipbook: index 0 = fully open ... last index = almost shut.
## Swapped continuously as the mouth's cycle phase changes, so the danger is
## something Xavier can visibly watch rise and fall in a steady rhythm. Real
## Sprixen-generated frames (see res://imported_assets/) rather than
## procedural art - see README's "Art pipeline" section.
const TRAP_MOUTH_FRAMES := [
	preload("res://imported_assets/trap_stage0.png"),
	preload("res://imported_assets/trap_stage1.png"),
	preload("res://imported_assets/trap_stage2.png"),
	preload("res://imported_assets/trap_stage3.png"),
	preload("res://imported_assets/trap_stage4.png"),
]
const TEX_TRAP_SNAP := preload("res://imported_assets/trap_bite.png")

## Xavier has one real sprite (see res://imported_assets/) rather than a
## separate baked image per pose. Catches/successes are conveyed with
## tween-driven motion and color instead of separate baked poses.
const TEX_XAVIER := preload("res://imported_assets/xavier_sprite.png")
const BONK_FLASH := Color8(0xFF, 0x6B, 0x6B)
const CHEER_FLASH := Color8(0xFF, 0xE0, 0x7A)

@onready var trap_sprite: Sprite2D = $Trap
@onready var xavier_sprite: Sprite2D = $Xavier
@onready var meter_fill_clip: Control = $HUD/RiskMeter/FillClip
@onready var meter_fill: TextureRect = $HUD/RiskMeter/FillClip/Fill
@onready var streak_label: Label = $HUD/PointsLabel
@onready var total_label: Label = $HUD/TotalLabel
@onready var tutorial_label: Label = $HUD/TutorialLabel
@onready var run_button: TouchButton = $Controls/RunButton
@onready var hint_arrow: TextureRect = $Controls/HintArrow

var _cycle_time := 0.0
var _cycle_duration := CYCLE_DURATION
var _on_left_side := true
var _crossing := false
var _crossing_elapsed := 0.0
var _busy := false
var _current_streak := 0
var _is_tutorial_active := false
var _rng := RandomNumberGenerator.new()
var _trap_home_pos: Vector2
var _xavier_home_y: float
var _xavier_home_scale: Vector2
var _hint_arrow_tween: Tween
var _idle_bob_tween: Tween
var _flee_bob_tween: Tween


func _ready() -> void:
	_rng.randomize()
	_trap_home_pos = trap_sprite.position
	_xavier_home_y = xavier_sprite.position.y
	_xavier_home_scale = xavier_sprite.scale

	run_button.pressed.connect(_on_run_pressed)

	total_label.text = "Total: %d" % GameManager.total_points
	GameManager.total_changed.connect(func(t: int): total_label.text = "Total: %d" % t)

	start_new_round()


func start_new_round() -> void:
	_cycle_time = 0.0
	_is_tutorial_active = not GameManager.has_seen_tutorial
	_cycle_duration = TUTORIAL_CYCLE_DURATION if _is_tutorial_active else CYCLE_DURATION
	_crossing = false
	_busy = false
	_on_left_side = true

	xavier_sprite.texture = TEX_XAVIER
	xavier_sprite.position = Vector2(LEFT_X, _xavier_home_y)
	xavier_sprite.scale = _xavier_home_scale
	xavier_sprite.rotation = 0.0
	xavier_sprite.modulate = Color(1, 1, 1, 1)

	_update_streak_label()
	run_button.set_enabled(true)
	_start_idle_bob()

	if _is_tutorial_active:
		_play_tutorial_intro()
	else:
		_hide_tutorial_hints()


func _play_tutorial_intro() -> void:
	tutorial_label.visible = true
	tutorial_label.modulate.a = 0.0
	tutorial_label.text = "WATCH THE MOUTH'S PATTERN..."
	var tw := create_tween()
	tw.tween_property(tutorial_label, "modulate:a", 1.0, 0.3)

	await get_tree().create_timer(_cycle_duration * TUTORIAL_WATCH_CYCLES).timeout
	if not _is_tutorial_active:
		return

	tutorial_label.text = "TAP RUN WHEN IT'S CLOSED!"
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
	if not _is_tutorial_active:
		return
	_is_tutorial_active = false
	GameManager.mark_tutorial_seen()
	_hide_tutorial_hints()


func _process(delta: float) -> void:
	if _busy:
		return

	_cycle_time = fmod(_cycle_time + delta, _cycle_duration)
	var closedness := _closedness(_cycle_time)
	var danger_t := _danger_from_closedness(closedness)
	_update_meter(closedness, danger_t)

	if _crossing:
		_crossing_elapsed += delta
		var progress: float = _crossing_elapsed / CROSS_DURATION
		if progress >= RISK_WINDOW_START and progress <= RISK_WINDOW_END and danger_t >= 1.0:
			_catch_mid_crossing()
		elif progress >= 1.0:
			_finish_crossing()


## 0.0 = fully open, 1.0 = fully closed. A symmetric triangle wave peaking
## at the cycle's midpoint, so the rhythm is exactly as predictable as it
## looks - no hidden randomness anywhere in this mechanic. This purely
## describes the mouth's physical state and always drives which frame is
## shown - it's deliberately kept separate from "danger" below, since the
## two aren't the same thing.
func _closedness(t: float) -> float:
	var phase := t / _cycle_duration
	return 1.0 - 2.0 * absf(phase - 0.5)


## The mouth is a hazard while it's open (wide open reads as "about to
## bite" - and a closed mouth physically can't catch anything further),
## so danger tracks openness, not closedness. Getting this backwards
## early on made the game feel rigged: the visuals told you "open = safe,
## about to relax", but the catch check fired exactly then.
func _danger_from_closedness(closedness: float) -> float:
	var openness := 1.0 - closedness
	if openness >= 1.0 - DANGER_FRACTION:
		return 1.0
	return openness / (1.0 - DANGER_FRACTION)


func _on_run_pressed() -> void:
	if _busy or _crossing:
		return
	_crossing = true
	_crossing_elapsed = 0.0
	run_button.set_enabled(false)
	_stop_idle_bob()

	var target_x := RIGHT_X if _on_left_side else LEFT_X
	xavier_sprite.scale.x = absf(_xavier_home_scale.x) if _on_left_side else -absf(_xavier_home_scale.x)

	var tw := create_tween()
	tw.tween_property(xavier_sprite, "position:x", target_x, CROSS_DURATION).set_trans(Tween.TRANS_LINEAR)

	_flee_bob_tween = create_tween()
	_flee_bob_tween.set_loops()
	_flee_bob_tween.tween_property(xavier_sprite, "position:y", _xavier_home_y - 10.0, 0.1).set_trans(Tween.TRANS_SINE)
	_flee_bob_tween.tween_property(xavier_sprite, "position:y", _xavier_home_y, 0.1).set_trans(Tween.TRANS_SINE)


func _finish_crossing() -> void:
	_crossing = false
	_busy = true
	_stop_flee_bob()
	xavier_sprite.position.x = RIGHT_X if _on_left_side else LEFT_X
	_on_left_side = not _on_left_side

	_current_streak += 1
	ProceduralAudio.play_sfx("bank")
	_play_cheer()

	var result := GameManager.record_crossing(CROSSING_POINTS, _current_streak)
	_update_streak_label()
	_finish_tutorial_if_needed()

	await get_tree().create_timer(0.6).timeout

	_busy = false
	run_button.set_enabled(true)
	_start_idle_bob()

	# Celebrations are a non-blocking side note, not a gate on play - the
	# next crossing is already available the moment this one resolves.
	if result["is_new_best"] or result["milestone"] > 0:
		celebration.emit(_current_streak, result["is_new_best"], result["milestone"])


func _catch_mid_crossing() -> void:
	_crossing = false
	_busy = true
	_stop_flee_bob()

	trap_sprite.texture = TEX_TRAP_SNAP
	trap_sprite.modulate = Color(1, 1, 1, 1)
	_current_streak = 0
	_update_streak_label()
	ProceduralAudio.play_sfx("snap")
	_shake_trap()
	_play_bonk()
	_finish_tutorial_if_needed()

	await get_tree().create_timer(0.9).timeout

	xavier_sprite.position.x = LEFT_X if _on_left_side else RIGHT_X
	_busy = false
	run_button.set_enabled(true)
	_start_idle_bob()


func _shake_trap() -> void:
	var tw := create_tween()
	for i in range(4):
		var offset := Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-6, 6))
		tw.tween_property(trap_sprite, "position", _trap_home_pos + offset, 0.04)
	tw.tween_property(trap_sprite, "position", _trap_home_pos, 0.04)


## Knockback + red flash: a quick shove back toward the side he started
## from, conveying "caught" without a separate baked bonk pose.
func _play_bonk() -> void:
	var home := Vector2(xavier_sprite.position.x, _xavier_home_y)
	var back_x := LEFT_X if _on_left_side else RIGHT_X
	var kick_pos := Vector2(lerpf(home.x, back_x, 0.4), _xavier_home_y + 12)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(xavier_sprite, "position", kick_pos, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(xavier_sprite, "rotation", -0.35, 0.12)
	tw.tween_property(xavier_sprite, "modulate", BONK_FLASH, 0.08)
	tw.chain().tween_property(xavier_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.chain().tween_property(xavier_sprite, "position", Vector2(back_x, _xavier_home_y), 0.3).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(xavier_sprite, "rotation", 0.0, 0.3)


## Gold flash + a little hop in place at the far side, conveying "made it!"
func _play_cheer() -> void:
	var landed_pos := xavier_sprite.position
	var hop_pos := landed_pos + Vector2(0, -30)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(xavier_sprite, "position", hop_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(xavier_sprite, "scale:y", _xavier_home_scale.y * 1.15, 0.15)
	tw.tween_property(xavier_sprite, "modulate", CHEER_FLASH, 0.1)
	tw.chain().tween_property(xavier_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.chain().tween_property(xavier_sprite, "position", landed_pos, 0.25).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(xavier_sprite, "scale:y", _xavier_home_scale.y, 0.25)


## A gentle up/down bob while Xavier waits on a side, so the "ready" state
## visibly reads as alive rather than a frozen static image.
func _start_idle_bob() -> void:
	_stop_idle_bob()
	var base_y := _xavier_home_y
	_idle_bob_tween = create_tween()
	_idle_bob_tween.set_loops()
	_idle_bob_tween.tween_property(xavier_sprite, "position:y", base_y - 8.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_bob_tween.tween_property(xavier_sprite, "position:y", base_y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_bob() -> void:
	if _idle_bob_tween:
		_idle_bob_tween.kill()
		_idle_bob_tween = null


func _stop_flee_bob() -> void:
	if _flee_bob_tween:
		_flee_bob_tween.kill()
		_flee_bob_tween = null


func _update_streak_label() -> void:
	streak_label.text = "Streak: %d" % _current_streak


## The trap's real art carries its own color, so danger is conveyed purely
## by which physical open/closed frame is showing (see TRAP_MOUTH_FRAMES) -
## no modulate tint on the creature itself, which would just muddy its
## colors. The green->red ramp still drives the UI risk meter, though.
## closedness picks the frame (the mouth's true physical state); danger_t
## drives the meter/catch logic (which tracks openness - see
## _danger_from_closedness).
func _update_meter(closedness: float, danger_t: float) -> void:
	trap_sprite.texture = TRAP_MOUTH_FRAMES[_frame_index(closedness)]
	var col := _risk_color(danger_t)
	meter_fill.modulate = col
	var full_width: float = meter_fill.size.x
	meter_fill_clip.size.x = full_width * danger_t


func _frame_index(t: float) -> int:
	var last := TRAP_MOUTH_FRAMES.size() - 1
	return clampi(int(round(t * last)), 0, last)


func _risk_color(t: float) -> Color:
	var scaled: float = clampf(t, 0.0, 1.0) * float(RISK_COLORS.size() - 1)
	var i := int(scaled)
	if i >= RISK_COLORS.size() - 1:
		return RISK_COLORS[RISK_COLORS.size() - 1]
	return RISK_COLORS[i].lerp(RISK_COLORS[i + 1], scaled - i)
