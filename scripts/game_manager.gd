extends Node

## Autoload: persistent state that survives across plays (total bravery
## points banked, best-ever crossing streak, milestone progress). The
## moment-to-moment crossing/timing logic lives in game.gd instead - this
## just remembers the score between plays.

signal total_changed(total: int)

const SAVE_PATH := "user://progress.save"

## Bumped by hand on every deploy so the on-screen build tag makes it
## obvious whether a device is showing a stale cached build.
const BUILD_VERSION := "2026-08-04.2"

## A reveal screen celebrates every MILESTONE_STEP points banked in total.
const MILESTONE_STEP := 50

var total_points := 0

## Longest run of successful crossings in a row, ever. Unlike total_points,
## the in-progress current streak lives in game.gd (it resets on a catch and
## isn't meaningful to persist mid-run) - this only remembers the record.
var best_streak := 0

## Highest milestone index already celebrated (0 = none yet), persisted so
## replaying the game doesn't re-show reveals already seen this session.
var milestones_seen := 0

## Whether the first-time guided walkthrough (slow mouth cycle + arrow
## pointing at RUN) has already played. Persisted so it only ever shows
## once per player, not once per session.
var has_seen_tutorial := false


func _ready() -> void:
	load_progress()


## Records one successful crossing: adds its points to the permanent total
## and checks the current streak against the all-time best. Returns a
## dictionary the caller (game.gd) uses to decide whether/how to celebrate:
## {"is_new_best": bool, "milestone": int} - milestone is the index just
## reached (> milestones_seen) or -1 if none was crossed this time.
func record_crossing(points: int, current_streak: int) -> Dictionary:
	var is_new_best: bool = current_streak > best_streak
	if is_new_best:
		best_streak = current_streak

	total_points += points
	total_changed.emit(total_points)

	var milestone := -1
	var reached: int = total_points / MILESTONE_STEP
	if reached > milestones_seen:
		milestones_seen = reached
		milestone = reached

	save_progress()
	return {"is_new_best": is_new_best, "milestone": milestone}


func mark_tutorial_seen() -> void:
	if not has_seen_tutorial:
		has_seen_tutorial = true
		save_progress()


func reset_progress() -> void:
	total_points = 0
	best_streak = 0
	milestones_seen = 0
	has_seen_tutorial = false
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
			"best_streak": best_streak,
			"milestones_seen": milestones_seen,
			"has_seen_tutorial": has_seen_tutorial,
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
		best_streak = value.get("best_streak", 0)
		milestones_seen = value.get("milestones_seen", 0)
		has_seen_tutorial = value.get("has_seen_tutorial", false)
