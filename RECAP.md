# Session Recap — 2026-08-14/15, branch `splash-starfield-background`

Working from the Claude-Design wireframe handoff in `design_handoff_musicmatchup/`
(read `README.md` there for the full original spec — home graph, triage queue,
constellation-at-scale, search flow). This file is about **what actually
happened this session** and what's queued next — CLAUDE.md is still the
stable project reference, update that separately once things settle.

Nothing is committed yet. All changes below are in the working tree on
`splash-starfield-background`.

## What got built

1. **Triage queue redesign** (`ListenQueueView.swift`) — full-bleed swipeable
   card stack replacing the old 3-button inline banner. Dot progress up top,
   card capped at 320×420pt (not stretched full-screen), ✕ (pass, muted red)
   / ✓ (add, green) only — no third Save button (deferred to a future
   long-press-to-pin on settled nodes). Drag is horizontal-dominant (vertical
   dampened to 15%) with direction hints visible at rest, not just mid-drag.

2. **Search bottom sheet** (`ContentView.swift`) — graph is now the permanent
   home screen, no separate splash/search screen. Bottom-docked
   "Search or explore ▾" pill opens a Maps-style `.sheet` with
   `.presentationDetents`, reusing the existing library/curated/live-search
   dropdown (`ArtistSuggestionsList`).

3. **Parallax starfield** (`StarfieldBackgroundView.swift`) — rewritten from
   one static baked layer to 3 depth layers with independent slow drift via
   `TimelineView`. Runs everywhere the starfield shows, not just the empty
   state.

4. **Empty-sky state** (`ContentView.swift` — `EmptyGalaxySkyView`,
   `SuggestionStarView`) — true first-run (or any instant `sim.nodes` is
   empty) shows a breathing "proto-star" at center plus 5-8 scattered
   dashed-border "suggestion stars" pulled from `store.libraryArtists`
   (recently-added, falls back to `curatedArtists`). Tapping one ignites a
   New Galaxy directly, skipping the search sheet. Copy: "Your sky is
   empty — search an artist, or pick one below to begin."
   - Note: MusicKit has **no reliable recently-played or play-count signal
     for `Artist`** — `MusicRecentlyPlayedRequest` only covers Album/
     Playlist/Station. True "most played" would need `MPMediaQuery`
     (MediaPlayer framework, on-device-library-only). That's roadmap item 8
     in CLAUDE.md, not something to casually bolt on here.

5. **Seed confirmation beat** (`GraphCanvasView.swift` — `SeedConfirmationView`,
   `ForceSimulation.seedConfirmationID`) — after every `load()`, before the
   triage queue takes over, a short "Starting from [Artist]" card plays the
   *seed's own* preview and holds for ~3.5s (or tap/Continue to skip).
   Fixes a real confusion: previously the first thing to auto-play after a
   search was a related *neighbor* artist (seed is structurally excluded
   from the triage queue — see CLAUDE.md's Listen Mode section), not the
   artist actually searched. This is explicitly framed as **beat one** of a
   longer arc: seed confirmation → triage queue → per-decision feedback
   (not yet built) → arrival ceremony (not yet built, already speced in
   CLAUDE.md's Home Graph → 2b).

## Bugs found (from your screenshots/video) and fixed

- Search pill + sidebar toggle were rendered as a `ContentView`-level
  overlay on top of the *entire* `GraphCanvasView`, so they visually
  collided with the triage queue's own bottom buttons. Now hidden during
  any "modal moment" (triage queue or seed confirmation).
- `ContentView` held `sim` as plain `@State` instead of `@StateObject` —
  meant it wasn't actually subscribed to `ForceSimulation`'s `@Published`
  changes, so the pill-hiding fix above wouldn't have been reactive.
  Switched to `@StateObject`.
- Triage cards were sized via `Spacer()`-sandwiching, which let them
  greedily fill all available vertical space instead of honoring a real
  inset — fixed with a fixed `maxWidth: 320, maxHeight: 420` frame.
- Suggestion-star labels truncated mid-word ("Kendrick L…") — widened the
  label frame + added `minimumScaleFactor`.

## Environment gotcha worth remembering

**Xcode 27 renamed `Simulator.app` to `DeviceHub.app`** (bundle ID
`com.apple.dt.Devices`, lives at `Contents/Applications/DeviceHub.app`, not
the old `Contents/Developer/Applications/Simulator.app` path). The
`mcp__Claude_Code_iOS_Simulator__control` tool doesn't know about this yet
and crash-loops on `attach`/`screenshot` regardless of `xcode-select` being
correct. Confirmed this isn't a corrupt install — Xcode itself is fine
(8GB+ of platform runtimes installed, builds succeed, DeviceHub opens fine
manually). Fallback used this session: headless `xcrun simctl`
install/launch/screenshot for static verification; no way found yet to
send taps/text without a working panel or `idb` (not installed). Static
screenshots were enough to catch the real bugs above, but interactive
verification (drag gestures, animations, audio) still needs your own
Run-button testing in Xcode.

Also noted in passing: the app's real `CFBundleIdentifier` is
`MusicMatchupApp`, not `dbrock.MusicMatchup` as CLAUDE.md currently states
— small doc drift, not urgent.

## Open items for next session

1. **Audio — resolve, likely a non-issue.** Clarified this session: the
   "no audio" report was from an old local build (pre-dates everything
   above) shown to a friend, and separately the screen recording itself
   has no captured sound (Simulator screen recordings don't capture audio).
   Live audio on the current build hasn't actually been confirmed bad by
   either of you — just needs a real check with the latest build.
2. **Per-decision feedback** on triage pass/add — some
   action/element/haptic confirming a node is being added or removed, per
   your "word salad" timeline. Natural predecessor to the arrival ceremony.
3. **Arrival ceremony** (CLAUDE.md Home Graph → 2b, already speced but not
   built) — dashed placeholder star travels inward from off-node position,
   connects with a line to its source, settles into full opacity/solid
   border. One-shot per node (`hasArrived` flag). The dashed/solid language
   is already reused by the empty-sky suggestion stars this session, so
   there's now real visual continuity to land this on.
4. **Tier + halo deep-field layout** — still not started. Last standing
   decision on this: blend a radial-tier bias force into the existing
   organic physics (`ForceSimulation`'s repulsion/spring/gravity tick)
   rather than replacing it with computed positions — keeps the jitter,
   avoids a `load()`/`expand()` rewrite. Biggest architectural lift of
   everything on this list; sequence last.

## Full timeline as currently understood

```
search/tap suggestion star
  → seed lands, plays its own preview (✅ built this session)
  → triage queue: judge the seed's neighbors one at a time (✅ redesigned)
      → per-decision feedback (✗ not built)
  → return home
      → newly-added nodes play the arrival ceremony (✗ not built, speced)
```
