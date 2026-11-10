# MusicMatchup — Project Context

_Last verified against the actual files in this folder: 2026-07-22. Where this
doc and the code disagree in the future, trust the code and fix this file —
that drift is exactly the problem this file exists to prevent._

## What this is

An iOS (and macOS multiplatform) music discovery app that visualizes artist
similarity as an interactive force-directed graph, styled as a space
"constellation." The core personal use case: rapidly sample Apple Music's
similar-artist recommendations by skipping through short previews, rather
than reading text lists.

Bundle ID: `dbrock.MusicMatchup`. MusicKit requires a separate `music.`-prefixed
Media ID distinct from the App ID — this trips people up, worth remembering
if entitlements ever need touching.

## Environment

- Xcode 27 beta, targeting iOS 26 / macOS 26 (Tahoe)
- Swift, SwiftUI, MusicKit, AVFoundation
- Uses the `@Observable` macro for newer model types (`MusicGraphStore`,
  `PreviewPlayer`). `ForceSimulation` and `GraphNode` are still
  `ObservableObject`/`@Published` from earlier in the project — this is a
  known, deliberate inconsistency (the 60fps `Timer`-driven physics tick and
  `@Observable` don't necessarily play nicely together). Don't "fix" this
  without discussing first.
- Separate entitlement files for iOS and macOS targets
- MusicKit capability doesn't show in Xcode's Capabilities pane on this
  Xcode version — requires manually creating the entitlement file
- There's also a `MusicKitSandbox/` Swift package alongside the app target —
  a standalone command-line sandbox for exercising the MusicKit API directly
  (developer token, API client, endpoints) outside the app UI

## Author background (relevant for how code gets explained/reviewed)

Dave has a strong R/tidyverse background and is learning Swift as he goes.
R analogies land well in explanations and code comments — `filter()`,
`bind_rows()`, `left_join`, `arrange(desc(...))`, `case_when`, `map() +
compact()`, etc. Prefers full-file paste-over replacements over diff-style
patches when files may have drifted (a past partial-merge incident caused
cascading errors). Also juggles multiple projects at once and finds it
useful to be kept on task.

## Vocabulary

Space/astronomy terms are used deliberately in code comments and UI copy:
"galaxy" (a full graph rooted at one seed search), "constellation" (the
graph itself), "seed artist" (root node), "hop" (depth level from seed).
Keep this vocabulary consistent in new code.

## File map

- `MusicMatchupApp.swift` — app entry point, sets up the `AVAudioSession`
- `ContentView.swift` — top-level view: search bar + autocomplete dropdown,
  splash/starfield state, graph state, sidebar toggle, New Galaxy vs. Add to
  Constellation flow (via a `confirmationDialog`)
- `MusicGraphStore.swift` — `@Observable` store. Searches artists via
  MusicKit, builds the initial 1-hop graph (`buildGraph`), debounced
  autocomplete, and the search-dropdown empty-state data (library artists
  sorted by `libraryAddedDate` descending, plus a hardcoded curated
  fallback list — see "Search dropdown" below)
- `ArtistNode.swift` — plain struct representing a fetched artist +
  connections, used by `MusicGraphStore` before nodes enter the simulation
- `ForceSimulation.swift` — the physics engine. Owns `nodes: [GraphNode]`
  and `edges: [GraphEdge]`, runs a 60fps `Timer`-driven tick (repulsion +
  spring + center-gravity), handles `load()` (initial graph) and
  `expand()` (tap-to-grow). Also owns the Jaccard-similarity backfill logic,
  the Listen Mode review queue (`pendingReviewIDs`), and per-galaxy hue
  assignment (`galaxyHueCount`/`hueForGalaxy`)
- `GraphNode.swift` — `ObservableObject` per-node class (position,
  velocity, pinned state, depth, expanded flag, `galaxyHue`)
- `GraphCanvasView.swift` — renders the `Canvas` for edges, `ForEach` for
  node views, pan/zoom/tap/drag gestures, selected-node label, hosts
  `StarfieldBackgroundView`, `ListenQueueView`/`MiniPlayerView`, and the
  detail sheet
- `ListenQueueView.swift` — the triage queue UI: shows one newly-discovered
  artist at a time with an auto-playing preview and Discard/Skip/Save
  actions
- `ArtistTreeView.swift` — sidebar list of the constellation grouped by hop
  depth, shows average Jaccard match % per artist (confirmed edges only)
- `ArtistSuggestionsList.swift` — search dropdown; switches between library,
  curated, and live-search modes based on focus/typing state (see below)
- `LibraryGridView.swift` — grid browser over the user's MusicKit library,
  used as an alternate entry point to pick a seed artist
- `ArtistDetailSheet.swift` — swipe-up sheet with top songs, genres, Follow
  button (stub)
- `MiniPlayerView.swift` — persistent mini player shown when a preview is
  playing outside Listen Mode (long-press on a node)
- `PreviewPlayer.swift` — `@Observable @MainActor` class wrapping
  `AVPlayer`, fetches an artist's top songs/genres, plays 30s previews with
  auto-stop
- `StarfieldBackgroundView.swift` — faint ambient stars, baked once (no
  physics/timer), shown behind both the splash/search screen and the live
  graph so the background stays continuous across that transition

## Core concepts

**Jaccard similarity** — `ForceSimulation.jaccard(_:_:)` computes
`|intersection| / |union|` between two artists' `similarArtists` ID sets.
This is the similarity *index* (0–1, higher = more alike), not Jaccard
*distance* — the codebase intentionally uses the index throughout (edge
weight, sidebar %), since distance would be visually/semantically backwards
for a "% match" badge.

Edges (`GraphEdge`) carry a `weight` and an `isConfirmed` flag:
- `seedEdgeWeight` (0.6, unconfirmed) — edges straight from a seed search's
  own `similarArtists` list (a direct Apple match, not a derived score)
- `unknownWeight` (0.3, unconfirmed) — placeholder for edges where we don't
  yet know both endpoints' similar-artist sets
- Real computed Jaccard scores (confirmed) — backfilled lazily in
  `expand()`, both when a node is first expanded (against every already-known
  neighbor) and retroactively on existing edges once a second endpoint's set
  becomes known

`isConfirmed` matters: `ArtistTreeView` only shows a match % for confirmed
edges, to avoid displaying a misleadingly precise number for a placeholder
weight. Edge opacity/width and spring strength in the physics tick all scale
with `weight`.

**Listen Mode / triage queue** — `pendingReviewIDs` on `ForceSimulation`.
The seed's own 1-hop neighbors (from `load()`) *and* anything surfaced by
tapping to `expand()` an existing node both land here rather than entering
the constellation "confirmed" outright — the seed artist itself is
structurally excluded from this queue in both places, it's never a
candidate for review. `ListenQueueView` shows the front of the queue with
an auto-playing 30s preview and three actions:
- **Discard** → `sim.removeNode(id:)` — deletes the node *and* every edge
  touching it entirely (not just hides it — intentional, reinforces a
  curation mental model)
- **Skip** → `sim.dequeuePendingReview(id:)` — clears the queue entry, node
  stays in the graph
- **Save** → currently identical to Skip. Stub hook point for real
  playlist/library persistence via `MusicLibrary.shared` later, same
  pattern as `PreviewPlayer.toggleFollow()`

There's currently no first-run hint or coach mark explaining the queue —
it just appears the instant `pendingReviewIDs` is non-empty. Discussed as a
possible addition: a one-time hint shown only the first time the queue
appears (not a long/short-press gesture split, since tap and long-press
already carry distinct meanings on a node — expand vs. preview). Not
implemented yet.

**Galaxy hue / glow** (added 2026-07-22) — every node carries a `galaxyHue`
(0...1), assigned once per `load()` call to the seed and its 1-hop
neighbors, then inherited unchanged by anything spawned later via
`expand()` — so a whole tree grown from one seed shares one color, all the
way down. Successive galaxies (via "Add to Constellation") get a new hue via
golden-ratio stepping (`ForceSimulation.hueForGalaxy`), so colors stay well
separated regardless of how many galaxies accumulate. Rendered in
`GraphCanvasView.NodeView` as a soft blurred circle behind the node.
Purely visual so far — physics/clustering forces don't yet use it (see
roadmap item 4, multi-galaxy universe, which will want this).

