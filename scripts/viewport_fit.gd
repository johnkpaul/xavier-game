extends Node
class_name ViewportFit

## Keeps content that was authored against a fixed design resolution looking
## right on a real device.
##
## The project uses stretch/aspect = "expand", which grows the *logical*
## viewport on any screen wider than the 16:9 design aspect. A phone held in
## landscape is roughly 2.17:1, so the logical space becomes ~2340 wide
## rather than 1920. Anything positioned with absolute coordinates against
## an assumed 1920 then sits left of centre with a dead strip down the right
## hand side - and it is invisible at desktop aspect ratios, which is why it
## survives casual testing.
##
## Two kinds of content need fixing here, and they need different treatment:
##
##   * The gameplay world (a Node2D holding the trap, Xavier and the
##     backdrop at absolute world coordinates) is shifted so the whole
##     composition re-centres, and its background sprite is scaled up to
##     cover the wider screen instead of leaving bare clear-colour down one
##     side.
##   * An authored UI canvas (the title screen, the celebration toast) is a
##     CanvasLayer, which gets the same shift via its `offset`, plus a
##     backdrop stretched to the true viewport.
##
## This runs as a child node rather than as a bare static helper so the
## size_changed connection has a real owner and is torn down automatically
## with the thing it updates. A lambda connected by a static function would
## outlive its target.

const DESIGN_SIZE := Vector2(1920, 1080)

var _layer: CanvasLayer
var _world: Node2D
var _backdrop: Control
var _cover_sprite: Sprite2D


## For a CanvasLayer authored with absolute offsets. `backdrop` is stretched
## to cover the real viewport.
static func apply_layer(layer: CanvasLayer, backdrop: Control = null) -> ViewportFit:
	var fit := ViewportFit.new()
	fit.name = "ViewportFit"
	fit._layer = layer
	fit._backdrop = backdrop
	layer.add_child(fit)
	return fit


## For the gameplay world. `cover_sprite` is scaled to cover the viewport
## while keeping its aspect.
static func apply_world(world: Node2D, cover_sprite: Sprite2D = null) -> ViewportFit:
	var fit := ViewportFit.new()
	fit.name = "ViewportFit"
	fit._world = world
	fit._cover_sprite = cover_sprite
	world.add_child(fit)
	return fit


func _ready() -> void:
	get_viewport().size_changed.connect(_refit)
	_refit()
	# The first layout pass may not have settled when _ready runs, so
	# re-apply once it has.
	call_deferred("_refit")


func _refit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var shift := (vp - DESIGN_SIZE) / 2.0

	if is_instance_valid(_layer):
		_layer.offset = shift
		if is_instance_valid(_backdrop):
			# Undo the shift so the backdrop still starts at the true
			# top-left of the screen, then span the whole real viewport.
			_backdrop.position = -shift
			_backdrop.size = vp

	if is_instance_valid(_world):
		_world.position = shift
		if is_instance_valid(_cover_sprite):
			# The sprite sits at the design-space centre, which - once the
			# world is shifted - is exactly the screen centre, so only its
			# scale needs to change. Cover rather than stretch so the art
			# keeps its aspect instead of smearing.
			var tex := _cover_sprite.texture
			if tex:
				var factor: float = maxf(
					vp.x / float(tex.get_width()),
					vp.y / float(tex.get_height())
				)
				_cover_sprite.scale = Vector2(factor, factor)
