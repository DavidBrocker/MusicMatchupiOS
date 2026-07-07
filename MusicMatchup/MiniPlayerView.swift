//
//  MiniPlayerView.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//


import SwiftUI

struct MiniPlayerView: View {
    var player: PreviewPlayer
    @Binding var showDetailSheet: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: player.currentArtworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrackName ?? "")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(player.currentArtistName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 3, height: CGFloat.random(in: 8...20))
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: player.isPlaying
                        )
                }
            }
            .frame(width: 20, height: 20)

            Button {
                showDetailSheet = false
                player.stop()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.height < -15 {
                                showDetailSheet = true
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            showDetailSheet = true
                        }
                )
            }
    }