**Search dropdown** (`ArtistSuggestionsList` + `MusicGraphStore`) — three
modes, chosen by a `case_when`-style computed property: `.searching` (typed
query, live MusicKit catalog search, debounced 300ms) when there's text in
the field; otherwise `.library` if `libraryArtists` is populated, else
`.curated` (a hardcoded, genre-diverse fallback list). `loadEmptyStateArtists()`
fires the moment the search field gains focus (`ContentView`'s
`onChange(of: isSearchFocused)`), fetching both in parallel. The library
list is sorted by `libraryAddedDate` descending — this is a *recently added
to library* proxy, not *recently played*, since MusicKit's `Artist` type has
no play-count field (see roadmap item 8).

## Known issues / open gaps

- **Orphaned nodes on discard** (flagged 2026-07-22, in `ForceSimulation.
  removeNode`): discarding a node deletes it and every edge touching it, but
  doesn't cascade to nodes that removal orphans elsewhere in the graph. E.g.
  expand past node A into B and C, discard A afterward — B and C aren't
  deleted, just left with zero edges, drifting on repulsion/center-gravity
  alone. Doesn't affect the seed (structurally exempt from the review queue,
  so it can never reach `removeNode` via a Discard tap) — purely a
  deeper-in-the-tree case. Options: leave as-is, warn before a discard that
  would orphan descendants, or cascade-remove the orphaned subtree.
  Undecided.
