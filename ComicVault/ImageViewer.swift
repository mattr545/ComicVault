//
//  ImageViewer.swift
//  ComicVault
//
//  File created on 10/22/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Fullscreen image viewer for covers and defect photos.
//
//  Running Edit Log
//  - 10-23-25: Fullscreen swipe viewer with dimmed background and swipe down to dismiss.
//              Delete button calls back to the parent for confirmation first.
//
//  NOTES
//  This is a simple fullscreen gallery. It uses a paged TabView for left-right swiping.
//  We keep the chrome minimal. A Close button at top right, and a Delete button at bottom.
//

import SwiftUI
import UIKit

struct ImageViewer: View {
    let images: [Data]
    var startIndex: Int = 0
    var onDeleteCurrent: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(images: [Data], startIndex: Int = 0, onDeleteCurrent: @escaping (Int) -> Void) {
        self.images = images
        self.startIndex = min(max(0, startIndex), max(0, images.count - 1))
        self.onDeleteCurrent = onDeleteCurrent
        _index = State(initialValue: self.startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            if images.isEmpty {
                Text("No images")
                    .foregroundStyle(.white)
            } else {
                TabView(selection: $index) {
                    ForEach(images.indices, id: \.self) { i in
                        if let ui = UIImage(data: images[i]) {
                            ZoomableImage(uiImage: ui)
                                .tag(i)
                        } else {
                            Color.black.tag(i)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.height > 80 {
                            dismiss()
                        }
                    }
                )
            }

            // Top right close
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .padding([.top, .trailing], 16)
                Spacer()
            }

            // Bottom delete
            if !images.isEmpty {
                VStack {
                    Spacer()
                    Button(role: .destructive) {
                        onDeleteCurrent(index)
                    } label: {
                        Label("Delete Photo", systemImage: "trash")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .tint(.red)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// Pinch to zoom helper
private struct ZoomableImage: View {
    let uiImage: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = max(1.0, min(scale, 4.0))
                            scale = lastScale
                        }
                )
        }
        .ignoresSafeArea()
    }
}
