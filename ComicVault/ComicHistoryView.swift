//
//  ComicHistoryView.swift
//  ComicVault
//
//  File created on 10/14/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Displays the timeline of value points for a given comic.
//
//  Running Edit Log
//  - 10-15-25: Initial history list and chart.
//  - 10-22-25: Updated to use ValuePoint model.
//  - 11-08-25: Header normalization.
//
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct ComicHistoryView: View {
    @EnvironmentObject private var vm: CollectionViewModel
    let comic: Comic

    private var history: [ValuePoint] {
        vm.valueHistory(for: comic.id).sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            sectionChart
            sectionTable
        }
        .navigationTitle("Value History")
    }

    // MARK: Chart

    @ViewBuilder
    private var sectionChart: some View {
        #if canImport(Charts)
        if #available(iOS 16.0, *) {
            Section("Trend") {
                if history.count >= 2 {
                    Chart(history) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                    }
                    .frame(height: 220)
                } else {
                    Text("Add at least two value points to see a chart.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(height: 220, alignment: .center)
                }
            }
        } else {
            Section {
                Text("Charts require iOS 16 or later.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        #else
        Section {
            Text("Charts not available on this platform.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        #endif
    }

    // MARK: Table

    private var sectionTable: some View {
        Section("Points") {
            ForEach(history) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.value.formatted(.currency(code: "USD")))
                            .font(.body.weight(.semibold))
                        Text(p.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(p.source == .manual ? "Manual" : "Estimate")
                        .font(.caption2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Theme.surfaceAlt, in: Capsule())
                }
            }
            if history.isEmpty {
                Text("No value points yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
