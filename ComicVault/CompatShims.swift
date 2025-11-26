//
//  CompatShims.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Backwards-compatibility helpers to smooth API and OS differences.
//
//  Running Edit Log
//  - 10-22-25: Initial helpers for grouped forms and nav container.
//  - 11-10-25: Fixed onChangeCompat to use iOS 17 two-parameter API when available,
//              falling back to legacy onChange(of:perform:) otherwise (no warnings).
//

import SwiftUI

// MARK: - onChange compatibility (iOS 15–17)

extension View {
    @ViewBuilder
    func onChangeCompat<T: Equatable>(
        of value: T,
        perform action: @escaping (T) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

// MARK: - Grouped form style (iOS 15/16 guard)

extension View {
    @ViewBuilder
    func groupedFormStyleIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}

// MARK: - Simple navigation container helper

extension View {
    @ViewBuilder
    func navContainer(_ content: () -> some View) -> some View {
        // Currently the same behavior for all supported iOS versions,
        // but kept as a shim in case we ever need conditional stacks.
        NavigationView { content() }
    }
}
