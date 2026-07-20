# Xavier's Snap Trap

A hold-your-nerve tap game for a 5-year-old: Xavier stands his ground in
front of a big friendly monster's mouth, and bravery points tick up for
every second he holds out. Tap the one and only button — **RUN** — before
the mouth snaps shut to bank those points. Wait too long and the mouth
catches him: no permanent penalty, just a silly "bonk" and a fresh round.
Built for Godot 4.2+, mobile web first. Every texture and sound is
generated in code — there are no imported art or audio files anywhere in
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
  button drives the RUN button exactly like a finger would.
- There is **no keyboard control scheme** — this is intentional. The game is touch-native,
  and the whole game is one big button: RUN.
- Run the project with F5 and click the big blue circle at the bottom of the window.

## The mechanic

Every round:
1. Xavier braces in front of the trap's mouth. Bravery points start ticking up
   (`Points: N`), and the risk meter/mouth color creep from green toward red the longer
   he holds out.
2. A hidden timer (randomized per round, never shown to the player — see
   `MIN_SNAP_TIME`/`MAX_SNAP_TIME` in `scripts/game.gd`) decides exactly when the mouth
   snaps shut. The player never knows precisely when it'll happen, only that it's getting
   more likely.
3. Tap **RUN** any time to bank the points earned so far into the permanent total.
4. If the mouth snaps before RUN is tapped, this round's points are discarded — a silly
   "bonk" animation plays and a new round starts immediately. No game-over screen, ever.

Two kinds of celebrations pop up (`scripts/reveal_screen.gd`): a **new bravery record**
whenever a banked round beats the best round so far, and a **milestone** every
`GameManager.MILESTONE_STEP` points banked in total. Both the snap-time range and the
milestone step are small, clearly-commented constants — tune them freely.

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
  game_manager.gd           Autoload: total points banked, best round, milestone progress
  procedural_audio.gd        Autoload: generates & plays all SFX/BGM
  procedural_art.gd          Generates every PNG into generated_assets/
  game.gd                     The hold-your-nerve loop itself: hidden snap timer, live
                               points ticking, run/snap animation, HUD updates
  touch_button.gd              Generic big touch/mouse button with press feedback
  reveal_screen.gd              New-record / milestone celebration overlay
  main.gd                        Title -> Game flow, asset bootstrap, audio unlock
build.sh / build.bat        Generate assets + export the Web build
export_presets.cfg          HTML5 "Web" export preset
```

## Design constraints (for future contributors)

- No imported art/audio files — everything is generated via `Image`/`AudioStreamWAV` APIs.
- No keyboard `InputMap` entries — touch (and mouse-as-touch for desktop testing) only.
- Exactly one button (RUN), 480×480px, labeled and iconed as clearly as possible — the
  whole point is that a 5-year-old should never wonder what to do or how to escape.
- Losing a round (the mouth snaps) never ends the game or shows a game-over screen — it
  just discards the current round's unbanked points and starts over immediately.
