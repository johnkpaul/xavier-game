extends Node

## Autoload: persistent state that survives across rounds (total banked
## treats, best single-round haul, milestone progress). The moment-to-moment
## push-your-luck logic (risk level, snap rolls) lives in game.gd instead -
## this just remembers the score between plays.

signal total_changed(total: int)

const SAVE_PATH := "user://progress.save"

## Bumped by hand on every deploy so the on-screen build tag makes it
## obvious whether a device is showing a stale cached build.
const BUILD_VERSION := "2026-07-20.1"

## A reveal screen celebrates every MILESTONE_STEP treats banked in total.
const MILESTONE_STEP := 10

var total_treats := 0
var best_round := 0

## Highest milestone index already celebrated (0 = none yet), persisted so
## replaying the game doesn't re-show reveals already seen this session.
var milestones_seen := 0


func _ready() -> void:
	load_progress()


## Commits a round's uncollected treats to the permanent total. Returns the
## milestone index just reached (> milestones_seen) if one was crossed, or
## -1 if not - the caller (game.gd) decides whether/how to celebrate it.
func bank(round_treats: int) -> int:
	if round_treats <= 0:
		return -1
	total_treats += round_treats
	best_round = maxi(best_round, round_treats)
	total_changed.emit(total_treats)
	save_progress()

	var reached: int = total_treats / MILESTONE_STEP
	if reached > milestones_seen:
		milestones_seen = reached
		save_progress()
		return reached
	return -1


func reset_progress() -> void:
	total_treats = 0
	best_round = 0
	milestones_seen = 0
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.trim_prefix("user://"))
	total_changed.emit(total_treats)


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({
			"total_treats": total_treats,
			"best_round": best_round,
			"milestones_seen": milestones_seen,
		})


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var value = f.get_var()
	if typeof(value) == TYPE_DICTIONARY:
		total_treats = value.get("total_treats", 0)
		best_round = value.get("best_round", 0)
		milestones_seen = value.get("milestones_seen", 0)
