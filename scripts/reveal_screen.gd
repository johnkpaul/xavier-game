extends CanvasLayer
class_name RevealScreen

## Full-screen celebration shown whenever Xavier either sets a new bravery
## record (held out longer than ever before and still escaped) or banks his
## way past another milestone of total points (see GameManager.MILESTONE_STEP).
## Purely a fun pause between rounds - no unlockable content is gated
## behind it in this first pass, easy to add later.

signal reveal_complete

const RECORD_MESSAGES := [
	"THAT WAS SO BRAVE!",
	"YOU HELD OUT LONGER THAN EVER!",
	"THE MOUTH ALMOST GOT YOU!",
	"XAVIER THE BRAVEST!",
]

const MILESTONE_MESSAGES := [
	"KEEP BEING BRAVE, XAVIER!",
	"THE MOUTH CAN'T CATCH YOU!",
	"WOW, LOOK AT ALL THOSE POINTS!",
	"XAVIER THE TREAT CHAMPION!",
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


func play(points: int, is_new_best: bool, milestone: int) -> void:
	if is_new_best:
		headline.text = "NEW BRAVERY RECORD: %d!" % points
		subline.text = RECORD_MESSAGES[GameManager.best_round % RECORD_MESSAGES.size()]
	else:
		var total: int = milestone * GameManager.MILESTONE_STEP
		headline.text = "%d POINTS BANKED!" % total
		subline.text = MILESTONE_MESSAGES[(milestone - 1) % MILESTONE_MESSAGES.size()]

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
