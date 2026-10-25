import Foundation
import CoreSpotlight
import PlainDomain

/// Notes in the phone's own search. Indexing is diffed against what was last
/// published so an edit re-indexes one note, not the library.
@MainActor
enum SpotlightIndexer {
    static let domain = "co.plain.notes"

    private static var published: [UUID: Date] = [:]

    static func sync(notes: [Note]) {
        let lockedIDs = Set(notes.filter(\.isLocked).map(\.id))
        let notes = notes.filter { !$0.isLocked }
        let current = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0.updatedAt) })

        let changed = notes.filter { published[$0.id] != $0.updatedAt }
        let removed = Set(published.keys.filter { current[$0] == nil }).union(lockedIDs)

        published = current
        if !changed.isEmpty { index(changed) }
        if !removed.isEmpty { remove(Array(removed)) }
    }

    static func index(_ notes: [Note]) {
        let items = notes.map { note -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .plainText)
            attributes.title = note.title
            attributes.contentDescription = note.preview
            attributes.keywords = note.tags
            attributes.contentModificationDate = note.updatedAt
            attributes.textContent = PhotoMarkdown.strippingPhotos(from: note.body)

            let item = CSSearchableItem(
                uniqueIdentifier: note.id.uuidString,
                domainIdentifier: domain,
                attributeSet: attributes
            )
            item.expirationDate = .distantFuture
            return item
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }

    static func remove(_ ids: [UUID]) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids.map(\.uuidString))
    }

    static func removeAll() {
        published.removeAll()
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
    }
}
