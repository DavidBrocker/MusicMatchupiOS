//
//  ArtistSuggestionsList.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/20/26.
//

import SwiftUI
import MusicKit

struct ArtistSuggestionsList: View {
    var store: MusicGraphStore
    var searchText: String
    var onSelect: (Artist) -> Void

    // Which mode we're in — like a case_when on search state
    private var mode: Mode {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return .searching
        } else if !store.libraryArtists.isEmpty {
            return .library
        } else {
            return .curated
        }
    }

    private enum Mode { case searching, library, curated }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch mode {
            case .searching:
                artistRows(store.suggestions, showDividers: true)

            case .library:
                sectionHeader("From Your Library")
                artistRows(store.libraryArtists, showDividers: true)

            case .curated:
                sectionHeader("Try These")
                artistRows(store.curatedArtists, showDividers: true)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    // MARK: - Subviews

    // Section header — lighter weight + secondary color to
    // distinguish provenance without needing a separate color system
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    // Artist row list — reused across all three modes,
    // like a shared render function passed different tibbles
    @ViewBuilder
    private func artistRows(_ artists: [Artist], showDividers: Bool) -> some View {
        ForEach(artists, id: \.id) { artist in
            Button {
                onSelect(artist)
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: artist.artwork?.url(width: 80, height: 80)) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(.secondary.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                    }

                    Text(artist.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if showDividers && artist.id != artists.last?.id {
                Divider().padding(.leading, 56)
            }
        }
    }
}
