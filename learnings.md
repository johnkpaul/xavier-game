# Learnings: building Xavier's Snap Trap

A playbook for the birthdaycade game business, distilled from building this game
end-to-end — a browser game made for one specific 5-year-old, from first concept
through several mechanic pivots, an AI art integration, and real-device bug fixes.

## Mechanic design for young kids

- **One button beats two, every time.** The first real mechanic needed two buttons
  and constant judgment calls (grab vs. bank). Collapsing it to a single RUN button —
  with the core decision baked into *when* you tap, not *which* button — made the
  whole game instantly legible to a 5-year-old.
- **Hidden randomness feels rigged; visible rhythms feel fair.** An early version used
  a hidden per-round timer to decide when danger struck — mathematically sound, but it
  *felt* like bad luck when a kid got caught. Switching to a fixed, watchable pattern
  (a danger cycles open/closed on a predictable beat) turned "I got unlucky" into "I
  can learn this," a much better feeling for a young kid, and it made the tutorial
  trivial ("watch it, then time your tap").
- **No permanent failure states.** Every version kept this: getting caught never shows
  a game-over screen, never loses progress, just resets the current streak and starts
  again immediately. Low cost of failure means a kid keeps playing instead of getting
  frustrated and quitting.
- **Celebrations should never gate play.** An early version paused the whole game and
  demanded a dismiss-tap to see a "nice job!" screen. Fixed it to a toast that fades
  in/out on its own while the game keeps running underneath — kids want to keep
  playing, not acknowledge trophies.
- **Sanity-check the actual math before shipping a risk/reward mechanic.** Working out
  the expected-value curve for one version's hold-your-nerve mechanic revealed that the
  title screen's own copy ("hold out as long as you dare") was steering players toward
  the statistically worst strategy. Cheap to catch with ten minutes of arithmetic,
  expensive to discover from a frustrated kid.

## Art pipeline

- **Default to procedural/code-generated art; spend real money only on the hero
  elements.** Background, buttons, and UI chrome stayed cheap, instant, code-drawn
  art. Only the character and the monster — the two things a kid actually looks at and
  bonds with — got real AI-generated art. Spend the art budget where eyes actually
  land.
- **Match the resolution across every sprite in a scene**, or upscale to match — mixing
  a 128px hero sprite with 64px animation-endpoint output looked inconsistent until
  normalized.
- **Test an AI-art vendor's quirks on one throwaway generation before committing to a
  batch.** The vendor used here silently forced a fixed camera angle regardless of
  prompt, and credits charged didn't match documented pricing (2x in practice). Both
  were cheap to discover with one small test call, expensive to discover after
  generating a whole asset set the wrong way.
- **Cheap trick:** an "animation" job derived from an already-generated sprite produced
  five consistent frames for a fraction of the cost of five separate generations — even
  at lower resolution, which upscaled fine since the source was already blocky pixel
  art.

## Process that actually caught real bugs

- **Real-device playtesting from the actual person the game is for is irreplaceable.**
  Every meaty bug this project hit — a character that visually wasn't moving, a hazard
  that was dangerous at the wrong moment, a button that silently stopped responding —
  only surfaced because a real kid/parent played it on a real phone. Code review alone
  misses these.
- **When a bug report doesn't match the code, suspect stale cache before suspecting the
  code.** One "bug" report was just a browser holding onto a build from minutes
  earlier. Always ship a cache-busting URL alongside a fix, and keep an on-screen
  version tag so "did you get the new build" is answerable at a glance.
- **Deterministic test harnesses catch what eyeballing misses.** For timing-sensitive
  logic, a throwaway scene that force-sets the internal clock to exact "should be
  safe" and "should be caught" moments and asserts the outcome catches bugs with
  certainty instead of "looks right to me."
