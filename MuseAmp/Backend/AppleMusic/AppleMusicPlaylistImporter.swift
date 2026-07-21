//
//  AppleMusicPlaylistImporter.swift
//  MuseAmp
//
//  Created by Hwang on 2026/07/20.
//

import Foundation
import MuseAmpDatabaseKit

@available(iOS 16.0, macCatalyst 17.0, *)
final class AppleMusicPlaylistImporter {
    struct ImportResult {
        let playlistID: UUID?
        let playlistName: String
        let totalSongCount: Int
        let importedCount: Int
        let unmatchedSongs: [AppleMusicSongSummary]
    }

    private let libraryService = AppleMusicLibraryService()
    private let matcher: AppleMusicSongMatcher
    private let playlistStore: PlaylistStore
    private let maxConcurrentMatches = 4

    init(apiClient: APIClient, playlistStore: PlaylistStore) {
        matcher = AppleMusicSongMatcher(apiClient: apiClient)
        self.playlistStore = playlistStore
    }

    var authorizationState: AppleMusicAuthorizationState {
        libraryService.authorizationState()
    }

    func requestAuthorization() async -> AppleMusicAuthorizationState {
        await libraryService.requestAuthorization()
    }

    func fetchLibraryPlaylists() async throws -> [AppleMusicPlaylistSummary] {
        try await libraryService.fetchLibraryPlaylists()
    }

    func importPlaylist(
        _ playlist: AppleMusicPlaylistSummary,
        progressCallback: ((_ processed: Int, _ total: Int) -> Void)? = nil,
    ) async throws -> ImportResult {
        AppLog.info(self, "importPlaylist started id=\(playlist.id) name=\(playlist.name)")
        let songs = try await libraryService.fetchSongs(inPlaylistWithID: playlist.id)
        guard !songs.isEmpty else {
            AppLog.info(self, "importPlaylist name=\(playlist.name) has no songs")
            return ImportResult(
                playlistID: nil,
                playlistName: playlist.name,
                totalSongCount: 0,
                importedCount: 0,
                unmatchedSongs: [],
            )
        }

        let matches = await matchSongs(songs, progressCallback: progressCallback)
        let entries = matches.compactMap(\.self)
        let unmatched = zip(songs, matches).filter { $0.1 == nil }.map(\.0)
        guard !entries.isEmpty else {
            AppLog.warning(self, "importPlaylist matched none name=\(playlist.name) total=\(songs.count)")
            return ImportResult(
                playlistID: nil,
                playlistName: playlist.name,
                totalSongCount: songs.count,
                importedCount: 0,
                unmatchedSongs: unmatched,
            )
        }

        let created = playlistStore.importPlaylist(name: playlist.name, entries: entries)
        AppLog.info(
            self,
            "importPlaylist finished name=\(playlist.name) imported=\(entries.count)/\(songs.count)",
        )
        return ImportResult(
            playlistID: created.id,
            playlistName: playlist.name,
            totalSongCount: songs.count,
            importedCount: entries.count,
            unmatchedSongs: unmatched,
        )
    }

    private func matchSongs(
        _ songs: [AppleMusicSongSummary],
        progressCallback: ((_ processed: Int, _ total: Int) -> Void)?,
    ) async -> [PlaylistEntry?] {
        let matcher = matcher
        var results = [PlaylistEntry?](repeating: nil, count: songs.count)
        var processed = 0
        await withTaskGroup(of: (Int, PlaylistEntry?).self) { group in
            var nextIndex = 0
            func enqueueNext() {
                guard nextIndex < songs.count else { return }
                let index = nextIndex
                let song = songs[index]
                nextIndex += 1
                group.addTask { await (index, matcher.matchSong(song)) }
            }
            for _ in 0 ..< min(maxConcurrentMatches, songs.count) {
                enqueueNext()
            }
            while let (index, entry) = await group.next() {
                results[index] = entry
                processed += 1
                progressCallback?(processed, songs.count)
                enqueueNext()
            }
        }
        return results
    }
}
