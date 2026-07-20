extends Node
class_name Main

## Root of the game: title screen -> Snap Trap gameplay, forever (there are
## no discrete levels here - the game is one continuous push-your-luck loop
## with celebration screens popping in at treat milestones).

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

	game = GAME_SCENE.instantiate()
	game_container.add_child(game)
	game.milestone_reached.connect(_on_milestone_reached)

	title_screen.visible = true
	_title_ready = false
	await get_tree().create_timer(TITLE_MIN_DURATION).timeout
	_title_ready = true


func _ensure_generated_assets() -> void:
	var probe_path := "res://generated_assets/xavier_idle.png"
	if not FileAccess.file_exists(probe_path):
		# Editor-convenience fallback only: an exported HTML5 build ships
		# with generated_assets/ already baked in by build.sh.
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


func _on_milestone_reached(index: int) -> void:
	if not reveal:
		reveal = REVEAL_SCENE.instantiate()
		add_child(reveal)
		reveal.reveal_complete.connect(func(): game.start_new_round())
	reveal.play(index)