- **Starfield sometimes doesn't render after "New Galaxy."** Best guess:
  `StarfieldBackgroundView`'s `GeometryReader` may report a zero size before
  layout settles during that transition. A `UIScreen.main.bounds` fallback
  is in place, but the root cause hasn't been confirmed — if it recurs, add
  real logging rather than re-guessing.
- **`@State` inside `ForEach` + rapid re-render risk**: a past bug where an
  animated subview with `@State`, repeatedly instantiated inside a
  `ForEach`, caused `EXC_BAD_ACCESS`. Watch for this pattern if new per-node
  UI gets added to `GraphCanvasView`.
- `ForceSimulation`/`GraphNode` are still `ObservableObject`/`@Published`
  while newer code uses `@Observable` — known, not yet worth migrating (see
  Environment section above).
- No true popularity signal exists in MusicKit's `Artist` type — search
  ranking can only use fuzzy string matching and library-overlap boosting,
  not a real popularity score.
- **This project also lives on the Claude.ai Projects side as an uploaded
  file snapshot, separate from this folder.** That snapshot has drifted
  stale before (missing Jaccard scoring, the triage queue, and the search
  dropdown modes entirely at one point) — this folder is the source of
  truth. If working from the Projects interface, re-upload from here first.

## Candidate features — "understand your taste" direction

Proposed 2026-07-23, not yet prioritized into the roadmap below or
scoped in detail — parking these here so a future session (mine or
Claude Code's) has the reasoning already done instead of starting cold.
Framed around *understanding* the music you like, not just discovering
more of it.

- **Explain the match, not just the score.** The detail sheet shows a %
  match but never *why*. Since `PreviewPlayer.genreNames` is already
  fetched per artist, a "shared genres: math rock, jazz fusion" line on
  `ArtistDetailSheet` (or the sidebar row in `ArtistTreeView`) turns the
  Jaccard number into something legible. Cheapest of these five — no new
  data needed, just a genre-intersection computation and a UI line.
- **Taste fingerprint / genre gravity.** Aggregate genre tags across
  everything *kept* in a galaxy (i.e. not discarded via `removeNode`) into
  a lightweight summary — "this galaxy leans 60% alt-rock, 25%
  shoegaze." Also buildable from data already flowing through
  `PreviewPlayer`; would live as a new computed property on
  `ForceSimulation` or a small summary view hung off `ArtistTreeView`'s
  header.
- **Retrospective on discards.** `removeNode` already knows what got
  rejected; it doesn't know *why*. A lightweight reason tag at discard
  time (too mainstream / wrong genre / already know them / didn't like
  the preview) — surfaced as an optional extra step in
  `ListenQueueView`'s discard action — would seed a future "why do you
  like what you like" view without having to backfill data later. Needs a
  design call: a full sheet per discard is too much friction, so probably
  a row of small icon buttons under the existing Discard action.
- **Cross-galaxy bridges, surfaced proactively.** Related to roadmap item
  1 (dual-constellation compare) and item 5 (multi-galaxy universe), but
  passive rather than on-demand — a nudge like "3 shared connections
  between your Aesop Rock and Bon Iver galaxies" the next time both exist
  in the same session. Depends on the cross-galaxy Jaccard bridging logic
  those roadmap items already need, so sequence this after them rather
  than building bridging logic twice.
- **Time-based replay.** `libraryAddedDate` is already the proxy for
  "recent" (see Known issues). A "how your taste has shifted" view —
  genre mix bucketed by month-added — is close to free given what
  `fetchLibraryArtistsForEmptyState` already fetches; mostly a
  presentation problem once the genre-fingerprint piece above exists.

## Roadmap (rough priority order)

1. **Dual-constellation compare view** — the original core concept. Run
   Jaccard between two seed artists' full similar-sets (not just within one
   expansion) to compare two galaxies directly.
2. **Triage queue discoverability hint** — a one-time coach mark the first
   time `ListenQueueView` appears (see "Listen Mode / triage queue" above)
3. **Fuzzy search ranking** — re-rank `ArtistSuggestionsList` results by
   string similarity to the query + library-overlap boosting
4. **Playlist saving** via `MusicLibrary.shared` — stub hook is the "Save"
   button in `ListenQueueView` and `toggleFollow()` in `PreviewPlayer`
5. **Multi-galaxy "musical universe"** — persistent history of multiple seed
   searches, each as a mostly-disconnected subgraph, using `galaxyHue` for
   both display and (new) per-galaxy clustering forces in the physics tick.
   Needs a `Galaxy` wrapper type and persistence (likely SwiftData given
   iOS 26). Sequenced after the dual-constellation compare view, since it
   reuses the same cross-galaxy Jaccard bridging logic at larger scale.
6. Wire up splash screen chips (Random Artist, Explore Genres, Export
   Galaxy) — currently decorative only in `ContentView`
7. Haptic feedback, edge styling options, developer/appearance settings mode
8. True play-count-based sort via `MPMediaQuery` (current library sort uses
   `libraryAddedDate` as a rough proxy)
9. Decide on the orphaned-node handling above once it comes up in practice
