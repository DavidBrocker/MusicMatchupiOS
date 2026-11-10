import CryptoKit
import Foundation

enum DeveloperToken {
    static func generate(
        teamID: String,
        keyID: String,
        privateKeyPEM: String,
        ttl: TimeInterval = 3600
    ) throws -> String {
        let header = ["alg": "ES256", "kid": keyID]
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": teamID,
            "iat": now,
            "exp": now + Int(ttl)
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let signingInput = "\(base64URLEncode(headerData)).\(base64URLEncode(payloadData))"

        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let signature = try privateKey.signature(for: Data(signingInput.utf8))

        return "\(signingInput).\(base64URLEncode(signature.rawRepresentation))"
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
