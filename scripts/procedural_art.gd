extends SceneTree
class_name ProceduralArt

## Generates every game texture at runtime/editor-time and saves PNGs to
## res://generated_assets/. Callable two ways:
##   1. Headless CLI: `godot --headless --path . --script scripts/procedural_art.gd`
##      (this script is the SceneTree main loop; _initialize() runs run_all() then quits)
##   2. From game code: `ProceduralArt.run_all()` (pure static call, no instancing needed)

const OUT_DIR := "res://generated_assets/"

## Everything below is drawn in "logical" pixel-art coordinates; the
## primitive draw helpers transparently multiply by SCALE before touching
## real pixels, so a bigger SCALE means finer edges on high-DPI phones
## without redrawing anything by hand.
const SCALE := 4

const CLOUD_WHITE := Color8(0xF5, 0xF5, 0xF5)
const VOID_BLACK := Color8(0x1A, 0x1A, 0x1A)
const STAR_YELLOW := Color8(0xFF, 0xD5, 0x4F)

const CREATURE_OUTLINE := Color8(0x8A, 0x80, 0x74)

const SKY_BLUE := Color8(0x7E, 0xD6, 0xF2)
const SKY_LIGHT := Color8(0xC8, 0xEE, 0xFB)
const GRASS_GREEN := Color8(0x6A, 0xB8, 0x4A)
const GRASS_DARK := Color8(0x4E, 0x92, 0x36)
const SUN_YELLOW := Color8(0xFF, 0xE8, 0x7A)

const RUN_BLUE := Color8(0x42, 0xA5, 0xF5)
const RUN_BLUE_DARK := Color8(0x1E, 0x6F, 0xB0)

const TRANSPARENT := Color(0, 0, 0, 0)


func _initialize() -> void:
	run_all()
	quit()


static func run_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Xavier and the trap creature are no longer procedural - see
	# res://imported_assets/ for their real Sprixen-generated sprites (a
	# deliberate, documented exception to "everything is code-generated";
	# see README).

	_save(_make_background(), "background")

	_save(_make_button_base(RUN_BLUE, RUN_BLUE_DARK), "button_run")
	_save(_make_icon_run(), "icon_run")
	_save(_make_icon_point_down(), "icon_point_down")

	_save(_make_meter_frame(), "ui_meter_frame")
	_save(_make_meter_fill(), "ui_meter_fill")

	print("ProceduralArt: all textures generated in ", OUT_DIR)


static func _save(img: Image, name: String) -> void:
	var path := OUT_DIR + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("ProceduralArt: failed to save %s (err %d)" % [path, err])


# ---------------------------------------------------------------------------
# Draw primitives (logical-pixel coordinates, auto-scaled)
# ---------------------------------------------------------------------------

static func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


static func _fill_rect(img: Image, x: float, y: float, w: float, h: float, color: Color) -> void:
	var ix := int(x * SCALE)
	var iy := int(y * SCALE)
	var iw := int(w * SCALE)
	var ih := int(h * SCALE)
	for py in range(iy, iy + ih):
		for px in range(ix, ix + iw):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, color)


static func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	_fill_ellipse(img, cx, cy, r, r, color)


static func _stroke_circle(img: Image, cx: float, cy: float, r: float, thickness: float, color: Color) -> void:
	_stroke_ellipse(img, cx, cy, r, r, thickness, color)


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	rx *= SCALE
	ry *= SCALE
	var minx := int(max(0, cx - rx))
	var maxx := int(min(img.get_width() - 1, cx + rx))
	var miny := int(max(0, cy - ry))
	var maxy := int(min(img.get_height() - 1, cy + ry))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = (px + 0.5 - cx) / rx
			var dy: float = (py + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, color)


static func _stroke_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, thickness: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	rx *= SCALE
	ry *= SCALE
	thickness *= SCALE
	var minx := int(max(0, cx - rx - 1))
	var maxx := int(min(img.get_width() - 1, cx + rx + 1))
	var miny := int(max(0, cy - ry - 1))
	var maxy := int(min(img.get_height() - 1, cy + ry + 1))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = (px + 0.5 - cx) / rx
			var dy: float = (py + 0.5 - cy) / ry
			var d: float = dx * dx + dy * dy
			var edge: float = thickness / max(rx, ry)
			if d <= 1.0 and d >= (1.0 - edge) * (1.0 - edge):
				img.set_pixel(px, py, color)


