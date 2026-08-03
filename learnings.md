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
