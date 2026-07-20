extends Node2D
class_name Game

## The whole push-your-luck loop lives here. Each round: a treat appears,
## GRAB increases the haul but rolls a rising chance the mouth snaps shut
## (losing that round's unbanked treats - never anything permanent), RUN
## banks the haul into GameManager.total_treats and starts a fresh round.

signal milestone_reached(index: int)

## Index = risk_level (how many successful grabs so far this round). The
## last entry is 1.0 so the mouth is guaranteed to snap by the 9th grab,
## keeping rounds short enough for a 5-year-old's attention span.
const SNAP_CHANCES: Array[float] = [0.0, 0.05, 0.12, 0.22, 0.35, 0.50, 0.68, 0.85, 1.0]

const RISK_COLORS: Array[Color] = [
	Color8(0x4C, 0xAF, 0x50), Color8(0xFF, 0xD5, 0x4F),
	Color8(0xFF, 0x8A, 0x3D), Color8(0xE5, 0x39, 0x35),
]

const TEX_TRAP_OPEN := preload("res://generated_assets/trap_mouth_open.png")
const TEX_TRAP_SNAP := preload("res://generated_assets/trap_mouth_snap.png")
const TEX_XAVIER_IDLE := preload("res://generated_assets/xavier_idle.png")
const TEX_XAVIER_REACH := preload("res://generated_assets/xavier_reach.png")
const TEX_XAVIER_BONK := preload("res://generated_assets/xavier_bonk.png")
const TEX_XAVIER_CHEER := preload("res://generated_assets/xavier_cheer.png")
const TREAT_TEXTURES := [
	preload("res://generated_assets/treat_red.png"),
	preload("res://generated_assets/treat_blue.png"),
	preload("res://generated_assets/treat_yellow.png"),
]

@onready var trap_sprite: Sprite2D = $Trap
@onready var xavier_sprite: Sprite2D = $Xavier
@onready var treat_sprite: Sprite2D = $Treat
@onready var meter_fill_clip: Control = $HUD/RiskMeter/FillClip
@onready var meter_fill: TextureRect = $HUD/RiskMeter/FillClip/Fill
@onready var round_label: Label = $HUD/RoundLabel
@onready var total_label: Label = $HUD/TotalLabel
@onready var grab_button: TouchButton = $Controls/GrabButton
@onready var run_button: TouchButton = $Controls/RunButton

var round_treats := 0
var risk_level := 0
var busy := false
var _rng := RandomNumberGenerator.new()
var _trap_home_pos: Vector2


func _ready() -> void:
	_rng.randomize()
	_trap_home_pos = trap_sprite.position

	grab_button.pressed.connect(_on_grab_pressed)
	run_button.pressed.connect(_on_run_pressed)

	total_label.text = "Treats: %d" % GameManager.total_treats
	GameManager.total_changed.connect(func(t: int): total_label.text = "Treats: %d" % t)

	start_new_round()


func start_new_round() -> void:
	round_treats = 0
	risk_level = 0
	busy = false
	trap_sprite.texture = TEX_TRAP_OPEN
	trap_sprite.modulate = RISK_COLORS[0]
	xavier_sprite.texture = TEX_XAVIER_IDLE
	_update_round_label()
	_update_meter()
	_spawn_treat()
	_refresh_buttons()


func _spawn_treat() -> void:
	treat_sprite.texture = TREAT_TEXTURES[_rng.randi_range(0, TREAT_TEXTURES.size() - 1)]
	treat_sprite.modulate.a = 0.0
	treat_sprite.visible = true
	var tw := create_tween()
	tw.tween_property(treat_sprite, "modulate:a", 1.0, 0.2)


func _on_grab_pressed() -> void:
	if busy:
		return
	busy = true
	_refresh_buttons()

	xavier_sprite.texture = TEX_XAVIER_REACH
	ProceduralAudio.play_sfx("grab")

	var chance: float = SNAP_CHANCES[mini(risk_level, SNAP_CHANCES.size() - 1)]
	var will_snap: bool = _rng.randf() < chance
	risk_level += 1

	await get_tree().create_timer(0.22).timeout

	if will_snap:
		_do_snap()
	else:
		round_treats += 1
		treat_sprite.visible = false
		xavier_sprite.texture = TEX_XAVIER_IDLE
		_update_round_label()
		_update_meter()
		await get_tree().create_timer(0.15).timeout
		_spawn_treat()
		busy = false
		_refresh_buttons()


func _on_run_pressed() -> void:
	if busy or round_treats <= 0:
		return
	busy = true
	_refresh_buttons()

	xavier_sprite.texture = TEX_XAVIER_CHEER
	treat_sprite.visible = false
	ProceduralAudio.play_sfx("bank")

	var banked := round_treats
	var milestone := GameManager.bank(banked)

	await get_tree().create_timer(0.9).timeout

	if milestone > 0:
		milestone_reached.emit(milestone)
	else:
		start_new_round()


func _do_snap() -> void:
	trap_sprite.texture = TEX_TRAP_SNAP
	trap_sprite.modulate = Color(1, 1, 1, 1)
	xavier_sprite.texture = TEX_XAVIER_BONK
	treat_sprite.visible = false
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


func _update_round_label() -> void:
	round_label.text = "In hand: %d" % round_treats


func _update_meter() -> void:
	var t: float = float(risk_level) / float(SNAP_CHANCES.size() - 1)
	var col := _risk_color(t)
	trap_sprite.modulate = col
	var full_width: float = meter_fill.size.x
	var tw := create_tween()
	tw.tween_property(meter_fill_clip, "size:x", full_width * t, 0.2)
	meter_fill.modulate = col


func _risk_color(t: float) -> Color:
	var scaled: float = clampf(t, 0.0, 1.0) * float(RISK_COLORS.size() - 1)
	var i := int(scaled)
	if i >= RISK_COLORS.size() - 1:
		return RISK_COLORS[RISK_COLORS.size() - 1]
	return RISK_COLORS[i].lerp(RISK_COLORS[i + 1], scaled - i)


func _refresh_buttons() -> void:
	grab_button.set_enabled(not busy)
	run_button.set_enabled(not busy and round_treats > 0)
