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
                        .padding(.bottom, (player.isPlaying || !sim.pendingReviewIDs.isEmpty) ? 110 : 16)
                    }
                }

                // Bottom slot: listen-mode queue takes priority over the
                // plain mini player, since the queue *is* a player too.
                VStack {
                    Spacer()
                    if !sim.pendingReviewIDs.isEmpty {
                        ListenQueueView(sim: sim, player: player)
                    } else if player.isPlaying {
                        MiniPlayerView(player: player, showDetailSheet: $showDetailSheet)
                    }
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

    var body: some View {
        let size = node.nodeSize

        ZStack {
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