- **The nastiest bug (a button randomly not responding) was a genuine platform
  gotcha, not a design issue:** the UI toolkit used here doesn't capture a touch
  gesture the way native mobile UI does — a release event landing even a few pixels
  outside a button (extremely common for a kid's touch) never reaches that button's
  input handler, leaving it permanently stuck. Worth remembering for *any* touch-button
  implementation: always handle release globally, matched by touch ID, never by
  screen position.

## For the birthdaycade format specifically

- **Personalize the one thing that matters, generically everything else.** The
  character's real appearance (hair, skin tone, described mannerisms) was worth
  getting right; the backdrop and UI chrome didn't need to be personal at all.
- **A deployed, shareable link — not a downloadable file — is the right delivery
  format.** The birthday kid can just open it on a phone, no install friction, and a
  fix can ship mid-party if something's off.
- **Scope to what a single mechanic can teach in one sentence.** Every pivot in this
  project was really a search for "what's the one-sentence rule a kid can hold in
  their head" — and each simplification made the game better, never worse.

## Reusing a scaffold forks the bugs too

The stuck-RUN-button fix in 23ca2b9 — the nastiest bug this project hit —
never made it back to `chip-game`, which had copied `touch_button.gd` from
the same shared scaffold. That game shipped with the identical bug for two
weeks: a button that permanently stopped responding whenever a finger lifted
a few pixels outside it, silently, with no error.

Nothing links the copies, so nothing catches this automatically. The cheap
standing habit is to **diff the shared scaffold files across every sibling
repo whenever picking a project back up** — `touch_button.gd`,
`procedural_audio.gd`, `viewport_fit.gd`, `procedural_font.gd`, and
`main.gd`'s generated-asset probe. Two of the bugs found in the August 2026
pass would have surfaced in thirty seconds that way.

Corollary: when a fix lands in a scaffold file, it isn't finished until the
siblings have it.

## The scaling contract (added in the 2026-08-03 polish pass)

- **`stretch/mode = "viewport"` was costing legibility for free.** It renders
  into a fixed buffer and downsamples, so on a high-density phone most of the
  detail in the text is thrown away before it reaches the screen.
  `canvas_items` renders at native device resolution — a one-word change in
  `project.godot` and the single biggest readability win available.
- **`stretch/aspect = "expand"` grows the *logical* viewport,** so a phone in
  landscape (~2.17:1) gives ~2340 logical units of width, not 1920. The whole
  gameplay world — trap, Xavier, both waiting spots, the 1920x1080 backdrop —
  was authored at absolute coordinates against 1920, so it all sat 210 units
  left of centre with bare clear-colour down the right hand edge. The title
  screen and the celebration toast had the same problem.
  `scripts/viewport_fit.gd` shifts the world and the authored canvases by
  `(viewport - design) / 2` and scales the backdrop to cover.
- **The HUD and Controls layers were already correctly anchored and had to be
  left alone** — shifting them too would have pulled the RUN button and the
  totals away from the edges they're anchored to. "Re-centre everything" is
  the wrong instinct; only authored-absolute canvases want it.
- **None of this is visible at desktop aspect ratios,** which is why it
  survived a whole project. A 1084x500 headless-Chrome window (2.17:1)
  surfaced all of it in one screenshot.

## `FileAccess.file_exists()` is the wrong way to probe for a generated asset

The stale-probe bug fixed in 9d7302b was only half fixed. In an *exported*
build the source `.png` files aren't shipped at all — they're converted to
imported `.ctex` resources — so `FileAccess.file_exists()` returns false for
every generated asset and the game silently regenerates its entire art set on
every single launch, on the device, before the title screen appears. Use
`ResourceLoader.exists()`, which understands the import remaps and answers
correctly in both the editor and an export.

This is the third distinct incarnation of this bug in the series. The failure
mode is always the same and always invisible: nothing errors, the game just
does a pile of pointless work at startup.

## Convert design units to device pixels before choosing any size

The design space is 1080 tall and an iPhone in landscape is ~390 CSS pixels
tall, so the scale factor is about **0.36**. The title screen's prologue —
"WATCH THE MOUTH, THEN TAP RUN TO DASH ACROSS!", which is the entire rule of
the game — was set at 36, i.e. **13 CSS pixels**. Anything carrying meaning
wants 44+; below ~14 CSS px is decoration, not text. This one calculation
predicts most "it's too small" complaints.

## Portrait is not a hypothetical

`display/window/handheld/orientation = "landscape"` binds a *native* app via
its manifest. A browser ignores it completely, and Godot's web export can't
lock orientation outside fullscreen — so a kid handed a phone in portrait
gets the real thing. With `expand`, portrait grows the logical viewport
*vertically* (measured: 1920x3840), so everything renders at roughly a
quarter size. Nothing errors and nothing clips; it's silently unreadable
with no hint that turning the phone would fix it.

A "turn your phone sideways" overlay is the honest fix. Two things to get
right: size it from the viewport rather than in design-space constants (or
it comes out microscopic too — the exact problem it exists to explain), and
test that it *hides* again on rotating back. An overlay stuck over a
perfectly playable game is much worse than the problem it was solving.


## Typography was the single biggest perceived-quality gap

Every label rendered in Godot's built-in fallback, **Open Sans SemiBold** - a
smooth corporate sans - on top of deliberately blocky pixel art. Nothing was
broken, so it never surfaced as a bug; it just made the game read as a
prototype, because the words and the world looked like they came from
different products. There was no `Theme` anywhere either, just ad-hoc
`theme_override_*` lines scattered through the scenes.

A 5x7 pixel font generated in code fixed it with no asset and no licensing.
The traps, all of which cost real time:

- **`fixed_size_scale_mode` must be set before the first cache entry
  exists**, or the font silently ignores `font_size` and renders everything
  at 7 pixels, with no error.
- **`root.theme`, `theme.set_font(name, type, font)` and
  `ThemeDB.fallback_font` all fail to reach a Label that lives under a
  `CanvasLayer`** - theme lookup walks the *Control* parent chain and a
  CanvasLayer isn't a Control. Only a per-node `add_theme_font_override`
  works. Verified all four in a test scene rather than guessing.
- **Bitmap fonts have no natural leading**, so wrapped lines collide until
  blank rows are baked into the descent.
- **A pixel font is visually bigger than Open Sans at the same nominal
  size.** The tutorial line - the one piece of text that teaches the game -
  started wrapping and collided with the streak counter above it.
  Re-screenshot every screen after a font swap; don't assume layouts hold.

## Text over artwork needs a plate

The streak counter and the tutorial line both sit directly on the trap,
which is a busy high-contrast creature, and light text on it was hard to
read. `Label` supports a `normal` StyleBox, so the dark plate can be part of
the label itself rather than a separate node whose size and position would
have to be kept in sync.
## The loading screen was advertising Godot, not birthdaycade

For the whole ~38MB wasm download - by far the longest-lived screen in the
product, and the very first thing a kid sees - every game showed the Godot
robot and the words "Game engine". It is entirely replaceable, and the
mechanism is worth writing down because it is spread across three places:

- **`application/boot_splash/image`** is what the web export writes out as
  `index.png`, and the HTML shell references it as `src="index.png"`. Set
  this and the logo is gone. None of the games had it set, so all three
  inherited the engine default.
- **`application/boot_splash/bg_color`** feeds the `$GODOT_SPLASH_COLOR`
  placeholder, which colours the loading overlay behind the image.
- **`application/boot_splash/use_filter`** feeds `$GODOT_SPLASH_CLASSES`;
  `false` yields `use-filter--false`, which is `image-rendering: pixelated`.
  Essential for pixel art, otherwise the splash is smoothed as it scales.

Three traps:

- **Hardcoding a value where the template has a placeholder silently
  disconnects the project setting.** A shell copy here had a literal
  `#242424` where stock has `$GODOT_SPLASH_COLOR`, and literal splash
  classes where stock has `$GODOT_SPLASH_CLASSES` - so `bg_color` and
  `use_filter` were being ignored entirely.
- **Only a fixed set of `$GODOT_*` placeholders is substituted**:
  `CONFIG`, `HEAD_INCLUDE`, `PROJECT_NAME`, `SPLASH`, `SPLASH_CLASSES`,
  `SPLASH_COLOR`, `THREADS_ENABLED`, `URL`. Anything else ships as literal
  text. A shell here had invented `$GODOT_ICON32_PNG` /
  `$GODOT_ICON180_PNG`, which shipped verbatim into production - so the
  favicon and the add-to-home-screen icon were both broken links. Use
  `$GODOT_HEAD_INCLUDE`, which Godot fills with the correct icon tags.
- **The stock shell's bootstrap script is load-bearing** (feature
  detection, service-worker fallback, failure reporting). Patch its CSS;
  don't retype it.

**Capturing the loading screen needs network throttling.** Served from
localhost it is over in under 250ms, so an ordinary screenshot always lands
on the title screen and it looks like nothing changed. Drive it over CDP
with `Network.emulateNetworkConditions` (~10 Mbps) and shoot on a timer
*without* awaiting the load event.
