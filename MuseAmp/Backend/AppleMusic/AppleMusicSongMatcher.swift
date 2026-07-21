//
//  AppleMusicSongMatcher.swift
//  MuseAmp
//
//  Created by Hwang on 2026/07/20.
//

import Foundation
import MuseAmpDatabaseKit
import SubsonicClientKit

nonisolated struct AppleMusicMatchCandidate {
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMillis: Int?
}

nonisolated enum AppleMusicSongMatchScorer {
    static let acceptanceThreshold: Double = 5.5
    static let durationToleranceMillis = 5000

    /// Returns nil when the candidate title has no overlap with the target
    /// title; otherwise a score that must reach `acceptanceThreshold`.
    static func score(
        _ candidate: AppleMusicMatchCandidate,
        against target: AppleMusicSongSummary,
    ) -> Double? {
        let candidateTitle = normalize(candidate.title)
        let targetTitle = normalize(target.title)
        guard !candidateTitle.isEmpty, !targetTitle.isEmpty else { return nil }

        var score: Double = 0
        if candidateTitle == targetTitle {
            score += 4
        } else if candidateTitle.contains(targetTitle) || targetTitle.contains(candidateTitle) {
            score += 2
        } else {
            return nil
        }

        let candidateArtist = normalize(candidate.artistName)
        let targetArtist = normalize(target.artistName)
        if !candidateArtist.isEmpty, !targetArtist.isEmpty {
            if candidateArtist == targetArtist {
                score += 3
            } else if candidateArtist.contains(targetArtist) || targetArtist.contains(candidateArtist) {
                score += 1.5
            }
        }

        if let candidateMillis = candidate.durationMillis,
           let targetMillis = target.durationMillis,
           abs(candidateMillis - targetMillis) <= durationToleranceMillis
        {
            score += 2
        }

        if let candidateAlbum = candidate.albumTitle.map(normalize),
           let targetAlbum = target.albumTitle.map(normalize),
           !candidateAlbum.isEmpty, candidateAlbum == targetAlbum
        {
            score += 1
        }

        return score
    }

    private static let apostrophes: Set<Character> = ["'", "’", "`", "ʼ"]

    static func normalize(_ raw: String) -> String {
        let folded = raw.folding(
            options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive],
            locale: nil,
        )
        let spaced = String(folded.compactMap { character -> Character? in
            if apostrophes.contains(character) {
                return nil
            }
            let isPunctuation = character.unicodeScalars.allSatisfy {
                CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0)
            }
            return isPunctuation ? " " : character
        })
        return spaced
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

final nonisolated class AppleMusicSongMatcher: Sendable {
    private let apiClient: APIClient
    private let searchLimit = 10

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func matchSong(_ song: AppleMusicSongSummary) async -> PlaylistEntry? {
        let primaryQuery = [song.title, song.artistName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if let entry = await bestMatch(query: primaryQuery, for: song) {
            return entry
        }
        guard primaryQuery != song.title else { return nil }
        return await bestMatch(query: song.title, for: song)
    }

    private func bestMatch(query: String, for song: AppleMusicSongSummary) async -> PlaylistEntry? {
        guard !query.isEmpty else { return nil }
        let candidates: [CatalogSong]
        do {
            candidates = try await apiClient.searchSongs(query: query, limit: searchLimit, offset: 0)
        } catch {
            AppLog.warning(self, "bestMatch search failed query=\(query) error=\(error)")
            return nil
        }

        var best: (song: CatalogSong, score: Double)?
        for candidate in candidates {
            let fields = AppleMusicMatchCandidate(
                title: candidate.attributes.name,
                artistName: candidate.attributes.artistName,
                albumTitle: candidate.attributes.albumName,
                durationMillis: candidate.attributes.durationInMillis,
            )
            guard let score = AppleMusicSongMatchScorer.score(fields, against: song),
                  score >= AppleMusicSongMatchScorer.acceptanceThreshold
            else { continue }
            if score > (best?.score ?? 0) {
                best = (candidate, score)
            }
        }
        return best?.song.playlistEntry()
    }
}
