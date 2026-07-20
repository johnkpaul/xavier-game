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

const HAIR_BLACK := Color8(0x18, 0x14, 0x12)
const SKIN := Color8(0xC8, 0x8E, 0x5E)
const SKIN_SHADE := Color8(0xA8, 0x72, 0x48)
const SHIRT_TEAL := Color8(0x2E, 0xC4, 0xB6)
const SHIRT_LIGHT := Color8(0x5C, 0xDE, 0xD2)
const SHORTS_NAVY := Color8(0x2A, 0x3A, 0x5C)
const CLOUD_WHITE := Color8(0xF5, 0xF5, 0xF5)
const VOID_BLACK := Color8(0x1A, 0x1A, 0x1A)
const STAR_YELLOW := Color8(0xFF, 0xD5, 0x4F)

const CREATURE_BASE := Color8(0xE6, 0xDE, 0xD4)
const CREATURE_OUTLINE := Color8(0x8A, 0x80, 0x74)
const MOUTH_INSIDE := Color8(0x8A, 0x24, 0x24)
const TONGUE_PINK := Color8(0xE0, 0x6E, 0x8A)
const SNAP_RED := Color8(0xD6, 0x3B, 0x33)
const SNAP_RED_DARK := Color8(0x9A, 0x22, 0x1E)

const SKY_BLUE := Color8(0x7E, 0xD6, 0xF2)
const SKY_LIGHT := Color8(0xC8, 0xEE, 0xFB)
const GRASS_GREEN := Color8(0x6A, 0xB8, 0x4A)
const GRASS_DARK := Color8(0x4E, 0x92, 0x36)
const SUN_YELLOW := Color8(0xFF, 0xE8, 0x7A)

const GRAB_GREEN := Color8(0x4C, 0xAF, 0x50)
const GRAB_GREEN_DARK := Color8(0x2E, 0x7D, 0x32)
const RUN_BLUE := Color8(0x42, 0xA5, 0xF5)
const RUN_BLUE_DARK := Color8(0x1E, 0x6F, 0xB0)

const TRANSPARENT := Color(0, 0, 0, 0)


func _initialize() -> void:
	run_all()
	quit()


static func run_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_make_xavier(0), "xavier_idle")
	_save(_make_xavier(1), "xavier_reach")
	_save(_make_xavier(2), "xavier_bonk")
	_save(_make_xavier(3), "xavier_cheer")

	_save(_make_trap_mouth_open(), "trap_mouth_open")
	_save(_make_trap_mouth_snap(), "trap_mouth_snap")

	_save(_make_treat(Color8(0xE5, 0x39, 0x35)), "treat_red")
	_save(_make_treat(Color8(0x42, 0xA5, 0xF5)), "treat_blue")
	_save(_make_treat(Color8(0xFF, 0xC1, 0x07)), "treat_yellow")

	_save(_make_background(), "background")

	_save(_make_button_base(GRAB_GREEN, GRAB_GREEN_DARK), "button_grab")
	_save(_make_button_base(RUN_BLUE, RUN_BLUE_DARK), "button_run")
	_save(_make_icon_hand(), "icon_hand")
	_save(_make_icon_run(), "icon_run")
	_save(_make_icon_treat(), "icon_treat_hud")

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


