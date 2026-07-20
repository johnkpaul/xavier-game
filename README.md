# Xavier's Snap Trap

A push-your-luck tap game for a 5-year-old: grab treats from a big friendly
monster's mouth one at a time, and decide each round whether to run away
with what you've got or grab one more. Grab too many and the mouth snaps
shut — you lose that round's treats (never anything permanent) and start a
fresh round. Built for Godot 4.2+, mobile web first. Every texture and sound
is generated in code — there are no imported art or audio files anywhere in
this project.

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
  button drives the GRAB/RUN buttons exactly like a finger would.
- There is **no keyboard control scheme** — this is intentional. The game is touch-native,
  and the whole mechanic is two big buttons: GRAB and RUN.
- Run the project with F5 and click the big green/blue circles at the bottom of the window.

## The mechanic

Every round:
1. A treat appears in the monster's mouth.
2. Tap **GRAB** to take it — your "in hand" count goes up, but so does the risk the mouth
   snaps shut on the *next* grab (see `SNAP_CHANCES` in `scripts/game.gd`).
3. Tap **RUN** any time to bank everything you're holding into your permanent treat total.
4. If the mouth snaps before you run, you lose that round's unbanked treats — a silly
   "bonk" animation plays and a new round starts immediately. No game-over screen, ever.

Every 10 treats banked in total triggers a full-screen celebration
(`scripts/reveal_screen.gd`). The snap-chance table, milestone step, and celebration
messages are all small, clearly-commented constants — tune them freely.

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
scenes/                    All .tscn scene files
scripts/
  game_manager.gd           Autoload: total treats banked, milestone progress, save/load
  procedural_audio.gd        Autoload: generates & plays all SFX/BGM
  procedural_art.gd          Generates every PNG into generated_assets/
  game.gd                     The push-your-luck loop itself: risk level, snap rolls,
                               grab/bank/snap animation, HUD updates
  touch_button.gd              Generic big touch/mouse button with press feedback
  reveal_screen.gd              Milestone celebration overlay
  main.gd                        Title -> Game flow, asset bootstrap, audio unlock
build.sh / build.bat        Generate assets + export the Web build
export_presets.cfg          HTML5 "Web" export preset
```

## Design constraints (for future contributors)

- No imported art/audio files — everything is generated via `Image`/`AudioStreamWAV` APIs.
- No keyboard `InputMap` entries — touch (and mouse-as-touch for desktop testing) only.
- Two buttons total (GRAB, RUN), each 400×400px — deliberately simpler than a joystick
  scheme since this game is for a 5-year-old, not an 8-year-old.
- Losing a round (the mouth snaps) never ends the game or shows a game-over screen — it
  just resets the current round's unbanked treats and starts over immediately.
