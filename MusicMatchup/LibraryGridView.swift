import SwiftUI
import MusicKit

struct LibraryGridView: View {
    var store: MusicGraphStore
    var onSelect: (Artist) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 84), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoadingLibrary {
                    ProgressView("Loading your library...")
                        .padding(.top, 60)
                } else if store.libraryAuthStatus != .authorized {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Library access needed")
                            .font(.headline)
                        Text("Allow access to see constellations built from artists already in your library.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 60)
                } else if store.libraryArtists.isEmpty {
                    Text("No artists found in your library")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(store.libraryArtists, id: \.id) { artist in
                            Button {
                                onSelect(artist)
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    AsyncImage(url: artist.artwork?.url(width: 160, height: 160)) { phase in
                                        if case .success(let img) = phase {
                                            img.resizable()
                                                .scaledToFill()
                                        } else {
                                            Circle().fill(.secondary.opacity(0.2))
                                        }
                                    }
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())

                                    Text(artist.name)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Your Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await store.loadLibraryArtists()
        }
        .preferredColorScheme(.dark)
    }
}