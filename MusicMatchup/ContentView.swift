import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var store = MusicGraphStore()
    @State private var sim = ForceSimulation()
    @State private var searchText = ""
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var showGraph = false
    @State private var showSidebar = false
    @State private var showSearchModeChoice = false
    @State private var pendingAppend = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content
            VStack(spacing: 16) {
                if !showGraph {
                    Text("MusicMatchup")
                        .font(.largeTitle.bold())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if authStatus == .authorized {
                    if !showGraph {
                        VStack(spacing: 0) {
                            HStack {
                                HStack {
                                    TextField("Search an artist...", text: $searchText)
                                        .autocorrectionDisabled()
                                        .keyboardType(.webSearch)
                                        .focused($isSearchFocused)
                                        .onChange(of: searchText) { _, newValue in
                                            store.updateSuggestions(for: newValue)
                                        }
                                        .onChange(of: isSearchFocused) { _, focused in
                                            if focused {
                                                Task {
                                                    await store.loadEmptyStateArtists()
                                                }
                                            }
                                        }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                                )

                                Button("Go") {
                                    Task {
                                        isSearchFocused = false
                                        showGraph = false
                                        await store.searchArtist(named: searchText, freshStart: !pendingAppend)
                                        pendingAppend = false
                                        withAnimation(.easeInOut(duration: 0.6)) {
                                            showGraph = true
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(searchText.isEmpty)
                            }
                            .padding(.horizontal)

                            // Show the dropdown whenever the search bar is focused —
                            // library/curated when empty, live results when typing.
                            // Like a reactive filter: input state drives output state.
                            if isSearchFocused {
                                ArtistSuggestionsList(
                                    store: store,
                                    searchText: searchText
                                ) { artist in
                                    Task {
                                        isSearchFocused = false
                                        searchText = artist.name
                                        showGraph = false
                                        await store.selectArtist(artist, freshStart: !pendingAppend)
                                        pendingAppend = false
                                        withAnimation(.easeInOut(duration: 0.6)) {
                                            showGraph = true
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if store.isLoading {
                        Spacer()
                        ProgressView("Building constellation...")
                        Spacer()
                    } else if let error = store.errorMessage {
                        Spacer()
                        Text(error).foregroundStyle(.red)
                        Spacer()
                    } else if showGraph {
                        GeometryReader { geo in
                            GraphCanvasView(sim: sim)
                                .onAppear {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                    sim.configureViewport(geo.size) 
                                    sim.load(
                                        from: store,
                                        center: CGPoint(
                                            x: geo.size.width / 2,
                                            y: geo.size.height / 2
                                        ),
                                        append: pendingAppend
                                    )
                                }
                        }
                        .ignoresSafeArea()
                        .overlay(alignment: .topTrailing) {
                            Button {
                                showSearchModeChoice = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .padding()
                            .confirmationDialog(
                                "Start a new search",
                                isPresented: $showSearchModeChoice,
                                titleVisibility: .visible
                            ) {
                                Button("New Galaxy") {
                                    pendingAppend = false
                                    withAnimation(.spring()) {
                                        showGraph = false
                                        showSidebar = false
                                    }
                                }
                                Button("Add to Constellation") {
                                    pendingAppend = true
                                    withAnimation(.spring()) {
                                        showGraph = false
                                        showSidebar = false
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                        .overlay(alignment: .topLeading) {
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
                    } else {
                        ZStack {
                            GhostConstellationView()
                                .transition(.opacity)

                            VStack {
                                Spacer()
                                Text("See how your music connects")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    SplashOptionChip(icon: "shuffle", title: "Random\n Artist")
                                    SplashOptionChip(icon: "square.grid.2x2", title: "Explore Genres")
                                    SplashOptionChip(icon: "square.and.arrow.up", title: "Export\n Galaxy")
                                }
                                .padding(.top, 14)

                                Spacer()
                                    .frame(height: 60)
                            }
                        }
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
            .padding(.top)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSearchFocused {
                    isSearchFocused = false
                }
            }

            // Sidebar overlay
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
        }
        .preferredColorScheme(.dark)
        .task {
            authStatus = MusicAuthorization.currentStatus
        }
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
