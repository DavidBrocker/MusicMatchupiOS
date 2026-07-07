//
//  ForceSimulation.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//

import SwiftUI
import Combine
import MusicKit

// A connection between two artists. `weight` holds the Jaccard similarity
// between their similar-artist sets (0...1). `isConfirmed` distinguishes a
// real computed score from a placeholder default (seedEdgeWeight for edges
// straight off a seed search, unknownWeight for anything not yet
// cross-referenced) — like a flag column marking which rows in a join
// actually matched versus which just got a fallback value.
struct GraphEdge: Equatable {
    let source: String
    let target: String
    var weight: Double = ForceSimulation.unknownWeight
    var isConfirmed: Bool = false
}

class ForceSimulation: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var pendingReviewIDs: [String] = []
    var edges: [GraphEdge] = []

    // id -> node, kept in sync with every `nodes` mutation below. Lets
    // tick() and edge-drawing do O(1) lookups instead of scanning `nodes`
    // per edge per node per frame — matters once galaxies grow large.
    private(set) var nodesByID: [String: GraphNode] = [:]

    // Default weight for edges where we don't yet know both endpoints'
    // similar-artist sets. Below "seed" edges but above nothing, so
    // unconfirmed connections read as present-but-tentative.
    static let unknownWeight: Double = 0.3
    // Weight for edges pulled directly from a seed artist's own
    // similarArtists list — Apple's direct match, not a derived Jaccard
    // score, so it gets a confident-but-not-maximal weight.
    static let seedEdgeWeight: Double = 0.6

    private var timer: Timer?
    private var expandedIDs: Set<String> = []

    // artistID -> that artist's similarArtists ID set. Populated as nodes
    // get expanded, reused to backfill Jaccard scores without re-fetching.
    private var similarArtistsCache: [String: Set<String>] = [:]

    // Scales physics constants relative to the actual screen size, so the
    // constellation fills more of the frame on larger devices instead of
    // staying pinned to one fixed pixel range. Set once via configureViewport.
    private var viewportScale: CGFloat = 1.0

    let repulsion: CGFloat = 4000
    let springLength: CGFloat = 140
    let springStrength: CGFloat = 0.05
    let damping: CGFloat = 0.85
    let centerStrength: CGFloat = 0.01

    // Call once, before the first `load`, with the canvas's actual size.
    func configureViewport(_ size: CGSize) {
        let referenceDimension: CGFloat = 420 // roughly an iPhone-width baseline
        let smallestDimension = min(size.width, size.height)
        viewportScale = max(0.85, smallestDimension / referenceDimension)
    }

    func start(center: CGPoint) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            self.tick(center: center)
        }
    }

    func stop() {
        timer?.invalidate()
    }

    func tick(center: CGPoint) {
        let effectiveRepulsion = repulsion * viewportScale
        let effectiveSpringLength = springLength * viewportScale

        for node in nodes where !node.isPinned {
            var fx: CGFloat = 0
            var fy: CGFloat = 0

            // Repulsion between all nodes
            for other in nodes where other.id != node.id {
                let dx = node.position.x - other.position.x
                let dy = node.position.y - other.position.y
                let dist = max(sqrt(dx*dx + dy*dy), 1)
                let force = effectiveRepulsion / (dist * dist)
                fx += (dx / dist) * force
                fy += (dy / dist) * force
            }

            // Spring attraction along edges — stronger for higher-Jaccard
            // connections, so similar artists pull tighter together.
            for edge in edges {
                var otherId: String? = nil
                if edge.source == node.id { otherId = edge.target }
                else if edge.target == node.id { otherId = edge.source }

                if let otherId,
                   let other = nodesByID[otherId] {
                    let dx = other.position.x - node.position.x
                    let dy = other.position.y - node.position.y
                    let dist = max(sqrt(dx*dx + dy*dy), 1)
                    let force = (dist - effectiveSpringLength) * springStrength * max(edge.weight, 0.15)
                    fx += (dx / dist) * force
                    fy += (dy / dist) * force
                }
            }

            // Gentle pull toward center
            fx += (center.x - node.position.x) * centerStrength
            fy += (center.y - node.position.y) * centerStrength

            node.velocity.x = (node.velocity.x + fx) * damping
            node.velocity.y = (node.velocity.y + fy) * damping
            node.position.x += node.velocity.x
            node.position.y += node.velocity.y
        }

        objectWillChange.send()
    }

    func load(from store: MusicGraphStore, center: CGPoint, append: Bool = false) {
        if !append {
            nodes = []
            nodesByID = [:]
            edges = []
            expandedIDs = []
            similarArtistsCache = [:]
            pendingReviewIDs = []
        }

        let nodeList = Array(store.nodes.values)

        for artist in nodeList {
            // Skip if this node already exists (relevant when appending)
            if nodes.contains(where: { $0.id == artist.id.rawValue }) {
                continue
            }

            let isSeed = artist.id == store.seedArtistID
            let pos: CGPoint
            if isSeed {
                // New seed artists spawn near center but offset slightly if appending,
                // so two seeds don't stack exactly on top of each other
                if append {
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    pos = CGPoint(x: center.x + cos(angle) * 180 * viewportScale, y: center.y + sin(angle) * 180 * viewportScale)
                } else {
                    pos = center
                }
            } else {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let radius = CGFloat.random(in: 80...160) * viewportScale
                pos = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }

            let node = GraphNode(
                id: artist.id.rawValue,
                name: artist.name,
                imageURL: artist.imageURL,
                position: pos,
                depth: isSeed ? 0 : 1
            )
            node.isPinned = isSeed && !append
            nodes.append(node)
            nodesByID[node.id] = node

            // The seed's own neighbors are the artists the person knows
            // least about — Apple picked them, not a tap the person made —
            // so they go through the same listen-mode triage as anything
            // surfaced by expand(), instead of landing pre-confirmed.
            if !isSeed {
                pendingReviewIDs.append(node.id)
            }
        }

        let newEdges = nodeList.flatMap { artist in
            artist.connections.map {
                GraphEdge(source: artist.id.rawValue, target: $0.rawValue, weight: Self.seedEdgeWeight, isConfirmed: false)
            }
        }
        for edge in newEdges where !edges.contains(where: { $0.source == edge.source && $0.target == edge.target }) {
            edges.append(edge)
        }

        if let seed = store.seedArtistID {
            expandedIDs.insert(seed.rawValue)
            // The seed's connections *are* its similarArtists list (already
            // fetched in MusicGraphStore.buildGraph) — cache it now instead
            // of re-fetching the first time someone taps a neighbor.
            if let seedNode = nodeList.first(where: { $0.id == seed }) {
                similarArtistsCache[seed.rawValue] = Set(seedNode.connections.map(\.rawValue))
            }
        }

        start(center: center)
    }

    // Expand a node in place — fetch its related artists (queued for
    // listen-mode review), and score every edge touching this node with a
    // real Jaccard similarity wherever we already know both endpoints' sets.
    func expand(nodeID: String, center: CGPoint) {
        guard !expandedIDs.contains(nodeID),
              let tappedNode = nodes.first(where: { $0.id == nodeID })
        else { return }

        expandedIDs.insert(nodeID)
        tappedNode.isExpanded = true

        Task { @MainActor in
            do {
                var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(nodeID))
                request.properties = [.similarArtists]
                let response = try await request.response()

                guard let artist = response.items.first,
                      let similar = artist.similarArtists
                else { return }

                let similarIDs = Set(similar.map { $0.id.rawValue })
                similarArtistsCache[nodeID] = similarIDs

                // Backfill: now that we know this node's full similar set,
                // recompute weight on any existing edges to neighbors whose
                // sets we already have cached — and mark them confirmed.
                for i in edges.indices {
                    let otherID: String?
                    if edges[i].source == nodeID { otherID = edges[i].target }
                    else if edges[i].target == nodeID { otherID = edges[i].source }
                    else { otherID = nil }

                    if let otherID, let otherSet = similarArtistsCache[otherID] {
                        edges[i].weight = Self.jaccard(similarIDs, otherSet)
                        edges[i].isConfirmed = true
                    }
                }

                for related in similar {
                    let relatedID = related.id.rawValue
                    // If we've already expanded this neighbor before, we know
                    // its set too — compute a real, confirmed Jaccard score.
                    // Otherwise fall back to "unknown" until it gets tapped.
                    let knownSet = similarArtistsCache[relatedID]
                    let weight = knownSet.map { Self.jaccard(similarIDs, $0) } ?? Self.unknownWeight
                    let isConfirmed = knownSet != nil

                    // Skip if already in the constellation
                    if nodes.contains(where: { $0.id == relatedID }) {
                        if let idx = edges.firstIndex(where: {
                            ($0.source == nodeID && $0.target == relatedID) ||
                            ($0.source == relatedID && $0.target == nodeID)
                        }) {
                            edges[idx].weight = weight
                            edges[idx].isConfirmed = isConfirmed
                        } else {
                            edges.append(GraphEdge(source: nodeID, target: relatedID, weight: weight, isConfirmed: isConfirmed))
                        }
                        continue
                    }

                    // Spawn new node near the tapped node
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    let radius = CGFloat.random(in: 60...120) * viewportScale
                    let pos = CGPoint(
                        x: tappedNode.position.x + cos(angle) * radius,
                        y: tappedNode.position.y + sin(angle) * radius
                    )

                    let newNode = GraphNode(
                        id: relatedID,
                        name: related.name,
                        imageURL: related.artwork?.url(width: 200, height: 200),
                        position: pos,
                        depth: tappedNode.depth + 1
                    )

                    nodes.append(newNode)
                    nodesByID[newNode.id] = newNode
                    edges.append(GraphEdge(source: nodeID, target: relatedID, weight: weight, isConfirmed: isConfirmed))
                    // New artists go into the listen queue for triage rather
                    // than just appearing — this is what keeps the graph from
                    // accumulating everything Apple hands back unfiltered.
                    pendingReviewIDs.append(relatedID)
                }

            } catch {
                print("Expansion error: \(error)")
            }
        }
    }

    // Removes a node the user discarded from listen mode — deletes it, any
    // edges touching it, and clears it from caches/queues. Equivalent to a
    // `filter(id != discarded_id)` pass across every table that references it.
    func removeNode(id: String) {
        nodes.removeAll { $0.id == id }
        nodesByID.removeValue(forKey: id)
        edges.removeAll { $0.source == id || $0.target == id }
        similarArtistsCache.removeValue(forKey: id)
        expandedIDs.remove(id)
        dequeuePendingReview(id: id)
    }

    // Clears an artist from the listen-mode queue without touching the
    // graph — used for both "keep" and "skip" (the deciding factor for a
    // future real "keep" action, e.g. following the artist, hooks in here).
    func dequeuePendingReview(id: String) {
        pendingReviewIDs.removeAll { $0 == id }
    }

    // Average Jaccard similarity across a node's *confirmed* edges only —
    // placeholder weights (seedEdgeWeight, unknownWeight) are excluded so
    // the sidebar never shows a precise-looking percentage for artists that
    // haven't actually been cross-referenced yet. Returns nil if none confirmed.
    func averageSimilarity(for nodeID: String) -> Double? {
        let confirmed = edges.filter { $0.isConfirmed && ($0.source == nodeID || $0.target == nodeID) }
        guard !confirmed.isEmpty else { return nil }
        return confirmed.map(\.weight).reduce(0, +) / Double(confirmed.count)
    }

    // Jaccard index: |intersection| / |union| of two similar-artist ID sets.
    // Equivalent to `length(intersect(a, b)) / length(union(a, b))` in R.
    // Note: this is the *similarity* index (1 = identical sets), not Jaccard
    // distance (1 - index), which would be a dissimilarity measure instead.
    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !(a.isEmpty && b.isEmpty) else { return 0 }
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }
}
