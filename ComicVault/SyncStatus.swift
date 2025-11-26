//
//  SyncStatus.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Enum representing sync states for CloudKit/local operations.
//

import Foundation

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}
