//
//  GradingModels.swift
//  ComicVault
//
//  File created on 11/08/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Data models representing condition inputs, defect weights, and grade ranges.
//

import Foundation

/// Checklist of major condition signals.
/// Keep this intentionally small + friendly.
struct ConditionChecklist: Codable, Equatable {
    // Spine / cover
    var spineTicksLight: Int = 0           // tiny non–color-breaking
    var spineTicksColorBreaking: Int = 0   // color-breaking ticks
    var cornerWear: Int = 0                // 0 none, 1 slight, 2 heavy
    var surfaceWear: Bool = false          // mild scuffing, gloss loss
    var colorBreaks: Bool = false          // noticeable color breaks/creases

    // Structural
    var smallTear: Bool = false            // <= 1/2"
    var largeTearOrPieceMissing: Bool = false
    var detachedOrLooseCoverOrCenterfold: Bool = false

    // Other
    var stains: Bool = false
    var writingOrColoring: Bool = false    // marker, pen, crayon, etc.
    var rustyOrDamagedStaples: Bool = false
    var generalWaveOrWarp: Bool = false    // water ripple / warping
}

/// Suggested grade band + explanatory note.
struct GradeSuggestion: Codable, Equatable {
    let minGrade: String
    let maxGrade: String
    let note: String
}

/// Value hint range for a given grade band.
struct GradeValueRange: Codable, Equatable {
    let floor: Double?
    let ceiling: Double?
    let source: String
}

/// Lightweight rules engine for turning checklist → grade band.
/// This is intentionally conservative and clearly non-official.
enum GradingEngine {

    static func suggest(from c: ConditionChecklist) -> GradeSuggestion {
        // Start high, subtract per defect.
        var score: Double = 9.8

        func bump(_ amount: Double) {
            score = max(0.3, score - amount)
        }

        if c.spineTicksLight > 2 {
            bump(Double(c.spineTicksLight - 2) * 0.1)
        }

        if c.spineTicksColorBreaking > 0 {
            bump(Double(c.spineTicksColorBreaking) * 0.3)
        }

        if c.cornerWear == 1 { bump(0.3) }
        if c.cornerWear >= 2 { bump(0.7) }

        if c.surfaceWear { bump(0.3) }
        if c.colorBreaks { bump(0.5) }

        if c.smallTear { bump(1.0) }
        if c.largeTearOrPieceMissing { bump(3.0) }

        if c.stains { bump(0.7) }
        if c.writingOrColoring { bump(1.0) }

        if c.detachedOrLooseCoverOrCenterfold { bump(4.0) }
        if c.rustyOrDamagedStaples { bump(0.7) }
        if c.generalWaveOrWarp { bump(0.3) }

        let maxGrade = gradeString(from: score)
        let minScore = max(0.3, score - 1.5)
        let minGrade = gradeString(from: minScore)

        let note = "Suggested range based on your checklist. This is not an official third-party grade."

        return GradeSuggestion(minGrade: minGrade, maxGrade: maxGrade, note: note)
    }

    // Map numeric score to a simple CGC-style band.
    private static func gradeString(from score: Double) -> String {
        switch score {
        case 9.6...10: return "9.8–9.9"
        case 9.2..<9.6: return "9.4–9.6"
        case 8.5..<9.2: return "9.0–9.2"
        case 7.5..<8.5: return "8.0–8.5"
        case 6.5..<7.5: return "7.0–7.5"
        case 5.5..<6.5: return "6.0–6.5"
        case 4.5..<5.5: return "5.0–5.5"
        case 3.5..<4.5: return "4.0–4.5"
        case 2.5..<3.5: return "3.0–3.5"
        case 1.5..<2.5: return "2.0–2.5"
        case 0.8..<1.5: return "1.0–1.5"
        default:        return "0.3–0.5"
        }
    }
}

