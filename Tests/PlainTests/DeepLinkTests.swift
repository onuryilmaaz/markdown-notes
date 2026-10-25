import Testing
import Foundation
@testable import PlainDomain

/// `DeepLink` lives in the app target, so these cover the domain half the app
/// relies on: the wiki-link URL contract that the same parser reads.
@Suite("Link URLs")
struct LinkURLTests {
    @Test("A wiki URL survives titles with punctuation")
    func wikiURLs() throws {
        for title in ["Spec", "Retry & timeouts", "9/11 report", "Düşünceler"] {
            let url = try #require(WikiLink.url(for: title))
            #expect(WikiLink.target(from: url) == title, "\(title)")
        }
    }

    @Test("Only our scheme answers")
    func scheme() throws {
        let ours = try #require(WikiLink.url(for: "Spec"))
        #expect(ours.scheme == "plain-note")
        #expect(WikiLink.target(from: try #require(URL(string: "plain://new?title=Spec"))) == nil)
    }
}
