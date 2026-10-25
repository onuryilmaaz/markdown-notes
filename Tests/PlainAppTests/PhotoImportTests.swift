import XCTest
import UIKit
import ImageIO
import PlainDomain
@testable import Plain

@MainActor
final class PhotoImportTests: XCTestCase {
    func testLargePhotoIsDownsampledWithAnIndependentSmallThumbnail() throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_000)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_000))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(original.pngData()).write(to: url)
        let result = try PhotoImport.process(url)
        XCTAssertLessThanOrEqual(max(result.photo.pixelWidth, result.photo.pixelHeight), 2_048)
        XCTAssertEqual(Double(result.photo.pixelWidth) / Double(result.photo.pixelHeight), 1.5, accuracy: 0.01)
        let thumbnail = try XCTUnwrap(UIImage(data: result.photo.thumbnail))
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), 320)
        XCTAssertNotNil(UIImage(data: result.jpeg))
        XCTAssertLessThan(result.photo.thumbnail.count, result.jpeg.count)
    }

    func testUnsupportedFileProducesAnErrorRatherThanAnEmptyAttachment() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not an image".utf8).write(to: url)
        XCTAssertThrowsError(try PhotoImport.process(url))
    }

    func testPhotoExportRequiresOriginalBytes() {
        let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 10, pixelHeight: 10)
        let note = Note(title: "Trip", photos: [photo])
        XCTAssertThrowsError(try LibraryExchange.markdownFile(for: note))
        XCTAssertThrowsError(try LibraryExchange.archive(notes: [note], folderName: { _ in "Trip" }))
    }

    func testPDFIncludesASeparatePhotoPage() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
        }
        let bytes = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let photo = NotePhoto(thumbnail: bytes, pixelWidth: 100, pixelHeight: 80)
        let note = Note(title: "Trip", body: "# Trip\n\nA memory.", photos: [photo])
        let url = try NotePDF.file(for: note, bodySize: 15, photoData: { _ in bytes })
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertEqual(document.numberOfPages, 2)
    }
}

@MainActor
final class WidgetLinkTests: XCTestCase {
    func testWidgetURLsOpenTheirActualNote() throws {
        let id = UUID()
        XCTAssertEqual(DeepLink(url: WidgetSnapshot.noteURL(id)), .note(id))
        XCTAssertEqual(DeepLink(url: try XCTUnwrap(URL(string: "plain://home"))), .home)
    }
}
