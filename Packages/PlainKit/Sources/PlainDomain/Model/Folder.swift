import Foundation

public struct Folder: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var sortIndex: Int

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}
