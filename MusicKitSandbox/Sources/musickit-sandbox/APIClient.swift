import Foundation

struct APIClient {
    let developerToken: String
    let userToken: String?

    private let session = URLSession(configuration: .default)

    func get(path: String, query: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(string: "https://api.music.apple.com\(path)") else {
            throw URLError(.badURL)
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(developerToken)", forHTTPHeaderField: "Authorization")
        if let userToken {
            request.setValue(userToken, forHTTPHeaderField: "Music-User-Token")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
