//
//  ListenQueueView.swift
//  MusicMatchup
//
//  Created by David Brocker on 7/1/26.
//

import SwiftUI

// The triage queue: after expanding a node, newly discovered artists land
// here one at a time as a full-bleed swipeable card — a 30s preview
// auto-plays, and a pass/add decides whether the artist earns a spot in
// the constellation or gets pruned. This is the app-native version of
// "skip through Apple's recommendations 10 seconds at a time."
struct ListenQueueView: View {
    @ObservedObject var sim: ForceSimulation
    var player: PreviewPlayer

    @State private var sessionTotal: Int = 0
    @State private var dragOffset: CGSize = .zero

    private let passColor = Color(red: 0.8, green: 0.4, blue: 0.4)
    private let addColor = Color(red: 0.4, green: 0.8, blue: 0.6)
    private let swipeThreshold: CGFloat = 110

    private var currentNode: GraphNode? {
        guard let id = sim.pendingReviewIDs.first else { return nil }
        return sim.nodes.first(where: { $0.id == id })
    }

    private var nextNode: GraphNode? {
        guard sim.pendingReviewIDs.count > 1 else { return nil }
        let id = sim.pendingReviewIDs[1]
        return sim.nodes.first(where: { $0.id == id })
    }

    var body: some View {
        if let node = currentNode {
            ZStack {
                // Card layer — a fixed, capped size (not "fill the space
                // between insets") so it reads as a card floating over the
                // dimmed starfield on any screen height, not a takeover.
                ZStack {
                    if let next = nextNode {
                        CardFace(node: next, player: player, isPeek: true)
                            .scaleEffect(0.94)
                            .offset(y: 14)
                            .opacity(0.5)
                    }

                    CardFace(node: node, player: player, isPeek: false)
                        .overlay(alignment: .topLeading) { swipeStamp(.pass) }
                        .overlay(alignment: .topTrailing) { swipeStamp(.add) }
                        .offset(dragOffset)
                        .rotationEffect(.degrees(dragOffset.width / 18))
                        .gesture(dragGesture(for: node))
                }
                .frame(maxWidth: 320, maxHeight: 420)

                VStack {
                    dotProgress
                        .padding(.top, 6)
                    Spacer()
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        triageButton(systemName: "xmark", tint: passColor, label: "Pass") {
                            pass(node)
                        }
                        Spacer()
                        triageButton(systemName: "checkmark", tint: addColor, label: "Add") {
                            add(node)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .onAppear { sessionTotal = sim.pendingReviewIDs.count }
            .onChange(of: sim.pendingReviewIDs.count) { _, newCount in
                if newCount > sessionTotal { sessionTotal = newCount }
            }
            .onChange(of: node.id) { _, _ in dragOffset = .zero }
            // Re-runs (and auto-cancels the previous preview) whenever the
            // front of the queue changes — no manual onChange bookkeeping needed.
            .task(id: node.id) {
                await player.play(artistID: node.id, artistName: node.name, imageURL: node.imageURL)
            }
        }
    }

    // MARK: - Dot progress

    private var dotProgress: some View {
        let total = max(sessionTotal, sim.pendingReviewIDs.count, 1)
        let dotCount = min(total, 6)
        let filled = min(dotCount, max(0, total - sim.pendingReviewIDs.count) + 1)
        return HStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { i in
                Circle()
                    .strokeBorder(.secondary.opacity(0.6), lineWidth: 1)
                    .background(Circle().fill(i < filled ? Color.secondary : .clear))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Swipe direction stamp
    // Visible at a low baseline opacity even at rest, so "left = pass,
    // right = add" is legible before you've touched the card at all — not
    // just discovered mid-drag. The matching direction intensifies as you
    // drag toward it; the other one fades further out of the way.

    private enum SwipeDirection { case pass, add }

    @ViewBuilder
    private func swipeStamp(_ direction: SwipeDirection) -> some View {
        let progress = min(1, abs(dragOffset.width) / swipeThreshold)
        let matches = (direction == .pass && dragOffset.width < 0) || (direction == .add && dragOffset.width > 0)
        let opacity = matches ? 0.25 + 0.75 * progress : max(0.16, 0.25 - progress * 0.25)
        Image(systemName: direction == .pass ? "xmark.circle.fill" : "checkmark.circle.fill")
            .font(.largeTitle)
            .foregroundStyle(direction == .pass ? passColor : addColor)
            .opacity(opacity)
            .padding(16)
    }

    private func dragGesture(for node: GraphNode) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Mostly-horizontal — this is a left/right decision, not a
                // free drag. A little vertical follow keeps it feeling
                // physical without implying you can toss the card anywhere.
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                if value.translation.width <= -swipeThreshold {
                    pass(node)
                } else if value.translation.width >= swipeThreshold {
                    add(node)
                } else {
                    withAnimation(.spring()) { dragOffset = .zero }
                }
            }
    }

    private func triageButton(systemName: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(tint, lineWidth: 1.5))
                .foregroundStyle(tint)
        }
        .accessibilityLabel(label)
    }

    // MARK: - Actions
    // "Pass" discards the node entirely (no further trace); "Add" keeps it
    // in the constellation. There's no third "save" action in this flow —
    // favoriting lives on settled nodes (long-press to pin) instead.

    private func pass(_ node: GraphNode) {
        player.stop()
        withAnimation(.spring()) {
            dragOffset = CGSize(width: -500, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sim.removeNode(id: node.id)
        }
    }

    private func add(_ node: GraphNode) {
        player.stop()
        withAnimation(.spring()) {
            dragOffset = CGSize(width: 500, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sim.dequeuePendingReview(id: node.id)
        }
    }
}

private struct CardFace: View {
    @ObservedObject var node: GraphNode
    var player: PreviewPlayer
    var isPeek: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let url = node.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            if !isPeek {
                VStack {
                    HStack {
                        Spacer()
                        if player.isPlaying {
                            Image(systemName: "waveform")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if let track = player.currentTrackName {
                            Text(track)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        } else {
                            Text("Loading preview…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        if !player.genreNames.isEmpty {
                            Text(player.genreNames.prefix(2).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: isPeek ? 4 : 12)
    }
}
