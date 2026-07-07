//
//  ListenQueueView.swift
//  MusicMatchup
//
//  Created by David Brocker on 7/1/26.
//

import SwiftUI

// The triage queue: after expanding a node, newly discovered artists land
// here one at a time — a 30s preview auto-plays, and the person decides
// whether the artist earns a spot in the constellation or gets pruned.
// This is the app-native version of "skip through Apple's recommendations
// 10 seconds at a time."
struct ListenQueueView: View {
    @ObservedObject var sim: ForceSimulation
    var player: PreviewPlayer

    private var currentNode: GraphNode? {
        guard let id = sim.pendingReviewIDs.first else { return nil }
        return sim.nodes.first(where: { $0.id == id })
    }

    var body: some View {
        if let node = currentNode {
            VStack(spacing: 10) {
                HStack {
                    Text("Listen Mode")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(sim.pendingReviewIDs.count) left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    AsyncImage(url: node.imageURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Circle().fill(.secondary.opacity(0.3))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)

                        if let track = player.currentTrackName {
                            Text(track)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineLimit(1)
                        } else {
                            Text("Loading preview…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !player.genreNames.isEmpty {
                            Text(player.genreNames.prefix(2).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if player.isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                HStack(spacing: 16) {
                    queueButton(icon: "xmark", tint: .red, label: "Discard") {
                        discard(node)
                    }
                    queueButton(icon: "plus.circle.fill", tint: .secondary, label: "Skip") {
                        skip(node)
                    }
                    // "Save" — currently just clears the queue entry, same as
                    // Skip. This is the hook point for real playlist/library
                    // persistence later (MusicLibrary.shared), same pattern
                    // as PreviewPlayer.toggleFollow().
                    queueButton(icon: "heart.fill", tint: .accentColor, label: "Save") {
                        save(node)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Re-runs (and auto-cancels the previous preview) whenever the
            // front of the queue changes — no manual onChange bookkeeping needed.
            .task(id: node.id) {
                await player.play(artistID: node.id, artistName: node.name, imageURL: node.imageURL)
            }
        }
    }

    private func queueButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: Circle())
                .foregroundStyle(tint)
        }
        .accessibilityLabel(label)
    }

    private func discard(_ node: GraphNode) {
        player.stop()
        withAnimation(.spring()) {
            sim.removeNode(id: node.id)
        }
    }

    private func skip(_ node: GraphNode) {
        player.stop()
        withAnimation(.spring()) {
            sim.dequeuePendingReview(id: node.id)
        }
    }

    private func save(_ node: GraphNode) {
        player.stop()
        withAnimation(.spring()) {
            sim.dequeuePendingReview(id: node.id)
        }
    }
}
