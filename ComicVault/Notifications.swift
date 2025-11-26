//
//  Notifications.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Shared notification names and helpers.
//

import Foundation

extension Notification.Name {
    /// Posted when a valid CloudKit push is received and the app should pull changes.
    static let ckRemoteChange = Notification.Name("CKRemoteChange")
}
