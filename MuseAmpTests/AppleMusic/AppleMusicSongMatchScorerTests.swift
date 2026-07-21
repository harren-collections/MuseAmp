import Foundation
@testable import MuseAmp
import Testing

struct AppleMusicSongMatchScorerTests {
    private func target(
        title: String = "Golden Hour",
        artist: String = "JVKE",
        album: String? = "This Is What ____ Feels Like (Vol. 1-4)",
        durationMillis: Int? = 209_000,
    ) -> AppleMusicSongSummary {
        AppleMusicSongSummary(
            title: title,
            artistName: artist,
            albumTitle: album,
            durationMillis: durationMillis,
        )
    }

    private func candidate(
        title: String = "Golden Hour",
        artist: String = "JVKE",
        album: String? = "This Is What ____ Feels Like (Vol. 1-4)",
        durationMillis: Int? = 209_000,
    ) -> AppleMusicMatchCandidate {
        AppleMusicMatchCandidate(
            title: title,
            artistName: artist,
            albumTitle: album,
            durationMillis: durationMillis,
        )
    }

    private func accepts(_ candidate: AppleMusicMatchCandidate, _ target: AppleMusicSongSummary) -> Bool {
        guard let score = AppleMusicSongMatchScorer.score(candidate, against: target) else {
            return false
        }
        return score >= AppleMusicSongMatchScorer.acceptanceThreshold
    }

    @Test func `exact title and artist is accepted`() {
        #expect(accepts(candidate(album: nil, durationMillis: nil), target()))
    }

    @Test func `unrelated title is rejected outright`() {
        let score = AppleMusicSongMatchScorer.score(
            candidate(title: "Completely Different Song"),
            against: target(),
        )
        #expect(score == nil)
    }

    @Test func `same title alone is not enough`() {
        #expect(!accepts(
            candidate(artist: "Someone Else", album: nil, durationMillis: nil),
            target(),
        ))
    }

    @Test func `same title with close duration is accepted`() {
        #expect(accepts(
            candidate(artist: "Someone Else", album: nil, durationMillis: 210_500),
            target(),
        ))
    }

    @Test func `duration outside tolerance does not corroborate`() {
        #expect(!accepts(
            candidate(artist: "Someone Else", album: nil, durationMillis: 245_000),
            target(),
        ))
    }

    @Test func `featured artist variant is accepted`() {
        #expect(accepts(
            candidate(artist: "JVKE feat. Ruel", album: nil, durationMillis: nil),
            target(),
        ))
    }

    @Test func `title variant needs corroboration beyond artist`() {
        let variantWithoutDuration = candidate(
            title: "Golden Hour (Acoustic)",
            album: nil,
            durationMillis: nil,
        )
        #expect(!accepts(variantWithoutDuration, target()))

        let variantWithDuration = candidate(
            title: "Golden Hour (Acoustic)",
            album: nil,
            durationMillis: 209_800,
        )
        #expect(accepts(variantWithDuration, target()))
    }

    @Test func `higher scoring candidate wins over variant`() throws {
        let exact = try #require(AppleMusicSongMatchScorer.score(candidate(), against: target()))
        let variant = try #require(AppleMusicSongMatchScorer.score(
            candidate(title: "Golden Hour (Sped Up)"),
            against: target(),
        ))
        #expect(exact > variant)
    }

    @Test func `normalization ignores case punctuation and diacritics`() {
        #expect(AppleMusicSongMatchScorer.normalize("Déjà Vu!") == AppleMusicSongMatchScorer.normalize("deja vu"))
        #expect(AppleMusicSongMatchScorer.normalize("  Golden   Hour ") == "golden hour")
        #expect(AppleMusicSongMatchScorer.normalize("Don't Stop") == AppleMusicSongMatchScorer.normalize("Dont Stop"))
    }

    @Test func `normalized comparison matches across formatting differences`() {
        #expect(accepts(
            candidate(title: "don't stop believin'", artist: "JOURNEY", album: nil, durationMillis: nil),
            target(title: "Don’t Stop Believin’", artist: "Journey", album: nil, durationMillis: nil),
        ))
    }
}
