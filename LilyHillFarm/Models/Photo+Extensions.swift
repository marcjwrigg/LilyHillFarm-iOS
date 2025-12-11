//
//  Photo+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Photo {

    // MARK: - Computed Properties

    var owner: String {
        if cattle != nil {
            return "Cattle"
        } else if healthRecord != nil {
            return "Health Record"
        } else if calvingRecord != nil {
            return "Calving Record"
        } else if pregnancyRecord != nil {
            return "Pregnancy Record"
        }
        return "Unknown"
    }

    var ownerReference: NSManagedObject? {
        return cattle ?? healthRecord ?? calvingRecord ?? pregnancyRecord
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, in context: NSManagedObjectContext) -> Photo {
        let photo = Photo(context: context)
        photo.id = UUID()
        photo.cattle = cattle
        photo.dateTaken = Date()
        photo.createdAt = Date()
        photo.isPrimary = false
        return photo
    }

    static func create(for healthRecord: HealthRecord, in context: NSManagedObjectContext) -> Photo {
        let photo = Photo(context: context)
        photo.id = UUID()
        photo.healthRecord = healthRecord
        photo.dateTaken = Date()
        photo.createdAt = Date()
        photo.isPrimary = false
        return photo
    }

    static func create(for calvingRecord: CalvingRecord, in context: NSManagedObjectContext) -> Photo {
        let photo = Photo(context: context)
        photo.id = UUID()
        photo.calvingRecord = calvingRecord
        photo.dateTaken = Date()
        photo.createdAt = Date()
        photo.isPrimary = false
        return photo
    }

    static func create(for pregnancyRecord: PregnancyRecord, in context: NSManagedObjectContext) -> Photo {
        let photo = Photo(context: context)
        photo.id = UUID()
        photo.pregnancyRecord = pregnancyRecord
        photo.dateTaken = Date()
        photo.createdAt = Date()
        photo.isPrimary = false
        return photo
    }

    // MARK: - Image Handling

    #if os(iOS)
    func setThumbnail(from image: UIImage, compressionQuality: CGFloat = 0.8) {
        // Store full-resolution image (resized to max 1920px) for upload
        let maxDimension: CGFloat = 1920
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            // Resize if larger than max dimension
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            if let fullResData = resizedImage.jpegData(compressionQuality: compressionQuality) {
                self.thumbnailData = fullResData
            }
        } else {
            // Use original size if already smaller than max
            if let fullResData = image.jpegData(compressionQuality: compressionQuality) {
                self.thumbnailData = fullResData
            }
        }
    }

    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    #elseif os(macOS)
    func setThumbnail(from image: NSImage, compressionQuality: CGFloat = 0.8) {
        // Store full-resolution image (resized to max 1920px) for upload
        let maxDimension: CGFloat = 1920
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        var finalImage = image
        if scale < 1.0 {
            // Resize if larger than max dimension
            let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            finalImage = NSImage(size: newSize)
            finalImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(origin: .zero, size: newSize))
            finalImage.unlockFocus()
        }

        // Convert to JPEG data
        guard let cgImage = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) {
            self.thumbnailData = jpegData
        }
    }

    var thumbnailImage: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }
    #endif

    // MARK: - Primary Photo Management

    func makePrimary() {
        // Remove primary flag from other photos in the same group
        if let cattle = cattle {
            let allPhotos = cattle.photos?.allObjects as? [Photo] ?? []
            allPhotos.forEach { $0.isPrimary = false }
        } else if let healthRecord = healthRecord {
            let allPhotos = healthRecord.photos?.allObjects as? [Photo] ?? []
            allPhotos.forEach { $0.isPrimary = false }
        } else if let calvingRecord = calvingRecord {
            let allPhotos = calvingRecord.photos?.allObjects as? [Photo] ?? []
            allPhotos.forEach { $0.isPrimary = false }
        } else if let pregnancyRecord = pregnancyRecord {
            let allPhotos = pregnancyRecord.photos?.allObjects as? [Photo] ?? []
            allPhotos.forEach { $0.isPrimary = false }
        }

        // Set this photo as primary
        self.isPrimary = true
    }
}
