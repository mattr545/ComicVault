//
//  TrendsView.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: UI for viewing trend lines and analytics.
//
//  Running Edit Log
//  - 11-02-25: “Explain My Trends” button (AITrendsHelper).
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TrendsView: View {
    @EnvironmentObject private var vm: CollectionViewModel

    enum Range: String, CaseIterable, Identifiable {
        case d30 = "30D", d90 = "90D", all = "All"
        var id: String { rawValue }
    }

    @State private var selectedRange: Range = .d90

    // AI
    @State private var aiText: String?
    @State private var showExplain = false
    @State private var busy = false

    private var fullSeries: [TrendPoint] {
        TrendStore.collectionSeries(
            comics: vm.comics,
            valueHistoryProvider: { vm.valueHistory(for: $0) }
        )
    }

    private var series: [TrendPoint] {
        guard !fullSeries.isEmpty else { return [] }
        switch selectedRange {
        case .all:
            return fullSeries
        case .d30, .d90:
            let days = selectedRange == .d30 ? 30 : 90
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
            let filtered = fullSeries.filter { $0.date >= cutoff }
            return filtered.count >= 2 ? filtered : Array(fullSeries.suffix(min(2, fullSeries.count)))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                chartCard
                benchmarkNote

                if !series.isEmpty {
                    Button {
                        Task {
                            busy = true
                            defer { busy = false }
                            do {
                                aiText = try await AITrendsHelper.explainTrends(points: series)
                                showExplain = true
                            } catch {
                                aiText = "Couldn’t generate an explanation."
                                showExplain = true
                            }
                        }
                    } label: {
                        if busy {
                            ProgressView()
                        } else {
                            Label("Explain My Trends", systemImage: "sparkles")
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Trends")
        .alert("AI Summary", isPresented: $showExplain, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(aiText ?? "—")
        })
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Portfolio Value").font(.headline)
                Text(series.last?.value.formatted(.currency(code: "USD")) ?? "—")
                    .font(.title2.weight(.semibold))
            }
            Spacer()
            Picker("", selection: $selectedRange) {
                ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }

    @ViewBuilder private var chartCard: some View {
        #if canImport(Charts)
        if #available(iOS 16.0, *) {
            GroupBox {
                if series.count >= 2 {
                    Chart(series) { pt in
                        LineMark(x: .value("Date", pt.date),
                                 y: .value("Total", pt.value))
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 220)
                } else {
                    Text("Add value points or run estimates to see a trend.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(height: 220, alignment: .center)
                }
            }
        } else {
            Text("Trends require iOS 16 or later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        #else
        Text("Charts not available on this platform.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }

    private var benchmarkNote: some View {
        Text("Benchmarks coming soon. We’ll compare key issues against market medians.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
