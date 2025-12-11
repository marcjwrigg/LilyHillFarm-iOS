//
//  PhotoPickerView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
import PhotosUI
import Photos

#if os(iOS)
// MARK: - Image Picker Controller (Camera)
struct ImagePickerController: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController

        init(_ parent: ImagePickerController) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Picker View
struct PhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImages: [UIImage] = []
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false

    let onImagesSelected: ([UIImage]) -> Void
    let maxSelection: Int

    init(maxSelection: Int = 10, onImagesSelected: @escaping ([UIImage]) -> Void) {
        self.maxSelection = maxSelection
        self.onImagesSelected = onImagesSelected
    }

    // Request full photo library access using custom picker with PHAsset APIs
    private func requestPhotoLibraryAccess() {
        // Show custom picker that uses PHAsset APIs for true full access
        showPhotoLibrary = true
    }

    var body: some View {
        NavigationView {
            VStack {
                if selectedImages.isEmpty {
                    emptyPhotoState
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.red))
                                    }
                                    .padding(4)
                                }
                            }

                            // Add more button if under max selection
                            if selectedImages.count < maxSelection {
                                Button(action: {
                                    showActionSheet = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.blue)
                                        Text("Add More")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding()
                    }

                    Button(action: {
                        onImagesSelected(selectedImages)
                        dismiss()
                    }) {
                        Text("Add \(selectedImages.count) Photo\(selectedImages.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showActionSheet) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    requestPhotoLibraryAccess()
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePickerController(sourceType: .camera) { image in
                    if selectedImages.count < maxSelection {
                        selectedImages.append(image)
                    }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                FullAccessPhotoLibraryPicker(
                    maxSelection: maxSelection - selectedImages.count,
                    onImagesPicked: { images in
                        selectedImages.append(contentsOf: images)
                    }
                )
            }
        }
    }

    // MARK: - Empty State View

    private var emptyPhotoState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Add Photos")
                .font(.headline)

            Text("Choose up to \(maxSelection) photos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            showActionSheet = true
        }
    }

}

// MARK: - Photos Library Picker (for multiple selection)
struct PhotosLibraryPicker: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var isLoading = false
    @State private var showPicker = false

    let maxSelection: Int
    let onImagesSelected: ([UIImage]) -> Void

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty view - picker opens automatically
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .photosPicker(
            isPresented: $showPicker,
            selection: $selectedItems,
            maxSelectionCount: maxSelection,
            matching: .images
        )
        .onAppear {
            // Automatically open picker when view appears
            showPicker = true
        }
        .onChange(of: selectedItems) {
            guard !selectedItems.isEmpty else { return }
            isLoading = true

            _Concurrency.Task {
                loadedImages = []
                for item in selectedItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        loadedImages.append(image)
                    }
                }

                if !loadedImages.isEmpty {
                    onImagesSelected(loadedImages)
                }
                dismiss()
            }
        }
        .onChange(of: showPicker) {
            // If user dismisses picker without selecting, close the sheet
            if !showPicker && selectedItems.isEmpty {
                dismiss()
            }
        }
    }
}

#elseif os(macOS)
struct PhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImages: [NSImage] = []

    let onImagesSelected: ([NSImage]) -> Void
    let maxSelection: Int

    init(maxSelection: Int = 10, onImagesSelected: @escaping ([NSImage]) -> Void) {
        self.maxSelection = maxSelection
        self.onImagesSelected = onImagesSelected
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Photos")
                .font(.headline)

            if selectedImages.isEmpty {
                Button(action: openFilePicker) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Select Photos")
                            .font(.headline)

                        Text("Choose up to \(maxSelection) photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            Image(nsImage: selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }

                    Spacer()

                    Button(action: {
                        onImagesSelected(selectedImages)
                        dismiss()
                    }) {
                        Text("Add \(selectedImages.count) Photo\(selectedImages.count == 1 ? "" : "s")")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .padding()
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select up to \(maxSelection) photos"

        if panel.runModal() == .OK {
            selectedImages = panel.urls.prefix(maxSelection).compactMap { NSImage(contentsOf: $0) }
        }
    }
}
#endif

#Preview {
    #if os(iOS)
    PhotoPickerView(maxSelection: 5) { images in
        print("Selected \(images.count) images")
    }
    #else
    PhotoPickerView(maxSelection: 5) { images in
        print("Selected \(images.count) images")
    }
    #endif
}
