//
//  TipsAndTricksView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: View showing helpful usage tips and tricks for ComicVault.
//
//  Running Edit Log
//  - 10-22-25: First full implementation of categorized accordion FAQ.
//  - 10-22-25: Styled category headers with brand color, no numbering, links supported.
//  - 10-22-25: Removed filler notes.
//
//  NOTES
//  This screen presents Tips & Tricks as grouped accordions.
//  Category headers sit above each group (not inside accordions), tinted with Theme.brandPrimary.
//  Each question is a button row that expands to reveal the answer below it.
//
//  Security / privacy
//  - Pure local UI. No network calls here.
//  - Links open in Safari via Markdown parsing in Text.
//

import SwiftUI

// MARK: - Model

private struct FAQItem: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let answer: String   // Answers can include basic Markdown, including inline links.
}

private struct FAQCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [FAQItem]
}

// MARK: - View

struct TipsTricksView: View {

    // Grouped content (headers rendered outside the accordions)
    private let categories: [FAQCategory] = [
        FAQCategory(
            title: "Getting Started",
            items: [
                FAQItem(
                    question: "How do I add a comic to my collection?",
                    answer: "Open the **Collection** tab and tap **Add**. You can type details manually or, if online metadata is enabled, use ComicVine to prefill title and publisher."
                ),
                FAQItem(
                    question: "Can I scan barcodes to add comics faster?",
                    answer: "Yes. When adding a comic, choose **Scan Barcode** to read EAN, UPC, or QR codes. If online metadata is enabled, ComicVine will help prefill fields."
                ),
                FAQItem(
                    question: "Do I need an internet connection to use ComicVault?",
                    answer: "Only for optional features like ComicVine lookups and iCloud snapshots. Browsing, editing, searching, and sorting your collection works offline."
                ),
                FAQItem(
                    question: "Where is my collection data stored?",
                    answer: "Data is stored locally on your device. If you enable iCloud, snapshots are stored in your private iCloud Drive, tied to your Apple ID."
                ),
                FAQItem(
                    question: "What is the difference between Collection and Wishlist?",
                    answer: "**Collection** is for issues you own. **Wishlist** tracks the issues you want to buy, trade, or watch."
                ),
                FAQItem(
                    question: "Can I add notes to each comic?",
                    answer: "Yes. Use **Notes** to record grading details, signatures, variants, or anything else you care about."
                ),
                FAQItem(
                    question: "Can I edit comics after I add them?",
                    answer: "Yes. Tap a comic to view details, then tap **Edit** to update fields, assign storage, or adjust notes and value."
                )
            ]
        ),
        FAQCategory(
            title: "Backups & Storage",
            items: [
                FAQItem(
                    question: "What are snapshots and why do they matter?",
                    answer: "Snapshots are daily backups of your collection. They make it easy to recover from mistakes or device changes."
                ),
                FAQItem(
                    question: "How many snapshots should I keep?",
                    answer: "Ninety days is a good default. Adjust this under **More → Backup & Data** to fit your needs."
                ),
                FAQItem(
                    question: "What happens if I do not open the app for a while?",
                    answer: "Your most recent snapshot remains available. When you return, ComicVault will resume daily snapshots if enabled."
                ),
                FAQItem(
                    question: "How do I restore data on a new phone?",
                    answer: "Install ComicVault, sign in with the same Apple ID, enable iCloud snapshots under **Backup & Data**, then restore from your latest snapshot."
                ),
                FAQItem(
                    question: "Can I export my collection?",
                    answer: "CSV export is part of the Backup Center. You can share a CSV for spreadsheets or archival uses."
                )
            ]
        ),
        FAQCategory(
            title: "Online Metadata & ComicVine",
            items: [
                FAQItem(
                    question: "How do I enable online comic lookups?",
                    answer: "Go to **More → Settings**, toggle **Online Metadata** on, and provide a ComicVine API key to unlock lookups."
                ),
                FAQItem(
                    question: "What is a ComicVine API key and how do I get one?",
                    answer: "It is a free key that lets ComicVault fetch official comic data. Request one at [comicvine.gamespot.com/api](https://comicvine.gamespot.com/api) and paste it in Settings."
                ),
                FAQItem(
                    question: "Why is there a built in key already?",
                    answer: "We include a small shared key so you can try lookups. After a few queries you should add your own key for reliable results."
                )
            ]
        ),
        FAQCategory(
            title: "Collection Organization",
            items: [
                FAQItem(
                    question: "How do I organize comics into boxes or storage sections?",
                    answer: "Set your **Longbox** and **Shortbox** counts in **More → Collection Setup**, then assign each comic to a box when adding or editing."
                ),
                FAQItem(
                    question: "Can I track what my collection is worth?",
                    answer: "Yes. You can enter values manually or use the local estimator in the Edit screen. Values are displayed in your Collection and detail views."
                ),
                FAQItem(
                    question: "Does ComicVault support multiple series with the same name?",
                    answer: "Yes. If online metadata is enabled, matching considers volume and publisher, which helps separate different runs."
                ),
                FAQItem(
                    question: "What if I accidentally delete a comic?",
                    answer: "Use **Backup Center** to restore from your most recent snapshot."
                )
            ]
        ),
        FAQCategory(
            title: "Customization & Appearance",
            items: [
                FAQItem(
                    question: "Can I use Dark Mode or Light Mode?",
                    answer: "By default, the app follows your system appearance. You can set a preferred theme under **More → Appearance**."
                ),
                FAQItem(
                    question: "How do I search my collection?",
                    answer: "Use the **Search** field at the top of the Collection screen. You can search by title, issue number, publisher, or notes."
                ),
                FAQItem(
                    question: "Can I maintain multiple collections?",
                    answer: "Today the app manages one main collection per device. We plan to support multiple collections in a future update."
                )
            ]
        ),
        FAQCategory(
            title: "Community & Support",
            items: [
                FAQItem(
                    question: "Will ComicVault ever cost money?",
                    answer: "The app is free to use. Any future online integrations will be optional and clearly explained before activation."
                ),
                FAQItem(
                    question: "How can I share feedback or request features?",
                    answer: "Open **More → Help & Support → Contact Support** to send us a message. We read every request."
                ),
                FAQItem(
                    question: "How can I stay updated on new features?",
                    answer: "Follow CryptoComics on YouTube, Discord, and Facebook for release news and feature previews."
                )
            ]
        )
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(categories) { cat in
                        // Category header outside the accordions
                        Text(cat.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.brandPrimary)
                            .padding(.horizontal)

                        // Accordion group
                        VStack(spacing: 10) {
                            ForEach(cat.items) { item in
                                AccordionRow(question: item.question, answerMarkdown: item.answer)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Tips & Tricks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Accordion Row

private struct AccordionRow: View {
    let question: String
    let answerMarkdown: String

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    // Chevron
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(Theme.brandPrimary)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 16)

                    // Question
                    Text(question)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)

            if expanded {
                // Answer body; supports basic Markdown including inline links
                Text(.init(answerMarkdown))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 6)
            }
        }
        .animation(.default, value: expanded)
    }
}

// MARK: - Preview

#if DEBUG
struct TipsTricksView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { TipsTricksView() }
            .tint(Theme.brandPrimary)
    }
}
#endif
