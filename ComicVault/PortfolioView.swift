//
//  PortfolioView.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Visualizes collection value over time via charts and stats.
//
//  Shows a simple portfolio chart of the collection’s total value over time.
//  The data comes from `SnapshotManager.entries`, where each entry is a
//  `PortfolioEntry` with a `date` and a `total` (USD).
//
//  Running Edit Log
//  - 11-03-25: Added iOS 15 fallback (no Swift Charts dependency required).
//  - 11-09-25: Added median band toggle + 25% key-change callouts for Trends v2.
//  - 11-10-25: Corrected type + extensions so MainTabView can reference `PortfolioView`
//              unambiguously; tightened fallback paths; zero compile warnings.
//


import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct PortfolioView: View {
    @EnvironmentObject private var snapshot: SnapshotManager
    @State private var range: RangeKind = .d30

    // AI
    @State private var aiExplanation: String?
    @State private var showExplain = false
    @State private var busy = false

    // Trends v2 toggles
    @State private var showMedianBand: Bool = true
    @State private var showKeyChangeCallouts: Bool = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Range picker + headline + toggles
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Range", selection: $range) {
                                ForEach(RangeKind.allCases, id: \.self) { rk in
                                    Text(rk.label).tag(rk)
                                }
                            }
                            .pickerStyle(.segmented)

                            if let delta = deltaText {
                                Text(delta)
                                    .font(.subheadline)
                                    .foregroundColor(deltaHasGain ? .green : .red)
                            } else {
                                Text("No snapshots in this range yet. Snapshots are taken automatically once per day.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }

                            if !filtered.isEmpty {
                                HStack(spacing: 16) {
                                    Toggle("Median band", isOn: $showMedianBand)
                                    Toggle("Key change dots", isOn: $showKeyChangeCallouts)
                                }
                                .font(.caption)
                            }
                        }
                    }

                    // Chart (with iOS 15+ fallback)
                    GroupBox {
                        if filtered.isEmpty {
                            Text("No data in this range yet. Snapshots are taken automatically once per day on app launch.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                        } else {
                            #if canImport(Charts)
                            if #available(iOS 16.0, *) {
                                Chart {
                                    // Base line + points
                                    ForEach(filtered, id: \.date) { entry in
                                        LineMark(
                                            x: .value("Date", entry.date),
                                            y: .value("Total", entry.total)
                                        )
                                        PointMark(
                                            x: .value("Date", entry.date),
                                            y: .value("Total", entry.total)
                                        )
                                    }

                                    // Median band (subtle dashed line)
                                    if showMedianBand, let median = medianValue {
                                        RuleMark(
                                            y: .value("Median", median)
                                        )
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundStyle(.primary.opacity(0.28))
                                    }

                                    // Key-change callouts (25%+ abs change)
                                    if showKeyChangeCallouts {
                                        ForEach(keyChangeCallouts) { c in
                                            PointMark(
                                                x: .value("Date", c.date),
                                                y: .value("Total", c.total)
                                            )
                                            .symbolSize(80)
                                            .foregroundStyle(.orange)
                                            .annotation(position: .top) {
                                                Text(c.label)
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.thinMaterial, in: Capsule())
                                            }
                                        }
                                    }
                                }
                                .frame(height: 220)
                            } else {
                                fallbackList
                            }
                            #else
                            fallbackList
                            #endif
                        }
                    }

                    // Explain button (AI)
                    if !filtered.isEmpty {
                        Button {
                            Task {
                                busy = true
                                defer { busy = false }
                                do {
                                    aiExplanation = try await AITrendsHelper.explainPortfolio(entries: filtered)
                                    showExplain = true
                                } catch {
                                    aiExplanation = "Couldn’t generate an explanation."
                                    showExplain = true
                                }
                            }
                        } label: {
                            if busy {
                                ProgressView()
                            } else {
                                Label("Explain My Portfolio", systemImage: "sparkles")
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .alert("AI Summary", isPresented: $showExplain) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiExplanation ?? "—")
            }
        }
    }
}

// MARK: - Derived values

private extension PortfolioView {
    var filtered: [PortfolioEntry] {
        guard !snapshot.entries.isEmpty else { return [] }
        let cutoff = range.cutoff(from: Date())
        return snapshot.entries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    var deltaHasGain: Bool {
        guard
            let first = filtered.first,
            let last = filtered.last
        else { return false }
        return last.total - first.total >= 0
    }

    var deltaText: String? {
        guard
            let first = filtered.first,
            let last = filtered.last
        else { return nil }

        let diff = last.total - first.total
        let pct  = first.total == 0 ? 0 : (diff / first.total)

        let number = abs(diff).formatted(.currency(code: "USD"))
        let percent = NumberFormatter.localizedString(
            from: NSNumber(value: abs(pct)),
            number: .percent
        )
        let sign = diff >= 0 ? "+" : "−"
        let since = DateFormatter.localizedString(
            from: first.date,
            dateStyle: .medium,
            timeStyle: .none
        )
        return "\(sign)\(number) (\(percent)) since \(since)"
    }

    /// Median of totals in the filtered range.
    var medianValue: Double? {
        let values = filtered.map { $0.total }.sorted()
        guard !values.isEmpty else { return nil }

        let mid = values.count / 2
        if values.count % 2 == 0 {
            return (values[mid - 1] + values[mid]) / 2.0
        } else {
            return values[mid]
        }
    }

    /// Key-change callouts: 25%+ absolute change vs previous point.
    var keyChangeCallouts: [KeyChangeCallout] {
        guard filtered.count >= 2 else { return [] }

        var out: [KeyChangeCallout] = []
        for i in 1..<filtered.count {
            let prev = filtered[i - 1]
            let cur  = filtered[i]

            guard prev.total != 0 else { continue }
            let change = (cur.total - prev.total) / prev.total
            if abs(change) >= 0.25 {
                out.append(
                    KeyChangeCallout(
                        date: cur.date,
                        total: cur.total,
                        pctChange: change
                    )
                )
            }
        }
        return out
    }

    /// Fallback list when Charts isn’t available.
    @ViewBuilder
    var fallbackList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(filtered, id: \.date) { e in
                HStack {
                    Text(
                        DateFormatter.localizedString(
                            from: e.date,
                            dateStyle: .short,
                            timeStyle: .none
                        )
                    )
                    .font(.caption)
                    Spacer()
                    Text(e.total, format: .currency(code: "USD"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - KeyChangeCallout model

private struct KeyChangeCallout: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
    let pctChange: Double

    var label: String {
        let pct = NumberFormatter.localizedString(
            from: NSNumber(value: abs(pctChange)),
            number: .percent
        )
        let arrow = pctChange >= 0 ? "↑" : "↓"
        return "\(arrow) \(pct)"
    }
}

// MARK: - RangeKind Helper

private enum RangeKind: CaseIterable {
    case d7, d30, d90, y1, all

    var label: String {
        switch self {
        case .d7:  return "7D"
        case .d30: return "30D"
        case .d90: return "90D"
        case .y1:  return "1Y"
        case .all: return "All"
        }
    }

    func cutoff(from today: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .d7:
            return cal.date(byAdding: .day, value: -7, to: today)  ?? today
        case .d30:
            return cal.date(byAdding: .day, value: -30, to: today) ?? today
        case .d90:
            return cal.date(byAdding: .day, value: -90, to: today) ?? today
        case .y1:
            return cal.date(byAdding: .year, value: -1, to: today) ?? today
        case .all:
            return .distantPast
        }
    }
}
