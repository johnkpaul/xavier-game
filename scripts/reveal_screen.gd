extends CanvasLayer
class_name RevealScreen

## Non-blocking celebration toast shown whenever Xavier either sets a new
## best crossing streak (most times in a row he's made it across without
## being caught) or banks his way past another milestone of total points
## (see GameManager.MILESTONE_STEP). Fades in, holds briefly, fades out on
## its own - it never pauses gameplay, disables input, or requires a tap to
## dismiss. Xavier keeps dashing, the mouth keeps cycling, and RUN stays
## live the entire time this is on screen.

const RECORD_MESSAGES := [
	"THAT WAS SO BRAVE!",
	"YOU'VE NEVER MADE IT ACROSS THIS MANY TIMES!",
	"THE MOUTH CAN'T KEEP UP WITH YOU!",
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

const FADE_IN := 0.35
const HOLD := 1.4
const FADE_OUT := 0.4

@onready var backdrop: ColorRect = $Backdrop
@onready var headline: Label = $Headline
@onready var subline: Label = $Subline

var _tween: Tween


func _ready() -> void:
	layer = 20
	visible = false

	# Never intercepts input - this floats over live gameplay, it doesn't
	# gate it. mouse_filter=IGNORE on every Control child lets taps pass
	# straight through to the RUN button underneath (CanvasLayer itself
	# isn't a Control and has no mouse_filter of its own).
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color(0.101961, 0.101961, 0.101961, 0.55)

	headline.add_theme_color_override("font_color", GOLD)
	subline.add_theme_color_override("font_color", ORANGE)
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subline.mouse_filter = Control.MOUSE_FILTER_IGNORE

	backdrop.modulate.a = 0.0
	headline.modulate.a = 0.0
	subline.modulate.a = 0.0


func play(streak: int, is_new_best: bool, milestone: int) -> void:
	if is_new_best:
		headline.text = "NEW BEST STREAK: %d IN A ROW!" % streak
		subline.text = RECORD_MESSAGES[GameManager.best_streak % RECORD_MESSAGES.size()]
	else:
		var total: int = milestone * GameManager.MILESTONE_STEP
		headline.text = "%d POINTS BANKED!" % total
		subline.text = MILESTONE_MESSAGES[(milestone - 1) % MILESTONE_MESSAGES.size()]

	ProceduralAudio.play_sfx("reveal")

	if _tween:
		_tween.kill()

	visible = true
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(backdrop, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(headline, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(subline, "modulate:a", 1.0, FADE_IN)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(backdrop, "modulate:a", 0.0, FADE_OUT)
	_tween.parallel().tween_property(headline, "modulate:a", 0.0, FADE_OUT)
	_tween.parallel().tween_property(subline, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(func(): visible = false)
