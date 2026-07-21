//
//  AppleMusicLibraryService.swift
//  MuseAmp
//
//  Created by Hwang on 2026/07/20.
//

import Foundation
import MusicKit

@available(iOS 16.0, macCatalyst 17.0, *)
final nonisolated class AppleMusicLibraryService: Sendable {
    func authorizationState() -> AppleMusicAuthorizationState {
        Self.state(from: MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AppleMusicAuthorizationState {
        let status = await MusicAuthorization.request()
        AppLog.info(self, "requestAuthorization status=\(status)")
        return Self.state(from: status)
    }

    func fetchLibraryPlaylists() async throws -> [AppleMusicPlaylistSummary] {
        AppLog.verbose(self, "fetchLibraryPlaylists")
        do {
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.sort(by: \.name, ascending: true)
            let response = try await request.response()
            let playlists = try await Self.collectAllItems(startingAt: response.items)
            AppLog.info(self, "fetchLibraryPlaylists returned \(playlists.count) playlists")
            return playlists.map {
                AppleMusicPlaylistSummary(
                    id: $0.id.rawValue,
                    name: $0.name,
                    curatorName: $0.curatorName,
                )
            }
        } catch {
            AppLog.error(self, "fetchLibraryPlaylists failed error=\(error)")
            throw error
        }
    }

    func fetchSongs(inPlaylistWithID playlistID: String) async throws -> [AppleMusicSongSummary] {
        AppLog.verbose(self, "fetchSongs playlistID=\(playlistID)")
        do {
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.filter(matching: \.id, equalTo: MusicItemID(playlistID))
            let response = try await request.response()
            guard let playlist = response.items.first else {
                AppLog.warning(self, "fetchSongs playlist not found playlistID=\(playlistID)")
                return []
            }
            let detailed = try await playlist.with([.tracks])
            guard let firstBatch = detailed.tracks else {
                AppLog.info(self, "fetchSongs playlistID=\(playlistID) has no tracks")
                return []
            }
            let tracks = try await Self.collectAllItems(startingAt: firstBatch)
            AppLog.info(self, "fetchSongs playlistID=\(playlistID) returned \(tracks.count) tracks")
            return tracks.map { track in
                AppleMusicSongSummary(
                    title: track.title,
                    artistName: track.artistName,
                    albumTitle: track.albumTitle,
                    durationMillis: track.duration.map { Int(($0 * 1000).rounded()) },
                )
            }
        } catch {
            AppLog.error(self, "fetchSongs failed playlistID=\(playlistID) error=\(error)")
            throw error
        }
    }
}

@available(iOS 16.0, macCatalyst 17.0, *)
private nonisolated extension AppleMusicLibraryService {
    static func state(from status: MusicAuthorization.Status) -> AppleMusicAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .authorized:
            .authorized
        @unknown default:
            .denied
        }
    }

    static func collectAllItems<Item>(
        startingAt collection: MusicItemCollection<Item>,
    ) async throws -> [Item] {
        var current = collection
        var items = Array(current)
        while current.hasNextBatch {
            guard let next = try await current.nextBatch() else { break }
            current = next
            items.append(contentsOf: next)
        }
        return items
    }
}
