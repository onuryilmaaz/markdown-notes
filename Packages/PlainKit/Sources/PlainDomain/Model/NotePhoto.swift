import Foundation

/// Lightweight metadata travels with a note. The full JPEG is fetched only
/// when the reader opens it or exports it, never for every list refresh.
public struct NotePhoto: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var thumbnail: Data
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), thumbnail: Data, pixelWidth: Int, pixelHeight: Int, createdAt: Date = .now) {
        self.id = id
        self.thumbnail = thumbnail
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
    }

    public var fileName: String { id.uuidString + ".jpg" }
}
