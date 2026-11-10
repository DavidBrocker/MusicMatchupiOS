//
//  GraphCanvasView.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//

import SwiftUI

struct GraphCanvasView: View {
    @ObservedObject var sim: ForceSimulation
    @State private var selectedNode: GraphNode? = nil
    @State private var center: CGPoint = .zero
    @State private var player = PreviewPlayer()

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showDetailSheet = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Group {
                    StarfieldBackgroundView()
                        .ignoresSafeArea()

                ZStack {
                    // Draw edges
                    Canvas { context, size in
                        for edge in sim.edges {
                            guard
                                let a = sim.nodesByID[edge.source],
                                let b = sim.nodesByID[edge.target]
                            else { continue }

                            let dimmed = isEdgeDimmed(edge)

                            var path = Path()
                            path.move(to: a.position)
                            path.addLine(to: b.position)
                            // Opacity and thickness both scale with Jaccard
                            // weight — stronger similarity reads as a bolder line.
                            context.stroke(
                                path,
                                with: .color(.secondary.opacity(dimmed ? 0.08 : 0.12 + edge.weight * 0.45)),
                                lineWidth: dimmed ? 0.75 : 0.75 + edge.weight * 2.25
                            )
                        }
                    }

                    // Draw nodes
                    ForEach(sim.nodes) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            isDimmed: isDimmed(node)
                        )
                        .position(node.position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    node.isPinned = true
                                    node.position = value.location
                                }
                                .onEnded { _ in
                                    if node.depth != 0 {
                                        node.isPinned = false
                                    }
                                }
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedNode = selectedNode?.id == node.id ? nil : node
                            }
                            sim.expand(nodeID: node.id, center: center)
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            withAnimation(.spring()) {
                                selectedNode = node
                            }
                            Task {
                                await player.play(
                                    artistID: node.id,
                                    artistName: node.name,
                                    imageURL: node.imageURL
                                )
                            }
                        }
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                selectedNode = nil
                            }
                        }
                )

                // Selected node label
                if let selected = selectedNode {
                    VStack {
                       // Spacer()
                        HStack(spacing: 8) {
                            Text(selected.name)
                                .font(.headline)
                            if selected.isExpanded {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, player.isPlaying ? 110 : 16)
                    }
                }

                // Bottom slot for the plain mini player. The triage queue
                // (below) takes over the whole screen instead of sharing
                // this slot, since it's a full-bleed card stack now.
                if player.isPlaying {
                    VStack {
                        Spacer()
                        MiniPlayerView(player: player, showDetailSheet: $showDetailSheet)
                    }
                }
                }
                .opacity(isModalMoment ? 0.2 : 1.0)

                // Seed confirmation takes priority over the triage queue —
                // both can be true at once right after a fresh load(), and
                // "who did I search" has to land before "judge this stranger."
                if let seedID = sim.seedConfirmationID, let seedNode = sim.nodesByID[seedID] {
                    SeedConfirmationView(node: seedNode, player: player) {
                        sim.confirmSeed()
                    }
                } else if !sim.pendingReviewIDs.isEmpty {
                    ListenQueueView(sim: sim, player: player)
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                ArtistDetailSheet(
                    player: player,
                    artistName: player.currentArtistName ?? "",
                    artworkURL: player.currentArtworkURL
                )
            }
            .onAppear {
                center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onDisappear {
                // Otherwise the 60fps physics tick keeps running in the
                // background for as long as `sim` is alive (the whole app
                // session), even while this view isn't shown — e.g. back on
                // the search/splash screen. `load()` restarts the timer via
                // `start(center:)` the next time the graph appears.
                sim.stop()
            }
        }
    }

    // MARK: - Dimming helpers

    private var isModalMoment: Bool {
        sim.seedConfirmationID != nil || !sim.pendingReviewIDs.isEmpty
    }

    func isDimmed(_ node: GraphNode) -> Bool {
        guard let selected = selectedNode else { return false }
        if node.id == selected.id { return false }
        let isNeighbor = sim.edges.contains {
            ($0.source == selected.id && $0.target == node.id) ||
            ($0.target == selected.id && $0.source == node.id)
        }
        return !isNeighbor
    }

    func isEdgeDimmed(_ edge: GraphEdge) -> Bool {
        guard let selected = selectedNode else { return false }
        return edge.source != selected.id && edge.target != selected.id
    }
}

struct NodeView: View {
    @ObservedObject var node: GraphNode
    var isSelected: Bool
    var isDimmed: Bool = false

    // Same hue for every node in a galaxy (seed + all its descendants,
    // however many hops deep) — subtle enough not to compete with the
    // selection/accent color, just enough to read "these belong together."
    private var galaxyColor: Color {
        Color(hue: node.galaxyHue, saturation: 0.65, brightness: 0.95)
    }

    var body: some View {
        let size = node.nodeSize

        ZStack {
            // Galaxy glow — soft, blurred, sits behind everything else.
            Circle()
                .fill(galaxyColor.opacity(isDimmed ? 0.10 : 0.30))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: size * 0.22)

            Circle()
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isSelected ? 3 : 1
                    )
                )

            if let url = node.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        initialsView(size: size)
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        initialsView(size: size)
                    }
                }
            } else {
                initialsView(size: size)
            }
        }
        .opacity(isDimmed ? 0.25 : 1.0)
        .shadow(radius: isSelected ? 10 : 3)
        .animation(.spring(), value: isSelected)
        .animation(.spring(), value: isDimmed)
        .animation(.spring(), value: node.depth)
    }

    func initialsView(size: CGFloat) -> some View {
        Text(node.name.prefix(2).uppercased())
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.secondary.opacity(0.5)))
    }
}

// The beat between "you searched an artist" and "now judge some strangers":
// plays the seed's own preview and holds its portrait on screen for a few
// seconds (or until tapped/Continue) before the triage queue takes over —
// so the first thing you hear is always the artist you actually typed.
private struct SeedConfirmationView: View {
    @ObservedObject var node: GraphNode
    var player: PreviewPlayer
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Starting from")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color(hue: node.galaxyHue, saturation: 0.65, brightness: 0.95).opacity(0.35))
                    .frame(width: 150, height: 150)
                    .blur(radius: 20)

                if let url = node.imageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Circle().fill(.secondary.opacity(0.3))
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 120, height: 120)
                }
            }

            VStack(spacing: 4) {
                Text(node.name)
                    .font(.title2.bold())

                if let track = player.currentTrackName {
                    Text(track)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Loading preview…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onContinue) {
                Text("Continue")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .transition(.opacity)
        .task(id: node.id) {
            await player.play(artistID: node.id, artistName: node.name, imageURL: node.imageURL)
        }
        .task(id: node.id) {
            try? await Task.sleep(for: .seconds(3.5))
            onContinue()
        }
    }
}
