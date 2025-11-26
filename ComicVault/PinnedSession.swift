//
//  PinnedSession.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Models a pinned user session or view state for quick access.
//
//  HTTPS-only URLSession with optional public-key pinning.
//  Updated to modern Security APIs (no deprecation warnings).
//

import Foundation
import CryptoKit

final class PinnedSession: NSObject, URLSessionDelegate {
    private let baseConfiguration: URLSessionConfiguration
    private let pinnedSPKIHashes: Set<String> // base64(SHA256(SPKI))

    init(configuration: URLSessionConfiguration = .ephemeral,
         pinnedSPKIHashes: Set<String> = []) {
        self.pinnedSPKIHashes = pinnedSPKIHashes

        // Sensible defaults for a content app
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.baseConfiguration = configuration
        super.init()
    }

    /// Perform a request, enforcing HTTPS and (optionally) SPKI pinning.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Enforce HTTPS
        guard request.url?.scheme?.lowercased() == "https" else {
            throw URLError(.appTransportSecurityRequiresSecureConnection)
        }

        // If no pins configured, no delegate needed.
        if pinnedSPKIHashes.isEmpty {
            let s = URLSession(configuration: baseConfiguration)
            return try await s.data(for: request)
        } else {
            // Use self as delegate to perform pinning.
            let s = URLSession(configuration: baseConfiguration, delegate: self, delegateQueue: nil)
            return try await s.data(for: request)
        }
    }

    // MARK: - URLSessionDelegate (pinning)

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 1) Evaluate system trust using modern API
        var trustError: CFError?
        guard SecTrustEvaluateWithError(trust, &trustError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 2) Extract the leaf certificate from the evaluated chain
        //    (modern replacement for SecTrustGetCertificateAtIndex)
        let chain = (SecTrustCopyCertificateChain(trust) as NSArray?) as? [SecCertificate] ?? []
        guard let leaf = chain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 3) Get SPKI bytes from the leaf public key and hash them (SHA256 → base64)
        guard let spkiKey = SecCertificateCopyKey(leaf),
              let spkiData = SecKeyCopyExternalRepresentation(spkiKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let spkiHashB64 = Data(SHA256.hash(data: spkiData)).base64EncodedString()

        // 4) Compare against our pinned set (if any)
        if pinnedSPKIHashes.contains(spkiHashB64) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
