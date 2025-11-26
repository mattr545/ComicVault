//
//  GradingWizardView.swift
//  ComicVault
//
//  File created on 11/08/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Step-by-step wizard to capture condition checklist and suggest a grade range.
//

import SwiftUI

struct GradingWizardView: View {
    let comic: Comic
    let onSave: (_ checklist: ConditionChecklist, _ suggestion: GradeSuggestion) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var checklist: ConditionChecklist
    @State private var suggestion: GradeSuggestion?

    init(comic: Comic,
         onSave: @escaping (_ checklist: ConditionChecklist, _ suggestion: GradeSuggestion) -> Void) {
        self.comic = comic
        self.onSave = onSave
        _checklist = State(initialValue: comic.conditionChecklist ?? ConditionChecklist())
        _suggestion = State(initialValue: comic.suggestedGradeRange)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Spine & Corners")) {
                    Stepper("Light spine ticks: \(checklist.spineTicksLight)",
                            value: $checklist.spineTicksLight,
                            in: 0...12)
                    Stepper("Color-breaking ticks: \(checklist.spineTicksColorBreaking)",
                            value: $checklist.spineTicksColorBreaking,
                            in: 0...12)

                    Picker("Corner wear", selection: $checklist.cornerWear) {
                        Text("None").tag(0)
                        Text("Slight").tag(1)
                        Text("Heavy").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Surface & Color")) {
                    Toggle("Surface wear / gloss loss", isOn: $checklist.surfaceWear)
                    Toggle("Color-breaking crease(s)", isOn: $checklist.colorBreaks)
                }

                Section(header: Text("Tears & Structure")) {
                    Toggle("Small tear (≤ 1/2\")", isOn: $checklist.smallTear)
                    Toggle("Large tear / piece missing", isOn: $checklist.largeTearOrPieceMissing)
                    Toggle("Detached/loose cover or centerfold", isOn: $checklist.detachedOrLooseCoverOrCenterfold)
                }

                Section(header: Text("Other Issues")) {
                    Toggle("Stains / smudges", isOn: $checklist.stains)
                    Toggle("Writing / coloring inside or on cover", isOn: $checklist.writingOrColoring)
                    Toggle("Rusty / damaged staples", isOn: $checklist.rustyOrDamagedStaples)
                    Toggle("General waviness / warping", isOn: $checklist.generalWaveOrWarp)
                }

                if let s = suggestion {
                    Section(header: Text("Suggested Grade Range")) {
                        Text("\(s.minGrade) – \(s.maxGrade)")
                            .font(.title3.weight(.semibold))
                        Text(s.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Grade Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let s = GradingEngine.suggest(from: checklist)
                        suggestion = s
                        onSave(checklist, s)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(comic.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            .onAppear {
                if suggestion == nil {
                    suggestion = GradingEngine.suggest(from: checklist)
                }
            }
        }
    }
}

