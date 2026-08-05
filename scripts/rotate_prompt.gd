extends CanvasLayer
class_name RotatePrompt

## Covers the screen with "turn your phone sideways" whenever the device is
## held in portrait.
##
## The project sets display/window/handheld/orientation = "landscape", but
## that only binds a native app via its manifest - a browser will happily
## render the page in whatever orientation the phone is held, and Godot's
## web export cannot lock orientation outside of fullscreen. So a kid handed
## a phone in portrait gets the real thing: stretch/aspect = "expand" grows
## the *logical* viewport vertically instead of horizontally, the logical
## space becomes roughly 1920x3700, and every element in the game renders at
## about a quarter of its intended size - roughly 11 CSS pixels for body
## text. Nothing errors and nothing is clipped; it's just silently
## unreadable, with no hint that turning the phone would fix it.
##
## Telling them to rotate is far better than trying to make a landscape
## composition work at 0.5:1. Deliberately does not pause anything - the
## game underneath keeps running and is revealed the instant the phone
## turns, so this can never trap a player.

const BG_COLOR := Color(0.06, 0.06, 0.07, 1.0)
const TEXT_COLOR := Color(1.0, 0.72, 0.30)
const HINT_COLOR := Color(1.0, 1.0, 1.0, 0.7)

var _backdrop: ColorRect
var _icon: Label
var _label: Label
var _hint: Label
var _spin: Tween


func _ready() -> void:
	# Above every other layer in both games, including the version tag.
	layer = 90
	_build()
	get_viewport().size_changed.connect(_refresh)
	_refresh()
	call_deferred("_refresh")


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BG_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# A phone drawn with text rather than a texture, so this needs no
	# generated art and works even if asset generation is what's broken.
	_icon = Label.new()
	_icon.text = "[ ]"
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_label = Label.new()
	_label.text = "TURN YOUR PHONE SIDEWAYS"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_hint = Label.new()
	_hint.text = "THE GAME IS WAITING!"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait: bool = vp.y > vp.x
	visible = portrait
	if not portrait:
		if _spin:
			_spin.kill()
			_spin = null
		return

	# Sizes are derived from the viewport rather than written as design-space
	# constants. In portrait the logical space is ~1920x3700, so a font size
	# chosen against a 1080-tall design would come out microscopic - exactly
	# the problem this screen exists to explain.
	var base: float = minf(vp.x, vp.y)
	var title_size := int(clampf(base * 0.062, 48.0, 190.0))
	var hint_size := int(clampf(base * 0.040, 32.0, 130.0))
	var icon_size := int(clampf(base * 0.130, 80.0, 380.0))

	_backdrop.position = Vector2.ZERO
	_backdrop.size = vp

	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var width: float = vp.x * 0.86

	_icon.add_theme_font_size_override("font_size", icon_size)
	_icon.size = Vector2(width, icon_size * 1.6)
	_icon.position = Vector2(cx - width * 0.5, cy - icon_size * 1.9)
	_icon.pivot_offset = _icon.size * 0.5

	_label.add_theme_font_size_override("font_size", title_size)
	_label.size = Vector2(width, title_size * 2.6)
	_label.position = Vector2(cx - width * 0.5, cy)

	_hint.add_theme_font_size_override("font_size", hint_size)
	_hint.size = Vector2(width, hint_size * 2.0)
	_hint.position = Vector2(cx - width * 0.5, cy + title_size * 2.9)

	_start_spin()


## Rocks the phone glyph a quarter turn and back, so the instruction is
## demonstrated rather than only written - the same reasoning as animating
## the joystick until first use.
func _start_spin() -> void:
	if _spin:
		return
	_spin = create_tween()
	_spin.set_loops()
	_spin.tween_interval(0.35)
	_spin.tween_property(_icon, "rotation", -PI / 2.0, 0.65).set_trans(Tween.TRANS_CUBIC)
	_spin.tween_interval(0.7)
	_spin.tween_property(_icon, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC)
