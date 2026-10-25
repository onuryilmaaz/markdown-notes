import Foundation
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import ImageIO
import PlainDomain

struct ImportedPhotoFile: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImportedPhotoFile(url: copy)
        }
    }
}

struct PreparedPhoto: Sendable {
    let photo: NotePhoto
    let jpeg: Data
}

enum PhotoImport {
    static func prepare(_ item: PhotosPickerItem) async throws -> PreparedPhoto {
        guard let file = try await item.loadTransferable(type: ImportedPhotoFile.self) else { throw CocoaError(.fileReadCorruptFile) }
        defer { try? FileManager.default.removeItem(at: file.url) }
        let prepared = try await Task.detached(priority: .userInitiated) { try process(file.url) }.value
        try Task.checkCancellation()
        return prepared
    }

    /// Decode directly to a bounded image, respecting HEIC/portrait orientation.
    /// A separate tiny thumbnail keeps list and widget memory predictable.
    static func process(_ url: URL) throws -> PreparedPhoto {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let full = thumbnail(source, size: 2_048),
              let small = thumbnail(source, size: 320) else { throw CocoaError(.fileReadCorruptFile) }
        let jpeg = try encode(full, quality: 0.82)
        guard jpeg.count <= 5_000_000 else { throw CocoaError(.fileReadTooLarge) }
        return PreparedPhoto(
            photo: NotePhoto(thumbnail: try encode(small, quality: 0.7), pixelWidth: full.width, pixelHeight: full.height),
            jpeg: jpeg
        )
    }

    private static func thumbnail(_ source: CGImageSource, size: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }

    private static func encode(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
}
