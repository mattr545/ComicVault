//
//  DefectPhotoGalleryView.swift
//  ComicVault
//
//  File created on 11/08/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Horizontal gallery to browse and manage defect photos per comic.
//
//  Running Edit Log
//  - 11-08-25: Updated to avoid iOS 17-only onChange API and clarified max() usage.
//  - 11-09-25: Routed PhotosPicker changes through onChangeCompat.
//

import SwiftUI
import UIKit
#if canImport(PhotosUI)
import PhotosUI
#endif

struct DefectPhotoGalleryView: View {
    @EnvironmentObject private var vm: CollectionViewModel
    let comicID: UUID

    #if canImport(PhotosUI)
    @State private var pickerItems: [PhotosPickerItem] = []
    #endif

    private var photos: [DefectPhoto] {
        vm.defectPhotos(for: comicID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Photos & Defects", systemImage: "photo.stack")
                    .font(.headline)
                Spacer()
                uploadButton
            }

            if photos.isEmpty {
                Text("Add photos of your actual copy and its defects to support more accurate grading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            if let uiImage = UIImage(data: photo.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 120)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        Button {
                                            vm.removeDefectPhoto(for: comicID, photoID: photo.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                        }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                                    .softCardShadow()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Upload

    @ViewBuilder
    private var uploadButton: some View {
        #if canImport(PhotosUI)
        if #available(iOS 16.0, *) {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "plus.circle.fill")
                    .cvIcon(size: 22, useGoldHighlight: true)
            }
            .onChangeCompat(of: pickerItems) { newItems in
                handlePickedItems(newItems)
            }
        } else {
            Button {
                // iOS 15 fallback: could add UIImagePickerController wrapper later.
            } label: {
                Image(systemName: "plus.circle")
                    .cvIcon(size: 22)
            }
        }
        #else
        EmptyView()
        #endif
    }

    #if canImport(PhotosUI)
    @available(iOS 16.0, *)
    private func handlePickedItems(_ items: [PhotosPickerItem]) {
        for item in items {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let downsized = data.downsizedJPEGData(maxDimension: 1600, quality: 0.7) {
                    vm.addDefectPhoto(for: comicID, data: downsized, label: nil)
                }
            }
        }
    }
    #endif
}

#if canImport(UIKit)
private extension Data {
    /// Downsize + recompress to keep local storage reasonable.
    func downsizedJPEGData(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: self) else { return nil }
        let size = image.size
        let maxSide = Swift.max(size.width, size.height)
        let scale = (maxSide > maxDimension && maxSide > 0)
            ? (maxDimension / maxSide)
            : 1.0
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.jpegData(compressionQuality: quality)
    }
}
#endif
