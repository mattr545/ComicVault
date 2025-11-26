//
//  ComicDetailView.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Comic details, metadata chips, manual/estimated values, grading, defects, and history link.
//
//  Running Edit Log
//  - 10-27-25: Initial layout with chips and value controls.
//  - 11-07-25: Wired to PriceService router and ValueHistory.
//  - 11-08-25: Header normalization.
//  - 11-09-25: Integrated grading wizard + defect photo gallery.
//
import SwiftUI
import UIKit

struct ComicDetailView: View {
    @EnvironmentObject private var vm: CollectionViewModel
    let comic: Comic

    @State private var manualValueText: String = ""
    @State private var working = false
    @State private var lastChecked: Date?
    @State private var showGrading = false

    /// Always prefer the latest instance from the ViewModel so updates stay in sync.
    private var liveComic: Comic {
        vm.comics.first(where: { $0.id == comic.id }) ?? comic
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Title
                Text(liveComic.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.leading)

                // Primary chips
                WrapHStack(spacing: 8, runSpacing: 8) {
                    if let n = liveComic.issueNumber { pill("Issue #\(n)") }
                    if let v = liveComic.volume      { pill("Vol. \(v)") }
                    if let y = liveComic.year        { pill("\(y)") }
                    if let p = liveComic.publisher, !p.isEmpty { pill(p) }
                    pill(StorageConfig.label(forStoredKey: liveComic.storageLocation))
                }

                // Key flags
                if let flags = liveComic.keyFlags, !flags.isEmpty {
                    WrapHStack(spacing: 8, runSpacing: 8) {
                        ForEach(flags, id: \.self) { f in pill(flagLabel(f)) }
                    }
                }

                // First / Cameo
                if let fa = liveComic.firstAppearanceOf, !fa.isEmpty {
                    pill("First: \(fa)")
                }
                if let ca = liveComic.cameoOf, !ca.isEmpty {
                    pill("Cameo: \(ca)")
                }

                // Storyline tags
                if let tags = liveComic.storylineTags, !tags.isEmpty {
                    WrapHStack(spacing: 8, runSpacing: 8) {
                        ForEach(tags, id: \.self) { pill($0) }
                    }
                }

                // Variant notes
                if let vnotes = liveComic.variantNotes, !vnotes.isEmpty {
                    Text(vnotes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Value
                valueSection

                // Grading helper
                gradingSection

                // Defect photos
                DefectPhotoGalleryView(comicID: liveComic.id)
                    .environmentObject(vm)

                // Notes
                if let notes = liveComic.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        .withEditActions(for: comic)
        .onAppear {
            if let v = liveComic.currentValue {
                manualValueText = String(format: "%.2f", v)
            }
            if lastChecked == nil {
                lastChecked = liveComic.lastValueUpdate
            }
        }
        .sheet(isPresented: $showGrading) {
            GradingWizardView(comic: liveComic) { checklist, suggestion in
                Task {
                    await vm.applyGrading(
                        for: liveComic.id,
                        checklist: checklist,
                        suggestion: suggestion
                    )
                }
            }
        }
    }

    // MARK: - Value Section

    private var valueSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current Value")
                    Spacer()
                    Text(displayValue(for: liveComic))
                        .font(.title3.weight(.semibold))
                }

                HStack {
                    TextField("Manual value (USD)", text: $manualValueText)
                        .keyboardType(.decimalPad)
                    Button("Apply") { applyManual() }
                        .disabled(Double(manualValueText) == nil || Double(manualValueText)! < 0)
                }

                Button {
                    Task { await estimate() }
                } label: {
                    if working {
                        ProgressView()
                    } else {
                        Label("Estimate Value", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(working)

                NavigationLink {
                    ComicHistoryView(comic: liveComic)
                        .environmentObject(vm)
                } label: {
                    Label("View Value History", systemImage: "clock.arrow.circlepath")
                }

                if let last = lastChecked {
                    Text("Last checked: \(relativeDate(last))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(Constants.valueDisclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceAlt)
            )
        } header: {
            Text("Value").font(.headline)
        }
    }

    // MARK: - Grading Section

    private var gradingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = liveComic.suggestedGradeRange {
                HStack {
                    Text("Suggested Grade Range")
                        .font(.headline)
                    Spacer()
                    Text("\(s.minGrade) – \(s.maxGrade)")
                        .font(.headline)
                }

                if let floor = liveComic.gradeFloorValueHint,
                   let ceil = liveComic.gradeCeilingValueHint {
                    let sourceSuffix = liveComic.gradeHintSource.map { " via \($0)" } ?? ""
                    Text("Value hint: \(floor.formatted(.currency(code: "USD"))) – \(ceil.formatted(.currency(code: "USD")))\(sourceSuffix)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let src = liveComic.gradeHintSource {
                    Text("Hints via \(src)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(s.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    showGrading = true
                } label: {
                    Label("Refine Checklist", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showGrading = true
                } label: {
                    Label("Run Grade Helper", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceAlt)
        )
    }

    // MARK: - Actions

    private func applyManual() {
        guard let v = Double(manualValueText), v >= 0 else { return }
        vm.addValuePoint(for: liveComic.id, value: v, source: .manual, note: nil)
        Haptics.success()
    }

    private func estimate() async {
        working = true
        defer { working = false }

        let result = await PriceService.estimateValue(for: liveComic)
        if let v = result.updatedComic.currentValue {
            vm.addValuePoint(for: liveComic.id,
                             value: v,
                             source: .estimated,
                             note: result.quote?.source)
            lastChecked = result.quote?.obtainedAt ?? Date()
            Haptics.success()
        } else {
            Haptics.warning()
        }
    }

    // MARK: - Helpers

    private func displayValue(for comic: Comic) -> String {
        comic.currentValue?
            .formatted(.currency(code: "USD")) ?? "-"
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.brandPrimary.opacity(0.12), in: Capsule())
    }

    private func flagLabel(_ f: KeyFlag) -> String {
        switch f {
        case .firstAppearance:   return "First Appearance"
        case .origin:            return "Origin"
        case .death:             return "Death"
        case .cameo:             return "Cameo"
        case .majorEvent:        return "Major Event"
        case .iconicCover:       return "Iconic Cover"
        case .errorPrint:        return "Error Print"
        case .newsstand:         return "Newsstand"
        case .direct:            return "Direct"
        case .retailerIncentive: return "Retailer Incentive"
        case .signed:            return "Signed"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chip flow layout helpers

@available(iOS 16.0, *)
fileprivate struct FlowRows: Layout {
    var spacing: CGFloat = 8
    var runSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + (x > 0 ? spacing : 0)
        }

        return CGSize(width: min(maxWidth, x), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            sub.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + (x > 0 ? spacing : 0)
        }
    }
}

fileprivate struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let runSpacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 8,
         runSpacing: CGFloat = 8,
         @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.runSpacing = runSpacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            FlowRows(spacing: spacing, runSpacing: runSpacing) {
                content
            }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}
