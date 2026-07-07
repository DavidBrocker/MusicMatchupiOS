//
//  ArtistDetailSheet.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/20/26.
//

import SwiftUI
import MusicKit

struct ArtistDetailSheet: View {
    var player: PreviewPlayer
    var artistName: String
    var artworkURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                AsyncImage(url: artworkURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .scaledToFill()
                    } else {
                        Circle().fill(.secondary.opacity(0.2))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .shadow(radius: 12)

                VStack(spacing: 6) {
                    Text(artistName)
                        .font(.title.bold())

                    if !player.genreNames.isEmpty {
                        Text(player.genreNames.prefix(3).joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    player.toggleFollow()
                } label: {
                    Label(
                        player.isFollowing ? "Following" : "Follow",
                        systemImage: player.isFollowing ? "checkmark" : "plus"
                    )
                    .font(.subheadline.bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        player.isFollowing ? Color.secondary.opacity(0.2) : Color.accentColor,
                        in: Capsule()
                    )
                    .foregroundStyle(player.isFollowing ? Color.primary : Color.white)
                }

                if !player.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Songs")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(player.topSongs.prefix(10)) { song in
                            Button {
                                Task {
                                    await player.playSong(
                                        song,
                                        artistName: artistName,
                                        imageURL: artworkURL
                                    )
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    let isCurrentlyPlaying = player.currentTrackName == song.title && player.isPlaying

                                Image(systemName: isCurrentlyPlaying ? "waveform" : "play.fill")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 20)

                                    Text(song.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Spacer()

                                    if let duration = song.duration {
                                        Text(formatted(duration))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(
                                    player.currentTrackName == song.title
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                }

                Spacer(minLength: 30)
            }
        }
        .background(.black)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    func formatted(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
