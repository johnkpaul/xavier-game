extends CanvasLayer
class_name RevealScreen

## Full-screen celebration shown every time Xavier banks his way past
## another milestone of total treats (see GameManager.MILESTONE_STEP).
## Purely a fun pause between rounds - no unlockable content is gated
## behind it in this first pass, easy to add later.

signal reveal_complete

const MESSAGES := [
	"YOU'RE SO QUICK!",
	"WOW, LOOK AT ALL THOSE TREATS!",
	"THE MOUTH CAN'T CATCH YOU!",
	"XAVIER THE TREAT CHAMPION!",
	"KEEP GOING, XAVIER!",
]

const ORANGE := Color(1.0, 0.55, 0.15)
const GOLD := Color(1.0, 0.83, 0.3)

@onready var background: ColorRect = $Background
@onready var headline: Label = $Headline
@onready var subline: Label = $Subline
@onready var tap_hint: Label = $TapHint

var _ready_for_tap := false


func _ready() -> void:
	layer = 20
	visible = false
	background.color = Color(0.101961, 0.101961, 0.101961, 0.85)

	headline.add_theme_color_override("font_color", GOLD)
	subline.add_theme_color_override("font_color", ORANGE)
	tap_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))

	headline.modulate.a = 0.0
	subline.modulate.a = 0.0
	tap_hint.modulate.a = 0.0


func play(milestone_index: int) -> void:
	var total: int = milestone_index * GameManager.MILESTONE_STEP
	headline.text = "%d TREATS BANKED!" % total
	subline.text = MESSAGES[(milestone_index - 1) % MESSAGES.size()]

	visible = true
	_ready_for_tap = false
	ProceduralAudio.play_sfx("reveal")

	var tw := create_tween()
	tw.tween_property(headline, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(headline, "scale", Vector2(1, 1), 0.35).from(Vector2(0.6, 0.6))
	tw.tween_interval(0.15)
	tw.tween_property(subline, "modulate:a", 1.0, 0.35)
	tw.tween_interval(0.4)
	tw.tween_callback(_show_tap_hint)


func _show_tap_hint() -> void:
	tap_hint.text = "TAP TO KEEP PLAYING"
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(tap_hint, "modulate:a", 1.0, 0.5)
	tw.tween_property(tap_hint, "modulate:a", 0.2, 0.5)
	_ready_for_tap = true


func _input(event: InputEvent) -> void:
	if not visible or not _ready_for_tap:
		return
	if event is InputEventScreenTouch and event.pressed:
		_continue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_continue()


func _continue() -> void:
	_ready_for_tap = false
	visible = false
	headline.modulate.a = 0.0
	subline.modulate.a = 0.0
	tap_hint.modulate.a = 0.0
	reveal_complete.emit()
