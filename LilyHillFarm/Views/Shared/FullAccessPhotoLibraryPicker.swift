//
//  FullAccessPhotoLibraryPicker.swift
//  LilyHillFarm
//
//  Custom photo picker that uses PHAsset APIs for true full library access
//

import SwiftUI
import Photos

struct FullAccessPhotoLibraryPicker: View {
    @Environment(\.dismiss) private var dismiss

    let maxSelection: Int
    let onImagesPicked: ([UIImage]) -> Void

    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedAssets: [PHAsset] = []
    @State private var allPhotos: [PHAsset] = []
    @State private var isLoadingImages = false

    var body: some View {
        NavigationView {
            Group {
                switch authorizationStatus {
                case .notDetermined:
                    requestPermissionView
                case .authorized:
                    photoGridView
                case .limited:
                    limitedAccessView
                case .denied, .restricted:
                    deniedAccessView
                @unknown default:
                    deniedAccessView
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if authorizationStatus == .authorized && !selectedAssets.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add (\(selectedAssets.count))") {
                            loadSelectedImages()
                        }
                    }
                }
            }
        }
        .onAppear {
            checkAuthorization()
        }
    }

    // MARK: - Views

    private var requestPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("LilyHillFarm needs full access to your photo library to select and attach photos to cattle records.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: requestFullAuthorization) {
                Text("Grant Full Access")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 2) {
                ForEach(allPhotos, id: \.localIdentifier) { asset in
                    PhotoThumbnailView(
                        asset: asset,
                        isSelected: selectedAssets.contains(asset)
                    )
                    .onTapGesture {
                        toggleSelection(asset)
                    }
                }
            }
        }
        .overlay {
            if allPhotos.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading photos...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var limitedAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Limited Photo Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You've granted limited access. To select from all photos, please grant full access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: openSettings) {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: {
                // Use limited selection
                loadAllPhotos()
            }) {
                Text("Continue with Limited Access")
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }

    private var deniedAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Photo Access Denied")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please enable photo library access in Settings to select photos.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: openSettings) {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func checkAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if authorizationStatus == .authorized || authorizationStatus == .limited {
            loadAllPhotos()
        }
    }

    private func requestFullAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authorizationStatus = status
                if status == .authorized || status == .limited {
                    loadAllPhotos()
                }
            }
        }
    }

    private func loadAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var photos: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            photos.append(asset)
        }

        DispatchQueue.main.async {
            self.allPhotos = photos
        }
    }

    private func toggleSelection(_ asset: PHAsset) {
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        } else if selectedAssets.count < maxSelection {
            selectedAssets.append(asset)
        }
    }

    private func loadSelectedImages() {
        isLoadingImages = true

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat

        var images: [UIImage] = []
        let group = DispatchGroup()

        for asset in selectedAssets {
            group.enter()
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                if let image = image {
                    images.append(image)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isLoadingImages = false
            onImagesPicked(images)
            dismiss()
        }
    }

    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay {
                        ProgressView()
                    }
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color.white))
                    .padding(4)
            }
        }
        .overlay {
            if isSelected {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 3)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isSynchronous = false

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: requestOptions
        ) { image, _ in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}
