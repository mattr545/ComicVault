//
//  CCAuth.swift
//  ComicVault
//
//  File created on 11/25/25 by ApogeeINVENT, a software engineering company,
//  in collaboration with the CryptoComics team.
//
//  Description:
//  Handles API authentication payloads for CryptoComics.
//  Supports plain-ID/password and token-based authentication.
//

import Foundation

struct CCAuth: Codable {
    let loginID: String
    let loginPassword: String
    let token: String?

    init(loginID: String, loginPassword: String, token: String? = nil) {
        self.loginID = loginID
        self.loginPassword = loginPassword
        self.token = token
    }

    /// Converts to form-body POST dictionary for API calls.
    func asParams(command: String, extras: [String: String] = [:]) -> [String: String] {
        var params: [String: String] = [
            "ai_command": command
        ]

        if let t = token {
            params["ai_sitecom_token"] = t
        } else {
            params["ai_login_id"] = loginID
            params["ai_login_password"] = loginPassword
        }

        extras.forEach { key, value in params[key] = value }
        return params
    }
}
