# Handoff: MusicMatchup — Graph-Centric Music Discovery UI

## Overview
MusicMatchup is a music discovery app built around a persistent "constellation" graph: every artist you explore becomes a star node, connected to related artists you've triaged in. There is no separate home screen — the graph IS the home screen, rendered over a starfield backdrop that carries through every screen (splash, graph, search, triage). This package documents the splash animation and the four core screens/flows needed to build the iOS app in SwiftUI.

## About the Design Files
The files in this bundle (`MusicMatchup Splash.dc.html`, `MusicMatchup Wireframes.dc.html`) are **design references created in HTML** — prototypes and wireframes showing intended look, structure, and behavior, not production code to copy directly. The task is to **recreate these designs natively in SwiftUI** using standard iOS patterns (SwiftUI views, `Canvas`/SpriteKit or similar for the starfield/graph rendering, AVFoundation for audio snippet playback), not to embed or wrap the HTML.

## Fidelity
- **Splash screen** (`MusicMatchup Splash.dc.html`): High-fidelity motion design — exact timing, easing, and animation beats should be matched. Already exported to MP4 as a visual reference for the animator; use it to match timing precisely.
- **Wireframes** (`MusicMatchup Wireframes.dc.html`): Low-fidelity structure/flow only — line-art placeholder boxes, not final visuals. Use these for layout, navigation flow, and interaction logic; apply your own final type/color polish consistent with the starfield/graph visual language described below (dark backgrounds, white/translucent nodes, soft radial-gradient halos). Do not treat exact wireframe pixel values as final — they are illustrative at a 260–300px mock width.

## Screens / Views

### 1. Splash Screen
**Purpose**: App launch animation, establishes the constellation/starfield brand identity before landing on the home graph.

**Sequence** (4 scenes, ~9.2s total):
1. **Void** (1.0s) — black/starfield fade-in begins.
2. **Draw** (3.6s) — the "MM" logo mark draws on-stroke (animated stroke-path reveal, not a fade).
3. **Constellation** (2.2s) — constellation nodes snap into place with connecting lines drawn between them, radiating from/around the logo mark.
4. **Wordmark** (2.4s) — "MusicMatchup" wordmark settles/fades in below the mark.

**Notes**: Canvas is 1080×1920 (portrait, 9:16). Tweakable params exposed in the prototype: `accentTone` (default "plum"), `showSubtitle` (boolean). Recreate as a native SwiftUI animation (e.g. `TimelineView` + `Canvas`, or Core Animation / Lottie if exporting motion curves) rather than replaying the MP4 — a native version can respond to real launch timing and skip-on-tap.

### 2. Home Graph (constellation canvas)
**Decision**: **1a — graph-as-home with bottom search sheet.**

**Layout**: No separate empty home screen. A full-bleed starfield canvas (dark, near-black background, sparse white dots) is the permanent backdrop. The user's personal constellation (artist nodes + connecting lines) renders directly on it, centered/framed based on the current focus node. A pill-shaped search affordance ("Search or explore ▾") is docked at the bottom, ~14pt inset from each edge, ~38pt tall, translucent/frosted style.

**Interaction**: Tapping the search affordance slides up a bottom sheet (Maps-style) over the dimmed starfield (backdrop opacity drops to ~0.15) containing a search field and result rows. Selecting a result crossfades into that artist's node in Listen Mode.

**Node visual language** (see Design Tokens below): circular nodes, white/translucent fill, white or gray 1.5px border; size encodes importance (seed/focus node largest, distant nodes smaller and dimmer).

**Arrival behavior — Decision: 2b (ceremony arrival only for new nodes)**: Ordinary app launches show a quiet, quick fade-in of the existing constellation — no camera move, no ceremony. The FIRST time the user returns home after triaging in a brand-new artist, that specific node plays a one-time "arrival" animation: a dim/dashed placeholder star travels inward from off-node position, then connects with a line to its source node and settles into full opacity/solid border. This is a per-node, one-shot event (track a "hasArrived" flag per node), not a full-screen transition.

### 3. Constellation at Scale (30+ expansions)
**Decision: 5a/5b — radial tiers + similarity halos ("deep-field" aesthetic).**

**Structure** (invisible in the final UI, but must drive layout math):
- **Tiers**: nodes are placed in concentric rings around the seed/focus node based on hop-distance in the graph (tier 1 = directly connected, tier 2 = two hops, tier 3 = three hops, etc.). Ring radius increases per tier; position within a ring has randomized jitter (angle + slight radius variance) so it doesn't look gridded.
- **Similarity halos**: independent of tiers, artists that are musically similar (by whatever similarity score backs recommendations) are grouped under a shared soft radial-gradient glow ("halo") — large, low-opacity colored blobs sitting beneath the node layer. A node's tier controls WHERE it sits (distance from center); halo membership controls its background glow color/grouping. These two systems overlay independently.
- **Node sizing/opacity by tier**: tier-1 (closest) nodes render largest (~22px) and full opacity/white border; tier-2 mid-size (~14px) at ~0.75 opacity; tier-3+ smallest (~8px) at ~0.4 opacity. This is a magnitude falloff, similar to real star brightness by distance.
- **Final look (5b)**: no visible ring guides or dashed boundaries in production — those are debug-only annotations shown in variant 5a for engineering reference. Ship 5b: just the softly-colored halo blobs, starfield background, and nodes at their tiered position/size/opacity. The result should read as a Hubble-deep-field-style star cluster, not a diagram.

