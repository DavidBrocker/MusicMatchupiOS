struct EndpointInfo {
    let name: String
    let path: String
    let description: String
    let requiresUserToken: Bool
}

enum Endpoints {
    static let catalog: [EndpointInfo] = [
        EndpointInfo(name: "storefronts", path: "/v1/storefronts", description: "All available storefronts", requiresUserToken: false),
        EndpointInfo(name: "storefront", path: "/v1/storefronts/{storefront}", description: "A single storefront", requiresUserToken: false),
        EndpointInfo(name: "search", path: "/v1/catalog/{storefront}/search", description: "Search the catalog (term, types, limit)", requiresUserToken: false),
        EndpointInfo(name: "search-hints", path: "/v1/catalog/{storefront}/search/hints", description: "Search term autocomplete hints", requiresUserToken: false),
        EndpointInfo(name: "songs", path: "/v1/catalog/{storefront}/songs/{id}", description: "A catalog song by id", requiresUserToken: false),
        EndpointInfo(name: "albums", path: "/v1/catalog/{storefront}/albums/{id}", description: "A catalog album by id", requiresUserToken: false),
        EndpointInfo(name: "artists", path: "/v1/catalog/{storefront}/artists/{id}", description: "A catalog artist by id, can include relationships like albums,songs", requiresUserToken: false),
        EndpointInfo(name: "playlists", path: "/v1/catalog/{storefront}/playlists/{id}", description: "A catalog playlist by id", requiresUserToken: false),
        EndpointInfo(name: "music-videos", path: "/v1/catalog/{storefront}/music-videos/{id}", description: "A catalog music video by id", requiresUserToken: false),
        EndpointInfo(name: "charts", path: "/v1/catalog/{storefront}/charts", description: "Top charts (types=songs,albums,...)", requiresUserToken: false),
        EndpointInfo(name: "genres", path: "/v1/catalog/{storefront}/genres", description: "All catalog genres", requiresUserToken: false),
        EndpointInfo(name: "recommendations", path: "/v1/me/recommendations", description: "Personalized recommendations (needs Music-User-Token)", requiresUserToken: true),
        EndpointInfo(name: "library-songs", path: "/v1/me/library/songs", description: "Songs in the user's library (needs Music-User-Token)", requiresUserToken: true),
        EndpointInfo(name: "library-playlists", path: "/v1/me/library/playlists", description: "The user's library playlists (needs Music-User-Token)", requiresUserToken: true),
        EndpointInfo(name: "heavy-rotation", path: "/v1/me/history/heavy-rotation", description: "The user's heavy rotation content (needs Music-User-Token)", requiresUserToken: true),
        EndpointInfo(name: "recently-played", path: "/v1/me/recent/played", description: "The user's recently played resources (needs Music-User-Token)", requiresUserToken: true)
    ]
}
