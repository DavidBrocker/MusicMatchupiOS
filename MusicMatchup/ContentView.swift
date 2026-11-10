import SwiftUI
import MusicKit

// The graph IS the home screen — there's no separate empty landing page.
// A bottom-docked search pill is always present; tapping it slides up a
// Maps-style sheet over the (dimmed, by the system sheet itself) graph.
struct ContentView: View {
    @State private var store = MusicGraphStore()
    @StateObject private var sim = ForceSimulation()
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var showSidebar = false
    @State private var showSearchSheet = false
    @State private var showSearchModeChoice = false
    @State private var pendingAppend = false
    @State private var canvasSize: CGSize = UIScreen.main.bounds.size

    var body: some View {
        ZStack {
            if authStatus == .authorized {
                GeometryReader { geo in
                    GraphCanvasView(sim: sim)
                        .onAppear {
                            canvasSize = geo.size
                            sim.configureViewport(geo.size)
                        }
                        .onChange(of: geo.size) { _, newSize in
                            canvasSize = newSize
                            sim.configureViewport(newSize)
                        }
                }
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) {
                    // Hidden during triage/seed-confirmation — both are
                    // full-bleed modal moments, nothing else should float
                    // on top of them.
                    if !isModalMoment {
                        Button {
                            withAnimation(.spring()) {
                                showSidebar.toggle()
                            }
                        } label: {
                            Image(systemName: showSidebar ? "xmark" : "list.bullet")
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding()
                    }
                }
                .overlay(alignment: .bottom) {
                    if !isModalMoment {
                        searchPill
                    }
                }
                .overlay {
                    // True first-run (or any instant the graph is briefly
                    // empty) — a proto-star anchors the eye, and a handful
                    // of library artists offer a fast way back in without
                    // opening the search sheet at all.
                    if sim.nodes.isEmpty && !isModalMoment {
                        EmptyGalaxySkyView(artists: suggestionArtists, canvasSize: canvasSize) { artist in
                            pendingAppend = false
                            selectArtist(artist)
                        }
                    }
                }

                if showSidebar {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showSidebar = false
                            }
                        }
                        .transition(.opacity)

                    ArtistTreeView(sim: sim) {
                        withAnimation(.spring()) {
                            showSidebar = false
                        }
                    }
                    .frame(width: 280)
                    .transition(.move(edge: .leading))
                }
            } else {
                Spacer()
                Button("Request Music Access") {
                    Task { authStatus = await MusicAuthorization.request() }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            authStatus = MusicAuthorization.currentStatus
            if authStatus == .authorized {
                await store.loadEmptyStateArtists()
            }
        }
        .confirmationDialog(
            "Start a new search",
            isPresented: $showSearchModeChoice,
            titleVisibility: .visible
        ) {
            Button("New Galaxy") {
                pendingAppend = false
                showSearchSheet = true
            }
            Button("Add to Constellation") {
                pendingAppend = true
                showSearchSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheetView(store: store) { artist in
                selectArtist(artist)
            } onSubmitQuery: { query in
                Task {
                    let append = pendingAppend
                    await store.searchArtist(named: query, freshStart: !append)
                    pendingAppend = false
                    showSearchSheet = false
                    withAnimation(.easeInOut(duration: 0.6)) {
                        sim.load(from: store, center: centerPoint, append: append)
                    }
                }
            }
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(16)
        }
    }

    private var centerPoint: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private var isModalMoment: Bool {
        sim.seedConfirmationID != nil || !sim.pendingReviewIDs.isEmpty
    }

    // Library artists (recently added — MusicKit has no reliable
    // recently-played or play-count signal for Artist, see roadmap item 8)
    // if we have them, else the curated fallback. Same source/precedence
    // as the search dropdown's empty state.
    private var suggestionArtists: [Artist] {
        let source = store.libraryArtists.isEmpty ? store.curatedArtists : store.libraryArtists
        return Array(source.prefix(7))
    }

    private func selectArtist(_ artist: Artist) {
        Task {
            let append = pendingAppend
            await store.selectArtist(artist, freshStart: !append)
            pendingAppend = false
            showSearchSheet = false
            withAnimation(.easeInOut(duration: 0.6)) {
                sim.load(from: store, center: centerPoint, append: append)
            }
        }
    }

    private var searchPill: some View {
        Button {
            if sim.nodes.isEmpty {
                showSearchSheet = true
            } else {
                showSearchModeChoice = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Search or explore")
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

// The slide-up search sheet: a text field + Go, plus the same
// library/curated/live-search dropdown used before, now full-height.
private struct SearchSheetView: View {
    var store: MusicGraphStore
    var onSelect: (Artist) -> Void
    var onSubmitQuery: (String) -> Void

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Search an artist...", text: $searchText)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        store.updateSuggestions(for: newValue)
                    }
                    .onSubmit {
                        guard !searchText.isEmpty else { return }
                        onSubmitQuery(searchText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Button("Go") {
                    guard !searchText.isEmpty else { return }
                    onSubmitQuery(searchText)
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty || store.isLoading)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                ArtistSuggestionsList(store: store, searchText: searchText, onSelect: onSelect)
                    .padding(.horizontal)
            }

            if store.isLoading {
                ProgressView("Building constellation...")
            } else if let error = store.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                SplashOptionChip(icon: "shuffle", title: "Random\n Artist")
                SplashOptionChip(icon: "square.grid.2x2", title: "Explore Genres")
                SplashOptionChip(icon: "square.and.arrow.up", title: "Export\n Galaxy")
            }
            .padding(.bottom, 20)
        }
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            isSearchFocused = true
            Task { await store.loadEmptyStateArtists() }
        }
    }
}

// The true-empty-sky state: a breathing proto-star marks where the first
// seed will land, plus a scatter of library-artist "suggestion stars" —
// dashed-border, lower-opacity, deliberately not real graph nodes yet
// (same dashed = potential / solid = real language as the 2b arrival
// ceremony) — offering a one-tap way back into something familiar.
private struct EmptyGalaxySkyView: View {
    var artists: [Artist]
    var canvasSize: CGSize
    var onIgnite: (Artist) -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("Your sky is empty")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.9))
                Text("Search an artist, or pick one below to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .position(x: canvasSize.width / 2, y: canvasSize.height * 0.26)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 46
                    )
                )
                .frame(width: 92, height: 92)
                .scaleEffect(pulse ? 1.15 : 0.85)
                .opacity(pulse ? 0.9 : 0.5)
                .position(x: canvasSize.width / 2, y: canvasSize.height / 2 - 10)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                SuggestionStarView(artist: artist) {
                    onIgnite(artist)
                }
                .position(scatterPosition(for: artist.id, index: index, total: artists.count, in: canvasSize))
            }
        }
        .transition(.opacity)
    }

    // Deterministic per-artist jitter (stable within a session, no stored
    // state needed) arranged in a rough ring around the proto-star.
    private func scatterPosition(for id: MusicItemID, index: Int, total: Int, in size: CGSize) -> CGPoint {
        let hash = abs(id.rawValue.hashValue)

        let baseAngle = (Double(index) / Double(max(total, 1))) * 2 * .pi
        let jitterAngle = (Double(hash % 1000) / 1000.0 - 0.5) * 0.7
        let angle = baseAngle + jitterAngle

        let smallest = min(size.width, size.height)
        let minRadius = smallest * 0.24
        let maxRadius = smallest * 0.42
        let radiusJitter = Double((hash / 1000) % 1000) / 1000.0
        let radius = minRadius + (maxRadius - minRadius) * radiusJitter

        let cx = size.width / 2
        let cy = size.height / 2 - 10
        let rawX = cx + CGFloat(cos(angle)) * CGFloat(radius)
        let rawY = cy + CGFloat(sin(angle)) * CGFloat(radius)

        let x = min(max(rawX, 40), max(size.width - 40, 40))
        let y = min(max(rawY, 130), max(size.height - 140, 130))
        return CGPoint(x: x, y: y)
    }
}

private struct SuggestionStarView: View {
    let artist: Artist
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .blur(radius: 6)
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(
                                Color.secondary.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                            )
                        )

                    AsyncImage(url: artist.artwork?.url(width: 68, height: 68)) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .opacity(0.85)
                        }
                    }
                }

                Text(artist.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 88)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SplashOptionChip: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
            Text(title)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary.opacity(0.6))
        .frame(width: 78, height: 64)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
