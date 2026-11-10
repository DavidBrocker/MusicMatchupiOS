import Foundation

struct Config {
    let teamID: String
    let keyID: String
    let privateKeyPEM: String
    let defaultStorefront: String
    let userToken: String?

    static func fromEnvironment() throws -> Config {
        let env = ProcessInfo.processInfo.environment

        guard let teamID = env["MUSICKIT_TEAM_ID"], !teamID.isEmpty else {
            throw ConfigError.missing("MUSICKIT_TEAM_ID")
        }
        guard let keyID = env["MUSICKIT_KEY_ID"], !keyID.isEmpty else {
            throw ConfigError.missing("MUSICKIT_KEY_ID")
        }
        guard let keyPath = env["MUSICKIT_PRIVATE_KEY_PATH"], !keyPath.isEmpty else {
            throw ConfigError.missing("MUSICKIT_PRIVATE_KEY_PATH")
        }

        let expandedPath = (keyPath as NSString).expandingTildeInPath
        let pem = try String(contentsOfFile: expandedPath, encoding: .utf8)

        return Config(
            teamID: teamID,
            keyID: keyID,
            privateKeyPEM: pem,
            defaultStorefront: env["MUSICKIT_STOREFRONT"] ?? "us",
            userToken: env["MUSICKIT_USER_TOKEN"]
        )
    }
}

enum ConfigError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "Missing required environment variable \(name). Copy .env.example to .env, fill it in, and `source .env` before running."
        }
    }
}
