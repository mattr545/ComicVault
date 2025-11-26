//
//  ValueChartView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Swift Charts-based value-over-time chart with colored points.
//
//  Running Edit Log
//  - 10-22-25: Added combined line + point chart.
//  - 11-08-25: Header normalization.
//
//
//  NOTES
//  Draws a simple value-over-time chart using Swift Charts (iOS 16+).
//  We render a unified line across all points, and color the dots by source.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct ValueChartView: View {
    /// The full, time-ordered set of points for this comic.
    let points: [ValuePoint]

    var body: some View {
        #if canImport(Charts)
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            if points.isEmpty {
                Text("No value history yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    let sorted = points.sorted { $0.date < $1.date }

                    // Unified line over time
                    ForEach(sorted) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                    }

                    // Dots colored by source
                    ForEach(sorted) { p in
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                        .foregroundStyle(style(for: p.source))
                    }
                }
                .chartYAxisLabel("USD")
                .chartYScale(domain: yDomain(for: points))
                .frame(height: 220)
            }
        } else {
            Text("Charts require a newer OS version.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        #else
        Text("Charts not available on this platform.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }

    // Pick simple, readable colors that work in light/dark.
    private func style(for source: ValueSource) -> some ShapeStyle {
        switch source {
        case .manual:
            return Color.green
        case .estimated:
            return Color.blue
        }
    }

    // Expand the y-axis a little so dots do not sit on the edges.
    private func yDomain(for pts: [ValuePoint]) -> ClosedRange<Double> {
        let vals = pts.map(\.value)
        guard let minV = vals.min(), let maxV = vals.max() else { return 0...1 }
        if minV == maxV {
            let base = max(minV, 0)
            return (base * 0.9)...(base * 1.1 + 1)
        }
        let pad = max(1.0, (maxV - minV) * 0.1)
        return max(0, minV - pad)...(maxV + pad)
    }
}