static func _fill_diamond(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	w *= SCALE
	h *= SCALE
	var minx := int(max(0, cx - w / 2.0))
	var maxx := int(min(img.get_width() - 1, cx + w / 2.0))
	var miny := int(max(0, cy - h / 2.0))
	var maxy := int(min(img.get_height() - 1, cy + h / 2.0))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = absf(px + 0.5 - cx) / (w / 2.0)
			var dy: float = absf(py + 0.5 - cy) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(px, py, color)


static func _fill_triangle_up(img: Image, x: float, y: float, w: float, h: float, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	var ih := int(h)
	for py in range(ih):
		var t := float(py) / float(ih - 1) if ih > 1 else 0.0
		var half_w := (t * w) / 2.0
		var cx := x + w / 2.0
		var minx := int(round(cx - half_w))
		var maxx := int(round(cx + half_w))
		for px in range(minx, maxx + 1):
			if px >= 0 and (y + py) >= 0 and px < img.get_width() and (y + py) < img.get_height():
				img.set_pixel(px, y + py, color)


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
# Xavier (40x48 logical). mode: 0=idle, 1=reach, 2=bonk, 3=cheer
# ---------------------------------------------------------------------------

static func _make_xavier(mode: int) -> Image:
	var img := _new_image(40, 48)
	var tilt := -2 if mode == 2 else 0

	# Shorts + feet (drawn first, body/head layer on top).
	_fill_rect(img, 13 + tilt, 40, 14, 6, SHORTS_NAVY)
	_fill_rect(img, 12 + tilt, 45, 6, 3, VOID_BLACK)
	_fill_rect(img, 22 + tilt, 45, 6, 3, VOID_BLACK)

	# Shirt.
	_fill_rect(img, 12 + tilt, 24, 16, 17, SHIRT_TEAL)
	_fill_rect(img, 12 + tilt, 24, 16, 3, SHIRT_LIGHT)

	# Arms, pose-dependent.
	match mode:
		1:
			# Reach: right arm stretched toward the trap, left arm at side.
			_fill_rect(img, 8 + tilt, 27, 4, 11, SKIN)
			_fill_rect(img, 27 + tilt, 22, 15, 5, SKIN)
		2:
			# Bonk: both arms flung up in surprise.
			_fill_rect(img, 3 + tilt, 18, 9, 5, SKIN)
			_fill_rect(img, 28 + tilt, 18, 9, 5, SKIN)
		3:
			# Cheer: both arms up in a V, triumphant.
			_fill_rect(img, 6 + tilt, 14, 5, 13, SKIN)
			_fill_rect(img, 29 + tilt, 14, 5, 13, SKIN)
		_:
			_fill_rect(img, 8 + tilt, 26, 4, 12, SKIN)
			_fill_rect(img, 28 + tilt, 26, 4, 12, SKIN)

	# Head.
	_fill_circle(img, 20 + tilt, 15, 9, SKIN)
	# Wavy black hair: a rounded mass on top plus a few bump "waves".
	_fill_circle(img, 20 + tilt, 10, 10, HAIR_BLACK)
	_fill_circle(img, 20 + tilt, 16, 8, SKIN)
	_fill_circle(img, 10 + tilt, 16, 3, HAIR_BLACK)
	_fill_circle(img, 30 + tilt, 16, 3, HAIR_BLACK)
	_fill_circle(img, 13 + tilt, 20, 2.5, HAIR_BLACK)
	_fill_circle(img, 27 + tilt, 20, 2.5, HAIR_BLACK)

	# Face.
	if mode == 2:
		# Dizzy X eyes + small stars orbiting the head.
		_draw_line(img, 15 + tilt, 14, 18 + tilt, 17, 0.8, VOID_BLACK)
		_draw_line(img, 18 + tilt, 14, 15 + tilt, 17, 0.8, VOID_BLACK)
		_draw_line(img, 22 + tilt, 14, 25 + tilt, 17, 0.8, VOID_BLACK)
		_draw_line(img, 25 + tilt, 14, 22 + tilt, 17, 0.8, VOID_BLACK)
		_draw_line(img, 16, 19, 24, 19, 0.8, SKIN_SHADE)
		_fill_diamond(img, 8, 4, 5, 5, STAR_YELLOW)
		_fill_diamond(img, 33, 6, 4, 4, STAR_YELLOW)
		_fill_diamond(img, 6, 12, 3.5, 3.5, STAR_YELLOW)
	else:
		_fill_rect(img, 16 + tilt, 14, 2, 2, VOID_BLACK)
		_fill_rect(img, 23 + tilt, 14, 2, 2, VOID_BLACK)
		if mode == 3:
			_draw_line(img, 15 + tilt, 19, 20 + tilt, 21, 1.0, VOID_BLACK)
			_draw_line(img, 20 + tilt, 21, 25 + tilt, 19, 1.0, VOID_BLACK)
		else:
			_draw_line(img, 16 + tilt, 19, 24 + tilt, 19, 0.8, SKIN_SHADE)

	return img


# ---------------------------------------------------------------------------
# The trap creature's mouth (200x170 logical). A light, near-neutral base
# so Sprite2D.modulate can tint the whole thing green->yellow->orange->red
# as risk rises without needing separate baked-color textures per state.
# ---------------------------------------------------------------------------

static func _make_trap_mouth_open() -> Image:
	var img := _new_image(200, 170)
	_fill_ellipse(img, 100, 92, 92, 70, CREATURE_BASE)
	_stroke_ellipse(img, 100, 92, 92, 70, 4, CREATURE_OUTLINE)

	# Eyes.
	_fill_circle(img, 62, 48, 14, CLOUD_WHITE)
	_fill_circle(img, 138, 48, 14, CLOUD_WHITE)
	_fill_circle(img, 62, 48, 6, VOID_BLACK)
	_fill_circle(img, 138, 48, 6, VOID_BLACK)

	# Mouth interior.
	_fill_ellipse(img, 100, 108, 72, 42, MOUTH_INSIDE)
	_fill_ellipse(img, 100, 124, 32, 15, TONGUE_PINK)

	# Teeth: upper row hanging down, lower row pointing up.
	for i in range(6):
		var tx := 48.0 + i * 21.0
		_fill_triangle_up(img, tx, 90, 12, 12, CLOUD_WHITE)
	for i in range(6):
		var bx := 48.0 + i * 21.0
		_fill_rect(img, bx, 128, 12, 8, CLOUD_WHITE)

	return img


static func _make_trap_mouth_snap() -> Image:
	var img := _new_image(200, 170)
	_fill_ellipse(img, 100, 92, 92, 70, SNAP_RED)
	_stroke_ellipse(img, 100, 92, 92, 70, 4, SNAP_RED_DARK)

	# Squeezed-shut eyes (happy-angry little arcs).
	_draw_line(img, 52, 46, 72, 50, 2.0, VOID_BLACK)
	_draw_line(img, 72, 46, 52, 50, 2.0, VOID_BLACK)
	_draw_line(img, 128, 46, 148, 50, 2.0, VOID_BLACK)
	_draw_line(img, 148, 46, 128, 50, 2.0, VOID_BLACK)

	# Closed mouth: a single dark line with a little tooth peeking out.
	_fill_rect(img, 40, 104, 120, 6, VOID_BLACK)
	_fill_rect(img, 96, 100, 10, 8, CLOUD_WHITE)

	# Impact burst around the mouth.
	var burst_pts := [
		Vector2(20, 92), Vector2(180, 92), Vector2(30, 60), Vector2(170, 60),
		Vector2(30, 130), Vector2(170, 130),
	]
	for p in burst_pts:
		_fill_diamond(img, p.x, p.y, 14, 14, STAR_YELLOW)

	return img


# ---------------------------------------------------------------------------
# Treat (20x20 logical) - simple candy gem, offered pre-colored in a few
# bright variants so each round's treat looks a little different.
# ---------------------------------------------------------------------------

static func _make_treat(color: Color) -> Image:
	var img := _new_image(20, 20)
	var c := 10.0
	_fill_diamond(img, c, c, 15, 17, color)
	_fill_diamond(img, c, c - 1.5, 8, 9, color.lightened(0.4))
	_stroke_ellipse(img, c, c, 7.5, 8.5, 1.5, color.darkened(0.35))
	return img


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


static func _make_icon_hand() -> Image:
	var img := _new_image(32, 32)
	_fill_rect(img, 9, 14, 16, 14, CLOUD_WHITE)
	_fill_rect(img, 9, 26, 16, 3, CLOUD_WHITE.darkened(0.1))
	for i in range(4):
		_fill_rect(img, 10 + i * 4, 3, 3, 13, CLOUD_WHITE)
	_fill_rect(img, 4, 16, 6, 4, CLOUD_WHITE)
	return img


static func _make_icon_run() -> Image:
	var img := _new_image(32, 32)
	_fill_triangle_rot90(img, 3, 8, 13, 16)
	_fill_triangle_rot90(img, 16, 8, 13, 16)
	return img


static func _fill_triangle_rot90(img: Image, x: float, y: float, h: float, w: float) -> void:
	# A triangle pointing right, used twice to form a ">>" run/forward icon.
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	var iw := int(w)
	for px in range(iw):
		var t := float(px) / float(iw - 1) if iw > 1 else 0.0
		var half_h := (t * h) / 2.0
		var cy := y + h / 2.0
		var miny := int(round(cy - half_h))
		var maxy := int(round(cy + half_h))
		for py in range(miny, maxy + 1):
			if (x + px) >= 0 and py >= 0 and (x + px) < img.get_width() and py < img.get_height():
				img.set_pixel(int(x + px), py, CLOUD_WHITE)


static func _make_icon_treat() -> Image:
	var img := _new_image(32, 32)
	_fill_diamond(img, 16, 16, 22, 25, CLOUD_WHITE)
	return img


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
