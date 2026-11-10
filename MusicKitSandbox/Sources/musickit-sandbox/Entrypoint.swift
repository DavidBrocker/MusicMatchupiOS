import ArgumentParser
import Foundation

@main
struct MusicKitSandbox: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "musickit-sandbox",
        abstract: "Explore Apple Music API endpoints and inspect raw JSON responses.",
        subcommands: [List.self, Token.self, Search.self, Raw.self],
        defaultSubcommand: List.self
    )
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List known endpoint templates.")

    func run() throws {
        for endpoint in Endpoints.catalog {
            let flag = endpoint.requiresUserToken ? " [needs Music-User-Token]" : ""
            print("\(endpoint.name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(endpoint.path)\(flag)")
            print("  \(endpoint.description)")
        }
    }
}

struct Token: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print a freshly generated developer token.")

    func run() throws {
        let config = try Config.fromEnvironment()
        print(try DeveloperToken.generate(teamID: config.teamID, keyID: config.keyID, privateKeyPEM: config.privateKeyPEM))
    }
}

struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search the Apple Music catalog.")

    @Option(help: "Search term") var term: String
    @Option(help: "Comma-separated resource types, e.g. songs,albums,artists") var types: String = "songs"
    @Option(help: "Storefront code, defaults to MUSICKIT_STOREFRONT or 'us'") var storefront: String?

    func run() async throws {
        let config = try Config.fromEnvironment()
        let token = try DeveloperToken.generate(teamID: config.teamID, keyID: config.keyID, privateKeyPEM: config.privateKeyPEM)
        let client = APIClient(developerToken: token, userToken: config.userToken)
        let sf = storefront ?? config.defaultStorefront

        let (data, response) = try await client.get(
            path: "/v1/catalog/\(sf)/search",
            query: ["term": term, "types": types]
        )
        print("HTTP \(response.statusCode)")
        printPrettyJSON(data)
    }
}

struct Raw: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Call an arbitrary Apple Music API path and pretty-print the JSON response.")

    @Argument(help: "API path, e.g. /v1/catalog/us/charts") var path: String
    @Option(name: .long, help: "Query parameter as key=value; repeat for multiple.") var query: [String] = []

    func run() async throws {
        let config = try Config.fromEnvironment()
        let token = try DeveloperToken.generate(teamID: config.teamID, keyID: config.keyID, privateKeyPEM: config.privateKeyPEM)
        let client = APIClient(developerToken: token, userToken: config.userToken)

        let (data, response) = try await client.get(path: path, query: try parseQuery(query))
        print("HTTP \(response.statusCode)")
        printPrettyJSON(data)
    }
}

private func parseQuery(_ pairs: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    for pair in pairs {
        guard let separator = pair.firstIndex(of: "=") else {
            throw ValidationError("Query parameter '\(pair)' must be in key=value form.")
        }
        result[String(pair[pair.startIndex..<separator])] = String(pair[pair.index(after: separator)...])
    }
    return result
}

private func printPrettyJSON(_ data: Data) {
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: pretty, encoding: .utf8) else {
        print(String(data: data, encoding: .utf8) ?? "<non-UTF8 response>")
        return
    }
    print(string)
}
