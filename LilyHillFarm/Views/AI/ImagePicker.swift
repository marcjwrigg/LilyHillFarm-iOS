//
//  ImagePicker.swift
//  LilyHillFarm
//
//  Photo picker for AI chat image uploads
//

import SwiftUI
import PhotosUI

struct ImagePicker: View {
    @Binding var selectedImages: [UIImage]
    let maxImages: Int
    let onAddImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var photoPickerItems: [PhotosPickerItem] = []

    var remainingSlots: Int {
        max(0, maxImages - selectedImages.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if remainingSlots > 0 {
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: remainingSlots,
                        matching: .images
                    ) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("Select Photos")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("You can select up to \(remainingSlots) more image\(remainingSlots == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if selectedImages.count > 0 {
                                Text("\(selectedImages.count) / \(maxImages) selected")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .onChange(of: photoPickerItems) { items in
                        _Concurrency.Task {
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    onAddImage(image)
                                }
                            }
                            dismiss()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Maximum Images Selected")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("You've selected \(maxImages) images")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Add Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