static func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, thickness: float, color: Color) -> void:
	x0 *= SCALE
	y0 *= SCALE
	x1 *= SCALE
	y1 *= SCALE
	thickness *= SCALE
	var dist := Vector2(x0, y0).distance_to(Vector2(x1, y1))
	var steps := int(maxi(1, ceili(dist)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := lerpf(x0, x1, t)
		var py := lerpf(y0, y1, t)
		var r := thickness / 2.0
		for oy in range(-ceili(r), ceili(r) + 1):
			for ox in range(-ceili(r), ceili(r) + 1):
				if Vector2(ox, oy).length() <= r:
					var ix := int(px) + ox
					var iy := int(py) + oy
					if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
						img.set_pixel(ix, iy, color)


# ---------------------------------------------------------------------------
# Background (480x270 logical) - sunny yard: sky, sun, clouds, grass.
# ---------------------------------------------------------------------------

static func _make_background() -> Image:
	var img := _new_image(480, 270)
	var h := img.get_height()
	var w := img.get_width()
	var horizon := int(h / SCALE * 0.62)
	for y in range(h / SCALE):
		var col: Color
		if y < horizon:
			var t := float(y) / float(maxi(horizon - 1, 1))
			col = SKY_LIGHT.lerp(SKY_BLUE, t)
		else:
			var t2 := float(y - horizon) / float(maxi((h / SCALE) - horizon - 1, 1))
			col = GRASS_GREEN.lerp(GRASS_DARK, t2)
		for x in range(w / SCALE):
			for sy in range(SCALE):
				for sx in range(SCALE):
					img.set_pixel(x * SCALE + sx, y * SCALE + sy, col)

	_fill_circle(img, 400, 50, 32, SUN_YELLOW)
	_fill_cloud(img, 90, 55, 60, 26)
	_fill_cloud(img, 260, 35, 46, 20)
	return img


static func _fill_cloud(img: Image, x: float, y: float, w: float, h: float) -> void:
	_fill_circle(img, x - w * 0.25, y, h * 0.4, CLOUD_WHITE)
	_fill_circle(img, x, y - h * 0.15, h * 0.5, CLOUD_WHITE)
	_fill_circle(img, x + w * 0.25, y, h * 0.4, CLOUD_WHITE)
	_fill_rect(img, x - w * 0.35, y, w * 0.7, h * 0.35, CLOUD_WHITE)


# ---------------------------------------------------------------------------
# Buttons (100x100 logical, same footprint as touch_button expects).
# ---------------------------------------------------------------------------

static func _make_button_base(fill_color: Color, outline_color: Color) -> Image:
	var img := _new_image(100, 100)
	var c := 50.0
	var fill := fill_color
	fill.a = 0.9
	_fill_circle(img, c, c, 48, fill)
	_stroke_circle(img, c, c, 48, 5, outline_color)
	return img


## A running stick figure, drawn mid-stride (leaning forward, one leg
## kicked back, arms pumping) - the only control in the whole game, so it
## needs to read as "escape!" instantly rather than needing an arrow or
## chevron to be interpreted as "go".
static func _make_icon_run() -> Image:
	var img := _new_image(32, 32)
	const T := 3.2
	# Speed lines trailing behind (to the left) reinforce "moving fast" even
	# before the pose itself is parsed.
	_draw_line(img, 1, 14, 7, 14, 1.8, CLOUD_WHITE)
	_draw_line(img, 0, 19, 6, 19, 1.8, CLOUD_WHITE)
	_draw_line(img, 2, 24, 8, 24, 1.8, CLOUD_WHITE)
	_fill_circle(img, 21, 6, 3.4, CLOUD_WHITE)
	_draw_line(img, 19, 9, 13, 17, T, CLOUD_WHITE)
	_draw_line(img, 13, 17, 19, 25, T, CLOUD_WHITE)
	_draw_line(img, 13, 17, 5, 21, T, CLOUD_WHITE)
	_draw_line(img, 16, 12, 24, 10, T, CLOUD_WHITE)
	_draw_line(img, 16, 14, 8, 12, T, CLOUD_WHITE)
	return img


## A bouncing down-pointing arrow used only during the first-time guided
## walkthrough, to point at the RUN button unmistakably.
static func _make_icon_point_down() -> Image:
	var img := _new_image(32, 32)
	_fill_triangle_down(img, 2, 2, 28, 20, STAR_YELLOW)
	_fill_rect(img, 11, 22, 10, 8, STAR_YELLOW)
	return img


static func _fill_triangle_down(img: Image, x: float, y: float, w: float, h: float, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	var ih := int(h)
	for py in range(ih):
		var t := float(py) / float(ih - 1) if ih > 1 else 0.0
		var half_w := ((1.0 - t) * w) / 2.0
		var cx := x + w / 2.0
		var minx := int(round(cx - half_w))
		var maxx := int(round(cx + half_w))
		for px in range(minx, maxx + 1):
			if px >= 0 and (y + py) >= 0 and px < img.get_width() and (y + py) < img.get_height():
				img.set_pixel(px, y + py, color)


# ---------------------------------------------------------------------------
# UI meter (risk bar): near-white fill so it can be tinted at runtime with
# the same green->red ramp as the trap's mouth.
# ---------------------------------------------------------------------------

static func _make_meter_frame() -> Image:
	var img := _new_image(128, 16)
	_fill_rect(img, 0, 0, 128, 16, CREATURE_OUTLINE)
	_fill_rect(img, 2, 2, 124, 12, VOID_BLACK)
	return img


static func _make_meter_fill() -> Image:
	var img := _new_image(124, 12)
	_fill_rect(img, 0, 0, 124, 12, CLOUD_WHITE)
	return img