### 4. Triage Queue (adding related artists)
**Decision: 3a — refined card stack, binary pass/add.**

**Layout**: Full-bleed swipeable card stack over the dimmed starfield (opacity ~0.2). A slim dot-progress indicator (e.g. "• • ○ ○ ○") sits centered at the top, ~6pt inset, showing position in the queue. The main card area (inset ~20pt sides, ~40pt top, ~90pt bottom) shows album art with an audio snippet auto-playing.

**Controls**: Two buttons only, bottom-centered, evenly spaced (space-around): **✕ (pass, red/muted-red)** and **✓ (add, green)**. No third heart/favorite button — favoriting was removed from this flow entirely; it's deferred to direct interaction with nodes already in the graph (e.g. long-press a settled node to favorite/pin it, not part of this queue).

**Behavior**: swipe or tap to advance; "add" queues the candidate to animate into the graph per the arrival ceremony (see Home Graph → 2b) on next return home; "pass" discards and advances to the next card with no further trace.

## Interactions & Behavior Summary
- **Search sheet**: slide-up bottom sheet, backdrop dims to ~15% starfield opacity while open; dismiss returns to full-opacity graph.
- **Node tap** (in graph): opens Listen Mode / triage-adjacent detail for that artist (exact target screen TBD — flag with product if unclear from wireframes).
- **New-node arrival**: one-shot per node, triggered on the first home-screen return after that node is added via triage; subsequent launches render it as a normal settled node with no animation.
- **Triage swipe/tap**: pass (✕) or add (✓); no undo shown in current wireframes — confirm with product before implementing undo.
- **Audio**: snippet auto-plays when a triage card becomes active; pause/stop on advance.

## State Management
- **Graph state**: nodes (id, artist metadata, tier/hop-distance from current seed, similarity-cluster id, hasArrived flag, position seed for jitter), edges (connections between nodes).
- **Triage queue state**: ordered list of candidate artists for a given source node, current index, pass/add outcome per candidate.
- **Session/launch state**: track whether this is the first home-render since a given node's add (drives the 2b arrival ceremony), and current focus/seed node.
- **Search sheet state**: open/closed, query text, results list.

## Design Tokens
(extracted from wireframe reference — treat as starting values, refine visually in SwiftUI)
- **Background**: near-black, e.g. `#050505`–`#0f0f12`.
- **Starfield**: sparse white dots (~1px), repeating on a ~22px grid, ~30–35% opacity.
- **Node fill**: `rgba(255,255,255,0.15)`; **border**: 1.5px, `#999` (dim) or `#fff` (focus/tier-1).
- **Similarity halo colors** (soft radial gradients, ~20–28% opacity, transparent at 70% radius): plum `rgba(160,130,210)`, teal `rgba(120,190,190)`, tan `rgba(210,170,130)`, blue `rgba(130,150,220)`. Use additional hues as more clusters appear; keep opacity low so halos read as atmosphere, not solid shapes.
- **Node size/opacity by tier**: tier-1 ~22px/100%, tier-2 ~14px/75%, tier-3 ~8px/40%.
- **Triage accent colors**: pass ✕ muted red `#c66`; add ✓ green `#6c9`.
- **Typography**: wireframes use Kalam (a handwriting font) as a placeholder annotation font only — NOT intended for production UI. Pick a production type system separately (not specified by these wireframes).
- **Search sheet**: bottom-docked, ~14pt side insets, ~38pt height (collapsed/pill state), expands to full-height sheet with ~16px corner radius on the top edges.

## Screenshots
`screenshots/` contains a rendered capture of each wireframe turn for quick visual reference alongside the README descriptions:
- `01-structure-1a-1d.png` — Turn 1: app structure options (1a decided).
- `02-home-growth-2a-2b.png` — Turn 2: home constellation growth options (2b decided).
- `03-triage-3a-3d.png` — Turn 3: triage queue options (3a decided).
- `04-scale-4a-4d.png` — Turn 4: constellation-at-scale explorations (informed 5a/5b).
- `05-final-5a-5b.png` — Turn 5: final tier + halo treatment (5a/5b decided).

## Assets
No bitmap/vector image assets are used — all visuals (starfield, nodes, halos) are procedurally drawn (radial gradients, dots, circles). Album art in the triage queue is a placeholder box in the wireframe; real album art will come from a music metadata API (not yet integrated).

## Files
- `MusicMatchup Splash.dc.html` — splash animation prototype (references `animations-v2.jsx`, `mm-splash-scenes.jsx`, `tweaks-panel.jsx`, `support.js`).
- `animations-v2.jsx`, `mm-splash-scenes.jsx`, `tweaks-panel.jsx`, `support.js` — supporting scene/animation logic and runtime for the splash prototype (JS, for prototype behavior reference only — not to be ported directly to Swift).
- `MusicMatchup Wireframes.dc.html` — all wireframe variants and decision history for: app structure (turn 1), home constellation growth (turn 2), triage queue (turn 3), constellation at scale (turn 4), and final tier/halo treatment (turn 5). Decided options are called out per screen above; other options in the file are earlier explorations kept for context, not additional screens to build.
