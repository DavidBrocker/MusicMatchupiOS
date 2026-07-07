//
//  ArtistTreeView.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//


import SwiftUI

struct ArtistTreeView: View {
    @ObservedObject var sim: ForceSimulation
    var onDismiss: () -> Void

    // Group nodes by depth
    var nodesByDepth: [(Int, [GraphNode])] {
        let depths = Set(sim.nodes.map(\.depth)).sorted()
        return depths.map { depth in
            (depth, sim.nodes.filter { $0.depth == depth }
                .sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Constellation")
                    .font(.title2.bold())
                Spacer()
                Text("\(sim.nodes.count) artists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Tree list grouped by hop depth
            List {
                ForEach(nodesByDepth, id: \.0) { depth, nodes in
                    Section {
                        ForEach(nodes) { node in
                            HStack(spacing: 12) {
                                AsyncImage(url: node.imageURL) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(.secondary.opacity(0.3))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Text(node.name.prefix(2).uppercased())
                                                    .font(.caption2.bold())
                                            )
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.name)
                                        .font(.subheadline)
                                    if node.isExpanded {
                                        Text("Expanded")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }

                                Spacer()

                                // Average Jaccard similarity across this
                                // artist's confirmed edges, as a percentage —
                                // omitted entirely (rather than showing 0%)
                                // when nothing's been confirmed yet, since
                                // "no data" and "zero overlap" mean different
                                // things.
                                if depth != 0, let score = sim.averageSimilarity(for: node.id) {
                                    Text("\(Int(score * 100))% match")
                                        .font(.caption2.bold())
                                        .foregroundStyle(Color.accentColor)
                                }

                                if node.isExpanded {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onDismiss()
                            }
                        }
                    } header: {
                        Text(depth == 0 ? "⭐ Seed Artist" : "Hop \(depth)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .padding(.vertical)
    }
}
