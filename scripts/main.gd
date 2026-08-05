extends Node
class_name Main

## Root of the game: title screen -> Snap Trap gameplay, forever (there are
## no discrete levels here - the game is one continuous dash-across loop).
## Celebrations for new best streaks and point milestones are a
## non-blocking toast that fades in over live gameplay - they never pause
## the game or require a dismiss tap.

const GAME_SCENE := preload("res://scenes/game.tscn")
const REVEAL_SCENE := preload("res://scenes/reveal_screen.tscn")

const TITLE_MIN_DURATION := 1.0

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var game_container: Node = $GameContainer
@onready var version_label: Label = $VersionTag/VersionLabel

var game: Game
var reveal: RevealScreen
var _audio_unlocked := false
var _title_ready := false


func _ready() -> void:
	_ensure_generated_assets()
	version_label.text = "v" + GameManager.BUILD_VERSION

	# The title screen's labels are authored with absolute offsets against
	# the 1920x1080 design space, so they need re-centring on the wider
	# logical viewport a phone in landscape produces. VersionTag is
	# deliberately excluded - it is genuinely corner-anchored in the scene
	# and a shift would pull it inward, away from the corner.
	ViewportFit.apply_layer(title_screen, $TitleScreen/Background)

	# Held in portrait the whole game renders at about a quarter size with
	# no explanation, so say so rather than letting a kid squint at it.
	add_child(RotatePrompt.new())

	game = GAME_SCENE.instantiate()
	game_container.add_child(game)
	game.celebration.connect(_on_celebration)

	title_screen.visible = true
	_title_ready = false
	await get_tree().create_timer(TITLE_MIN_DURATION).timeout
	_title_ready = true


## Must use ResourceLoader rather than FileAccess. In an exported build the
## source .png files are not shipped - they're converted to imported .ctex
## resources - so FileAccess.file_exists() reports false for every one of
## them and the game silently regenerates its entire art set on every single
## launch, on a device, before the title screen appears. ResourceLoader
## understands the import remaps and answers correctly in both cases.
func _ensure_generated_assets() -> void:
	var probe_path := "res://generated_assets/background.png"
	if not ResourceLoader.exists(probe_path):
		# Editor-convenience fallback only: an exported build ships with
		# generated_assets/ already baked in by build.sh.
		ProceduralArt.run_all()


func _unhandled_input(event: InputEvent) -> void:
	if not title_screen.visible or not _title_ready:
		return
	var touched: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if touched:
		_start_game()


func _start_game() -> void:
	if not _audio_unlocked:
		_audio_unlocked = true
		ProceduralAudio.unlock_audio()
	title_screen.visible = false


func _on_celebration(streak: int, is_new_best: bool, milestone: int) -> void:
	if not reveal:
		reveal = REVEAL_SCENE.instantiate()
		add_child(reveal)
		# The toast is authored at absolute offsets, so it would otherwise
		# sit left of centre on a phone in landscape.
		ViewportFit.apply_layer(reveal)
	reveal.play(streak, is_new_best, milestone)
