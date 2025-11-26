//
//  GradingInfoView.swift
//  ComicVault
//
//  File created on 10/19/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Educational view explaining grading terms, defects, and example photos.
//
//  Running Edit Log
//  - 11/08/25: Reformatted and annotated on 11/08/25.
//

//
//  GradingInfoView.swift
//  ComicVault
//
//  Created by RUSSELL, MATTHEW on 10/18/25.
//

import SwiftUI
import UIKit

// === STRUCT: GradingInfoView ===
// This view explains grading scales and links to an external guide.
struct GradingInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Overview
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How Comic Grading Works")
                                .font(.headline)
                            Text("""
Comic grading describes overall condition. Higher grade generally means fewer defects and a higher market value. The two common systems are the ten-point numeric scale (10.0–0.5) and the traditional letter scale (NM, VF, FN, VG, GD, FR, PR). When in doubt, be conservative and consider professional grading for high-value keys.
""")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Ten-point scale
                    SectionHeader("Ten-Point Grading Scale")

                    VStack(spacing: 10) {
                        GradeRow(title: "10.0 – Gem Mint",
                                 detail: "Essentially perfect; sharp corners, flawless surface, tight spine; extremely rare in the wild.")
                        GradeRow(title: "9.9 – Mint",
                                 detail: "Near-perfect; microscopic imperfections only visible under close inspection.")
                        GradeRow(title: "9.8 – Near Mint/Mint",
                                 detail: "Top-tier modern condition; very sharp with virtually no wear. Common benchmark for ‘investment-grade’ moderns.")
                        GradeRow(title: "9.6 – Near Mint+",
                                 detail: "Outstanding; minor manufacturing or handling hints (tiny spine tick, barely visible corner rub).")
                        GradeRow(title: "9.4 – Near Mint",
                                 detail: "Excellent copy; very small stress or color break allowed, still bright and tight.")
                        GradeRow(title: "9.2 – Near Mint−",
                                 detail: "High-grade; a couple of small, non-distracting defects possible.")
                        GradeRow(title: "9.0 – Very Fine/Near Mint",
                                 detail: "Clean and glossy with light overall wear.")
                        GradeRow(title: "8.5 – Very Fine+",
                                 detail: "High eye appeal; a few minor defects such as light spine ticks or slight corner blunting.")
                        GradeRow(title: "8.0 – Very Fine",
                                 detail: "Presentable; small accumulation of minor wear but no major defects.")
                        GradeRow(title: "7.5 – Very Fine−",
                                 detail: "Solid copy showing some handling; mild stresses and tiny color breaks possible.")
                        GradeRow(title: "7.0 – Fine/Very Fine",
                                 detail: "Light overall wear; small creases or stress lines that may show light color break.")
                        GradeRow(title: "6.5 – Fine+",
                                 detail: "Noticeable but moderate wear; still attractive.")
                        GradeRow(title: "6.0 – Fine",
                                 detail: "General wear with minor creasing, small tears, or spine stress; still structurally sound.")
                        GradeRow(title: "5.5 – Fine−",
                                 detail: "Similar to FN with slightly more wear.")
                        GradeRow(title: "5.0 – Very Good/Fine",
                                 detail: "Moderate wear; small splits or tears possible; staples firm.")
                        GradeRow(title: "4.5 – Very Good+",
                                 detail: "Increasing wear; small pieces out or more visible creases possible.")
                        GradeRow(title: "4.0 – Very Good",
                                 detail: "Overall wear, multiple small defects, still complete and readable.")
                        GradeRow(title: "3.5 – Very Good−",
                                 detail: "Heavier general wear; may include small chips or larger creases.")
                        GradeRow(title: "3.0 – Good/Very Good",
                                 detail: "Well-read; small pieces out, creasing, and minor writing possible.")
                        GradeRow(title: "2.5 – Good+",
                                 detail: "Heavier wear but solid; defects more pronounced.")
                        GradeRow(title: "2.0 – Good",
                                 detail: "Significant wear; cover and pages intact; may have splits, tears, writing, or stains.")
                        GradeRow(title: "1.8 – Good−",
                                 detail: "Approaching Fair; still complete.")
                        GradeRow(title: "1.5 – Fair/Good",
                                 detail: "Heavy wear; multiple defects; complete but fragile.")
                        GradeRow(title: "1.0 – Fair",
                                 detail: "Major defects; pieces out, heavy creasing, possible detached cover; still mostly complete.")
                        GradeRow(title: "0.5 – Poor",
                                 detail: "Severely damaged; large pieces missing, brittle; used as fillers or for restoration.")
                    }

                    // Traditional scale
                    SectionHeader("Traditional Letter Grades")

                    VStack(spacing: 10) {
                        GradeRow(title: "NM (Near Mint)",
                                 detail: "High-grade copy with virtually no wear; sharp corners, glossy cover, tight spine.")
                        GradeRow(title: "VF (Very Fine)",
                                 detail: "Excellent overall with minor wear; a few small spine ticks or light corner rub.")
                        GradeRow(title: "FN (Fine)",
                                 detail: "Moderate wear visible; small creases, minor color breaks, light stress lines.")
                        GradeRow(title: "VG (Very Good)",
                                 detail: "Well-read but intact; creases, small tears, or minor writing may be present.")
                        GradeRow(title: "GD (Good)",
                                 detail: "Significant wear; possible splits, stains, or writing; complete and readable.")
                        GradeRow(title: "FR (Fair)",
                                 detail: "Major defects; detached cover or centerfold possible; best used as placeholder.")
                        GradeRow(title: "PR (Poor)",
                                 detail: "Severely worn or incomplete; extensive damage; often only for parts or restoration.")
                    }

                    // Disclaimer
                    SectionHeader("Important Note on Values")
                    Text(Constants.valueDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    // External reference link
                    LinkButton(
                        title: "View Full Grading Guide at MyComicShop",
                        systemImage: "link",
                        url: URL(string: "https://www.mycomicshop.com/help/grading")!
                    )
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Grading Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Subviews

private struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

private struct GradeRow: View {
    let title: String
    let detail: String
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        } label: {
            Text(title)
                .font(.headline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct LinkButton: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
    }
}

#Preview {
    GradingInfoView()
}
