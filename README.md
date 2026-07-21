# Xavier's Snap Trap

A dash-across tap game for a 5-year-old: a big friendly monster's mouth
opens and closes on a fixed, visible rhythm — never hidden, never random.
Xavier waits on one side; tap the one and only button — **RUN** — to send
him dashing to the other side. Time it with the mouth's pattern and he
makes it across safely, banking points and extending his streak. Mistime
it and he's caught mid-crossing, bounces back to where he started, and his
streak resets: no permanent penalty, just a silly "bonk" and another shot
at the rhythm. Built for Godot 4.2+, mobile web first. Every texture and
sound is generated in code, with one deliberate exception: Xavier's own
sprite is a real AI-generated image (via [Sprixen](https://sprixen.com))
checked into `imported_assets/` — see "Art pipeline" below.

## Opening in Godot

1. Install Godot 4.2 or later (the [Standard build](https://godotengine.org/download), not
   .NET/C# — this project is pure GDScript).
2. Open Godot, choose **Import**, and select the `project.godot` file in this folder.
3. On first open, Godot will import the project. Press **F5** (or the Play button) to run.
   `main.gd` automatically calls `ProceduralArt.run_all()` if `generated_assets/` is empty,
   so the very first run may take an extra second to generate all sprites before the title
   screen appears.

## Testing on desktop

Desktop testing uses your mouse as a stand-in for touch:

- `input_devices/pointing/emulate_touch_from_mouse` is enabled in `project.godot`, and
  `touch_button.gd` also listens for `InputEventMouseButton` directly, so the left mouse
  button drives the RUN button exactly like a finger would.
- There is **no keyboard control scheme** — this is intentional. The game is touch-native,
  and the whole game is one big button: RUN.
- Run the project with F5 and click the big blue circle at the bottom of the window.

## The mechanic

The trap's mouth cycles open → closed → open on a fixed, predictable rhythm
(`CYCLE_DURATION` in `scripts/game.gd`, a symmetric triangle wave — no RNG anywhere in
this mechanic). Xavier waits on one side, watching:

1. Tap **RUN** to send him dashing to the other side (`CROSS_DURATION`, ~1 second).
2. If the mouth is in its closed/dangerous phase while he's passing through the middle
   (`RISK_WINDOW_START`/`RISK_WINDOW_END`, the portion of the crossing where he's actually
   near the mouth), he's caught: knocked back to the side he started from, streak resets to
   0, no points. No game-over screen, ever - just try the rhythm again.
3. If he makes it across, that crossing banks `CROSSING_POINTS` into the permanent total
   and extends his current streak (`Streak: N` in the HUD) - then he's ready to dash back
   the other way on the next tap.

Two kinds of celebrations pop up (`scripts/reveal_screen.gd`): a **new best streak**
whenever the current streak beats the all-time best, and a **milestone** every
`GameManager.MILESTONE_STEP` points banked in total. The cycle timing, risk window, and
milestone step are all small, clearly-commented constants — tune them freely.

## Exporting for mobile web

1. In the Godot editor, open **Project > Export…**. The `export_presets.cfg` in this repo
   already defines a **Web** preset (HTML5, canvas resizes to fill the browser window,
   headless export). You'll need the Godot **Web export templates** installed (Editor >
   Manage Export Templates).
2. Either export from the editor UI, or run the automation script from a terminal:
   - macOS/Linux: `./build.sh`
   - Windows: `build.bat`
   Both scripts (a) regenerate `generated_assets/` via
   `godot --headless --script scripts/procedural_art.gd`, then (b) export the "Web" preset
   to `build/web/index.html`. Set `GODOT_BIN` if `godot` isn't on your `PATH`.
3. Serve `build/web/` over HTTP (opening `index.html` via `file://` will not work — browsers
   block the WASM/threading requirements). Locally: `cd build/web && python3 -m http.server`.

### Mobile audio note

Browsers block audio playback until the user interacts with the page. `main.gd` calls
`ProceduralAudio.unlock_audio()` on the first tap on the title screen, which plays a
near-silent buffer to wake the browser's audio context before the background music starts.

## Project layout

```
project.godot              Window/stretch/input config, autoloads
default_bus_layout.tres    Master/SFX/BGM audio buses
imported_assets/           Real (non-procedural) art - currently just xavier_sprite.png
scenes/                    All .tscn scene files
scripts/
  game_manager.gd           Autoload: total points banked, best streak, milestone progress
  procedural_audio.gd        Autoload: generates & plays all SFX/BGM
  procedural_art.gd          Generates every other PNG into generated_assets/
  game.gd                     The dash-across loop itself: mouth cycle timing, crossing/
                               catch detection, run/bonk/cheer animation, HUD updates
  touch_button.gd              Generic big touch/mouse button with press feedback
  reveal_screen.gd              New-record / milestone celebration overlay
  main.gd                        Title -> Game flow, asset bootstrap, audio unlock
build.sh / build.bat        Generate assets + export the Web build
export_presets.cfg          HTML5 "Web" export preset
```

## Art pipeline

Xavier and the trap creature are real images from [Sprixen](https://sprixen.com), an AI
sprite generator, checked into `imported_assets/` — **not** regenerated by
`procedural_art.gd`, which now only draws the background, buttons, icons, and UI meter
into the git-ignored `generated_assets/`.

- `xavier_sprite.png` - a single side-profile bracing pose. There's no separate
  bonk/cheer artwork; those states are conveyed with code-driven tweens instead
  (`_play_bonk()` / `_play_cheer()` in `game.gd`: a knockback + red flash, or a hop + gold
  flash), so a new reaction never needs new art.
- `trap_stage0.png` … `trap_stage4.png` - a 5-frame mouth-closing flipbook, generated as
  one cheap job (`POST /v1/sprites/:spriteId/animations`, `type: custom`) against an
  already-generated base sprite, rather than five separate generations. Swapped by
  `game.gd` as the mouth cycle's danger level rises - see `TRAP_MOUTH_FRAMES`.
- `trap_bite.png` - a dedicated full-resolution "caught you" frame for the instant the
  mouth actually snaps shut, generated separately (the animation endpoint only returns
  images at the *project's* base resolution - 64×64 here - so it was upscaled with
  nearest-neighbor to 128×128 to match the other frames; the bite frame instead used a
  full `/v1/generations` call to get real 128×128 detail for that one dramatic beat).

The trap's real art carries its own color, so `game.gd` no longer applies the old
green→red `modulate` tint to the creature itself (that trick only worked because the
procedural version was drawn in a near-white base specifically so tinting it read
cleanly - tinting real colored art the same way just muddies it). The risk meter still
uses the same color ramp.

If you regenerate or replace either sprite, note two API quirks we hit: (1) Sprixen
forces a "side-scroller" camera angle unless you explicitly request
`viewAngle: front_facing` at the *project* level (`POST /v1/projects`) - the
per-generation prompt alone can't override it; (2) a generation must include a
`projectId` to ever be usable as the base for an `/animations` call later - a sprite
generated without one can never be promoted or animated.

## Design constraints (for future contributors)

- Everything is generated via `Image`/`AudioStreamWAV` APIs, except Xavier's and the
  trap's sprites (see "Art pipeline" above) - that's a deliberate, documented exception,
  not an oversight.
- No keyboard `InputMap` entries — touch (and mouse-as-touch for desktop testing) only.
- Exactly one button (RUN), 480×480px, labeled and iconed as clearly as possible — the
  whole point is that a 5-year-old should never wonder what to do or how to escape.
- The mouth's timing is always visible and predictable, never hidden or randomized -
  learnable pattern-reading, not a hidden-timer gamble.
- Getting caught never ends the game or shows a game-over screen — it just bounces Xavier
  back to the side he started from and resets the current streak.
