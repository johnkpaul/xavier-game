extends Node

## Autoload: persistent state that survives across rounds (total banked
## bravery points, best single-round score, milestone progress). The
## moment-to-moment hold-your-nerve timer lives in game.gd instead - this
## just remembers the score between plays.

signal total_changed(total: int)

const SAVE_PATH := "user://progress.save"

## Bumped by hand on every deploy so the on-screen build tag makes it
## obvious whether a device is showing a stale cached build.
const BUILD_VERSION := "2026-07-20.2"

## A reveal screen celebrates every MILESTONE_STEP points banked in total.
const MILESTONE_STEP := 50

var total_points := 0
var best_round := 0

## Highest milestone index already celebrated (0 = none yet), persisted so
## replaying the game doesn't re-show reveals already seen this session.
var milestones_seen := 0


func _ready() -> void:
	load_progress()


## Commits a round's bravery points to the permanent total. Returns a
## dictionary the caller (game.gd) uses to decide whether/how to celebrate:
## {"is_new_best": bool, "milestone": int} - milestone is the index just
## reached (> milestones_seen) or -1 if none was crossed this round.
func bank(round_points: int) -> Dictionary:
	if round_points <= 0:
		return {"is_new_best": false, "milestone": -1}

	var is_new_best: bool = round_points > best_round
	if is_new_best:
		best_round = round_points

	total_points += round_points
	total_changed.emit(total_points)

	var milestone := -1
	var reached: int = total_points / MILESTONE_STEP
	if reached > milestones_seen:
		milestones_seen = reached
		milestone = reached

	save_progress()
	return {"is_new_best": is_new_best, "milestone": milestone}


func reset_progress() -> void:
	total_points = 0
	best_round = 0
	milestones_seen = 0
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.trim_prefix("user://"))
	total_changed.emit(total_points)


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({
			"total_points": total_points,
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
		total_points = value.get("total_points", 0)
		best_round = value.get("best_round", 0)
		milestones_seen = value.get("milestones_seen", 0)
