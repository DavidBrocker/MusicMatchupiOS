import Foundation
import MusicKit

// Note: classes marked @Observable pair with plain `var` in SwiftUI views,
// not @ObservedObject (that wrapper is for the older ObservableObject protocol).
@Observable
class MusicGraphStore {
    var nodes: [MusicItemID: ArtistNode] = [:]
    var seedArtistID: MusicItemID? = nil
    var isLoading = false
    var errorMessage: String? = nil

    // Autocomplete (live search while typing)
    var suggestions: [Artist] = []
    private var searchTask: Task<Void, Never>? = nil

    // MARK: - Library

    var libraryArtists: [Artist] = []
    var libraryAuthStatus: MusicAuthorization.Status = .notDetermined
    var isLoadingLibrary = false

    // Request library access and fetch the user's artists.
    // Safe to call multiple times — only re-fetches if we don't already have results.
    // This is the primary entry point used by LibraryGridView.
    func loadLibraryArtists() async {
        guard libraryArtists.isEmpty else { return }

        isLoadingLibrary = true

        let status = await MusicAuthorization.request()
        libraryAuthStatus = status

        guard status == .authorized else {
            isLoadingLibrary = false
            return
        }

        do {
            var request = MusicLibraryRequest<Artist>()
            request.limit = 100
            let response = try await request.response()
            libraryArtists = Array(response.items)
        } catch {
            errorMessage = "Couldn't load your library: \(error.localizedDescription)"
        }

        isLoadingLibrary = false
    }

    // MARK: - Curated fallback
    //
    // Used by the search dropdown when it's focused but empty: shows library
    // artists if available, falling back to a hand-picked curated list
    // otherwise. Loaded once per session via loadEmptyStateArtists().

    var curatedArtists: [Artist] = []
    private var emptyStateLoaded = false

    // Our hand-picked roster: genre-diverse, rich Apple Music graphs,
    // universally recognizable. Loaded once and cached for the session.
    private let curatedArtistNames: [String] = [
        "Taylor Swift", "Billie Eilish", "The Weeknd",
        "Radiohead", "Arctic Monkeys", "Tame Impala",
        "Kendrick Lamar", "Frank Ocean", "Tyler the Creator",
        "Daft Punk", "Caribou",
        "Beyoncé", "SZA",
        "David Bowie", "Fleetwood Mac"
    ]

    // Call this when the search bar first focuses, if/when this flow
    // gets wired into the UI. Loads library artists (sorted by most
    // recently added) and a curated fallback, in parallel.
    func loadEmptyStateArtists() async {
        guard !emptyStateLoaded else { return }
        emptyStateLoaded = true

        async let library = fetchLibraryArtistsForEmptyState()
        async let curated = fetchCuratedArtists()

        let (lib, cur) = await (library, curated)
        if libraryArtists.isEmpty { libraryArtists = lib }
        curatedArtists = cur
    }

    // Fetch artists from the user's library, sorted by most recently added.
    // In tidy terms: library_artists %>% arrange(desc(libraryAddedDate)) %>% slice_head(n = 10)
    private func fetchLibraryArtistsForEmptyState() async -> [Artist] {
        do {
            var request = MusicLibraryRequest<Artist>()
            request.sort(by: \.libraryAddedDate, ascending: false)
            request.limit = 10
            let response = try await request.response()
            return Array(response.items)
        } catch {
            // Library unavailable or empty — curated fallback will show instead
            return []
        }
    }

    // Search the catalog for each curated name concurrently, then
    // collect the first result for each — like a map() + compact()
    private func fetchCuratedArtists() async -> [Artist] {
        await withTaskGroup(of: Artist?.self) { group in
            for name in curatedArtistNames {
                group.addTask {
                    do {
                        var req = MusicCatalogSearchRequest(term: name, types: [Artist.self])
                        req.limit = 1
                        let res = try await req.response()
                        return res.artists.first
                    } catch {
                        return nil
                    }
                }
            }

            var results: [Artist] = []
            for await artist in group {
                if let artist { results.append(artist) }
            }

            // Re-sort to match our original curated order, since
            // concurrent tasks complete in arbitrary order —
            // like arrange() after a parallel map()
            return results.sorted {
                let iA = curatedArtistNames.firstIndex(of: $0.name) ?? Int.max
                let iB = curatedArtistNames.firstIndex(of: $1.name) ?? Int.max
                return iA < iB
            }
        }
    }

    // MARK: - Search

    // Search for a seed artist by name (used by the "Go" button)
    // freshStart: true clears any existing constellation data first ("New Galaxy").
    // Pass false to layer this artist's network on top of what's already loaded
    // ("Add to Constellation").
    func searchArtist(named query: String, freshStart: Bool = true) async {
        isLoading = true
        errorMessage = nil
        clearSuggestions()
        if freshStart { nodes = [:] }

        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Artist.self])
            request.limit = 1
            let response = try await request.response()

            guard let artist = response.artists.first else {
                errorMessage = "No artist found for \"\(query)\""
                isLoading = false
                return
            }

            seedArtistID = artist.id
            await buildGraph(from: artist)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Search using a specific artist directly (from tapping an autocomplete
    // suggestion, or a library/curated artist)
    func selectArtist(_ artist: Artist, freshStart: Bool = true) async {
        isLoading = true
        errorMessage = nil
        clearSuggestions()
        if freshStart { nodes = [:] }

        seedArtistID = artist.id
        await buildGraph(from: artist)

        isLoading = false
    }

    // Debounced live search for the autocomplete dropdown
    func updateSuggestions(for query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                var request = MusicCatalogSearchRequest(term: query, types: [Artist.self])
                request.limit = 8
                let response = try await request.response()

                guard !Task.isCancelled else { return }
                self.suggestions = Array(response.artists)
            } catch {
                guard !Task.isCancelled else { return }
                self.suggestions = []
            }
        }
    }

    func clearSuggestions() {
        searchTask?.cancel()
        suggestions = []
    }

    // MARK: - Graph building

    // Fetch an artist + their related artists (1 hop)
    private func buildGraph(from artist: Artist) async {
        do {
            let detailedArtist = try await artist.with([.similarArtists])

            let node = ArtistNode(
                id: detailedArtist.id,
                name: detailedArtist.name,
                imageURL: detailedArtist.artwork?.url(width: 200, height: 200),
                connections: detailedArtist.similarArtists?.map(\.id) ?? []
            )
            nodes[node.id] = node

            for related in detailedArtist.similarArtists ?? [] {
                let relatedNode = ArtistNode(
                    id: related.id,
                    name: related.name,
                    imageURL: related.artwork?.url(width: 200, height: 200),
                    connections: [detailedArtist.id]
                )
                nodes[relatedNode.id] = relatedNode
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
