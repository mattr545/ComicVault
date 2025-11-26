//
//  OurStoryView.swift
//  ComicVault
//
//  File created on 10/15/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Static page telling the ComicVault / CryptoComics story.
//
//  Running Edit Log
//  - 11-03-25: Replaced story with updated ApogeeINVENT / CryptoComics origin text.
//  - 10-27-25: Full rewrite to integrate CryptoComics origin and philosophy.
//  - 10-22-25: Markdown, link, fade-in, and footer metadata.
//  - 10-19-25 Initial story draft and layout.
//

import SwiftUI

struct OurStoryView: View {

    @State private var appeared = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var updatedStamp: String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text("Our Story")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.blue) // fallback for Theme.brandPrimary

                Text("Created by ApogeeINVENT\nIn conjunction with CryptoComics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 6)

                Group {
                    Text("""
ComicVault was created inside ApogeeINVENT, the same development lab behind CryptoComics, as a natural extension of what we’ve always believed in: using smart technology to make creative passions easier to manage. What started as a simple idea to track a few personal comics quickly evolved into a professional-grade cataloging system built for serious collectors and casual fans alike.
""")

                    Text("""
I’ve led this project on behalf of CryptoComics to give our community something we’ve always wanted ourselves: a reliable way to organize, monitor, and value comic collections without the frustration of spreadsheets or guesswork. ComicVault makes it easy to scan barcodes, record key details, track values, and even pull insights using AI assistance when available. Every piece of the app was built with collectors in mind, balancing automation with control so that your collection always feels personal, not automated.
""")

                    Text("""
At ApogeeINVENT, we build tools that empower people to do what they love, and ComicVault is no different. It reflects years of collaboration between developers, comic creators, and collectors who wanted something smarter than the old methods but still true to the spirit of collecting.
""")

                    Text("""
Your comics tell your story. ComicVault’s mission is to help you protect that story, one issue at a time.
""")
                }
                .textSelection(.enabled)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 0.4), value: appeared)
            .onAppear { appeared = true }

            VStack(alignment: .leading, spacing: 4) {
                Divider().padding(.vertical, 8)
                Text("App version \(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Last updated \(updatedStamp)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("Our Story")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        OurStoryView()
            .tint(.blue) // fallback; swap back to .tint(Theme.brandPrimary) when Theme is available
    }
}
