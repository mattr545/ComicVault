//
//  CollectionSparklineHeader.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Compact sparkline header for visualizing portfolio trends above the collection.
//
//  Running Edit Log
//  - Updated on 10-28-25: Compact/Full modes for accordion label.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct CollectionSparklineHeader: View {
    // Matches calls like: CollectionSparklineHeader(mode: .full / .compact)
    enum Mode { case compact, full }
    var mode: Mode = .full

    @EnvironmentObject private var vm: CollectionViewModel

    // Range picker for the sparkline
    enum Range: String, CaseIterable, Identifiable {
        case d30 = "30D"
        case d90 = "90D"
        case all = "All"
        var id: String { rawValue }
    }
    @State private var selectedRange: Range = .d90

    // MARK: - Data

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

    private var currentTotal: Double { series.last?.value ?? 0 }
    private var startTotal: Double { series.first?.value ?? 0 }
    private var absDelta: Double { currentTotal - startTotal }
    private var pctDelta: Double? { startTotal > 0 ? (absDelta / startTotal) * 100.0 : nil }

    // MARK: - Body

    var body: some View {
        switch mode {
        case .compact:
            compactRow
        case .full:
            fullCard
        }
    }

    // MARK: - Views

    /// Single-line row: current total + tiny delta badge. Great as an accordion label.
    private var compactRow: some View {
        HStack(spacing: 10) {
            Text("Collection Value")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(currentTotal > 0
                 ? currentTotal.formatted(.currency(code: "USD"))
                 : "—")
                .font(.subheadline.weight(.semibold))

            if let pct = pctDelta {
                deltaBadge(value: absDelta, pct: pct, up: absDelta >= 0)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Collection value summary")
    }

    /// Original rich card with picker + sparkline.
    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Title + range picker
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collection Value")
                        .font(.headline)
                    Text(currentTotal > 0
                         ? currentTotal.formatted(.currency(code: "USD"))
                         : "—")
                        .font(.title2.weight(.semibold))
                }

                Spacer()

                Picker("", selection: $selectedRange) {
                    ForEach(Range.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            // Delta row
            HStack(spacing: 12) {
                if let pct = pctDelta {
                    deltaBadge(value: absDelta, pct: pct, up: absDelta >= 0)
                } else {
                    Text("No trend yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.thinMaterial, in: Capsule())
                }
                Spacer()
            }

            // Sparkline
            #if canImport(Charts)
            if #available(iOS 16.0, *) {
                if series.count >= 2 {
                    Chart {
                        ForEach(series) { pt in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Total", pt.value)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.brandPrimary)

                            if pt.id == series.last?.id {
                                PointMark(
                                    x: .value("Date", pt.date),
                                    y: .value("Total", pt.value)
                                )
                                .foregroundStyle(Theme.brandPrimary)
                            }
                        }
                    }
                    .frame(height: 110)
                } else {
                    placeholder
                }
            } else {
                placeholder
            }
            #else
            placeholder
            #endif

            Text(Constants.valueDisclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceAlt)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collection trend header")
    }

    private func deltaBadge(value: Double, pct: Double, up: Bool) -> some View {
        let sign = up ? "+" : "–"
        return HStack(spacing: 6) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
            Text("\(sign)\(abs(value).formatted(.currency(code: "USD")))")
            if pct.isFinite {
                Text("(\(String(format: "%@%.1f%%", sign, abs(pct))))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background((up ? Color.green.opacity(0.15) : Color.red.opacity(0.15)), in: Capsule())
    }

    private var placeholder: some View {
        Text("Not enough data to draw a trend. Add manual values or run an estimate.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110)
    }
}
